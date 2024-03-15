<#
.SYNOPSIS
  EKM Provider Prerequisites Check

.DESCRIPTION
  Checks Vault connectivity, TLS, authentication, license entitlements, and Transit Secrets Engine key access.

.PARAMETER VaultAddress
  URL of Vault load balancer including protocol and port number.

.PARAMETER VaultNamespace
  Namespace to use for Vault authentication. If not using namespaces, leave blank.

.PARAMETER AppRoleID
  AppRole ID for authentication.

.PARAMETER AppRoleSecretID
  AppRole Secret ID for authentication.

.PARAMETER CertChainPath
  Path to write certificate chain files. Default is "$env:USERPROFILE\Downloads".

.PARAMETER TransitPath
  Transit Secrets Engine path. Default is "transit".

.PARAMETER TransitKey
  Transit Secrets Engine key name.

.EXAMPLE
    Example without namespace and with default Transit Secrets Engine path:
    .\CheckEKMProvider.ps1 `
      -VaultAddress https://vault.example.com:8200 `
      -AppRoleID 00000000-0000-0000-0000-000000000000 `
      -AppRoleSecretID 00000000-0000-0000-0000-000000000000 `
      -TransitKey tde-key

.EXAMPLE
    Example with namespace using default Transit Secrets Engine path:
    .\CheckEKMProvider.ps1 `
      -VaultAddress https://vault.example.com:8200 `
      -VaultNamespace foo `
      -AppRoleID 00000000-0000-0000-0000-000000000000 `
      -AppRoleSecretID 00000000-0000-0000-0000-000000000000 `
      -TransitKey tde-key
#>

[CmdletBinding()]
param (
  [Parameter(Mandatory=$true)]
  [string]$VaultAddress,
  [string]$VaultNamespace = "",
  [Parameter(Mandatory=$true)]
  [string]$AppRoleID,
  [Parameter(Mandatory=$true)]
  [string]$AppRoleSecretID,
  [string]$CertChainPath = "$env:USERPROFILE\Downloads",
  [string]$TransitPath = "transit",
  [Parameter(Mandatory=$true)]
  [string]$TransitKey
)

function Get-CertificateChain {
  param (
    [string]$Address,
    [string]$Path
  )

  if (-not $(Test-Path -Path $Path)) {
    New-Item -ItemType Directory -Path $Path
  }

  try {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} # skip tls verification so we can get the cert
    $req = [Net.WebRequest]::Create($Address)
    $req.Timeout = 5000 # 5 seconds
    $req.GetResponse().Dispose()
    #$chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    #$chain.Build($req.ServicePoint.Certificate) # this is a choking point for some reason
    #$chain.ChainElements.Certificate | ForEach-Object {
    #  Set-Content -Value $($_.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)) -Encoding Byte -Path "$Path\$($_.Thumbprint).cer"
    #  Write-Output "To inspect $($_.SubjectName.Name) execute =>  certutil -dump $Path\$($_.Thumbprint).cer"
    #}
    Set-Content -Value $($req.ServicePoint.Certificate.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)) -Encoding Byte -Path "$Path\$($_.Thumbprint).cer"
    Write-Output "To inspect $($_.SubjectName.Name) execute =>  certutil -dump $Path\$($_.Thumbprint).cer"
  }
  catch {
    Write-Output "Error building certificate chain: $_"
    Exit 1
  }
  finally {
    # reset tls verification
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
  }
}

#[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
$header = @{ "X-Vault-Namespace" = "$VaultNamespace" }
$uri = New-Object System.Uri($VaultAddress)

# Verify Connectivity and Authentication
try {
  $resp = Invoke-RestMethod -Method Post `
    -Uri "$VaultAddress/v1/auth/approle/login" `
    -Headers $header `
    -TimeoutSec 5 `
    -Body @{ "role_id" = "$AppRoleID"; "secret_id" = "$AppRoleSecretID" }
}
catch [System.UriFormatException] {
  Write-Output "$_"
  Write-Output "Verify VaultAddress is correct: $VAULT_ADDRESS"
  Exit 1
}
catch {
  if (-not $(Test-NetConnection -ComputerName $uri.Host -Port $uri.Port).TcpTestSucceeded) {
    Write-Output "TCP connection failed: $_"
    Write-Output "Check port, firewall rules, security groups, and for general networking-level issues"
    Exit 1
  }

  if ($_ -match '(?i)ssl|tls') {
    Write-Output "Verify signing Certificate Authority for Vault has been added to Windows Trust Store: $_"

    Write-Output "Attempting to build certificate chain from $VaultAddress"
    Get-CertificateChain -Address $VaultAddress -Path $CertChainPath
    Exit 1
  }

  if ($_ -match '(?i)permission denied|role id|secret id|alias name') {
    Write-Output "Verify VaultNamespace, AppRoleID, and AppRoleSecretID are correct: $_"
    Exit 1
  }

  Write-Output "Generic Auth check failure: $_"
  Exit 1
}

# Verify license entitlements
$header.Add("X-Vault-Token", $resp.auth.client_token)
$resp = Invoke-RestMethod -Uri "$VaultAddress/v1/sys/license/status" -header $header
if ( -not $($resp.data.autoloaded.features | Select-String "Key Management Transparent Data Encryption" -quiet) ) {
  Write-Output "Vault Enterprise license entitlement not found: Key Management Transparent Data Encryption"
  Exit 1
}

# Check Transit Secrets Engine
try {
  $resp = Invoke-RestMethod -Uri "$VaultAddress/v1/$TransitPath/keys/$TransitKey" -header $header
}
catch {
  if ($_ -match '(?i)permission denied') {
    Write-Output "Verify EKM Key path and ACL policy are correct: $_"
    Exit 1
  }

  Write-Output "Generic Transit check failure: $_"
  Exit 1
}


Write-Output "Success: prerequisite checks passed" 
Exit 0

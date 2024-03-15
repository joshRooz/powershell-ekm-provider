<#
.SYNOPSIS
  This script installs the Vault EKM Provider on a Windows machine.

.DESCRIPTION
  This script installs the Vault EKM Provider on a Windows machine.

.PARAMETER vaultApiBaseUrl
  The base URL of the Vault server's API endpoint. This should include the protocol and port number. For example, https://vault.example.com:8200.

.PARAMETER enableTrace
  Enable Vault EKM Provider trace logging. Default is false.

.PARAMETER namespace
  The namespace to use for Vault authentication. If not using namespaces, leave blank.

.PARAMETER appRoleMountPath
  The path to the AppRole authentication mount. If unset, the script will use the default AppRole mount.

.PARAMETER transitMountPath 
  The path to the Transit Secrets Engine mount. If unset, the script will use the default Transit mount.

.PARAMETER ekmVersion
  The version of the EKM Provider to install. Default is "0.2.2".

.PARAMETER ekmWorkingDir
  The directory where the EKM Provider archive will be downloaded and extracted. Default is "$Env:USERPROFILE\Downloads\ekm".

.PARAMETER skipEkmFetchRelease
  If set, the script will expect the EKM Provider archive to be pre-populated in $ekmWorkingDir named "vault-mssql-ekm-provider_<version>+ent_windows_amd64.zip."

.PARAMETER updateCerts
  If true, the script will update the Windows certificate store with the latest root certificates from Microsoft.
  Default is false.

.PARAMETER certsTempDir
  The directory that will be used to update the Windows certificate store. Default is "$Env:USERPROFILE\Downloads\certs".

.EXAMPLE
    Example installation with minimal parameters:
    .\DeployEKMProvider.ps1 `
      -vaultApiBaseUrl https://vault.example.com:8200 `
      -ekmVersion 0.2.2 `
      -updateCerts

.EXAMPLE
    Example offline installation with minimal parameters:
    .\DeployEKMProvider.ps1 `
      -vaultApiBaseUrl https://vault.example.com:8200 `
      -ekmVersion 0.2.2 `
      -skipEkmFetchRelease `
      -updateCerts `

.LINK
  - Script source repository: https://github.com/joshRooz/powershell-ekm-provider.git
  - Official HashiCorp Vault EKM Provider documentation: https://developer.hashicorp.com/vault/docs/platform/mssql
  - Official Microsoft SQL Server EKM documentation: https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/extensible-key-management-ekm
#>


# Get-Help .\DeployEKMProvider.ps1 -Full
[CmdletBinding()]
Param(
  # EKM Provider Config Parameters
  [Parameter(Mandatory=$true)]
  [string]$vaultApiBaseUrl,
  [bool]$enableTrace = $false,
  [string]$namespace = $null,
  [string]$appRoleMountPath = $null,
  [string]$transitMountPath = $null,

  # EKM Installation Parameters
  [string]$ekmVersion = "0.2.2",
  [string]$ekmWorkingDir = "$Env:USERPROFILE\Downloads\ekm",
  [switch]$skipEkmFetchRelease,
  [switch]$updateCerts,
  [string]$certsTempDir = "$Env:USERPROFILE\Downloads\certs"
)

function checkCreateDirectory ([string]$dir) {
  if (-not (Test-Path -Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
}

# Check if the EKM Provider installation exists
try {
  $installed = Get-Package -Name "Transit Vault EKM Provider" -ErrorAction Stop
  if ($installed.Status -eq "Installed") {
    Write-Output "EKM Provider is already installed. Version: $($installed.Version)."
    exit 0
  }
}
catch {
  Write-Debug "EKM Provider is not installed."
}

# Set the EKM Provider installation parameters
$os = "windows" ; $arch = "amd64" 
if (-not $ekmVersion.EndsWith("+ent")) {
  $ekmVersion += "+ent"
}
$archive = "{0}\vault-mssql-ekm-provider_{1}_{2}_{3}.zip" -f $ekmWorkingDir, $ekmVersion, $os, $arch


# Set the EKM configuration hashmap that will be merged into config.json
$config = @{}
foreach ($key in @('vaultApiBaseUrl', 'enableTrace', 'namespace', 'appRoleMountPath', 'transitMountPath')) {
  if ($null -ne $PSBoundParameters[$key] -and $PSBoundParameters[$key] -ne $false) {
    $config[$key] = $PSBoundParameters[$key]
  }
}

# Download the EKM Provider
if (-not $skipEkmFetchRelease) {
  checkCreateDirectory $ekmWorkingDir
  $ekmProviderSourceUrl = "https://releases.hashicorp.com/vault-mssql-ekm-provider/{0}/vault-mssql-ekm-provider_{0}_{1}_{2}.zip" -f $ekmVersion, $os, $arch
  Invoke-WebRequest -URI $ekmProviderSourceUrl -Outfile $archive
}

if (-not (Test-Path -Path $archive )) {
  Write-Error `
  -Category ObjectNotFound `
  -Message "EKM Provider archive not found at '$archive'"
  exit 1
}

if ($updateCerts) {
  checkCreateDirectory $certsTempDir

  # https://developer.hashicorp.com/vault/docs/platform/mssql/troubleshooting#authenticode-error
  Cmd.exe /C "certutil -syncwithWU $certsTempDir"
  Cmd.exe /C "extrac32 /L $certsTempDir $certsTempDir\authrootstl.cab authroot.stl"
  Cmd.exe /C "certutil -f -v -ent -AddStore Root $certsTempDir\authroot.stl"
  Cmd.exe /C "certutil -f -v -ent -AddStore Root $certsTempDir\0563b8630d62d75abbc8ab1e4bdfb5a899b24d43.crt"
  Cmd.exe /C "certutil -f -v -ent -AddStore Root $certsTempDir\ddfb16cd4931c973a2037d3fc83a4d7d775d05e4.crt"
}

# Extract, install, and configure the EKM Provider
Expand-Archive $archive -DestinationPath $ekmWorkingDir -Force
Start-Process -Wait -FilePath "msiexec" -ArgumentList "/i $ekmWorkingDir\vault-mssql-ekm-provider.msi VAULT_API_URL=$vaultApiBaseUrl VAULT_API_URL_IS_VALID=1 VAULT_INSTALL_FOLDER=`"C:\Program Files\HashiCorp\Transit Vault EKM Provider\`" /qb /l* $ekmWorkingDir\vault-mssql-ekm-provider.log" 
Set-Content -Path "$env:SystemDrive\ProgramData\HashiCorp\Transit Vault EKM Provider\config.json" -Value $($config | ConvertTo-Json) 

Write-Output "EKM Provider version $ekmVersion has been installed."

exit 0
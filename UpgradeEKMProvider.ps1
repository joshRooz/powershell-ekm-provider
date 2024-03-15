<#
.SYNOPSIS
  This script upgrades the Vault EKM Provider on a Windows machine.

.DESCRIPTION
  This script upgrades the Vault EKM Provider on a Windows machine.

.PARAMETER ekmVersion
  The version of the EKM Provider to install. Must be a semantic version. For example, 0.2.2.

.PARAMETER ekmWorkingDir
  The directory where the EKM Provider archive will be downloaded and extracted. Default is "$Env:USERPROFILE\Downloads\ekm".

.PARAMETER skipEkmFetchRelease
  If set, the script will expect the EKM Provider archive to be pre-populated in $ekmWorkingDir named "vault-mssql-ekm-provider_<version>+ent_windows_amd64.zip."

.PARAMETER updateCerts
  If true, the script will update the Windows certificate store with the latest root certificates from Microsoft.
  Default is false.

.PARAMETER certsTempDir
  The directory that will be used to update the Windows certificate store. Default is "$Env:USERPROFILE\Downloads\certs".

.PARAMETER force
  Setting this parameter is acknowledgement that an upgrade is an interruptive operation, that prerequisites are complete, and post-steps will be performed out-of-band.
  If true, the script will non-interactively upgrade the EKM Provider to the specified version. Default is false.

.EXAMPLE
    Example upgrade with force specified. Caution: upgrading is an interruptive operation:
    .\UpgradeEKMProvider.ps1 `
      -ekmVersion 0.2.2 `
      -force

.LINK
  - Official HashiCorp Vault EKM Provider documentation: https://developer.hashicorp.com/vault/docs/platform/mssql
  - Official Microsoft SQL Server EKM documentation: https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/extensible-key-management-ekm
#>


# Get-Help .\UpgradeEKMProvider.ps1 -Full
[CmdletBinding()]
Param(
  # EKM Upgrade Parameters
  [Parameter(Mandatory=$true)]
  [string]$ekmVersion,
  [string]$ekmWorkingDir = "$Env:USERPROFILE\Downloads\ekm",
  [switch]$skipEkmFetchRelease,
  [switch]$updateCerts,
  [string]$certsTempDir = "$Env:USERPROFILE\Downloads\certs",
  [switch]$force
)

function checkCreateDirectory ([string]$dir) {
  if (-not (Test-Path -Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
}

# This function is a bit clunky, but sufficient
function upgradeEKMProvider {
  # Set static installation parameters to available option. Update in the future, if necessary
  $os = "windows" ; $arch = "amd64"

  if (-not $skipEkmFetchRelease) {
    checkCreateDirectory $ekmWorkingDir
    $ekmProviderSourceUrl = "https://releases.hashicorp.com/vault-mssql-ekm-provider/{0}/vault-mssql-ekm-provider_{0}_{1}_{2}.zip" -f $ekmVersion, $os, $arch
    Invoke-WebRequest -URI $ekmProviderSourceUrl -Outfile ("{0}\vault-mssql-ekm-provider_{1}_{2}_{3}.zip" -f $ekmWorkingDir, $ekmVersion, $os, $arch)
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

  # Extract the EKM Provider
  try {
    Expand-Archive ("{0}\vault-mssql-ekm-provider_{1}_{2}_{3}.zip" -f $ekmWorkingDir, $ekmVersion, $os, $arch) -DestinationPath $ekmWorkingDir -Force -ErrorAction Stop
  }
  catch {
    Write-Error "Failed to extract the EKM Provider archive. Exiting."
    exit 1
  }

  # Upgrade the EKM Provider
  $process = Start-Process -Wait -PassThru -FilePath "msiexec" -ArgumentList "/i $ekmWorkingDir\vault-mssql-ekm-provider.msi VAULT_API_URL=$vaultApiBaseUrl VAULT_API_URL_IS_VALID=1 VAULT_INSTALL_FOLDER=`"C:\Program Files\HashiCorp\Transit Vault EKM Provider\`" /qb /l* $ekmWorkingDir\vault-mssql-ekm-provider.log" 
  if ($process.ExitCode -ne 0) {
    Write-Error "Failed to upgrade the EKM Provider. Exiting."
    exit 1
  }
}


# Pre-flight Checks
try { $ekmSemanticVersion = [System.Version]::new($ekmVersion) }
catch {
  Write-Error "Invalid EKM Provider version. A valid semantic version format is required."
  exit 1
}

try {  $installed = Get-Package -Name "Transit Vault EKM Provider" -ErrorAction Stop }
catch {
  Write-Output "EKM Provider is not installed. Exiting."
  exit 1
}

if ($installed.Status -ne "Installed") {
  Write-Output "EKM Provider is not successfully installed. Exiting."
  exit 1
}
Write-Debug ("EKM Provider is installed. Version: {0}, Installation Status: {1}." -f $installed.Version, $installed.Status)

# We must provide the Vault API URL to the installer. Parse and use the value stored in the EKM Provider's config.json file.
$vaultApiBaseUrl = (Get-Content -Path "$env:SystemDrive\ProgramData\HashiCorp\Transit Vault EKM Provider\config.json" -Raw | ConvertFrom-Json).vaultApiBaseUrl
try { [System.Uri]::new($vaultApiBaseUrl) | Out-Null }
catch {
  Write-Error "Invalid Vault base URL value $vaultApiBaseUrl. Exiting."
  exit 1
}

# Begin primary upgrade flow control
$installedSemanticVersion = [System.Version]::new($installed.Version)
if ($installedSemanticVersion -lt $ekmSemanticVersion) {
  if ($force) {
    Write-Output "EKM Provider version will be upgraded from $($installed.Version) to $ekmVersion."
    $ekmVersion += "+ent"
    # invoke upgrade as a function call to minimize indentation; aiming to improve readability through this section
    upgradeEKMProvider
    exit 0
  }

  Write-Output "EKM Provider version upgrade requires the force parameter.`nSetting the force switch is acknowledgement that -
    1) an upgrade is an interruptive operation
    2) prerequisite steps are complete
    3) post-steps will be performed out-of-band after this script completes"
}else {
  Write-Output "EKM Provider is already installed. Version: $($installed.Version)."
}

exit 0
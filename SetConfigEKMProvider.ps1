<#
.SYNOPSIS
  This script updates the Vault EKM Provider configuration on a Windows machine.

.DESCRIPTION
  This script updates the Vault EKM Provider configuration on a Windows machine.

.PARAMETER vaultApiBaseUrl
  The base URL of the Vault cluster. This should include the protocol and port number. For example, https://vault.example.com:8200.

.PARAMETER enableTrace
  Enable Vault EKM Provider trace logging. Special case; if set to false, the key will be removed from the configuration. Default is false.

.PARAMETER namespace
  The namespace to use for Vault authentication.

.PARAMETER appRoleMountPath
  The path to the AppRole authentication mount.

.PARAMETER transitMountPath 
  The path to the Transit Secrets Engine mount.

.PARAMETER dryRun
  If set, the script will write the updated configuration to the console but will not write the changes to the configuration file. Default is false.

.EXAMPLE
    Example show the planned configuration without persisting:
    .\SetConfigEKMProvider.ps1 `
      -dryRun

.EXAMPLE
    Example enable tracing:
    .\SetConfigEKMProvider.ps1 `
      -enableTrace $true

.EXAMPLE
    Example with namespace and custom mounts:
    .\SetConfigEKMProvider.ps1 `
      -vaultApiBaseUrl https://vault.example.com:8200 `
      -namespace abc `
      -appRoleMountPath approle-adp `
      -transitMountPath transit-adp

.LINK
  - Official HashiCorp Vault EKM Provider documentation: https://developer.hashicorp.com/vault/docs/platform/mssql
  - Official Microsoft SQL Server EKM documentation: https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/extensible-key-management-ekm
#>


# Get-Help .\SetConfigEKMProvider.ps1 -Full
[CmdletBinding()]
Param(
  # EKM Provider Config Parameters
  [string]$vaultApiBaseUrl = $null,
  [bool]$enableTrace = $false,
  [string]$namespace = $null,
  [string]$appRoleMountPath = $null,
  [string]$transitMountPath = $null,
  [switch]$dryRun
)

Set-StrictMode -Version 3.0

# Check if the EKM Provider installation exists
try { $installed = Get-Package -Name "Transit Vault EKM Provider" -ErrorAction Stop }
catch {
  Write-Output "EKM Provider is not installed."
  exit 0
}

# Get the current EKM Provider configuration 
$config = @{}
$configPath = "$env:SystemDrive\ProgramData\HashiCorp\Transit Vault EKM Provider\config.json"
try { $configObj = Get-Content -Path $configPath -Raw -ErrorAction Stop | ConvertFrom-Json }
catch {
  Write-Output "Failed to read the EKM Provider configuration file. Exiting."
  exit 1
}
$configObj.PSObject.Properties | foreach { $config[$_.Name] = $_.Value }

# Set the EKM configuration hashmap that will be merged into config.json
$newConfig = @{}
foreach ($key in @('vaultApiBaseUrl', 'enableTrace', 'namespace', 'appRoleMountPath', 'transitMountPath')) {
  if ($null -ne $PSBoundParameters[$key] -and $PSBoundParameters[$key] -ne $false) {
    $newConfig[$key] = $PSBoundParameters[$key]
  }
}

# Overwrite any existing values with the new configuration values specified
foreach ($key in $newConfig.Keys) {
  $config[$key] = $newConfig[$key]
}

# Special case; if enableTrace is set to $false, remove the key from the config
if ($config.ContainsKey('enableTrace') -and $enableTrace -eq $false) {
  $config.Remove('enableTrace')
}

if ($dryRun) {
  Write-Output "Dry run mode. The EKM Provider configuration would be updated with the following values:`n$($config | ConvertTo-Json)"
}
else {
  Set-Content -Path $configPath -Value $($config | ConvertTo-Json) 
  Write-Output "EKM Provider config has been updated. Restart SQL Server for changes to take effect."
}

exit 0
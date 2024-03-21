<#
.SYNOPSIS
  EKM Provider Key Encryption Key Management

.DESCRIPTION
  Manage the lifecycle of a KEK version in SQL Server using the HashiCorp Vault EKM Provider

.PARAMETER version
  The version of the key to manage.
  Recommend keeping aligned to the version of the key in the Transit Secrets engine of Vault.

.PARAMETER transitKey
  The name of the key in the Transit Secrets engine of Vault.

.PARAMETER appRoleID
  HashiCorp Vault AppRole ID for authentication.

.PARAMETER appRoleSecretID
  HashiCorp Vault AppRole Secret ID for authentication.

.PARAMETER cryptographicProvider
  Name of the cryptographic provider. Default is "TransitVaultEKMProvider".

.PARAMETER sqlKeyPrefix
  Prefix for the credential name. Default is "TransitVaultAK".

.PARAMETER sqlPath
  Path to the SQL script to set Administrator Authentication.

.EXAMPLE
    Example with minimal parameters:
    .\SetSQLKeyEKMProvider.ps1 `
      -version 1 `
      -transitKey ekm-encryption-key `
      -appRoleID 00000000-0000-0000-0000-000000000000 `
      -appRoleSecretID 00000000-0000-0000-0000-000000000000 `
      -sqlPath "C:\path\to\SetEKMProviderKeyAuth.sql"
#>

[CmdletBinding()]
param (
  [Parameter(Mandatory=$true)]
  [ValidateRange(1, [int]::MaxValue)]
  [int]$version,

  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$transitKey,

  [Parameter(Mandatory=$true)]
  [ValidateScript({$_ -match '^[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}$' })]
  [string]$appRoleID,

  [Parameter(Mandatory=$true)]
  [ValidateScript({$_ -match '^[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}$' })]
  [string]$appRoleSecretID,

  [string]$cryptographicProvider = "TransitVaultEKMProvider",
  [string]$sqlKeyPrefix = "TransitVaultAK",

  [Parameter(Mandatory=$true)]
  [string]$sqlPath
)

# PSBoundParameters will only contain the parameters that were actually passed to the script.
# we must manually set the default values for cryptographicProvider and credsPrefix
$args = @(
  "CRYPTOGRAPHICPROVIDER='$cryptographicProvider'",
  "SQLKEYPREFIX='$sqlKeyPrefix'",
  "KEYVERSION=$version"
)

foreach ($key in @('transitKey', 'appRoleID', 'appRoleSecretID', 'cryptographicProvider', 'sqlKeyPrefix')){
  if (-not [string]::IsNullOrEmpty($PSBoundParameters[$key])) {
    $args += "$($key.ToUpper())='$($PSBoundParameters[$key])'" # very small so recreating the array
  }
}


# ACTION REQUIRED: Update Invoke-Sqlcmd arguments so that it works in your environment, uses encryption, etc.
try { Invoke-Sqlcmd -InputFile $sqlPath -Variable $args -ErrorAction Stop }
catch {
  throw "Failed to set SQL Server Administrator Authentication for HashiCorp Vault EKM Provider: $_"
}

Write-Output "SQL Server KEK Management for HashiCorp Vault EKM Provider set successfully."

exit 0
<#
.SYNOPSIS
  EKM Provider Set SQL Administrator Auth

.DESCRIPTION
  Set Administrator Authentication in SQL Server for HashiCorp Vault EKM Provider

.PARAMETER login
  SQL Server administrator login that uses HashiCorp Vault to set up and manage encryption scenarios.

.PARAMETER appRoleID
  HashiCorp Vault AppRole ID for authentication.

.PARAMETER appRoleSecretID
  HashiCorp Vault AppRole Secret ID for authentication.

.PARAMETER cryptographicProvider
  Name of the cryptographic provider. Default is "TransitVaultEKMProvider".

.PARAMETER credsPrefix
  Prefix for the credential name. Default is "EKMAdminCredentials".

.PARAMETER sqlPath
  Path to the SQL script to set Administrator Authentication.

.EXAMPLE
    Example with minimal parameters:
    .\SetSQLAdminAuthEKMProvider.ps1 `
      -login "mssqldev01\mssql-tde-dev" `
      -appRoleID 00000000-0000-0000-0000-000000000000 `
      -appRoleSecretID 00000000-0000-0000-0000-000000000000 `
      -sqlPath "C:\path\to\SetEKMProviderAdminAuth.sql"
#>


[CmdletBinding()]
param (
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$login,

  [Parameter(Mandatory=$true)]  # match any valid uuid eg: a9c5b1ba-6c9c-48e4-ac28-87e144a6d2c7
  [ValidateScript({$_ -match '^[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}$' })]
  [string]$appRoleID,

  [Parameter(Mandatory=$true)]
  [ValidateScript({$_ -match '^[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}$' })]
  [string]$appRoleSecretID,

  [string]$cryptographicProvider = "TransitVaultEKMProvider",
  [string]$credsPrefix = "EKMAdminCredentials",

  [Parameter(Mandatory=$true)]
  [string]$sqlPath
)

# PSBoundParameters will only contain the parameters that were actually passed to the script.
# we must manually set the default values for cryptographicProvider and credsPrefix
$args = @(
  "CRYPTOGRAPHICPROVIDER='$cryptographicProvider'",
  "CREDSPREFIX='$credsPrefix'"
)

foreach ($key in @('login', 'appRoleID', 'appRoleSecretID', 'cryptographicProvider', 'credsPrefix')){
  if (-not [string]::IsNullOrEmpty($PSBoundParameters[$key])) {
    $args += "$($key.ToUpper())='$($PSBoundParameters[$key])'" # very small so recreating the array
  }
}

# ACTION REQUIRED: Update Invoke-Sqlcmd arguments so that it works in your environment, uses encryption, etc.
try { Invoke-Sqlcmd -InputFile $sqlPath -Variable $args -ErrorAction Stop }
catch {
  throw "Failed to set SQL Server Administrator Authentication for HashiCorp Vault EKM Provider: $_"
}

Write-Output "SQL Server Administrator Authentication for HashiCorp Vault EKM Provider set successfully."

exit 0
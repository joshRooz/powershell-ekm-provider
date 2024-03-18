ALTER CRYPTOGRAPHIC PROVIDER TransitVaultEKMProvider DISABLE;
SELECT name,version,is_enabled FROM sys.cryptographic_providers where name = 'TransitVaultEKMProvider';

/*
Cryptographic provider is now disabled. However users who have an open cryptographic session with the provider can still use it. Restart the server to disable the provider for all users.
*/


-- Upgrade the EKM Provider via PowerShell or through other means
-- Will prompt to stop SQL Server - can continue without stopping (prompted twice)

-- THE UPGRADE STEPS ARE OUT OF ORDER ON THE DOCS!!

ALTER CRYPTOGRAPHIC PROVIDER TransitVaultEKMProvider ENABLE;

ALTER CRYPTOGRAPHIC PROVIDER TransitVaultEKMProvider
    FROM FILE = 'C:\Program Files\HashiCorp\Transit Vault EKM Provider\TransitVaultEKM.dll';

SELECT name,version,is_enabled FROM sys.cryptographic_providers where name = 'TransitVaultEKMProvider';

-- Restart the SQL Server service to complete the upgrade


/*
MS reference for refining these steps -
https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/sql-server-connector-maintenance-troubleshooting?view=sql-server-ver16
*/
ALTER CRYPTOGRAPHIC PROVIDER TransitVaultEKMProvider DISABLE;
SELECT name,version,is_enabled FROM sys.cryptographic_providers where name = 'TransitVaultEKMProvider';

/*
Cryptographic provider is now disabled. However users who have an open cryptographic session with the provider can still use it. Restart the server to disable the provider for all users.
*/


-- Upgrade the EKM Provider via PowerShell or through other means
-- Will prompt to stop SQL Server - can continue without stopping (prompted twice)

-- THESE STEPS ARE NOT CLEAN!!

ALTER CRYPTOGRAPHIC PROVIDER TransitVaultEKMProvider
    FROM FILE = 'C:\Program Files\HashiCorp\Transit Vault EKM Provider\TransitVaultEKM.dll';

ALTER CRYPTOGRAPHIC PROVIDER TransitVaultEKMProvider ENABLE;
SELECT name,version,is_enabled FROM sys.cryptographic_providers where name = 'TransitVaultEKMProvider';

-- Restart the SQL Server service to complete the upgrade

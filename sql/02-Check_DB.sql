-- Check the cryptographic provider
SELECT name,version,dll_path,is_enabled FROM sys.cryptographic_providers;

-- Check the status of key encryption
SELECT 
    (SELECT name FROM sys.cryptographic_providers WHERE guid = ak.cryptographic_provider_guid) as cryptographic_provider,
    name, thumbprint, algorithm_desc, key_length
FROM sys.asymmetric_keys ak;

-- Check the status of database encryption
/*
SELECT * FROM sys.dm_database_encryption_keys;

SELECT db.name, dek.encryption_state, dek.key_algorithm, dek.key_length, dek.encryptor_thumbprint,
    dek.encryptor_type, dek.encryption_state_desc, dek.encryption_scan_state_desc
FROM sys.dm_database_encryption_keys dek
JOIN sys.databases db ON db.database_id = dek.database_id
*/
SELECT count(*) as [databases],encryption_state, encryptor_thumbprint
FROM sys.dm_database_encryption_keys k
GROUP BY encryption_state, encryptor_thumbprint

-- Check the cred and login relationship
SELECT c.name FROM sys.credentials c
JOIN sys.server_principal_credentials spc ON c.credential_id = spc.credential_id
GO
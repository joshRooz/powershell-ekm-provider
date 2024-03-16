-- Check the cryptographic provider
SELECT name,version,dll_path,is_enabled FROM sys.cryptographic_providers;

-- Check the status of key encryption
SELECT 
    (SELECT name FROM sys.cryptographic_providers WHERE guid = ak.cryptographic_provider_guid) as cryptographic_provider,
    name, thumbprint, algorithm_desc, key_length
FROM sys.asymmetric_keys ak;

-- Check the status of database encryption
SELECT * FROM sys.dm_database_encryption_keys;

SELECT (SELECT name FROM sys.databases WHERE database_id = k.database_id) as name,
    encryption_state, key_algorithm, key_length, encryptor_thumbprint,
    encryptor_type, encryption_state_desc, encryption_scan_state_desc
FROM sys.dm_database_encryption_keys k;

-- Check the cred and login relationship
SELECT c.name FROM sys.credentials c
JOIN sys.server_principal_credentials spc ON c.credential_id = spc.credential_id
GO
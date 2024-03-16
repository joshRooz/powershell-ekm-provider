-- Name: SetEKMProviderKeyAuth
-- Description:
--   1. Create the asymmetric key, if the version specified does not exist. (kek rotation - Recommend matching the HashiCorp Vault Transit mount version)
--   2. Create the login, if it does not exist
--   3. Create and add a new credential to the login, dropping any existing credential (secret-id rotation)
-- Usage: EXECUTE [dbo].[SetEKMProviderKeyAuth] @version = 1, @transitkey = 'adp', @roleid = '<uuid1>', @secretid = '<uuid2>'

CREATE OR ALTER PROCEDURE [dbo].[SetEKMProviderKeyAuth]
    @version int
    ,@transitkey nvarchar(40)                                        -- Name of the key in HashiCorp Vault Transit mount
    ,@roleid nvarchar(40)                                            -- AppRole RoleID from HashiCorp Vault
    ,@secretid nvarchar(40)                                          -- AppRole SecretID from HashiCorp Vault
    ,@cryptographicprovider nvarchar(40) = 'TransitVaultEKMProvider' -- Name of the cryptographic provider
    ,@sqlkeyprefix nvarchar(40) = 'TransitVaultAK'                   -- Prefix for the asymmetric key name in SQL Server
AS
    DECLARE @iso8601 NVARCHAR(20)
    DECLARE @sqlkey NVARCHAR(80)
    DECLARE @cred NVARCHAR(100)
    DECLARE @login NVARCHAR(100)

    SET @iso8601 = (SELECT FORMAT(getdate(), 'yyyyMMddHHmmss'))
    SET @sqlkey = @sqlkeyprefix + '_V' + (SELECT CAST(@version AS nvarchar))
    SET @cred = @sqlkey + '_Cred_' + @iso8601
    SET @login = @sqlkey + '_Login'

    DECLARE @exec_stmt NVARCHAR(1000)
    DECLARE @return int

    -- Lightly validate AppRole credential
    if @roleid is null or @secretid is null
        return (1)

    -- Validate login --
    EXECUTE @return = sys.sp_validname @login
    if @return <> 0
        return (1)

    if NOT EXISTS (SELECT * FROM sys.asymmetric_keys WHERE name = @sqlkey)
    BEGIN -- Create the asymmetric key
        --print N'BEGIN ASYMMETRIC KEY SECTION'
        SET @exec_stmt = 'CREATE ASYMMETRIC KEY ' + @sqlkey
        SET @exec_stmt = @exec_stmt + ' FROM PROVIDER ' + @cryptographicprovider
        SET @exec_stmt = @exec_stmt + ' WITH CREATION_DISPOSITION = OPEN_EXISTING,'
        SET @exec_stmt = @exec_stmt + ' PROVIDER_KEY_NAME = ''' + @transitkey + ''''

        exec (@exec_stmt)
        if @@error <> 0
            return (1)
    END

    if NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = @login)  -- syslogins
    BEGIN -- Create the login
        --print N'BEGIN LOGIN SECTION'
        SET @exec_stmt = 'CREATE LOGIN ' + @login + ' FROM ASYMMETRIC KEY ' + @sqlkey
    
        exec (@exec_stmt)
        if @@error <> 0
            return (1)
    END

    BEGIN -- Create the credential
        --print N'BEGIN CREDENTIAL SECTION'
        SET @exec_stmt = 'CREATE CREDENTIAL ' + @cred
        SET @exec_stmt = @exec_stmt + ' WITH IDENTITY = ''' + @roleid + ''', SECRET = ''' + @secretid + ''''
        SET @exec_stmt = @exec_stmt + ' FOR CRYPTOGRAPHIC PROVIDER ' + @cryptographicprovider
    
        exec (@exec_stmt)
        if @@error <> 0
            return (1)
    END

    DECLARE @loginid int
    SET @loginid = (SELECT principal_id FROM sys.server_principals WHERE name = @login)
    if EXISTS (SELECT credential_id FROM sys.server_principal_credentials WHERE principal_id = @loginid)
    BEGIN -- Drop the existing credential; error handling is critical between the drop and add operations
        --print N'DROP EXISTING CREDENTIAL'
        DECLARE @excred nvarchar(100) -- existing credential
        SET @excred = (
            SELECT c.name FROM sys.credentials c
            JOIN sys.server_principal_credentials spc ON c.credential_id = spc.credential_id
            WHERE spc.principal_id = @loginid
        )
        SET @exec_stmt = 'ALTER LOGIN ' + @login + ' DROP CREDENTIAL ' + @excred

        exec (@exec_stmt)
        if @@error <> 0
            return (1)
    END

    -- Alter the login
    --print N'ADD CREDENTIAL'
    SET @exec_stmt = 'ALTER LOGIN ' + @login + ' ADD CREDENTIAL ' + @cred
    
    exec (@exec_stmt)
    if @@error <> 0
        return (1)


    return (0)
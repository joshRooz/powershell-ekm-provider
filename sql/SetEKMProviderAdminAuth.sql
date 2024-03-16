-- Name: SetEKMProviderAdminAuth
-- Description:
--  1. Create a credential for the sql server admin
--  2. Add the credential to the login
-- Preconditions: The cryptographic provider must be created.
-- Usage: EXECUTE [dbo].[SetEKMProviderAdminAuth] @login = 'admlogin', @roleid = '<uuid1>', @secretid = '<uuid2>'

CREATE OR ALTER PROCEDURE [dbo].[SetEKMProviderAdminAuth]
    @login nvarchar(60)                                              -- SQL Server administrator login that uses vault to set up and manage encryption scenarios
    ,@roleid nvarchar(40)                                            -- AppRole RoleID from HashiCorp Vault
    ,@secretid nvarchar(40)                                          -- AppRole SecretID from HashiCorp Vault
    ,@cryptographicprovider nvarchar(40) = 'TransitVaultEKMProvider' -- Name of the cryptographic provider
    ,@credsprefix nvarchar(40) = 'EKMAdminCredentials'               -- Prefix for the credential name
AS
    DECLARE @iso8601 NVARCHAR(20)
    DECLARE @creds NVARCHAR(80)
    SET @iso8601 = (SELECT FORMAT(getdate(), 'yyyyMMddHHmmss'))
    SET @creds = @credsprefix + '_' + @iso8601

    DECLARE @exec_stmt NVARCHAR(1000)
    DECLARE @return int

    -- Lightly validate AppRole credential
    if @roleid is null or @secretid is null
        return (1)

    -- Validate login
    if @login is null
        return (1)

    EXECUTE @return = sys.sp_validname @login
    if @return <> 0
        return (1)

    -- Create the credential
    --print N'BEGIN CREDENTIAL SECTION'
    SET @exec_stmt = 'CREATE CREDENTIAL ' + @creds
    SET @exec_stmt = @exec_stmt + ' WITH IDENTITY = ''' + @roleid + ''', SECRET = ''' + @secretid + ''''
    SET @exec_stmt = @exec_stmt + ' FOR CRYPTOGRAPHIC PROVIDER ' + @cryptographicprovider

    exec (@exec_stmt)
    if @@error <> 0
        return (1)

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
        SET @exec_stmt = 'ALTER LOGIN "' + @login + '" DROP CREDENTIAL ' + @excred

        exec (@exec_stmt)
        if @@error <> 0
            return (1)
    END

    -- Alter the login
    --print N'BEGIN LOGIN SECTION'
    SET @exec_stmt = 'ALTER LOGIN "' + @login + '" ADD CREDENTIAL ' + @creds
    exec (@exec_stmt)
    if @@error <> 0
        return (1)


    return (0)
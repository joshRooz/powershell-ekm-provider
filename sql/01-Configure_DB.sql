-- Enable advanced options
USE master;
GO

EXEC sp_configure 'show advanced options', 1;
GO

RECONFIGURE;
GO

-- Enable EKM provider
EXEC sp_configure 'EKM provider enabled', 1;
GO

RECONFIGURE;
GO

CREATE CRYPTOGRAPHIC PROVIDER TransitVaultEKMProvider
FROM FILE = 'C:\Program Files\HashiCorp\Transit Vault EKM Provider\TransitVaultEKM.dll'
GO

-- Create stored procedures - requires an efficient way to easily update the procedures at scale
-- checkout and execute the preferred commit ref SP each time (possibly, through temporary stored procedures?)
-- additionally, would need to apply principle of least privilege, general SP best practices, and update to sp_executesql
-- with parameters for SQL injection defense, etc.
#git clone ...
#sqlcmd -S <server> -d <database> ... -i ./CreateUpdateSetEKMProviderAdminAuth.sql
#sqlcmd -S <server> -d <database> ... -i ./CreateUpdateSetEKMProviderKeyAuth.sql


-- Create credentials for an admin
EXECUTE [dbo].[SetEKMProviderAdminAuth]
    @login = 'jroose-mssql\mssql-tde-dev',
    @roleid = '9ea4fee6-0c5b-39c6-a63f-e005c05358f0',
    @secretid = '00000000-0000-0000-0000-000000000000'
GO

-- Create the asymmetric key and login for the EKM provider
EXECUTE [dbo].[SetEKMProviderKeyAuth]
    @version = 1,
    @transitkey = 'ekm-encryption-key',
    @roleid = '9ea4fee6-0c5b-39c6-a63f-e005c05358f0',
    @secretid = '00000000-0000-0000-0000-000000000001'
GO


-- enable TDE and protect the database encryption key with the asymmetric key
CREATE DATABASE TestTDE1
GO

USE TestTDE1;
GO

CREATE DATABASE ENCRYPTION KEY WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER ASYMMETRIC KEY TransitVaultAK_V1;
GO

ALTER DATABASE TestTDE1 SET ENCRYPTION ON;
GO



-- scale it up
DECLARE @i INT = 2;
WHILE @i <= 20
BEGIN
    DECLARE @db NVARCHAR(100) = 'TestTDE' + CAST(@i AS NVARCHAR(10));
    print N'Creating ' + @db + N'...';

    EXEC ('CREATE DATABASE ' + @db)
	EXEC ('USE ' + @DB +
        ' CREATE DATABASE ENCRYPTION KEY WITH ALGORITHM = AES_256 ENCRYPTION BY SERVER ASYMMETRIC KEY TransitVaultAK_V1')
	EXEC ('USE ' + @DB +
        ' ALTER DATABASE ' + @db + ' SET ENCRYPTION ON')

    SET @i = @i + 1
END
GO

-- scale it down
DECLARE @i INT = 2;
WHILE @i <= 20
BEGIN
    DECLARE @db NVARCHAR(100) = 'TestTDE' + CAST(@i AS NVARCHAR(10));
    print N'Dropping ' + @db + N'...';

    EXEC ('DROP DATABASE ' + @db)

    SET @i = @i + 1
END
GO
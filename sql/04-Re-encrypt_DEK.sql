DECLARE @i INT = 1;
DECLARE @sqlkey NVARCHAR(80) = 'TransitVaultAK_V1';

WHILE @i <= 20
BEGIN
    DECLARE @db NVARCHAR(100) = 'TestTDE' + CAST(@i AS NVARCHAR(10));
    print N'Re-encrypting DEK ' + @db + N'...';
    EXEC ('USE ' + @db + ' ALTER DATABASE ENCRYPTION KEY ENCRYPTION BY SERVER ASYMMETRIC KEY ' + @sqlkey) -- eg: @sqlkey = TransitVaultAK_V2

    set @i = @i + 1
END

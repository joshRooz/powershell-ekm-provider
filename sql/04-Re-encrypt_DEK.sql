/*
 main via 💠 ❯ vault write -f transit/keys/ekm-encryption-key/rotate 
Success! Data written to: transit/keys/ekm-encryption-key/rotate

 main via 💠 ❯ vault read -field=keys -format=json transit/keys/ekm-encryption-key | jq
*/
EXECUTE [dbo].[SetEKMProviderKeyAuth]
    @version = 2,
    @transitkey = 'ekm-encryption-key',
    @roleid = '9ea4fee6-0c5b-39c6-a63f-e005c05358f0',
    @secretid = '00000000-0000-0000-0000-000000000002'
GO

/* rotate vault key again */
EXECUTE [dbo].[SetEKMProviderKeyAuth]
    @version = 3,
    @transitkey = 'ekm-encryption-key',
    @roleid = '9ea4fee6-0c5b-39c6-a63f-e005c05358f0',
    -- secretid and kek version can change independently as long as the secretid is valid
    @secretid = '00000000-0000-0000-0000-000000000002'
GO



DECLARE @i INT = 1;
DECLARE @sqlkey NVARCHAR(80) = 'TransitVaultAK_V1';

WHILE @i <= 20
BEGIN
    DECLARE @db NVARCHAR(100) = 'TestTDE' + CAST(@i AS NVARCHAR(10));
    print N'Re-encrypting DEK ' + @db + N'...';
    EXEC ('USE ' + @db + ' ALTER DATABASE ENCRYPTION KEY ENCRYPTION BY SERVER ASYMMETRIC KEY ' + @sqlkey) -- eg: @sqlkey = TransitVaultAK_V2

    set @i = @i + 1
END

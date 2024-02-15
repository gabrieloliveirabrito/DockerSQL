USE master;
GO

DECLARE @BackupFolder NVARCHAR(4000) = '/var/opt/mssql/backup/';
DECLARE @DataFolder NVARCHAR(4000) = '/var/opt/mssql/data/';

-- Lista de arquivos de backup
CREATE TABLE #BackupList
(
    Filename NVARCHAR(4000) NOT NULL,
    DatabaseName NVARCHAR(128) NULL,
    DataName NVARCHAR(128) NULL,
    DataPhysical NVARCHAR(4000) NULL,
    LogName NVARCHAR(128) NULL,
    LogPhysical NVARCHAR(4000) NULL
);
INSERT INTO #BackupList
    (Filename)
VALUES
    ('/var/opt/mssql/backup/Db_Management_20240209.bak'),
    ('/var/opt/mssql/backup/Db_Tank36_BR_20240209.bak'),
    ('/var/opt/mssql/backup/Db_Tank36_EN_20240209.bak'),
    ('/var/opt/mssql/backup/Db_Tank_BR_20240209.bak'),
    ('/var/opt/mssql/backup/Db_Tank_EN_20240209.bak'),
    ('/var/opt/mssql/backup/Db_Web_20240209.bak'),
    ('/var/opt/mssql/backup/Xttdenc.Database.CharGame_20240209.bak'),
    ('/var/opt/mssql/backup/Xttdenc.Database.Game_20240209.bak'),
    ('/var/opt/mssql/backup/Xttdenc.Database.Web_20240209.bak');

CREATE TABLE #FileDetails
(
    LogicalName NVARCHAR(128),
    PhysicalName NVARCHAR(4000),
    [Type] CHAR(1),
    FileGroupName NVARCHAR(128),
    Size NUMERIC(20,0),
    MaxSize NUMERIC(20,0),
    FileId BIGINT,
    CreateLSN NUMERIC(25,0),
    DropLSN NUMERIC(25,0),
    UniqueId UNIQUEIDENTIFIER,
    ReadOnlyLSN NUMERIC(25,0),
    ReadWriteLSN NUMERIC(25,0),
    BackupSizeInBytes BIGINT,
    SourceBlockSize INT,
    FileGroupId INT,
    LogGroupGUID UNIQUEIDENTIFIER,
    DifferentialBaseLSN NUMERIC(25,0),
    DifferentialBaseGUID UNIQUEIDENTIFIER,
    IsReadOnly BIT,
    IsPresent BIT,
    TDEThumbprint VARBINARY(32),
    SnapshotUrl NVARCHAR(360)
);

-- Loop através da lista de arquivos de backup e obter detalhes
DECLARE @Filename NVARCHAR(4000);
DECLARE @LogicalName NVARCHAR(128);
DECLARE @Type CHAR(1);
DECLARE fileListCursor CURSOR FOR SELECT Filename FROM #BackupList;

OPEN fileListCursor;

FETCH NEXT FROM fileListCursor INTO @Filename;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO #FileDetails
    EXEC('RESTORE FILELISTONLY FROM DISK = ''' + @Filename + '''');

    WHILE (SELECT TOP 1 COUNT(Type) FROM #FileDetails) > 0
    BEGIN
        SELECT TOP 1 @Type = Type, @LogicalName = LogicalName FROM #FileDetails

        IF @Type = 'D'
            UPDATE #BackupList SET DatabaseName = @LogicalName, DataName = @LogicalName, DataPhysical = @DataFolder + @LogicalName + '.mdf' WHERE [Filename] = @Filename
        ELSE IF @Type = 'L'
            UPDATE #BackupList SET LogName = @LogicalName, LogPhysical = @DataFolder + @LogicalName + '.ldf' WHERE [Filename] = @Filename
        
        DELETE TOP (1) FROM #FileDetails
    END

    FETCH NEXT FROM fileListCursor INTO @Filename;
END
CLOSE fileListCursor;
DEALLOCATE fileListCursor;

-- Loop através de cada arquivo de backup e restaurar o banco de dados
DECLARE @BackupFile NVARCHAR(4000);
DECLARE @DatabaseName NVARCHAR(128), @DataName NVARCHAR(128), @LogName NVARCHAR(128);
DECLARE @DataPath NVARCHAR(4000), @LogPath NVARCHAR(4000);
DECLARE @RestoreCommand NVARCHAR(MAX);

DECLARE backup_cursor CURSOR FOR
SELECT Filename, DatabaseName, DataName, DataPhysical, LogName, LogPhysical
FROM #BackupList;

OPEN backup_cursor;
FETCH NEXT FROM backup_cursor INTO @BackupFile, @DatabaseName, @DataName, @DataPath, @LogName, @LogPath;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @RestoreCommand = 'RESTORE DATABASE [' + @DatabaseName + ']'
    SET @RestoreCommand += ' FROM DISK = ''' + @BackupFile + ''' WITH REPLACE,'
    SET @RestoreCommand += ' MOVE ''' + @DataName + ''' TO ''' + @DataPath + ''','
    SET @RestoreCommand += ' MOVE ''' + @LogName + ''' TO ''' + @LogPath + ''';';

    EXEC sp_executesql @RestoreCommand;
    PRINT 'Banco de dados ' + @DatabaseName + ' restaurado.';

    FETCH NEXT FROM backup_cursor INTO @BackupFile, @DatabaseName, @DataName, @DataPath, @LogName, @LogPath;
END

CLOSE backup_cursor;
DEALLOCATE backup_cursor;

-- Limpeza
DROP TABLE #FileDetails;
DROP TABLE #BackupList;
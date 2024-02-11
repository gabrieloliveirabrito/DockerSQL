USE master;
GO

DECLARE @BackupPath NVARCHAR(4000) = '/var/opt/mssql/backup/';

-- Lista de arquivos de backup
DECLARE @FileList TABLE (Filename NVARCHAR(4000));
INSERT INTO @FileList (Filename)
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

-- Tabela para armazenar os detalhes dos arquivos de backup
CREATE TABLE #FileDetails (
    Id INT PRIMARY KEY IDENTITY(1,1),
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
DECLARE fileListCursor CURSOR FOR SELECT Filename FROM @FileList;
OPEN fileListCursor;
FETCH NEXT FROM fileListCursor INTO @Filename;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO #FileDetails
    EXEC('RESTORE FILELISTONLY FROM DISK = ''' + @Filename + '''');

    UPDATE #FileDetails SET PhysicalName = @Filename WHERE ID BETWEEN @@IDENTITY -1 AND @@IDENTITY

    FETCH NEXT FROM fileListCursor INTO @Filename;
END
CLOSE fileListCursor;
DEALLOCATE fileListCursor;

-- Loop através de cada arquivo de backup e restaurar o banco de dados
DECLARE @DatabaseName NVARCHAR(128);
DECLARE @PhysicalName NVARCHAR(4000);
DECLARE @RestoreCommand NVARCHAR(MAX);

DECLARE backup_cursor CURSOR FOR
SELECT LogicalName, PhysicalName
FROM #FileDetails;

OPEN backup_cursor;
FETCH NEXT FROM backup_cursor INTO @DatabaseName, @PhysicalName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @RestoreCommand = 'RESTORE DATABASE [' + @DatabaseName + '] FROM DISK = ''' + @PhysicalName + ''' WITH REPLACE, MOVE ''' + @DatabaseName + ''' TO ''' + REPLACE(@PhysicalName, '.bak', '.mdf') + ''', MOVE ''' + @DatabaseName + '_log'' TO ''' + REPLACE(@PhysicalName, '.bak', '.ldf') + ''';';
    EXEC sp_executesql @RestoreCommand;
    
    PRINT 'Banco de dados ' + @DatabaseName + ' restaurado.';
    
    FETCH NEXT FROM backup_cursor INTO @DatabaseName, @PhysicalName;
END

CLOSE backup_cursor;
DEALLOCATE backup_cursor;

-- Limpeza
DROP TABLE #FileDetails;

USE master;
GO

-- Define os diretórios de backup e de dados
DECLARE @BackupFolder NVARCHAR(4000) = 'D:\SQL Server\Backup\';
DECLARE @DataFolder NVARCHAR(4000) = 'D:\SQL Server\Data\';

/*
	Se estiver em um container docker, utilize as pastas abaixo:
	DECLARE @BackupFolder NVARCHAR(4000) = '/var/opt/mssql/backup/';
	DECLARE @DataFolder NVARCHAR(4000) = '/var/opt/mssql/data/';
*/

-- Tabela para armazenar a lista de arquivos de backup e informações relacionadas
DECLARE @BackupList TABLE
(
    Filename NVARCHAR(4000) NOT NULL,
    DatabaseName NVARCHAR(128) NULL,
    DataName NVARCHAR(128) NULL,
    DataPhysical NVARCHAR(4000) NULL,
    LogName NVARCHAR(128) NULL,
    LogPhysical NVARCHAR(4000) NULL
);

-- Insere os arquivos de backup na tabela de lista de backup
INSERT INTO @BackupList
    (Filename)
VALUES
    ('Db_Management_20240209.bak');

-- Tabela temporária para armazenar os detalhes dos arquivos de backup
DECLARE @FileDetails TABLE
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
DECLARE fileListCursor CURSOR FOR SELECT Filename FROM @BackupList;

OPEN fileListCursor;

FETCH NEXT FROM fileListCursor INTO @Filename;
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Executa RESTORE FILELISTONLY para obter os detalhes dos arquivos de backup
    INSERT INTO @FileDetails
    EXEC('RESTORE FILELISTONLY FROM DISK = ''' + @BackupFolder + @Filename + '''');

    -- Executa RESTORE HEADERONLY para obter informações sobre o backup
    INSERT INTO #BackupHeader
    EXEC('RESTORE HEADERONLY FROM DISK = ''' + @BackupFolder + @Filename + '''');

    -- Atualiza o nome do banco de dados na lista de backup com o nome do banco de dados do header do backup
    UPDATE @BackupList SET DatabaseName = (SELECT TOP 1 DatabaseName FROM #BackupHeader)
    WHERE [Filename] =  @Filename;

    -- Limpa a tabela temporária
    DELETE FROM #BackupHeader;

    -- Percorre os detalhes dos arquivos de backup
    WHILE (SELECT TOP 1 COUNT(Type) FROM @FileDetails) > 0
    BEGIN
        SELECT TOP 1 @Type = Type, @LogicalName = LogicalName FROM @FileDetails;

        -- Atualiza os nomes e caminhos dos arquivos de dados e log na lista de backup
        IF @Type = 'D'
            UPDATE @BackupList SET DataName = @LogicalName, DataPhysical = @DataFolder + DatabaseName + '.mdf' WHERE [Filename] = @Filename;
        ELSE IF @Type = 'L'
            UPDATE @BackupList SET LogName = @LogicalName, LogPhysical = @DataFolder + DatabaseName + '.ldf' WHERE [Filename] = @Filename;

        DELETE TOP (1) FROM @FileDetails;
    END;

    FETCH NEXT FROM fileListCursor INTO @Filename;
END;

CLOSE fileListCursor;
DEALLOCATE fileListCursor;

-- Exibe a lista de backup
SELECT * FROM @BackupList;

-- Loop através de cada arquivo de backup e restaurar o banco de dados
DECLARE @BackupFile NVARCHAR(4000);
DECLARE @DatabaseName NVARCHAR(128), @DataName NVARCHAR(128), @LogName NVARCHAR(128);
DECLARE @DataPath NVARCHAR(4000), @LogPath NVARCHAR(4000);
DECLARE @RestoreCommand NVARCHAR(MAX);

DECLARE backup_cursor CURSOR FOR
SELECT Filename, DatabaseName, DataName, DataPhysical, LogName, LogPhysical
FROM @BackupList;

OPEN backup_cursor;
FETCH NEXT FROM backup_cursor INTO @BackupFile, @DatabaseName, @DataName, @DataPath, @LogName, @LogPath;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Constrói o comando de restauração
    SET @RestoreCommand = 'RESTORE DATABASE [' + @DatabaseName + ']';
    SET @RestoreCommand += ' FROM DISK = ''' + @BackupFolder + @BackupFile + ''' WITH REPLACE,';
    SET @RestoreCommand += ' MOVE ''' + @DataName + ''' TO ''' + @DataPath + ''',';
    SET @RestoreCommand += ' MOVE ''' + @LogName + ''' TO ''' + @LogPath + ''';';

    -- Executa o comando de restauração
    EXEC sp_executesql @RestoreCommand;
    PRINT 'Banco de dados ' + @DatabaseName + ' restaurado.';

    FETCH NEXT FROM backup_cursor INTO @BackupFile, @DatabaseName, @DataName, @DataPath, @LogName, @LogPath;
END;

CLOSE backup_cursor;
DEALLOCATE backup_cursor;

-- Limpa a tabela temporária
DROP TABLE #BackupHeader;

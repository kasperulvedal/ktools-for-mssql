/*
--------------------------------------------------------------------------------------
 Script:    setup_kbulk.sql
 Purpose:   Azure SQL Bulk Import Framework
 Author:    Kasper Ulvedal
 License:   MIT
 Version:   1.0.0
 Date:      2025-01-07
--------------------------------------------------------------------------------------
 This script creates a lightweight, metadata-driven bulk insert framework for loading
 CSV files from Azure Blob Storage into SQL Server/Azure SQL.

 Components:
 - [kbulk].[blob_files]            : Metadata table for tracking files
 - [kbulk].[load_from_blob_by_file]: Procedure to load a single CSV
 - [kbulk].[run_all_blob_imports]  : Procedure to load all registered files
--------------------------------------------------------------------------------------
*/

-- 🏗️ Ensure the metadata schema exists
IF NOT EXISTS (
    SELECT 1 FROM sys.schemas WHERE name = 'kbulk'
)
BEGIN
    EXEC('CREATE SCHEMA [kbulk]');
END

-- 📂 Create the metadata table if it doesn't already exist
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.name = 'blob_files' AND s.name = 'kbulk'
)
BEGIN
    CREATE TABLE [kbulk].[blob_files] (
         id INT IDENTITY(1,1) PRIMARY KEY,
         file_name VARCHAR(255) NOT NULL UNIQUE,
         truncate_on_load BIT NOT NULL,
         schema_name NVARCHAR(255) NOT NULL DEFAULT 'stg_bcodata',
         data_source NVARCHAR(255) NOT NULL DEFAULT 'AzureBlobStorage',
         sys_insert_datetime DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
         sys_last_update_datetime DATETIME2 NULL
    );
END

-- 📦 Procedure: Load one CSV file into a specified table using metadata
CREATE OR ALTER PROCEDURE [kbulk].[load_from_blob_by_file]
    @EntityName NVARCHAR(255),
    @SchemaName NVARCHAR(255),
    @DataSource NVARCHAR(255)
AS
BEGIN
    /*
    --------------------------------------------------------------------------------------
    Procedure: [kbulk].[load_from_blob_by_file]
    Author:    Kasper Ulvedal
    License:   MIT
    Version:   1.0.0
    Purpose:   Load a single entity from blob storage based on filename metadata
    --------------------------------------------------------------------------------------
    */
    SET NOCOUNT ON;

    DECLARE 
        @FileName NVARCHAR(255) = @EntityName + '.csv',
        @FormatFile NVARCHAR(255) = @EntityName + '.xml',
        @Truncate BIT = 0,
        @TableName NVARCHAR(255) = @EntityName,
        @SQL NVARCHAR(MAX);

    -- 🔎 Check metadata for truncate behavior
    SELECT @Truncate = truncate_on_load
    FROM [kbulk].[blob_files]
    WHERE file_name = @FileName;

    IF @Truncate IS NULL
    BEGIN
        PRINT '⚠️ Warning: No truncate_on_load setting found for file ' + @FileName + ' in [kbulk].[blob_files]. Proceeding without truncation.';
        SET @Truncate = 0;
    END

    -- 🔒 Ensure table exists
    IF NOT EXISTS (
        SELECT 1
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = @SchemaName AND TABLE_NAME = @TableName
    )
    BEGIN
        PRINT '❌ Error: Table [' + @SchemaName + '].[' + @TableName + '] does not exist.';
        RETURN;
    END

    -- 🚮 Truncate table if required
    IF @Truncate = 1
    BEGIN
        SET @SQL = 'TRUNCATE TABLE [' + @SchemaName + '].[' + @TableName + ']';
        PRINT '🔄 Truncating table before load: [' + @SchemaName + '].[' + @TableName + ']';
        EXEC sp_executesql @SQL;
    END

    -- 📥 Bulk insert the CSV file
    SET @SQL = '
    BULK INSERT [' + @SchemaName + '].[' + @TableName + ']
    FROM ''' + @FileName + '''
    WITH (
        DATA_SOURCE = ''' + @DataSource + ''',
        FORMATFILE = ''' + @FormatFile + ''',
        FORMATFILE_DATA_SOURCE = ''' + @DataSource + ''',
        FIRSTROW = 2,
        TABLOCK
    );';

    PRINT '🚀 Executing BULK INSERT for [' + @SchemaName + '].[' + @TableName + ']';
    EXEC sp_executesql @SQL;

    -- 📆 Update load timestamp
    UPDATE [kbulk].[blob_files]
    SET sys_last_update_datetime = SYSUTCDATETIME()
    WHERE file_name = @FileName;
END


-- 🔁 Procedure: Load all registered files from metadata
CREATE OR ALTER PROCEDURE [kbulk].[run_all_blob_imports]
AS
BEGIN

    /*
    --------------------------------------------------------------------------------------
    Procedure: [kbulk].[run_all_blob_imports]
    Author:    Kasper Ulvedal
    License:   MIT
    Version:   1.0.0
    Purpose:   Iterate metadata and bulk load all configured CSV files
    --------------------------------------------------------------------------------------
    */

    SET NOCOUNT ON;

    -- 📌 Set global defaults (can be overridden per file in the future)
    DECLARE 
        @SchemaName NVARCHAR(255) = 'stg_bcodata',
        @DataSource NVARCHAR(255) = 'AzureBlobStorage',
        @FileName NVARCHAR(512),
        @EntityName NVARCHAR(255);

    -- 🔄 Cursor to iterate files
    DECLARE blob_cursor CURSOR FOR
        SELECT file_name
        FROM [kbulk].[blob_files];

    OPEN blob_cursor;

    FETCH NEXT FROM blob_cursor INTO @FileName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- 🧠 Derive entity name from file name (strip .csv)
        IF RIGHT(@FileName, 4) = '.csv'
        BEGIN
            SET @EntityName = LEFT(@FileName, LEN(@FileName) - 4);

            PRINT '📦 Importing entity: ' + @EntityName;

            EXEC [kbulk].[load_from_blob_by_file]
                @EntityName = @EntityName,
                @SchemaName = @SchemaName,
                @DataSource = @DataSource;
        END
        ELSE
        BEGIN
            PRINT '⚠️ Skipping file with unexpected extension: ' + @FileName;
        END

        FETCH NEXT FROM blob_cursor INTO @FileName;
    END

    CLOSE blob_cursor;
    DEALLOCATE blob_cursor;

    PRINT '✅ All blob imports completed.';
END

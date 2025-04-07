/*
--------------------------------------------------------------------------------------
 Script:    remove_klog.sql
 Purpose:   Fully remove the klog module and its objects from the database
 Author:    Kasper Ulvedal
 License:   MIT
 Version:   1.1.2
 Date:      2025-01-08
--------------------------------------------------------------------------------------
*/

-- Step 0: Dependency check
IF EXISTS (
    SELECT 1
    FROM sys.sql_expression_dependencies d
    JOIN sys.objects o ON d.referencing_id = o.object_id
    WHERE d.referenced_schema_name = 'klog'
)
BEGIN
    PRINT '❌ Cannot drop klog — other objects depend on it. See dependencies below:';

    SELECT 
        OBJECT_SCHEMA_NAME(d.referencing_id) AS referencing_schema,
        OBJECT_NAME(d.referencing_id) AS referencing_object,
        d.referenced_entity_name AS referenced_klog_object,
        o.type_desc AS referencing_type
    FROM sys.sql_expression_dependencies d
    JOIN sys.objects o ON d.referencing_id = o.object_id
    WHERE d.referenced_schema_name = 'klog';

    RETURN;
END

PRINT '✅ No dependencies found. Proceeding to remove klog module.';

DECLARE @sql NVARCHAR(MAX);
DECLARE @stmt NVARCHAR(MAX);

-- Step 1: Drop default + primary key constraints
DECLARE drop_constraints CURSOR FOR
SELECT 
    'ALTER TABLE [' + s.name + '].[' + t.name + '] DROP CONSTRAINT [' + d.name + '];'
FROM sys.objects d
JOIN sys.tables t ON d.parent_object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'klog'
  AND d.type IN ('D', 'PK');  -- D = Default, PK = Primary Key

OPEN drop_constraints;
FETCH NEXT FROM drop_constraints INTO @stmt;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC sp_executesql @stmt;
        PRINT '✅ Dropped constraint: ' + @stmt;
    END TRY
    BEGIN CATCH
        PRINT '⚠️ Could not drop constraint: ' + ERROR_MESSAGE();
    END CATCH
    FETCH NEXT FROM drop_constraints INTO @stmt;
END
CLOSE drop_constraints;
DEALLOCATE drop_constraints;

-- Step 2: Drop views
DECLARE drop_views CURSOR FOR
SELECT 'DROP VIEW IF EXISTS [' + s.name + '].[' + o.name + '];'
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name = 'klog' AND o.type = 'V';

OPEN drop_views;
FETCH NEXT FROM drop_views INTO @stmt;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC sp_executesql @stmt;
    FETCH NEXT FROM drop_views INTO @stmt;
END
CLOSE drop_views;
DEALLOCATE drop_views;

-- Step 3: Drop procedures
DECLARE drop_procs CURSOR FOR
SELECT 'DROP PROCEDURE IF EXISTS [' + s.name + '].[' + o.name + '];'
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name = 'klog' AND o.type = 'P';

OPEN drop_procs;
FETCH NEXT FROM drop_procs INTO @stmt;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC sp_executesql @stmt;
    FETCH NEXT FROM drop_procs INTO @stmt;
END
CLOSE drop_procs;
DEALLOCATE drop_procs;

-- Step 4: Drop tables
DECLARE drop_tables CURSOR FOR
SELECT 'DROP TABLE IF EXISTS [' + s.name + '].[' + o.name + '];'
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name = 'klog' AND o.type = 'U';

OPEN drop_tables;
FETCH NEXT FROM drop_tables INTO @stmt;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC sp_executesql @stmt;
    END TRY
    BEGIN CATCH
        PRINT '⚠️ Could not drop table: ' + ERROR_MESSAGE();
    END CATCH
    FETCH NEXT FROM drop_tables INTO @stmt;
END
CLOSE drop_tables;
DEALLOCATE drop_tables;

-- Step 5: Drop the schema
BEGIN TRY
    SET @sql = 'DROP SCHEMA IF EXISTS [klog];';
    EXEC sp_executesql @sql;
    PRINT '✅ klog schema successfully removed.';
END TRY
BEGIN CATCH
    PRINT '❌ Could not drop schema: ' + ERROR_MESSAGE();
END CATCH;

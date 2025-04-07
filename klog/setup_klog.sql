/*
--------------------------------------------------------------------------------------
 Script:    setup_klog.sql
 Purpose:   Procedure Execution Logging Framework
 Author:    Kasper Ulvedal
 License:   MIT
 Version:   1.0.3
 Date:      2025-01-08
--------------------------------------------------------------------------------------
 This script sets up a lightweight logging framework for tracking the execution of 
 SQL procedures against tables, including durations, row counts, and job status.

 Components:
 - [klog].[execution_log]            : Log table for recording each execution
 - [klog].[start_execution]          : Start log procedure with initial row count
 - [klog].[end_execution]            : End log procedure with final row count & optional message
 - [klog].[cleanup_stale_executions] : Cleans up logs still marked as 'Running' when procedure is not
 - [klog].[vw_execution_log]         : View to inspect job durations and row deltas (WITH NOLOCK)
 - [klog].[run_proc_with_logging]    : Wrapper for executing any procedure with klog automatically
--------------------------------------------------------------------------------------
*/

-- 📁 Ensure the logging schema exists
IF NOT EXISTS (
    SELECT 1 FROM sys.schemas WHERE name = 'klog'
)
BEGIN
    EXEC('CREATE SCHEMA [klog]');
END;
GO

-- 📋 Create the execution log table
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.name = 'execution_log' AND s.name = 'klog'
)
BEGIN
    CREATE TABLE [klog].[execution_log] (
        log_id INT IDENTITY(1,1) PRIMARY KEY,
        procedure_name SYSNAME NOT NULL,
        table_name SYSNAME NOT NULL,
        start_time DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        start_rowcount BIGINT NULL,
        end_time DATETIME2 NULL,
        end_rowcount BIGINT NULL,
        status NVARCHAR(50) NULL,
        message NVARCHAR(1000) NULL
    );
END;
GO

-- 🚀 Procedure: Start execution log
CREATE OR ALTER PROCEDURE [klog].[start_execution]
    @ProcedureName SYSNAME,
    @TableName SYSNAME,
    @LogId INT OUTPUT
AS
BEGIN
    /*
    --------------------------------------------------------------------------------------
    Procedure: [klog].[start_execution]
    Author:    Kasper Ulvedal
    License:   MIT
    Version:   1.0.2
    Purpose:   Start a new execution log and record initial row count. Also triggers cleanup.
    --------------------------------------------------------------------------------------
    */
    SET NOCOUNT ON;

    -- Clean stale logs
    EXEC klog.cleanup_stale_executions;

    DECLARE @Schema SYSNAME = PARSENAME(@TableName, 2);
    DECLARE @Object SYSNAME = PARSENAME(@TableName, 1);
    DECLARE @FullName NVARCHAR(512) = QUOTENAME(@Schema) + '.' + QUOTENAME(@Object);

    -- ✅ Validate that the table exists
    IF NOT EXISTS (
        SELECT 1
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = @Schema
          AND TABLE_NAME = @Object
    )
    BEGIN
        RAISERROR('Table %s does not exist.', 16, 1, @TableName);
        RETURN;
    END

    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @StartRowCount BIGINT;

    SET @SQL = 'SELECT @cnt = COUNT(*) FROM ' + @FullName;
    EXEC sp_executesql @SQL, N'@cnt BIGINT OUTPUT', @cnt = @StartRowCount OUTPUT;

    INSERT INTO [klog].[execution_log] (
        procedure_name, table_name, start_time, start_rowcount, status
    )
    VALUES (
        @ProcedureName, @TableName, SYSUTCDATETIME(), @StartRowCount, 'Running'
    );

    SET @LogId = SCOPE_IDENTITY();
END;
GO

-- ✅ Procedure: End execution log
CREATE OR ALTER PROCEDURE [klog].[end_execution]
    @LogId INT,
    @Status NVARCHAR(50),
    @Message NVARCHAR(1000) = NULL
AS
BEGIN
    /*
    --------------------------------------------------------------------------------------
    Procedure: [klog].[end_execution]
    Author:    Kasper Ulvedal
    License:   MIT
    Version:   1.0.1
    Purpose:   Finalize execution log with end time, row count, and outcome status
    --------------------------------------------------------------------------------------
    */
    SET NOCOUNT ON;

    DECLARE @TableName SYSNAME;
    DECLARE @Schema SYSNAME;
    DECLARE @Object SYSNAME;
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @EndRowCount BIGINT;

    SELECT @TableName = table_name
    FROM [klog].[execution_log]
    WHERE log_id = @LogId;

    IF @TableName IS NULL
    BEGIN
        RAISERROR('❌ Log ID %d not found in execution log.', 16, 1, @LogId);
        RETURN;
    END

    SET @Schema = PARSENAME(@TableName, 2);
    SET @Object = PARSENAME(@TableName, 1);
    DECLARE @FullName NVARCHAR(512) = QUOTENAME(@Schema) + '.' + QUOTENAME(@Object);

    SET @SQL = 'SELECT @cnt = COUNT(*) FROM ' + @FullName;
    EXEC sp_executesql @SQL, N'@cnt BIGINT OUTPUT', @cnt = @EndRowCount OUTPUT;

    UPDATE [klog].[execution_log]
    SET
        end_time = SYSUTCDATETIME(),
        end_rowcount = @EndRowCount,
        status = @Status,
        message = @Message
    WHERE log_id = @LogId;
END;
GO


-- 🧼 Procedure: Clean up stale executions
CREATE OR ALTER PROCEDURE [klog].[cleanup_stale_executions]
AS
BEGIN
    /*
    --------------------------------------------------------------------------------------
    Procedure: [klog].[cleanup_stale_executions]
    Author:    Kasper Ulvedal
    License:   MIT
    Version:   1.0.0
    Purpose:   Mark 'Running' executions as 'Failed' if no longer found in sys.dm_exec_requests
    --------------------------------------------------------------------------------------
    */
    SET NOCOUNT ON;

    -- Temp table for active procedure names
    IF OBJECT_ID('tempdb..#active_procs') IS NOT NULL DROP TABLE #active_procs;

    SELECT DISTINCT OBJECT_NAME(st.objectid) AS procedure_name
    INTO #active_procs
    FROM sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
    WHERE r.session_id <> @@SPID;

    -- Update stale entries
    UPDATE l
    SET
        status = 'Failed',
        message = '⛔ Automatically marked as failed - not found in active sessions',
        end_time = SYSUTCDATETIME(),
        end_rowcount = NULL
    FROM klog.execution_log l
    LEFT JOIN #active_procs ap ON l.procedure_name = ap.procedure_name
    WHERE l.status = 'Running' AND l.end_time IS NULL AND ap.procedure_name IS NULL;

    DROP TABLE #active_procs;
END;
GO

-- 🚀 Procedure: Run any procedure with logging
CREATE OR ALTER PROCEDURE [klog].[run_proc_with_logging]
    @ProcedureName SYSNAME,      -- The name of the procedure to run (e.g., 'mySchema.myProc')
    @TableName SYSNAME           -- The target table being modified (e.g., 'mySchema.myTable')
AS
BEGIN
    /*
    --------------------------------------------------------------------------------------
    Procedure: [klog].[run_proc_with_logging]
    Author:    Kasper Ulvedal
    License:   MIT
    Version:   1.0.1
    Purpose:   Wrapper to run any stored procedure with execution logging in klog
    --------------------------------------------------------------------------------------
    */
    SET NOCOUNT ON;

    DECLARE @LogId INT;
    DECLARE @ErrorMessage NVARCHAR(1000);

    BEGIN TRY
        -- 📝 Start the execution log
        EXEC klog.start_execution
            @ProcedureName = @ProcedureName,
            @TableName = @TableName,
            @LogId = @LogId OUTPUT;

        IF @LogId IS NULL
        BEGIN
            PRINT '❌ Logging failed to start. Procedure not executed.';
            RETURN;
        END

        -- 📦 Run the procedure
        DECLARE @SQL NVARCHAR(MAX) = 'EXEC ' + QUOTENAME(@ProcedureName);
        EXEC sp_executesql @SQL;

        -- ✅ Mark as successful
        EXEC klog.end_execution
            @LogId = @LogId,
            @Status = 'Success',
            @Message = NULL;
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        IF @LogId IS NOT NULL
        BEGIN
            EXEC klog.end_execution
                @LogId = @LogId,
                @Status = 'Failed',
                @Message = @ErrorMessage;
        END

        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;
GO

-- 🔍 View: Execution log overview
CREATE OR ALTER VIEW [klog].[vw_execution_log]
AS
/*
--------------------------------------------------------------------------------------
 View:      [klog].[vw_execution_log]
 Author:    Kasper Ulvedal
 License:   MIT
 Version:   1.0.1
 Purpose:   View to inspect procedure durations, row changes, and outcome messages
--------------------------------------------------------------------------------------
*/
SELECT
    log_id,
    procedure_name,
    table_name,
    status,
    DATEDIFF(SECOND, start_time, end_time) AS duration_sec,
    DATEDIFF(MINUTE, start_time, end_time) AS duration_min,
    start_rowcount,
    end_rowcount,
    end_rowcount - start_rowcount AS delta_rows,
    message,
    start_time,
    end_time
FROM [klog].[execution_log] WITH (NOLOCK);
GO

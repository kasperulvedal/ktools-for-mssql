/*
--------------------------------------------------------------------------------------
 Script:    example_klog_usage.sql
 Purpose:   Example procedure using klog to log execution of an insert operation
 Author:    Kasper Ulvedal
 License:   MIT
 Version:   1.0.7
 Date:      2025-01-08
--------------------------------------------------------------------------------------
 
 This template is designed to be used as a starting point for your own procedures. 
 You can modify the logic inside the TRY block to suit your needs.
 
 This procedure demonstrates a complete pattern for using klog to track insert
 operations. It ensures:
 - The log is written even on failure.
 - Transactions are scoped around risky logic only.
 - Failure bubbles through and is recorded with error message.

 Please note:
 - This template ensures that the execution of your procedure is logged, even if an error occurs.
 - However, it may not capture errors if object names (such as table names or column names) are incorrect, as this error will occur before the procedure logic is executed.
 - Look into example_klog_usage_with_generic_proc_call.sql for a more generic approach to logging.

--------------------------------------------------------------------------------------
*/

CREATE OR ALTER PROCEDURE [dim].[generate_Customer] AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogId INT;
    DECLARE @ErrorMessage NVARCHAR(1000);
    DECLARE @TableName SYSNAME = 'dim.Customer';

    -- 🔁 Start log (will return log_id or raise error if table doesn't exist)
    EXEC klog.start_execution
        @ProcedureName = 'dim.generate_Customer',
        @TableName = @TableName,
        @LogId = @LogId OUTPUT;

    -- ✅ Confirm log started
    IF @LogId IS NULL
    BEGIN
        PRINT '❌ Could not start execution log. Exiting procedure.';
        RETURN;
    END

    -- ⚙️ Do your actual data logic inside TRY
    BEGIN TRY
        -- Example logic — will fail if the table or columns are invalid
        TRUNCATE TABLE dim.Customer;

        INSERT INTO dim.Customer (
            [Customer Number],
            [Customer Name],
            [Customer Default Currency],
            [Customer City],
            [Customer Country]
        )
        SELECT
            customerNumber,
            name,
            currency,
            city,
            country
        --FROM stg_econRest.Customer;
        FROM stg_econRest.Customers;

        -- ✅ Success path: end log
        EXEC klog.end_execution
            @LogId = @LogId,
            @Status = 'Success',
            @Message = NULL;
    END TRY
    BEGIN CATCH
        -- 🐞 Catch error
        SET @ErrorMessage = ERROR_MESSAGE();

        -- 👇 Ensure log is updated even if insert failed
        IF @LogId IS NOT NULL
        BEGIN
            EXEC klog.end_execution
                @LogId = @LogId,
                @Status = 'Failed',
                @Message = @ErrorMessage;
        END

        -- 📣 Rethrow for visibility
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;

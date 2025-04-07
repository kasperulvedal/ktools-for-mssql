/*
--------------------------------------------------------------------------------------
 Script:    example_klog_usage_with_generic_proc_call.sql
 Purpose:   Example template for calling another procedure with logging
 Author:    Kasper Ulvedal
 License:   MIT
 Version:   1.0.0
 Date:      2025-01-08
--------------------------------------------------------------------------------------
 This template demonstrates how to use klog to log the execution of any procedure 
 through a generic call. The purpose of using klog for logging execution is to:

 1. **Ensure that each procedure execution is logged**: You can track the start, end, and duration of any procedure execution.
 2. **Error logging**: When a procedure fails, it automatically logs the failure, including the error message, ensuring transparency and easy debugging.
 3. **Consistency**: By using the logging template, all developers can ensure uniform error handling, making it easier to maintain and monitor operations.

 It is recommended to use this approach for all key procedures to monitor execution and capture errors for improved diagnostics and support.
--------------------------------------------------------------------------------------
*/

-- 🧩 Example Procedure to Call
CREATE OR ALTER PROCEDURE [dbo].[your_procedure_name]
AS
BEGIN
    -- Example logic (modify this part with your actual logic)
    SET NOCOUNT ON;

    PRINT 'Procedure logic goes here';
    -- Add your actual procedure logic here
END;

-- 🔁 Using run_proc_with_logging to call your procedure with logging
DECLARE @LogId INT;
DECLARE @Status NVARCHAR(50) = 'Success';
DECLARE @ErrorMessage NVARCHAR(1000);

BEGIN TRY
    -- Start the logging procedure with the procedure name and the table name
    EXEC klog.run_proc_with_logging
        @ProcedureName = 'your_procedure_name', -- Name of the procedure you want to call
        @TableName = 'your_table_name',         -- Specify the table related to the procedure
        @LogId = @LogId OUTPUT;                 -- Log ID returned for tracking

    -- Here you can place any additional logic to be executed after your procedure call
    -- Example:
    PRINT 'Additional logic after procedure call';

END TRY
BEGIN CATCH
    -- Catch any errors that happen during procedure execution
    SET @ErrorMessage = ERROR_MESSAGE();

    -- Log the failure and the error message
    IF @LogId IS NOT NULL
    BEGIN
        EXEC klog.end_execution
            @LogId = @LogId,
            @Status = 'Failed',
            @Message = @ErrorMessage;
    END

    -- Optionally rethrow the error or handle it in a way that suits your needs
    RAISERROR(@ErrorMessage, 16, 1);
END CATCH

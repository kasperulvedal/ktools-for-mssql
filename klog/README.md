
# klog – Lightweight Procedure Execution Logging

`klog` is a pure T-SQL module for logging the execution of stored procedures at the table level in Microsoft SQL Server and Azure SQL.  
It is part of the [ktools for MSSQL](../README.md) collection.

---

## 🔍 Purpose

The goal of `klog` is to help you **monitor and troubleshoot SQL jobs** by tracking:

- Procedure start and end timestamps
- Row counts before and after execution
- Status (`Success`, `Failed`, etc.)
- Optional messages (e.g. error outputs)
- Duration and row delta per execution

This helps identify:
- When a process started performing poorly
- If data volumes have changed unexpectedly
- Where errors occur during scheduled loads

---

## 📦 Components

| Object                        | Type       | Purpose                                                |
|------------------------------|------------|--------------------------------------------------------|
| `klog.execution_log`          | Table      | Stores procedure execution metadata                    |
| `klog.start_execution`       | Procedure  | Begins logging for a table-related procedure           |
| `klog.end_execution`         | Procedure  | Completes the log entry, records result + row count    |
| `klog.vw_execution_log`      | View       | Shows recent executions with duration and row delta    |
| `klog.cleanup_stale_executions` | Procedure  | Removes log entries that were marked as running but no longer active |

---

## 🛠 Setup

Run the [`setup_klog.sql`](./setup_klog.sql) script to install the module.

This will:
- Create the `klog` schema if it doesn't exist.
- Set up the `execution_log` table to store procedure execution data.
- Create the `start_execution` and `end_execution` procedures to manage logging.
- Create a view (`vw_execution_log`) for querying execution history.

---

## 🧪 Usage

### 1. Start a log entry
This step begins the logging process for your procedure execution. It ensures the procedure execution is logged, even if an error occurs.

```sql
DECLARE @LogId INT;

EXEC klog.start_execution 
    @ProcedureName = 'my_proc',
    @TableName = 'schema.my_table',
    @LogId = @LogId OUTPUT;
```

### 2. Execute your logic
Here you can add any SQL operation that you want to track, such as an `INSERT`, `UPDATE`, `MERGE`, or `DELETE`.

For example:

```sql
TRUNCATE TABLE schema.my_table;

INSERT INTO schema.my_table (Column1, Column2)
SELECT Column1, Column2
FROM another_table;
```

### 3. Finalize the log entry
After your logic completes, you finalize the log entry to indicate whether the procedure was successful or failed.

```sql
EXEC klog.end_execution 
    @LogId = @LogId,
    @Status = 'Success',
    @Message = NULL;  -- Or include an error message if there was an issue
```

### Optionally: Wrap in TRY/CATCH
To ensure that logs are written even if an error occurs, wrap your logic in a `TRY...CATCH` block:

```sql
BEGIN TRY
    -- Execute your logic
    EXEC klog.end_execution 
        @LogId = @LogId,
        @Status = 'Success',
        @Message = NULL;
END TRY
BEGIN CATCH
    -- Log the failure and capture the error message
    EXEC klog.end_execution 
        @LogId = @LogId,
        @Status = 'Failed',
        @Message = ERROR_MESSAGE();

    -- Re-throw the error for upstream handling
    THROW;
END CATCH
```

### 4. Handle execution timeouts
`klog` automatically updates the execution time, status, and message, but if your procedure takes too long or times out, you may need to manually handle these cases. You can use `klog.cleanup_stale_executions` to mark running jobs as failed if they are no longer active.

```sql
EXEC klog.cleanup_stale_executions;
```

This will ensure that any processes stuck in the "Running" state in the `execution_log` are updated with a "Failed" status.

---

## 🔎 Query execution history

To view recent execution logs, use the `vw_execution_log` view:

```sql
SELECT * 
FROM klog.vw_execution_log 
ORDER BY start_time DESC;
```

This will show:
- The procedure name, table name, status, and duration
- The row count before and after execution
- The delta (difference in row counts)
- Any optional messages (such as error messages)

---

## 📜 License

This module is published under the MIT License.

## 👤 Author

Kasper Ulvedal — [ktools for MSSQL](../README.md)

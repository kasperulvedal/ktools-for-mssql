# kbulk – Azure SQL Bulk Insert Framework

`kbulk` is a lightweight, metadata-driven T-SQL framework for performing structured `BULK INSERT` operations from Azure Blob Storage into SQL Server or Azure SQL.

This module is part of the **ktools for MSSQL** collection.

---

## 🚀 What It Does

- Uses metadata to manage file-based loads
- Supports CSV files with associated XML format files
- Automatically truncates destination tables (if setup in metadata)
- Loads one or all files using procedures
- Logs last successful load timestamps for monitoring

---

## 📋 Setup

Run the `setup_kbulk.sql` script. It will:

- Create the `kbulk` schema (if it doesn't exist)
- Create the `[kbulk].[blob_files]` metadata table
- Deploy:
  - `kbulk.load_from_blob_by_file` – load a single entity
  - `kbulk.run_all_blob_imports` – load all registered files

---

## 📂 Metadata Table

`kbulk.blob_files` defines what should be loaded:

| Column               | Description                                |
|----------------------|--------------------------------------------|
| `file_name`          | CSV filename (e.g., `PageCustomer.csv`)    |
| `truncate_on_load`   | 1 = truncate destination table before load |
| `schema_name`        | Schema of destination table                |
| `data_source`        | External data source (e.g., `AzureBlobStorage`) |
| `sys_insert_datetime`| Row creation timestamp                     |
| `sys_last_update_datetime` | Timestamp of last load              |

---

## 🛠️ Usage

### Register files

```sql
INSERT INTO kbulk.blob_files (file_name, truncate_on_load, schema_name, data_source)
VALUES 
('Companies.csv', 1, 'stg_hubspot', 'AzureBlobStorage'),
('Contacts.csv', 1, 'stg_hubspot', 'AzureBlobStorage');
('Deals.csv', 1, 'stg_hubspot', 'AzureBlobStorage');
```

### Load one file

```sql
EXEC kbulk.load_from_blob_by_file 
    @EntityName = 'Companies',
    @SchemaName = 'stg_hubspot',
    @DataSource = 'AzureBlobStorage';
```

### Load all registered files

```sql
EXEC kbulk.run_all_blob_imports;
```

---

## 📌 Conventions

- Format files must match the CSV name (e.g., `Companies.xml`)
- Destination tables must exist beforehand
- Assumes files are accessible via the `DATA_SOURCE` provided

---

## 👤 Author & License

- Developed by **Kasper Ulvedal**
- Licensed under the **MIT License**

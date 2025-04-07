# Lightweight SQL Data Warehouse (DW) Framework

A **self-contained, SQL-only framework** for building structured data warehouses directly inside Microsoft SQL Server or Azure SQL — with minimal dependencies and a strong focus on simplicity, consistency, and maintainability.

---

## 🧭 Purpose

This framework is designed for consultants, analysts, and engineers who want to implement structured dimensional models without external orchestration tools or heavyweight platforms.

> It **does not handle ingestion** — only modeling, transformation, and storage of curated data within SQL Server.

---

## 🧱 Schema Structure

The DW design follows a layered schema strategy:

| Schema        | Purpose                             |
|---------------|-------------------------------------|
| `dim`         | Dimension tables                    |
| `fact`        | Fact tables (observational data)    |
| `stg_*`       | (Optional) Raw or cleaned staging   |

---

## 🔤 Naming Conventions

| Type       | Prefix      | Example                    |
|------------|-------------|----------------------------|
| Dimension  | `dim_`      | `dim_customer`, `dim_date` |
| Fact       | `fact_`     | `fact_orders`, `fact_sales` |
| Views      | `vw_`       | `vw_sales_by_product`      |
| Keys       | `pk_`, `fk_`| `pk_dim_customer`, `fk_customer_id` |

- Use lowercase and underscores
- Keep names short but descriptive
- Always include business logic in views, not raw tables

---

## 🏗️ Template: Simple Dimension Table

```sql
CREATE TABLE dim.dim_customer (
    customer_id INT PRIMARY KEY,
    customer_name NVARCHAR(255),
    country_code CHAR(2),
    inserted_at DATETIME2 DEFAULT SYSUTCDATETIME()
);
```

---

## 🏗️ Template: Slowly Changing Dimension (Type 2)

```sql
CREATE TABLE dim.dim_employee (
    surrogate_key INT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT NOT NULL,
    employee_name NVARCHAR(255),
    department NVARCHAR(255),
    valid_from DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    valid_to DATETIME2,
    is_current BIT NOT NULL DEFAULT 1
);
```

> Use `MERGE` or scripting logic to insert new versions when attributes change.

---

## 🏗️ Template: Fact Table

```sql
CREATE TABLE fact.fact_sales (
    sales_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    product_id INT NOT NULL,
    sales_date DATE NOT NULL,
    amount DECIMAL(18,2) NOT NULL,
    inserted_at DATETIME2 DEFAULT SYSUTCDATETIME()
);
```

---

## 🔑 Template: Surrogate Key Generator (Key Store)

```sql
CREATE TABLE dw.key_store (
    entity_name SYSNAME PRIMARY KEY,
    last_id BIGINT NOT NULL
);

GO

-- Procedure to reserve the next key
CREATE OR ALTER PROCEDURE dw.reserve_next_key
    @EntityName SYSNAME,
    @NextId BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dw.key_store AS target
    USING (SELECT @EntityName AS entity_name) AS source
    ON target.entity_name = source.entity_name
    WHEN NOT MATCHED THEN
        INSERT (entity_name, last_id) VALUES (source.entity_name, 0);

    UPDATE dw.key_store
    SET last_id = last_id + 1
    OUTPUT inserted.last_id INTO @NextId;
END;
```

---

## 📈 Best Practices

- Build all transformations as **views or `INSERT INTO` statements**
- Use **SCD Type 2** where historical tracking is required
- Store **UTC timestamps** for consistency
- Separate business rules from data movement

---

## 🔍 Example Flow

```text
[ stg_* or external ETL ]
           ↓
   [ dim.dim_* and fact.fact_* ]
           ↓
 [ views for reporting or Power BI ]
```

---

## 📜 License

MIT — use freely, fork, and adapt.

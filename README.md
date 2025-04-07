# ktools for MSSQL

**ktools for MSSQL** is a collection of lightweight, modular tools written in T-SQL for Microsoft SQL Server and Azure SQL.  
These tools are designed to help data engineers, BI developers, and DBAs manage data processing, observability, and data modeling **without relying on external orchestration frameworks**.

> Think of it as your minimalist utility belt for SQL Server.

---

## 📦 Modules

### 🚀 [klog](./klog/)
A **procedure execution logger** that tracks run time, row changes, and job status at the table level.

Includes:
- Logging table
- Start/End logging procedures
- View with durations and delta row counts
- Useful for troubleshooting, monitoring, and auditing data jobs

### 🧱 [lightweight_dw](./lightweight_dw.md)
A SQL-first approach to **data warehouse modeling**, using simple schema conventions:

- `dim.` for dimension tables
- `fact.` for fact tables
- Naming templates and SCD Type 2 examples
- Includes surrogate key generator and best practices

---

## 🛠 Getting Started

Each module includes:
- A `setup_*.sql` script to deploy
- A dedicated `README.md` with purpose, setup, and usage

Just clone this repo and run what you need — you can adopt one or all modules independently.

```bash
git clone https://github.com/youruser/ktools-for-mssql.git
```

---

## 📌 Design Philosophy

- ⚙️ **Pure SQL**: No CLR, no external dependencies, no custom runtimes
- 🧼 **Lightweight**: Small, composable, and easy to understand
- 🪟 **Azure-Ready**: Optimized for use in Azure SQL Database
- 🧪 **Production-Ready**: Built for logging, maintenance, and observability

---

## 📜 License

This project is licensed under the [MIT License](./LICENSE). Use freely.

---

## 🤝 Contributing

We welcome suggestions and contributions!  
See [CONTRIBUTING.md](./CONTRIBUTING.md) to get started.
=======
# ktools-for-mssql
Modular SQL Server toolkit for logging, bulk insert, and lightweight data warehousing. Built in pure T-SQL for Azure SQL and beyond.
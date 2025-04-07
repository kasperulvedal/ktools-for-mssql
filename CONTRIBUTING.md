# Contributing to ktools for MSSQL

First off, thanks for taking the time to contribute! 🙌

We welcome improvements, suggestions, bug fixes, and new modules.

---

## 🧱 What's This Project About?

This toolkit is designed for SQL Server users who want production-quality,
modular utilities written in plain T-SQL — without heavy dependencies or frameworks.

---

## 💡 How to Contribute

1. **Fork the repo** and create your branch:
   ```bash
   git checkout -b feature/my-cool-feature
   ```

2. **Stick to the structure**:
   - Each module should live in its own folder (e.g., `/klog/`, `/kbulk/`)
   - Each module should include:
     - A `setup_*.sql` script
     - A `README.md` for documentation
     - Optional: `example.sql` for demos

3. **Document everything** clearly with SQL comments and/or markdown.

4. **Submit a pull request** and describe what you’re changing and why.

---

## 🧪 What Makes a Good Contribution?

- Self-contained: new functionality should not break others
- Lightweight: avoid unnecessary complexity
- Portable: it should work on both SQL Server and Azure SQL
- Helpful: focus on use cases data engineers encounter often

---

## 🙏 Thank You

We appreciate all contributions, whether they're big, small, fixes, features, or ideas.


<h1 align="center">SQL Pattern Cheat Sheet</h1>

<p align="center">
  Practical T-SQL patterns for window functions, deduplication, date spines,
  pivoting, joins and NULLs, and reconciliation, with mock data you can load in minutes.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/SQL-T--SQL-CC2927?style=for-the-badge&logo=microsoftsqlserver&logoColor=white" alt="T-SQL" />
  <img src="https://img.shields.io/badge/Data-100%25%20Mock-2EA44F?style=for-the-badge" alt="Mock data only" />
</p>

---

<!-- After you test the queries, add a line here such as:
> **Tested:** all queries were run on SQL Server (version) against the mock data in this repo.
-->

## Patterns

| Page | What it covers |
| --- | --- |
| [01. Window Functions](patterns/01-window-functions.md) | Ranking, running totals, moving averages, `LAG` and `LEAD`, percent of total |
| [02. Dedupe and Top N](patterns/02-dedupe-and-top-n.md) | Finding duplicates, keeping the latest row, safe deletes, top N per group |
| [03. Date Spines and Gaps](patterns/03-date-spines-and-gaps.md) | Filling missing months, finding gaps, streaks of consecutive months |
| [04. Conditional Aggregation and Pivot](patterns/04-conditional-aggregation-and-pivot.md) | Rows to columns, conditional counts and rates, `ROLLUP` subtotals |
| [05. Joins and NULLs](patterns/05-joins-and-nulls.md) | Anti-joins, the `NOT IN` trap, `LEFT JOIN` filters, row multiplication |
| [06. Reconciliation and Checks](patterns/06-reconciliation-and-checks.md) | Comparing two sources, data quality checks, performance habits |

Each page gives the query, a short explanation, and a table of common problems and fixes.

## Set Up the Mock Data

Run these in SQL Server, Azure SQL, or a free SQL Server Express install. Run them in order.

1. [`mock-data/01_create_and_load.sql`](mock-data/01_create_and_load.sql) creates `FactInvoices`, `DimDate`, and `FactSLA`. It ends with a row-count check (120, 822, and 216).
2. [`mock-data/02_staging_and_reconciliation.sql`](mock-data/02_staging_and_reconciliation.sql) adds `StagingInvoices` and `InvoicesSourceB`. It ends with a row-count check (28 and 118).

Both scripts can be re-run at any time. They drop and rebuild their tables.

## The Tables

| Table | Rows | Purpose |
| --- | --- | --- |
| `FactInvoices` | 120 | Invoices across 3 programs and 4 vendors, Oct 2024 to Sep 2026 |
| `DimDate` | 822 | Daily calendar with an October fiscal year start |
| `FactSLA` | 216 | Monthly results for 3 metrics, each with its own goal and direction |
| `StagingInvoices` | 28 | A messy load with corrected reloads and exact repeats, for dedupe patterns |
| `InvoicesSourceB` | 118 | A second system with planted differences, for reconciliation |

## Conventions

- **Dialect:** T-SQL. Most patterns need SQL Server 2016 or later.
- **Half-open date ranges:** date filters use `>= start AND < next start`, which works for dates and datetimes and lets indexes help.
- **Tiebreakers:** ranking and ordering examples add a unique column so results are repeatable.
- **Fiscal year naming:** the fiscal year is named for the calendar year in which it ends (Oct 2025 to Sep 2026 is FY2026).

## About the Data

All data in this repository is fabricated. No client, employer, or production data is included.

## Author

**Taryn Ledford**
[LinkedIn](https://www.linkedin.com/in/taryn-ledford)

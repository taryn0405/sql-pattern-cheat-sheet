# 03. Date Spines and Gaps

Reports break when a month with no activity simply disappears. A date spine (a complete list of dates or months) guarantees every period shows up, and the same idea finds missing periods and streaks.

## Fill missing months with zero

```sql
SELECT
    mo.MonthStart,
    COALESCE(SUM(f.Amount), 0) AS Amount
FROM (
    SELECT DISTINCT MonthStart
    FROM dbo.DimDate
    WHERE MonthStart <= '2026-09-01'
) AS mo
LEFT JOIN dbo.FactInvoices AS f
    ON f.InvoiceDate >= mo.MonthStart
   AND f.InvoiceDate <  DATEADD(MONTH, 1, mo.MonthStart)
GROUP BY mo.MonthStart
ORDER BY mo.MonthStart;
```

The join uses a half-open range (`>=` start and `<` next month start). It works whether the column is a date or a datetime, and it lets SQL Server use an index on the date column.

## Build a spine without a date table

```sql
WITH Spine AS (
    SELECT CAST('2024-10-01' AS DATE) AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d)
    FROM Spine
    WHERE d < '2024-12-31'
)
SELECT d
FROM Spine
OPTION (MAXRECURSION 400);
```

Recursive queries stop at 100 levels by default. `MAXRECURSION` raises the limit, and `0` removes it, so use it carefully. For anything permanent, a real date table (like `DimDate`) is faster and reusable.

## Find months with no invoices

```sql
SELECT p.Program, mo.MonthStart
FROM (SELECT DISTINCT Program FROM dbo.FactInvoices) AS p
CROSS JOIN (
    SELECT DISTINCT MonthStart
    FROM dbo.DimDate
    WHERE MonthStart BETWEEN '2024-10-01' AND '2026-09-01'
) AS mo
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.FactInvoices AS f
    WHERE f.Program = p.Program
      AND f.InvoiceDate >= mo.MonthStart
      AND f.InvoiceDate <  DATEADD(MONTH, 1, mo.MonthStart)
)
ORDER BY p.Program, mo.MonthStart;
```

This returns a row for each program and month with no activity. An empty result means every program invoiced in every month, which is a valid answer for this data.

## Gaps and islands: streaks of consecutive months

```sql
WITH Months AS (
    SELECT DISTINCT
        Program,
        DATEFROMPARTS(YEAR(InvoiceDate), MONTH(InvoiceDate), 1) AS MonthStart
    FROM dbo.FactInvoices
),
Numbered AS (
    SELECT
        Program,
        MonthStart,
        DATEADD(
            MONTH,
            -CAST(ROW_NUMBER() OVER (PARTITION BY Program ORDER BY MonthStart) AS INT),
            MonthStart
        ) AS GroupKey
    FROM Months
)
SELECT
    Program,
    MIN(MonthStart) AS IslandStart,
    MAX(MonthStart) AS IslandEnd,
    COUNT(*)        AS MonthsInRow
FROM Numbered
GROUP BY Program, GroupKey
ORDER BY Program, IslandStart;
```

For consecutive months, subtracting the row number from each month gives the same key, so each unbroken streak (an "island") shares one `GroupKey`. A new streak starts wherever there is a gap. With this mock data you will likely see one island per program. Delete a few invoices to watch it split.

## Common problems

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Zero months missing from the report | Joined from the fact table, not from a spine | Start from the date table and `LEFT JOIN` the facts |
| Last day of the month missing | Used `<= EOMONTH` on a datetime column | Use `>= start AND < next start` |
| "Maximum recursion" error | Spine longer than 100 steps | Add `OPTION (MAXRECURSION n)` or use a date table |
| Zeros appear for future months | Spine extends past the last data | Cap the spine at the last data date |
| Island logic gives odd groups | Duplicate months in the input | `SELECT DISTINCT` months first, as above |

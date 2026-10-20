# 06. Reconciliation and Checks

Prove two sources agree, find exactly where they differ, and catch bad data early. These use `dbo.InvoicesSourceB` and `dbo.StagingInvoices` from `mock-data/02_staging_and_reconciliation.sql`.

## Step 1: compare the totals

```sql
SELECT 'Source A' AS SourceName, COUNT(*) AS InvoiceRows, SUM(Amount) AS TotalAmount
FROM dbo.FactInvoices
UNION ALL
SELECT 'Source B', COUNT(*), SUM(Amount)
FROM dbo.InvoicesSourceB;
```

Matching totals can still hide offsetting errors, so always follow with a row-level comparison.

## Step 2: row-level reconciliation

```sql
SELECT
    COALESCE(a.InvoiceID, b.InvoiceID) AS InvoiceID,
    a.Amount AS AmountA,
    b.Amount AS AmountB,
    CASE
        WHEN b.InvoiceID IS NULL THEN 'Missing in B'
        WHEN a.InvoiceID IS NULL THEN 'Missing in A'
        WHEN a.Amount <> b.Amount THEN 'Amount mismatch'
    END AS Issue
FROM dbo.FactInvoices AS a
FULL OUTER JOIN dbo.InvoicesSourceB AS b
    ON b.InvoiceID = a.InvoiceID
WHERE a.InvoiceID IS NULL
   OR b.InvoiceID IS NULL
   OR a.Amount <> b.Amount
ORDER BY InvoiceID;
```

Expected: 6 rows. Invoices 10, 20, and 30 are missing in B, invoices 40 and 50 are mismatched, and invoice 999 is missing in A.

## Step 3: summarize the issues

```sql
WITH Differences AS (
    SELECT
        COALESCE(a.InvoiceID, b.InvoiceID) AS InvoiceID,
        a.Amount AS AmountA,
        b.Amount AS AmountB,
        CASE
            WHEN b.InvoiceID IS NULL THEN 'Missing in B'
            WHEN a.InvoiceID IS NULL THEN 'Missing in A'
            WHEN a.Amount <> b.Amount THEN 'Amount mismatch'
        END AS Issue
    FROM dbo.FactInvoices AS a
    FULL OUTER JOIN dbo.InvoicesSourceB AS b
        ON b.InvoiceID = a.InvoiceID
    WHERE a.InvoiceID IS NULL OR b.InvoiceID IS NULL OR a.Amount <> b.Amount
)
SELECT
    Issue,
    COUNT(*) AS InvoiceCount,
    SUM(COALESCE(AmountA, 0) - COALESCE(AmountB, 0)) AS NetDifference
FROM Differences
GROUP BY Issue
ORDER BY Issue;
```

This is the version to put in front of someone. It states how many records differ and the dollar impact of each type.

## Set comparisons

```sql
-- In A but not in B
SELECT InvoiceID FROM dbo.FactInvoices
EXCEPT
SELECT InvoiceID FROM dbo.InvoicesSourceB;

-- In both
SELECT InvoiceID FROM dbo.FactInvoices
INTERSECT
SELECT InvoiceID FROM dbo.InvoicesSourceB;
```

`EXCEPT` and `INTERSECT` compare whole rows, treat NULLs as equal, and remove duplicates, which makes them handy for quick checks.

## A reusable data quality block

```sql
SELECT 'Duplicate InvoiceIDs in staging' AS CheckName, COUNT(*) AS FailedRows
FROM (
    SELECT InvoiceID
    FROM dbo.StagingInvoices
    GROUP BY InvoiceID
    HAVING COUNT(*) > 1
) AS d
UNION ALL
SELECT 'Negative amounts', COUNT(*)
FROM dbo.FactInvoices
WHERE Amount < 0
UNION ALL
SELECT 'Invoice dates outside the calendar', COUNT(*)
FROM dbo.FactInvoices AS f
WHERE NOT EXISTS (SELECT 1 FROM dbo.DimDate AS d WHERE d.FullDate = f.InvoiceDate)
UNION ALL
SELECT 'Missing vendor', COUNT(*)
FROM dbo.FactInvoices
WHERE Vendor IS NULL OR LTRIM(RTRIM(Vendor)) = '';
```

Expected: 8 failed rows on the first check and 0 on the others. Every check returns a count, so a failing run is easy to spot.

## Performance habits

| Habit | Why |
| --- | --- |
| Compare dates with `>=` and `<`, not `YEAR(col) = 2026` | Functions on a column prevent index seeks |
| Match data types in joins and filters | Implicit conversions can force scans |
| Select only the columns you need | Less data to read and move |
| Use `EXISTS` instead of `COUNT(*) > 0` | It can stop at the first match |
| Index the columns you join and filter on | The single biggest speedup for large tables |
| Look at the execution plan and `SET STATISTICS IO ON` | Measures what the query actually reads |

## Common problems

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Totals match but rows differ | Offsetting differences | Reconcile at row level, not just totals |
| Matching rows reported as mismatched | Decimal precision or rounding differences | Compare `ROUND` values or allow a small tolerance |
| Rows missing from the comparison | `INNER JOIN` used instead of `FULL OUTER JOIN` | Use `FULL OUTER JOIN` to see both sides |
| Key matches fail on text keys | Trailing spaces or case differences | `LTRIM`, `RTRIM`, and a consistent collation |

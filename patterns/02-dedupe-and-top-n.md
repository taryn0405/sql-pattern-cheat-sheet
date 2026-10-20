# 02. Dedupe and Top N per Group

Keep the latest version of each record, remove repeats, and pull the top rows per group. These use `dbo.StagingInvoices` from `mock-data/02_staging_and_reconciliation.sql`.

## Find duplicates

```sql
SELECT InvoiceID, COUNT(*) AS TimesLoaded
FROM dbo.StagingInvoices
GROUP BY InvoiceID
HAVING COUNT(*) > 1
ORDER BY InvoiceID;
```

Expect 8 rows (invoices 1 through 8).

## Keep the latest row per key

```sql
WITH Ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY InvoiceID
            ORDER BY LoadedAt DESC, LoadID DESC
        ) AS rn
    FROM dbo.StagingInvoices
)
SELECT InvoiceID, InvoiceDate, Program, Vendor, Amount, LoadedAt
FROM Ranked
WHERE rn = 1
ORDER BY InvoiceID;
```

Expect 20 rows. Invoices 1 through 5 show the corrected amount (original plus 100). `LoadID DESC` breaks ties when two loads share a timestamp, such as the repeats of invoices 6 through 8.

## Delete duplicates, keeping the latest

Test with `SELECT` first. Deleting is permanent unless you wrap it in a transaction you can roll back.

```sql
BEGIN TRANSACTION;

WITH Ranked AS (
    SELECT
        ROW_NUMBER() OVER (
            PARTITION BY InvoiceID
            ORDER BY LoadedAt DESC, LoadID DESC
        ) AS rn
    FROM dbo.StagingInvoices
)
DELETE FROM Ranked
WHERE rn > 1;

SELECT COUNT(*) AS RemainingRows FROM dbo.StagingInvoices; -- expect 20

-- COMMIT TRANSACTION;   -- keep the change
-- ROLLBACK TRANSACTION; -- undo it
```

Re-run `02_staging_and_reconciliation.sql` to restore the original rows.

## Top N per group

The two largest invoices in each program:

```sql
WITH Ranked AS (
    SELECT
        Program,
        InvoiceID,
        Amount,
        ROW_NUMBER() OVER (PARTITION BY Program ORDER BY Amount DESC, InvoiceID) AS rn
    FROM dbo.FactInvoices
)
SELECT Program, InvoiceID, Amount
FROM Ranked
WHERE rn <= 2
ORDER BY Program, rn;
```

The same result with `CROSS APPLY`, which can use an index well when there are many groups:

```sql
SELECT p.Program, t.InvoiceID, t.Amount
FROM (SELECT DISTINCT Program FROM dbo.FactInvoices) AS p
CROSS APPLY (
    SELECT TOP (2) InvoiceID, Amount
    FROM dbo.FactInvoices AS f
    WHERE f.Program = p.Program
    ORDER BY Amount DESC, InvoiceID
) AS t
ORDER BY p.Program, t.Amount DESC;
```

## Handling ties

| Goal | Use |
| --- | --- |
| Exactly N rows per group, ties broken arbitrarily or by a column | `ROW_NUMBER()` with a tiebreaker |
| Include everyone tied for the Nth place | `RANK()` or `DENSE_RANK()` with `<= N` |
| Top N overall with ties | `TOP (N) WITH TIES` |

## Common problems

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Wrong row kept | `ORDER BY` direction reversed | `DESC` keeps the newest, `ASC` keeps the oldest |
| "Latest" row differs between runs | Ties on the timestamp | Add a unique column as a final tiebreaker |
| `DELETE` removed too much | Ran without testing | Run the `SELECT` version first, and use a transaction |
| Distinct count still off after dedupe | Duplicates differ by trailing spaces or case | Trim and standardize text before comparing |

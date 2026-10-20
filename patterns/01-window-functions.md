# 01. Window Functions

Window functions calculate across related rows without collapsing them into groups. They power rankings, running totals, comparisons to the previous row, and percent of total.

## Rank within a group

```sql
SELECT
    Program,
    Vendor,
    SUM(Amount) AS TotalAmount,
    RANK() OVER (PARTITION BY Program ORDER BY SUM(Amount) DESC) AS VendorRank
FROM dbo.FactInvoices
GROUP BY Program, Vendor
ORDER BY Program, VendorRank;
```

| Function | Ties | Example for values 100, 100, 90 |
| --- | --- | --- |
| `ROW_NUMBER()` | Never ties, arbitrary order unless you add a tiebreaker | 1, 2, 3 |
| `RANK()` | Ties share a rank, then skips | 1, 1, 3 |
| `DENSE_RANK()` | Ties share a rank, no skip | 1, 1, 2 |

## Running total

```sql
SELECT
    Program,
    InvoiceDate,
    InvoiceID,
    Amount,
    SUM(Amount) OVER (
        PARTITION BY Program
        ORDER BY InvoiceDate, InvoiceID
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS RunningTotal
FROM dbo.FactInvoices
ORDER BY Program, InvoiceDate, InvoiceID;
```

Write `ROWS` explicitly. When you only give `ORDER BY`, the default frame is `RANGE`, which treats rows with the same date as one unit, so ties get the same total, and it is slower.

## Moving average

```sql
SELECT
    Program,
    InvoiceDate,
    InvoiceID,
    Amount,
    AVG(Amount) OVER (
        PARTITION BY Program
        ORDER BY InvoiceDate, InvoiceID
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS MovingAvg3
FROM dbo.FactInvoices
ORDER BY Program, InvoiceDate, InvoiceID;
```

The first two rows in each program average over fewer than three invoices.

## Compare to the previous row

```sql
SELECT
    Program,
    InvoiceID,
    InvoiceDate,
    DATEDIFF(
        DAY,
        LAG(InvoiceDate) OVER (PARTITION BY Program ORDER BY InvoiceDate, InvoiceID),
        InvoiceDate
    ) AS DaysSincePrevious
FROM dbo.FactInvoices
ORDER BY Program, InvoiceDate, InvoiceID;
```

`LAG` looks back and `LEAD` looks ahead. The first row in each group has no previous row, so it returns NULL.

## Percent of total

```sql
SELECT
    Program,
    InvoiceID,
    Amount,
    CAST(Amount * 1.0 / SUM(Amount) OVER (PARTITION BY Program) AS DECIMAL(9,4)) AS PctOfProgram
FROM dbo.FactInvoices
ORDER BY Program, InvoiceID;
```

`SUM(...) OVER (PARTITION BY ...)` returns the group total on every row, so no join back to an aggregate is needed.

## Common problems

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| "Windowed functions can only appear in SELECT or ORDER BY" | Used a window function in `WHERE` | Put the query in a CTE, then filter in the outer query |
| Running total jumps on tied dates | Default `RANGE` frame | Add `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` and a tiebreaker column |
| Results change between runs | `ROW_NUMBER` with ties and no tiebreaker | Add a unique column to the `ORDER BY` |
| `LAG` returns NULL on every row | Wrong or missing `PARTITION BY`, or one row per group | Check the partition and that there are earlier rows |

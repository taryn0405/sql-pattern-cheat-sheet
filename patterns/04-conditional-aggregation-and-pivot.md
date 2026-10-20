# 04. Conditional Aggregation and Pivot

Turn rows into columns, count things that meet a condition, and add subtotals, all in one pass over the data.

## Conditional aggregation (one column per category)

Fiscal quarter totals as columns:

```sql
SELECT
    d.FiscalYear,
    SUM(CASE WHEN d.FiscalQuarter = 1 THEN f.Amount ELSE 0 END) AS Q1,
    SUM(CASE WHEN d.FiscalQuarter = 2 THEN f.Amount ELSE 0 END) AS Q2,
    SUM(CASE WHEN d.FiscalQuarter = 3 THEN f.Amount ELSE 0 END) AS Q3,
    SUM(CASE WHEN d.FiscalQuarter = 4 THEN f.Amount ELSE 0 END) AS Q4
FROM dbo.FactInvoices AS f
JOIN dbo.DimDate AS d
    ON d.FullDate = f.InvoiceDate
GROUP BY d.FiscalYear
ORDER BY d.FiscalYear;
```

This is the most portable approach and the easiest to extend with other conditions.

## PIVOT

```sql
SELECT FiscalYear, [1] AS Q1, [2] AS Q2, [3] AS Q3, [4] AS Q4
FROM (
    SELECT d.FiscalYear, d.FiscalQuarter, f.Amount
    FROM dbo.FactInvoices AS f
    JOIN dbo.DimDate AS d
        ON d.FullDate = f.InvoiceDate
) AS src
PIVOT (
    SUM(Amount)
    FOR FiscalQuarter IN ([1], [2], [3], [4])
) AS p
ORDER BY FiscalYear;
```

`PIVOT` is shorter, but the column list is fixed in the query. A quarter with no data returns NULL (the `CASE` version returns 0).

## Conditional counts and rates

Percent of monthly SLA results that met goal, honoring the direction of each metric:

```sql
SELECT
    Program,
    Metric,
    COUNT(*) AS ReportedCount,
    SUM(CASE
            WHEN HigherIsBetter = 1 AND Result >= Goal THEN 1
            WHEN HigherIsBetter = 0 AND Result <= Goal THEN 1
            ELSE 0
        END) AS MetCount,
    AVG(CASE
            WHEN HigherIsBetter = 1 AND Result >= Goal THEN 1.0
            WHEN HigherIsBetter = 0 AND Result <= Goal THEN 1.0
            ELSE 0.0
        END) AS AttainmentPct
FROM dbo.FactSLA
GROUP BY Program, Metric
ORDER BY Program, Metric;
```

Averaging a 1.0 or 0.0 flag gives a percentage directly. Use `1.0`, not `1`, so the average is not truncated to a whole number.

## Subtotals and grand totals with ROLLUP

```sql
SELECT
    CASE WHEN GROUPING(Program) = 1 THEN 'All Programs' ELSE Program END AS Program,
    CASE WHEN GROUPING(Vendor)  = 1 THEN 'All Vendors'  ELSE Vendor  END AS Vendor,
    SUM(Amount) AS TotalAmount
FROM dbo.FactInvoices
GROUP BY ROLLUP (Program, Vendor)
ORDER BY GROUPING(Program), Program, GROUPING(Vendor), Vendor;
```

`GROUPING()` returns 1 on the subtotal rows, which lets you label them and sort them below the detail. Without it, a real NULL and a subtotal NULL look the same.

## Common problems

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Percentages come out as 0 or 1 | Integer math in the `AVG` or division | Use `1.0` or cast to `DECIMAL` |
| `PIVOT` drops a category | Value missing from the `IN` list | Add it, or use conditional aggregation |
| Pivoted NULLs where you want 0 | `PIVOT` leaves missing combinations empty | Wrap in `COALESCE`, or use the `CASE` approach |
| Subtotal rows show blank labels | NULL labels from `ROLLUP` | Label with `GROUPING()` as above |
| Column list must change often | Fixed `IN` list | Build it with dynamic SQL only if you must, and validate the values |

# 05. Joins and NULLs

Most wrong numbers in SQL come from joins that multiply rows or from NULL behaving differently than expected.

## Find what is missing (anti-join)

Vendor and program pairs with no invoices:

```sql
SELECT p.Program, v.Vendor
FROM (SELECT DISTINCT Program FROM dbo.FactInvoices) AS p
CROSS JOIN (SELECT DISTINCT Vendor FROM dbo.FactInvoices) AS v
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.FactInvoices AS f
    WHERE f.Program = p.Program
      AND f.Vendor  = v.Vendor
)
ORDER BY p.Program, v.Vendor;
```

Rows appear only for pairs that never occur. An empty result means every combination exists.

## NOT IN versus NOT EXISTS

```sql
-- Returns NO rows, because of the NULL in the list
SELECT 'surprise' AS Result
WHERE 1 NOT IN (2, NULL);
```

`NOT IN` returns nothing if the list contains even one NULL, since `1 <> NULL` is unknown. `NOT EXISTS` is not affected. Prefer `NOT EXISTS` for anti-joins.

## LEFT JOIN with a filter

```sql
-- Behaves like an INNER JOIN: the WHERE removes the unmatched rows
SELECT mo.MonthStart, f.Amount
FROM (SELECT DISTINCT MonthStart FROM dbo.DimDate) AS mo
LEFT JOIN dbo.FactInvoices AS f
    ON f.InvoiceDate >= mo.MonthStart
   AND f.InvoiceDate <  DATEADD(MONTH, 1, mo.MonthStart)
WHERE f.Program = 'Program A';

-- Keeps every month: the filter moves into the ON clause
SELECT mo.MonthStart, f.Amount
FROM (SELECT DISTINCT MonthStart FROM dbo.DimDate) AS mo
LEFT JOIN dbo.FactInvoices AS f
    ON f.InvoiceDate >= mo.MonthStart
   AND f.InvoiceDate <  DATEADD(MONTH, 1, mo.MonthStart)
   AND f.Program = 'Program A';
```

A condition on the right-hand table in `WHERE` throws away the NULL rows the `LEFT JOIN` just created. Put it in `ON`.

## Check for row multiplication

If totals inflate after a join, the join key is not unique on one side.

```sql
SELECT
    COUNT(*)                 AS RowsAfterJoin,
    COUNT(DISTINCT f.InvoiceID) AS DistinctInvoices
FROM dbo.FactInvoices AS f
JOIN dbo.DimDate AS d
    ON d.FullDate = f.InvoiceDate;
```

The two numbers should match. If rows are higher, something on the other side has duplicate keys. Run the same check before and after each join when debugging.

## NULL rules to remember

| Expression | Result |
| --- | --- |
| `NULL = NULL` | Unknown (not true) |
| `col = NULL` | Never matches. Use `col IS NULL` |
| `NULL + 5` | NULL |
| `COUNT(*)` vs `COUNT(col)` | `COUNT(col)` skips NULLs |
| `SUM(col)` over all NULLs | NULL, not 0 |

```sql
COALESCE(col, 0)      -- first non-null, works with any number of arguments
ISNULL(col, 0)        -- two arguments only, result takes the first argument's type
NULLIF(col, 0)        -- returns NULL when col is 0, handy to prevent divide-by-zero
```

## Common problems

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Totals higher than the source | Join fan-out from a non-unique key | Check `COUNT(*)` against `COUNT(DISTINCT key)` |
| Unmatched rows vanish from a `LEFT JOIN` | Filter on the right table in `WHERE` | Move it into the `ON` clause |
| `NOT IN` returns no rows | NULL in the subquery | Use `NOT EXISTS` |
| Join misses matching dates | One side is `DATETIME` with a time portion | Cast to `DATE`, or use a half-open range |
| Divide-by-zero error | Zero denominator | Divide by `NULLIF(denominator, 0)` |

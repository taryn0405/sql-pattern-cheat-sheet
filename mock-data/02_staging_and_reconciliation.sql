-- 02_staging_and_reconciliation.sql
-- Run AFTER 01_create_and_load.sql (it reads from dbo.FactInvoices).
-- Adds two small tables used by the dedupe and reconciliation patterns.
-- All data is fabricated. Safe to re-run: existing tables are dropped first.

------------------------------------------------------------
-- StagingInvoices: a messy load with duplicates
--   Initial load : invoices 1-20            (20 rows)
--   Corrected reload: invoices 1-5, amount + 100   (5 rows, newer LoadedAt)
--   Exact repeat : invoices 6-8             (3 rows, newer LoadedAt)
-- Result: 28 rows, 20 distinct InvoiceIDs, 8 InvoiceIDs that appear more than once.
------------------------------------------------------------
DROP TABLE IF EXISTS dbo.StagingInvoices;

CREATE TABLE dbo.StagingInvoices (
    LoadID      INT IDENTITY(1,1) PRIMARY KEY,
    InvoiceID   INT           NOT NULL,
    InvoiceDate DATE          NOT NULL,
    Program     VARCHAR(50)   NOT NULL,
    Vendor      VARCHAR(100)  NOT NULL,
    Amount      DECIMAL(12,2) NOT NULL,
    LoadedAt    DATETIME2(0)  NOT NULL
);

INSERT INTO dbo.StagingInvoices (InvoiceID, InvoiceDate, Program, Vendor, Amount, LoadedAt)
SELECT InvoiceID, InvoiceDate, Program, Vendor, Amount, '2026-10-01T08:00:00'
FROM dbo.FactInvoices
WHERE InvoiceID BETWEEN 1 AND 20;

INSERT INTO dbo.StagingInvoices (InvoiceID, InvoiceDate, Program, Vendor, Amount, LoadedAt)
SELECT InvoiceID, InvoiceDate, Program, Vendor, Amount + 100, '2026-10-02T08:00:00'
FROM dbo.FactInvoices
WHERE InvoiceID BETWEEN 1 AND 5;

INSERT INTO dbo.StagingInvoices (InvoiceID, InvoiceDate, Program, Vendor, Amount, LoadedAt)
SELECT InvoiceID, InvoiceDate, Program, Vendor, Amount, '2026-10-02T08:00:00'
FROM dbo.FactInvoices
WHERE InvoiceID BETWEEN 6 AND 8;

------------------------------------------------------------
-- InvoicesSourceB: a second system to reconcile against FactInvoices
--   Missing from B  : invoices 10, 20, 30
--   Amount mismatch : invoices 40, 50 (B is 50 higher)
--   Missing from A  : invoice 999 (exists only in B)
-- Result: 118 rows.
------------------------------------------------------------
DROP TABLE IF EXISTS dbo.InvoicesSourceB;

CREATE TABLE dbo.InvoicesSourceB (
    InvoiceID INT           NOT NULL PRIMARY KEY,
    Program   VARCHAR(50)   NOT NULL,
    Amount    DECIMAL(12,2) NOT NULL
);

INSERT INTO dbo.InvoicesSourceB (InvoiceID, Program, Amount)
SELECT
    InvoiceID,
    Program,
    CASE WHEN InvoiceID IN (40, 50) THEN Amount + 50 ELSE Amount END
FROM dbo.FactInvoices
WHERE InvoiceID NOT IN (10, 20, 30);

INSERT INTO dbo.InvoicesSourceB (InvoiceID, Program, Amount)
VALUES (999, 'Program A', 1234.00);

------------------------------------------------------------
-- Quick checks: expect 28 and 118 rows
------------------------------------------------------------
SELECT 'StagingInvoices' AS TableName, COUNT(*) AS TotalRows FROM dbo.StagingInvoices
UNION ALL
SELECT 'InvoicesSourceB', COUNT(*) FROM dbo.InvoicesSourceB;

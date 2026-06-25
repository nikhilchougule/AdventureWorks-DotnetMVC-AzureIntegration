-- ============================================================
-- AdventureWorks2022DB  |  SQL SAMPLES  |  EXPERT LEVEL
-- Database: AdventureWorks2022DB
-- ============================================================
-- Concepts covered:
--   Dynamic SQL (sp_executesql)
--   Stored Procedures with OUTPUT params & error handling
--   Views and Indexed Views
--   Indexes — covering, composite, filtered, include columns
--   Query optimization — execution plans, SARGability
--   String aggregation (STRING_AGG)
--   JSON in SQL Server (FOR JSON, OPENJSON)
--   XML basics
--   Gaps and Islands problem
--   Deduplication strategies
--   Date spine / calendar generation
--   Top-N per group (multiple patterns)
--   Cumulative distribution (CUME_DIST, PERCENT_RANK)
--   Performance anti-patterns and how to fix them
-- ============================================================

USE AdventureWorks2022DB;
GO

-- ─────────────────────────────────────────────────────────────
-- 1. Dynamic SQL with sp_executesql (safe — parameterized)
-- Problem: Build a flexible product search that accepts an
--          optional category filter and an optional min price.
--          Using sp_executesql prevents SQL injection.
-- ─────────────────────────────────────────────────────────────
DECLARE @CategoryFilter VARCHAR(50) = 'Bikes';   -- set NULL to skip
DECLARE @MinPrice       MONEY       = 500;        -- set NULL to skip
DECLARE @SQL            NVARCHAR(MAX);
DECLARE @Params         NVARCHAR(500);

SET @SQL = N'
SELECT
    p.Name,
    ps.Name AS SubCategory,
    pc.Name AS Category,
    p.ListPrice
FROM Production.Product             p
JOIN Production.ProductSubcategory  ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory     pc ON ps.ProductCategoryID   = pc.ProductCategoryID
WHERE 1 = 1';

IF @CategoryFilter IS NOT NULL
    SET @SQL += N' AND pc.Name = @CategoryFilter';

IF @MinPrice IS NOT NULL
    SET @SQL += N' AND p.ListPrice >= @MinPrice';

SET @SQL += N' ORDER BY p.ListPrice DESC';

SET @Params = N'@CategoryFilter VARCHAR(50), @MinPrice MONEY';

EXEC sp_executesql @SQL, @Params,
    @CategoryFilter = @CategoryFilter,
    @MinPrice       = @MinPrice;


-- ─────────────────────────────────────────────────────────────
-- 2. Stored Procedure — full pattern with OUTPUT, TRY/CATCH
-- Problem: Create a procedure that accepts a CustomerID,
--          returns their lifetime value, order count, and
--          whether they are a "VIP" (spend > $50K).
--          Demonstrates OUTPUT params and error propagation.
-- ─────────────────────────────────────────────────────────────
-- DROP PROCEDURE IF EXISTS Sales.usp_GetCustomerLifetimeValue;
-- GO
CREATE OR ALTER PROCEDURE Sales.usp_GetCustomerLifetimeValue
    @CustomerID     INT,
    @TotalSpend     MONEY       OUTPUT,
    @OrderCount     INT         OUTPUT,
    @IsVIP          BIT         OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT
            @OrderCount = COUNT(*),
            @TotalSpend = SUM(TotalDue)
        FROM Sales.SalesOrderHeader
        WHERE CustomerID = @CustomerID;

        -- Handle customer with no orders
        SET @TotalSpend = ISNULL(@TotalSpend, 0);
        SET @OrderCount = ISNULL(@OrderCount, 0);
        SET @IsVIP      = CASE WHEN @TotalSpend > 50000 THEN 1 ELSE 0 END;

    END TRY
    BEGIN CATCH
        THROW;  -- re-raise to caller
    END CATCH;
END;
GO

-- Calling the procedure:
DECLARE @Spend MONEY, @Orders INT, @VIP BIT;
EXEC Sales.usp_GetCustomerLifetimeValue
    @CustomerID = 29825,
    @TotalSpend = @Spend   OUTPUT,
    @OrderCount = @Orders  OUTPUT,
    @IsVIP      = @VIP     OUTPUT;

SELECT @Spend AS LifetimeValue, @Orders AS Orders, @VIP AS IsVIP;


-- ─────────────────────────────────────────────────────────────
-- 3. View and Indexed View
-- Problem: Create a view that denormalises orders for BI use.
--          Then create an indexed view for instant aggregation.
-- ─────────────────────────────────────────────────────────────
CREATE OR ALTER VIEW Sales.vw_OrderLineSummary
AS
SELECT
    soh.SalesOrderID,
    soh.OrderDate,
    YEAR(soh.OrderDate)                     AS OrderYear,
    MONTH(soh.OrderDate)                    AS OrderMonth,
    soh.CustomerID,
    soh.TerritoryID,
    soh.SalesPersonID,
    p.Name                                  AS ProductName,
    ps.Name                                 AS SubCategory,
    pc.Name                                 AS Category,
    sod.OrderQty,
    sod.UnitPrice,
    sod.LineTotal
FROM Sales.SalesOrderHeader               soh
JOIN Sales.SalesOrderDetail               sod ON soh.SalesOrderID      = sod.SalesOrderID
JOIN Production.Product                   p   ON sod.ProductID         = p.ProductID
LEFT JOIN Production.ProductSubcategory   ps  ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN Production.ProductCategory      pc  ON ps.ProductCategoryID   = pc.ProductCategoryID;
GO

-- Query the view exactly like a table:
SELECT Category, SUM(LineTotal) AS Revenue
FROM Sales.vw_OrderLineSummary
WHERE OrderYear = 2013
GROUP BY Category
ORDER BY Revenue DESC;


-- ─────────────────────────────────────────────────────────────
-- 4. Index Strategy — what to create and why
-- Problem: The query below is slow (full table scan on a
--          large table). Explain what index to create.
-- ─────────────────────────────────────────────────────────────

-- Slow query — no useful index:
SELECT SalesOrderID, CustomerID, TotalDue, OrderDate
FROM Sales.SalesOrderHeader
WHERE TerritoryID = 5
  AND YEAR(OrderDate) = 2013    -- ← ANTI-PATTERN: function on indexed col
ORDER BY TotalDue DESC;

-- ❌ YEAR(OrderDate) = 2013 is NOT SARGable — SQL can't use an index on OrderDate.
-- ✅ Fix — use a range instead (SARGable):
SELECT SalesOrderID, CustomerID, TotalDue, OrderDate
FROM Sales.SalesOrderHeader
WHERE TerritoryID = 5
  AND OrderDate >= '2013-01-01'
  AND OrderDate <  '2014-01-01'
ORDER BY TotalDue DESC;

/*
Best index for the fixed query (composite + include):
CREATE INDEX IX_SalesOrderHeader_Territory_Date
ON Sales.SalesOrderHeader (TerritoryID, OrderDate)
INCLUDE (CustomerID, TotalDue, SalesOrderID);
-- TerritoryID + OrderDate in key = equality + range filter resolved in index
-- INCLUDE cols = no key lookup needed (covering index)
*/

-- Filtered index — useful when most queries target a subset:
/*
CREATE INDEX IX_SalesOrderHeader_Online
ON Sales.SalesOrderHeader (OrderDate, TotalDue)
WHERE OnlineOrderFlag = 1;           -- filter: only online orders indexed
*/


-- ─────────────────────────────────────────────────────────────
-- 5. STRING_AGG — Concatenate values into one string per group
-- Problem: For each sales order, list all product names on
--          that order as a comma-separated string in one row.
-- ─────────────────────────────────────────────────────────────
SELECT TOP 20
    soh.SalesOrderID,
    soh.OrderDate,
    STRING_AGG(p.Name, ', ')
        WITHIN GROUP (ORDER BY p.Name)  AS Products,
    COUNT(sod.SalesOrderDetailID)       AS LineItemCount,
    SUM(sod.LineTotal)                  AS OrderTotal
FROM Sales.SalesOrderHeader   soh
JOIN Sales.SalesOrderDetail   sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN Production.Product       p   ON sod.ProductID    = p.ProductID
GROUP BY soh.SalesOrderID, soh.OrderDate
ORDER BY soh.OrderDate DESC;


-- ─────────────────────────────────────────────────────────────
-- 6. FOR JSON — Export query results as JSON
-- Problem: Return the top 5 orders with their line items
--          as a nested JSON document.
-- ─────────────────────────────────────────────────────────────
SELECT TOP 5
    soh.SalesOrderID,
    soh.SalesOrderNumber,
    soh.OrderDate,
    soh.TotalDue,
    (
        SELECT
            sod.SalesOrderDetailID,
            p.Name          AS Product,
            sod.OrderQty,
            sod.UnitPrice,
            sod.LineTotal
        FROM Sales.SalesOrderDetail sod
        JOIN Production.Product     p ON sod.ProductID = p.ProductID
        WHERE sod.SalesOrderID = soh.SalesOrderID
        FOR JSON PATH
    )                       AS LineItems
FROM Sales.SalesOrderHeader soh
ORDER BY soh.TotalDue DESC
FOR JSON PATH, ROOT('Orders');


-- ─────────────────────────────────────────────────────────────
-- 7. OPENJSON — Parse incoming JSON into rows
-- Problem: A web API sends order line items as JSON.
--          Parse it into a tabular result for processing.
-- ─────────────────────────────────────────────────────────────
DECLARE @OrderJson NVARCHAR(MAX) = N'
[
  {"ProductID": 680, "OrderQty": 2, "UnitPrice": 1431.50},
  {"ProductID": 706, "OrderQty": 1, "UnitPrice": 858.90},
  {"ProductID": 707, "OrderQty": 3, "UnitPrice": 34.99}
]';

SELECT
    j.ProductID,
    p.Name          AS ProductName,
    j.OrderQty,
    j.UnitPrice,
    j.OrderQty * j.UnitPrice AS LineTotal
FROM OPENJSON(@OrderJson)
WITH (
    ProductID   INT     '$.ProductID',
    OrderQty    INT     '$.OrderQty',
    UnitPrice   MONEY   '$.UnitPrice'
) AS j
JOIN Production.Product p ON j.ProductID = p.ProductID;


-- ─────────────────────────────────────────────────────────────
-- 8. Gaps and Islands — Classic interview problem
-- Problem: Find contiguous date ranges where a given
--          employee was in the same department (island),
--          and identify the gaps between assignments.
-- ─────────────────────────────────────────────────────────────
WITH Islands AS (
    SELECT
        BusinessEntityID,
        DepartmentID,
        StartDate,
        EndDate,
        -- Rows in same "island" share the same group number
        ROW_NUMBER() OVER (PARTITION BY BusinessEntityID ORDER BY StartDate)
        - ROW_NUMBER() OVER (PARTITION BY BusinessEntityID, DepartmentID ORDER BY StartDate)
            AS IslandGroup
    FROM HumanResources.EmployeeDepartmentHistory
)
SELECT
    BusinessEntityID,
    DepartmentID,
    MIN(StartDate)  AS IslandStart,
    MAX(ISNULL(EndDate, '9999-12-31')) AS IslandEnd,
    COUNT(*)        AS RowsInIsland
FROM Islands
GROUP BY BusinessEntityID, DepartmentID, IslandGroup
ORDER BY BusinessEntityID, IslandStart;


-- ─────────────────────────────────────────────────────────────
-- 9. Deduplication — Find and remove duplicate rows
-- Problem: The Person.EmailAddress table might have duplicate
--          emails per person. Find duplicates and keep only
--          the row with the lowest EmailAddressID.
-- ─────────────────────────────────────────────────────────────
-- Step 1: Find duplicates
SELECT
    EmailAddress,
    COUNT(*)        AS DuplicateCount,
    MIN(EmailAddressID) AS KeepID
FROM Person.EmailAddress
GROUP BY EmailAddress
HAVING COUNT(*) > 1;

-- Step 2: Delete duplicates (keep the lowest ID per email)
-- DELETE FROM Person.EmailAddress
-- WHERE EmailAddressID NOT IN (
--     SELECT MIN(EmailAddressID)
--     FROM Person.EmailAddress
--     GROUP BY EmailAddress
-- );

-- Step 3: Modern CTE pattern (more readable dedup delete)
-- WITH Dupes AS (
--     SELECT *,
--         ROW_NUMBER() OVER (PARTITION BY EmailAddress ORDER BY EmailAddressID) AS Rn
--     FROM Person.EmailAddress
-- )
-- DELETE FROM Dupes WHERE Rn > 1;


-- ─────────────────────────────────────────────────────────────
-- 10. Date Spine — Generate a calendar of all dates in a year
-- Problem: You need to report daily sales including days with
--          zero orders. Without a date spine, those days are
--          missing from the result. Build a date table on-the-fly.
-- ─────────────────────────────────────────────────────────────
WITH DateSpine AS (
    SELECT CAST('2013-01-01' AS DATE) AS CalDate
    UNION ALL
    SELECT DATEADD(DAY, 1, CalDate)
    FROM DateSpine
    WHERE CalDate < '2013-12-31'
),
DailyOrders AS (
    SELECT
        CAST(OrderDate AS DATE)     AS OrderDay,
        COUNT(*)                    AS OrderCount,
        SUM(TotalDue)               AS Revenue
    FROM Sales.SalesOrderHeader
    WHERE OrderDate >= '2013-01-01' AND OrderDate < '2014-01-01'
    GROUP BY CAST(OrderDate AS DATE)
)
SELECT
    ds.CalDate,
    ISNULL(do.OrderCount, 0)    AS OrderCount,
    ISNULL(do.Revenue, 0)       AS Revenue
FROM DateSpine         ds
LEFT JOIN DailyOrders  do ON ds.CalDate = do.OrderDay
ORDER BY ds.CalDate
OPTION (MAXRECURSION 400);


-- ─────────────────────────────────────────────────────────────
-- 11. Top-N per group — 3 patterns (know ALL three for interviews)
-- Problem: Get the single most expensive product per category.
-- ─────────────────────────────────────────────────────────────

-- Pattern A: ROW_NUMBER in CTE  (cleanest, most common)
WITH Ranked AS (
    SELECT
        pc.Name AS Category, p.Name AS Product, p.ListPrice,
        ROW_NUMBER() OVER (PARTITION BY pc.Name ORDER BY p.ListPrice DESC) AS Rn
    FROM Production.Product            p
    JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
    JOIN Production.ProductCategory    pc ON ps.ProductCategoryID   = pc.ProductCategoryID
)
SELECT Category, Product, ListPrice FROM Ranked WHERE Rn = 1;

-- Pattern B: Correlated subquery  (works in older SQL versions)
SELECT
    pc.Name AS Category, p.Name AS Product, p.ListPrice
FROM Production.Product            p
JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory    pc ON ps.ProductCategoryID   = pc.ProductCategoryID
WHERE p.ListPrice = (
    SELECT MAX(p2.ListPrice)
    FROM Production.Product            p2
    JOIN Production.ProductSubcategory ps2 ON p2.ProductSubcategoryID = ps2.ProductSubcategoryID
    WHERE ps2.ProductCategoryID = pc.ProductCategoryID
);

-- Pattern C: CROSS APPLY  (great for Top-N > 1)
SELECT pc.Name AS Category, top1.Name AS Product, top1.ListPrice
FROM Production.ProductCategory pc
CROSS APPLY (
    SELECT TOP 1 p.Name, p.ListPrice
    FROM Production.Product            p
    JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
    WHERE ps.ProductCategoryID = pc.ProductCategoryID
    ORDER BY p.ListPrice DESC
) AS top1;


-- ─────────────────────────────────────────────────────────────
-- 12. CUME_DIST and PERCENT_RANK
-- Problem: For each product with a price > 0, show where it
--          falls within the overall price distribution.
--          PERCENT_RANK: 0 = cheapest, 1 = most expensive.
--          CUME_DIST: fraction of products <= this price.
-- ─────────────────────────────────────────────────────────────
SELECT
    Name,
    ListPrice,
    ROUND(PERCENT_RANK() OVER (ORDER BY ListPrice), 4)  AS PercentRank,
    ROUND(CUME_DIST()    OVER (ORDER BY ListPrice), 4)  AS CumulativeDist,
    NTILE(10)            OVER (ORDER BY ListPrice)       AS Decile
FROM Production.Product
WHERE ListPrice > 0
ORDER BY ListPrice DESC;


-- ─────────────────────────────────────────────────────────────
-- 13. Performance Anti-Patterns Cheatsheet
-- ─────────────────────────────────────────────────────────────

-- ❌ ANTI-PATTERN 1: Function on indexed column in WHERE (not SARGable)
--    SELECT * FROM Sales.SalesOrderHeader WHERE YEAR(OrderDate) = 2013
-- ✅ FIX: Use range
--    WHERE OrderDate >= '2013-01-01' AND OrderDate < '2014-01-01'

-- ❌ ANTI-PATTERN 2: SELECT * in production queries
--    SELECT * FROM Sales.SalesOrderHeader
-- ✅ FIX: Always name columns
--    SELECT SalesOrderID, OrderDate, TotalDue FROM ...

-- ❌ ANTI-PATTERN 3: LIKE with leading wildcard (full scan)
--    WHERE Name LIKE '%Mountain%'
-- ✅ FIX for exact suffix: flip logic or use full-text search
--    WHERE Name LIKE 'Mountain%'   -- index can be used

-- ❌ ANTI-PATTERN 4: Implicit conversion (index unusable)
--    WHERE CustomerID = '12345'    -- CustomerID is INT, '12345' is VARCHAR
-- ✅ FIX: Match data types
--    WHERE CustomerID = 12345

-- ❌ ANTI-PATTERN 5: NOT IN with NULLable subquery (returns 0 rows!)
--    WHERE x NOT IN (SELECT col FROM t)  -- if col has any NULLs = empty result
-- ✅ FIX: Use NOT EXISTS instead
--    WHERE NOT EXISTS (SELECT 1 FROM t WHERE t.col = x)

-- ❌ ANTI-PATTERN 6: Cursor for row-by-row work
-- ✅ FIX: Set-based UPDATE / INSERT ... SELECT

-- ❌ ANTI-PATTERN 7: COUNT(*) just to check existence
--    IF (SELECT COUNT(*) FROM t WHERE ...) > 0
-- ✅ FIX: Use EXISTS
--    IF EXISTS (SELECT 1 FROM t WHERE ...)


-- ─────────────────────────────────────────────────────────────
-- 14. Interview Classic: Second Highest Salary / Nth value
-- Problem: Find the 2nd highest ListPrice in the Product table
--          without using TOP 2 (interviewers often ban TOP).
-- ─────────────────────────────────────────────────────────────

-- Method 1: DENSE_RANK (best answer)
SELECT ListPrice
FROM (
    SELECT ListPrice,
           DENSE_RANK() OVER (ORDER BY ListPrice DESC) AS Rnk
    FROM Production.Product
    WHERE ListPrice > 0
) r
WHERE Rnk = 2;

-- Method 2: Subquery
SELECT MAX(ListPrice)
FROM Production.Product
WHERE ListPrice < (SELECT MAX(ListPrice) FROM Production.Product);

-- Method 3: Generalised — Nth highest (replace 2 with N)
DECLARE @N INT = 2;
SELECT DISTINCT ListPrice
FROM Production.Product
WHERE ListPrice > 0
ORDER BY ListPrice DESC
OFFSET @N - 1 ROWS
FETCH NEXT 1 ROW ONLY;


-- ─────────────────────────────────────────────────────────────
-- 15. Median calculation (no native MEDIAN in T-SQL)
-- Problem: Calculate the median TotalDue across all orders
--          in 2013. Shows how to solve missing-function problems.
-- ─────────────────────────────────────────────────────────────
SELECT DISTINCT
    PERCENTILE_CONT(0.5)    -- 50th percentile = median (interpolated)
        WITHIN GROUP (ORDER BY TotalDue)
        OVER ()                             AS MedianRevenue,
    PERCENTILE_DISC(0.5)    -- discrete: returns an actual row value
        WITHIN GROUP (ORDER BY TotalDue)
        OVER ()                             AS MedianRevenueDiscrete
FROM Sales.SalesOrderHeader
WHERE YEAR(OrderDate) = 2013;

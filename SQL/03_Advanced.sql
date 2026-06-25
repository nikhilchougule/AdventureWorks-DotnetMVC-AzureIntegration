-- ============================================================
-- AdventureWorks2022DB  |  SQL SAMPLES  |  ADVANCED LEVEL
-- Database: AdventureWorks2022DB
-- ============================================================
-- Concepts covered:
--   CTEs (Common Table Expressions) — simple & multiple
--   Recursive CTEs
--   Window Functions — ROW_NUMBER, RANK, DENSE_RANK, NTILE
--   Window Functions — LAG, LEAD
--   Window Functions — running totals, moving averages
--   PIVOT and UNPIVOT
--   APPLY (CROSS APPLY / OUTER APPLY)
--   MERGE statement
--   Transactions and error handling (TRY/CATCH)
--   Temp tables and table variables
--   Indexes explained
-- ============================================================

USE AdventureWorks2022DB;
GO

-- ─────────────────────────────────────────────────────────────
-- 1. CTE – Basic (replaces messy subquery)
-- Problem: Find the top 3 products by revenue in each
--          product category. Using a CTE makes the logic
--          readable compared to nested subqueries.
-- ─────────────────────────────────────────────────────────────
WITH ProductRevenue AS (
    SELECT
        pc.Name                         AS Category,
        p.Name                          AS Product,
        SUM(sod.LineTotal)              AS TotalRevenue
    FROM Sales.SalesOrderDetail           sod
    JOIN Production.Product               p   ON sod.ProductID          = p.ProductID
    JOIN Production.ProductSubcategory    ps  ON p.ProductSubcategoryID  = ps.ProductSubcategoryID
    JOIN Production.ProductCategory       pc  ON ps.ProductCategoryID    = pc.ProductCategoryID
    GROUP BY pc.Name, p.Name
),
Ranked AS (
    SELECT
        Category,
        Product,
        TotalRevenue,
        ROW_NUMBER() OVER (PARTITION BY Category ORDER BY TotalRevenue DESC) AS Rnk
    FROM ProductRevenue
)
SELECT Category, Product, TotalRevenue, Rnk
FROM Ranked
WHERE Rnk <= 3
ORDER BY Category, Rnk;


-- ─────────────────────────────────────────────────────────────
-- 2. Multiple CTEs chained together
-- Problem: Calculate each salesperson's annual revenue,
--          their revenue rank, and % of total company revenue.
-- ─────────────────────────────────────────────────────────────
WITH SalesPerPerson AS (
    SELECT
        soh.SalesPersonID,
        YEAR(soh.OrderDate)             AS OrderYear,
        SUM(soh.TotalDue)               AS Revenue
    FROM Sales.SalesOrderHeader soh
    WHERE soh.SalesPersonID IS NOT NULL
    GROUP BY soh.SalesPersonID, YEAR(soh.OrderDate)
),
AnnualTotal AS (
    SELECT OrderYear, SUM(Revenue) AS YearTotal
    FROM SalesPerPerson
    GROUP BY OrderYear
)
SELECT
    p.FirstName + ' ' + p.LastName      AS SalesPerson,
    sp.OrderYear,
    sp.Revenue,
    at.YearTotal,
    ROUND(sp.Revenue / at.YearTotal * 100, 2)   AS PctOfTotal,
    RANK() OVER (PARTITION BY sp.OrderYear ORDER BY sp.Revenue DESC) AS YearlyRank
FROM SalesPerPerson sp
JOIN AnnualTotal    at ON sp.OrderYear          = at.OrderYear
JOIN Person.Person  p  ON sp.SalesPersonID      = p.BusinessEntityID
ORDER BY sp.OrderYear, YearlyRank;


-- ─────────────────────────────────────────────────────────────
-- 3. Recursive CTE – Walk a hierarchy
-- Problem: Display the full employee reporting hierarchy
--          (who reports to whom) from the top down,
--          showing the depth level and full path.
-- ─────────────────────────────────────────────────────────────
WITH OrgHierarchy AS (
    -- Anchor: top-level employees (no manager)
    SELECT
        e.BusinessEntityID,
        p.FirstName + ' ' + p.LastName  AS EmployeeName,
        e.JobTitle,
        0                               AS Level,
        CAST(p.FirstName + ' ' + p.LastName AS VARCHAR(500)) AS Path
    FROM HumanResources.Employee   e
    JOIN Person.Person             p ON e.BusinessEntityID = p.BusinessEntityID
    WHERE e.OrganizationLevel = 1

    UNION ALL

    -- Recursive: employees who report to someone in the CTE
    SELECT
        child.BusinessEntityID,
        pc.FirstName + ' ' + pc.LastName,
        child.JobTitle,
        oh.Level + 1,
        CAST(oh.Path + ' > ' + pc.FirstName + ' ' + pc.LastName AS VARCHAR(500))
    FROM HumanResources.Employee   child
    JOIN Person.Person             pc ON child.BusinessEntityID = pc.BusinessEntityID
    JOIN OrgHierarchy              oh ON child.OrganizationNode.GetAncestor(1) = (
        SELECT OrganizationNode FROM HumanResources.Employee
        WHERE BusinessEntityID = oh.BusinessEntityID
    )
)
SELECT
    REPLICATE('    ', Level) + EmployeeName AS HierarchyDisplay,
    JobTitle,
    Level,
    Path
FROM OrgHierarchy
ORDER BY Path
OPTION (MAXRECURSION 50);


-- ─────────────────────────────────────────────────────────────
-- 4. ROW_NUMBER vs RANK vs DENSE_RANK vs NTILE
-- Problem: Rank salespeople by revenue for 2013.
--          Show the difference between all four ranking funcs.
-- ─────────────────────────────────────────────────────────────
WITH SalesRanked AS (
    SELECT
        p.FirstName + ' ' + p.LastName  AS SalesPerson,
        SUM(soh.TotalDue)               AS TotalRevenue
    FROM Sales.SalesOrderHeader soh
    JOIN Person.Person          p  ON soh.SalesPersonID = p.BusinessEntityID
    WHERE soh.SalesPersonID IS NOT NULL
      AND YEAR(soh.OrderDate) = 2013
    GROUP BY p.FirstName, p.LastName
)
SELECT
    SalesPerson,
    TotalRevenue,
    ROW_NUMBER()  OVER (ORDER BY TotalRevenue DESC) AS RowNum,
    -- Gaps after ties:
    RANK()        OVER (ORDER BY TotalRevenue DESC) AS RankNum,
    -- No gaps after ties:
    DENSE_RANK()  OVER (ORDER BY TotalRevenue DESC) AS DenseRankNum,
    -- Divide into 4 equal buckets:
    NTILE(4)      OVER (ORDER BY TotalRevenue DESC) AS Quartile
FROM SalesRanked
ORDER BY TotalRevenue DESC;


-- ─────────────────────────────────────────────────────────────
-- 5. LAG and LEAD – Compare current row to adjacent rows
-- Problem: For each month in 2013, show total revenue,
--          revenue from the previous month (LAG),
--          revenue from the next month (LEAD),
--          and the month-over-month growth %.
-- ─────────────────────────────────────────────────────────────
WITH MonthlyRevenue AS (
    SELECT
        YEAR(OrderDate)     AS OrderYear,
        MONTH(OrderDate)    AS OrderMonth,
        SUM(TotalDue)       AS Revenue
    FROM Sales.SalesOrderHeader
    WHERE YEAR(OrderDate) = 2013
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT
    OrderYear,
    OrderMonth,
    Revenue,
    LAG(Revenue)  OVER (ORDER BY OrderYear, OrderMonth)         AS PrevMonthRevenue,
    LEAD(Revenue) OVER (ORDER BY OrderYear, OrderMonth)         AS NextMonthRevenue,
    ROUND(
        (Revenue - LAG(Revenue) OVER (ORDER BY OrderYear, OrderMonth))
        / NULLIF(LAG(Revenue) OVER (ORDER BY OrderYear, OrderMonth), 0) * 100
    , 2)                                                        AS MoMGrowthPct
FROM MonthlyRevenue
ORDER BY OrderYear, OrderMonth;


-- ─────────────────────────────────────────────────────────────
-- 6. Running Total and Moving Average
-- Problem: Show a daily running total of orders and a
--          3-day moving average of order value for 2014.
-- ─────────────────────────────────────────────────────────────
WITH DailyOrders AS (
    SELECT
        CAST(OrderDate AS DATE)     AS OrderDay,
        COUNT(*)                    AS OrderCount,
        SUM(TotalDue)               AS DailyRevenue
    FROM Sales.SalesOrderHeader
    WHERE YEAR(OrderDate) = 2014
    GROUP BY CAST(OrderDate AS DATE)
)
SELECT
    OrderDay,
    OrderCount,
    DailyRevenue,
    SUM(DailyRevenue)  OVER (ORDER BY OrderDay
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                            AS RunningTotal,
    AVG(DailyRevenue)  OVER (ORDER BY OrderDay
                             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
                                                            AS MovingAvg3Day
FROM DailyOrders
ORDER BY OrderDay;


-- ─────────────────────────────────────────────────────────────
-- 7. PARTITION BY – Window functions per group
-- Problem: For each order, show: its value, the total value
--          for all orders by that customer, and what % of
--          that customer's spend this single order represents.
-- ─────────────────────────────────────────────────────────────
SELECT
    soh.SalesOrderID,
    soh.CustomerID,
    p.FirstName + ' ' + p.LastName          AS CustomerName,
    soh.TotalDue                            AS OrderValue,
    SUM(soh.TotalDue) OVER (PARTITION BY soh.CustomerID)
                                            AS CustomerTotalSpend,
    ROUND(
        soh.TotalDue
        / SUM(soh.TotalDue) OVER (PARTITION BY soh.CustomerID)
        * 100, 2
    )                                       AS PctOfCustomerSpend,
    ROW_NUMBER() OVER (PARTITION BY soh.CustomerID ORDER BY soh.TotalDue DESC)
                                            AS OrderRankForCustomer
FROM Sales.SalesOrderHeader soh
JOIN Sales.Customer          c  ON soh.CustomerID  = c.CustomerID
JOIN Person.Person           p  ON c.PersonID      = p.BusinessEntityID
ORDER BY CustomerName, OrderValue DESC;


-- ─────────────────────────────────────────────────────────────
-- 8. FIRST_VALUE and LAST_VALUE
-- Problem: For each product, show its current list price,
--          the cheapest and most expensive price within its
--          subcategory (using window functions).
-- ─────────────────────────────────────────────────────────────
SELECT
    p.Name,
    ps.Name                             AS SubCategory,
    p.ListPrice,
    FIRST_VALUE(p.ListPrice) OVER (
        PARTITION BY p.ProductSubcategoryID
        ORDER BY p.ListPrice ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )                                   AS CheapestInSubcat,
    LAST_VALUE(p.ListPrice) OVER (
        PARTITION BY p.ProductSubcategoryID
        ORDER BY p.ListPrice ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )                                   AS MostExpensiveInSubcat
FROM Production.Product             p
JOIN Production.ProductSubcategory  ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
ORDER BY ps.Name, p.ListPrice;


-- ─────────────────────────────────────────────────────────────
-- 9. PIVOT – Rotate rows to columns
-- Problem: Show total order count per territory, pivoted by
--          year (2011, 2012, 2013, 2014) as columns.
-- ─────────────────────────────────────────────────────────────
SELECT
    TerritoryID,
    ISNULL([2011], 0) AS [2011],
    ISNULL([2012], 0) AS [2012],
    ISNULL([2013], 0) AS [2013],
    ISNULL([2014], 0) AS [2014]
FROM (
    SELECT
        TerritoryID,
        YEAR(OrderDate) AS OrderYear,
        SalesOrderID
    FROM Sales.SalesOrderHeader
    WHERE YEAR(OrderDate) BETWEEN 2011 AND 2014
) AS src
PIVOT (
    COUNT(SalesOrderID)
    FOR OrderYear IN ([2011], [2012], [2013], [2014])
) AS pvt
ORDER BY TerritoryID;


-- ─────────────────────────────────────────────────────────────
-- 10. UNPIVOT – Rotate columns back to rows
-- Problem: The previous PIVOT result has year columns. Unpivot
--          to get a Year column and an OrderCount column.
-- ─────────────────────────────────────────────────────────────
SELECT TerritoryID, OrderYear, OrderCount
FROM (
    SELECT
        TerritoryID,
        ISNULL([2011], 0) AS [2011],
        ISNULL([2012], 0) AS [2012],
        ISNULL([2013], 0) AS [2013],
        ISNULL([2014], 0) AS [2014]
    FROM (
        SELECT TerritoryID, YEAR(OrderDate) AS OrderYear, SalesOrderID
        FROM Sales.SalesOrderHeader
        WHERE YEAR(OrderDate) BETWEEN 2011 AND 2014
    ) src
    PIVOT (COUNT(SalesOrderID) FOR OrderYear IN ([2011],[2012],[2013],[2014])) pvt
) AS pivoted
UNPIVOT (
    OrderCount FOR OrderYear IN ([2011],[2012],[2013],[2014])
) AS unpvt
ORDER BY TerritoryID, OrderYear;


-- ─────────────────────────────────────────────────────────────
-- 11. CROSS APPLY – Apply a table-valued function to each row
-- Problem: For each customer, get their 3 most recent orders
--          using CROSS APPLY with a correlated subquery.
--          (CROSS APPLY = inner join semantics, only customers
--           with orders returned.)
-- ─────────────────────────────────────────────────────────────
SELECT
    c.CustomerID,
    p.FirstName + ' ' + p.LastName  AS CustomerName,
    recentOrders.SalesOrderID,
    recentOrders.OrderDate,
    recentOrders.TotalDue
FROM Sales.Customer   c
JOIN Person.Person    p  ON c.PersonID = p.BusinessEntityID
CROSS APPLY (
    SELECT TOP 3
        SalesOrderID, OrderDate, TotalDue
    FROM Sales.SalesOrderHeader
    WHERE CustomerID = c.CustomerID
    ORDER BY OrderDate DESC
) AS recentOrders
ORDER BY CustomerName, recentOrders.OrderDate DESC;


-- ─────────────────────────────────────────────────────────────
-- 12. OUTER APPLY – Like LEFT JOIN version of CROSS APPLY
-- Problem: Same as above but include customers with NO orders.
--          (OUTER APPLY = left join semantics)
-- ─────────────────────────────────────────────────────────────
SELECT
    c.CustomerID,
    p.FirstName + ' ' + p.LastName  AS CustomerName,
    recentOrders.SalesOrderID,
    recentOrders.OrderDate,
    recentOrders.TotalDue
FROM Sales.Customer   c
JOIN Person.Person    p  ON c.PersonID = p.BusinessEntityID
OUTER APPLY (
    SELECT TOP 3
        SalesOrderID, OrderDate, TotalDue
    FROM Sales.SalesOrderHeader
    WHERE CustomerID = c.CustomerID
    ORDER BY OrderDate DESC
) AS recentOrders
ORDER BY CustomerName;


-- ─────────────────────────────────────────────────────────────
-- 13. MERGE – Upsert (Update existing + Insert new)
-- Problem: You have a staging table of updated product prices.
--          MERGE into Production.Product: update price if
--          product exists, insert if it does not.
--          (Demo uses a table variable as the source.)
-- ─────────────────────────────────────────────────────────────
DECLARE @PriceUpdates TABLE (
    ProductID   INT,
    NewPrice    MONEY,
    ProductName VARCHAR(100)
);
-- Simulate incoming data
INSERT INTO @PriceUpdates VALUES (680, 1400.00, NULL), (706, 850.00, NULL);

MERGE Production.Product AS target
USING @PriceUpdates      AS source
    ON target.ProductID = source.ProductID
WHEN MATCHED THEN
    UPDATE SET target.ListPrice = source.NewPrice,
               target.ModifiedDate = GETDATE()
WHEN NOT MATCHED BY TARGET THEN
    -- Would INSERT here if source had new products (skipped for safety)
    -- INSERT (...) VALUES (...)
    -- Uncomment above in a real scenario with all required columns
    UPDATE SET target.ModifiedDate = target.ModifiedDate  -- no-op placeholder
OUTPUT
    $action                         AS MergeAction,
    inserted.ProductID,
    deleted.ListPrice               AS OldPrice,
    inserted.ListPrice              AS NewPrice;


-- ─────────────────────────────────────────────────────────────
-- 14. TRY / CATCH + Transactions
-- Problem: Insert a new sales order header and its detail
--          rows atomically. If anything fails, roll back
--          entirely and surface the error.
-- ─────────────────────────────────────────────────────────────
BEGIN TRY
    BEGIN TRANSACTION;

        -- (Simplified demo — real insert needs all NOT NULL columns)
        -- This intentionally shows the pattern, not a runnable insert.
        PRINT 'Transaction started';

        -- Simulated work:
        UPDATE Sales.SalesOrderHeader
        SET    ModifiedDate = GETDATE()
        WHERE  SalesOrderID = -1;    -- no rows affected, safe demo

        -- Simulate an error to test the CATCH block:
        -- RAISERROR('Simulated failure', 16, 1);

    COMMIT TRANSACTION;
    PRINT 'Transaction committed successfully';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT
        ERROR_NUMBER()      AS ErrorNumber,
        ERROR_SEVERITY()    AS Severity,
        ERROR_STATE()       AS State,
        ERROR_PROCEDURE()   AS Procedure_,
        ERROR_LINE()        AS ErrorLine,
        ERROR_MESSAGE()     AS ErrorMessage;
END CATCH;


-- ─────────────────────────────────────────────────────────────
-- 15. Temp Tables vs Table Variables
-- Problem: Stage a complex intermediate result in a temp table
--          (shared within session), then query it.
--          Use a table variable for small, scoped data.
-- ─────────────────────────────────────────────────────────────

-- TEMP TABLE — stored in tempdb, supports statistics, indexes
DROP TABLE IF EXISTS #TopCustomers;

SELECT TOP 100
    c.CustomerID,
    p.FirstName + ' ' + p.LastName  AS CustomerName,
    COUNT(soh.SalesOrderID)         AS OrderCount,
    SUM(soh.TotalDue)               AS TotalSpend
INTO #TopCustomers
FROM Sales.Customer           c
JOIN Person.Person            p   ON c.PersonID       = p.BusinessEntityID
JOIN Sales.SalesOrderHeader   soh ON c.CustomerID     = soh.CustomerID
GROUP BY c.CustomerID, p.FirstName, p.LastName
ORDER BY TotalSpend DESC;

-- Add an index on the temp table for performance
CREATE INDEX IX_TopCustomers_Spend ON #TopCustomers (TotalSpend DESC);

SELECT * FROM #TopCustomers ORDER BY TotalSpend DESC;

-- TABLE VARIABLE — lighter, scoped to batch, no statistics
DECLARE @SummaryStats TABLE (
    Metric      VARCHAR(50),
    Value       DECIMAL(18,2)
);
INSERT INTO @SummaryStats VALUES
    ('AvgSpend',    (SELECT AVG(TotalSpend) FROM #TopCustomers)),
    ('MaxSpend',    (SELECT MAX(TotalSpend) FROM #TopCustomers)),
    ('TotalOrders', (SELECT SUM(OrderCount)  FROM #TopCustomers));

SELECT * FROM @SummaryStats;

DROP TABLE IF EXISTS #TopCustomers;

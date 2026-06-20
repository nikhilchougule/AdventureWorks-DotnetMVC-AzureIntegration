-- ============================================================
-- AdventureWorks2022DB  |  SQL SAMPLES  |  INTERMEDIATE LEVEL
-- Database: AdventureWorks2022DB
-- ============================================================
-- Concepts covered:
--   INNER JOIN, LEFT JOIN, RIGHT JOIN, FULL OUTER JOIN,
--   SELF JOIN, CROSS JOIN,
--   GROUP BY, HAVING,
--   Subqueries (correlated & non-correlated),
--   CASE expressions, IIF,
--   EXISTS / NOT EXISTS,
--   UNION / UNION ALL / INTERSECT / EXCEPT,
--   Derived tables,
--   Common aggregation patterns
-- ============================================================

USE AdventureWorks2022DB;
GO

-- ─────────────────────────────────────────────────────────────
-- 1. INNER JOIN – Only matching rows on both sides
-- Problem: List each sales order with the customer's full name.
-- ─────────────────────────────────────────────────────────────
SELECT
    soh.SalesOrderID,
    soh.OrderDate,
    soh.TotalDue,
    p.FirstName + ' ' + p.LastName AS CustomerName
FROM Sales.SalesOrderHeader   soh
INNER JOIN Sales.Customer      c   ON soh.CustomerID   = c.CustomerID
INNER JOIN Person.Person       p   ON c.PersonID        = p.BusinessEntityID
ORDER BY soh.OrderDate DESC;


-- ─────────────────────────────────────────────────────────────
-- 2. LEFT JOIN – Keep all rows from the left table
-- Problem: List every product and, if it has ever been ordered,
--          show the total quantity sold. Include products
--          that have NEVER been ordered.
-- ─────────────────────────────────────────────────────────────
SELECT
    p.ProductID,
    p.Name,
    p.ListPrice,
    ISNULL(SUM(sod.OrderQty), 0)    AS TotalQtySold
FROM Production.Product           p
LEFT JOIN Sales.SalesOrderDetail  sod ON p.ProductID = sod.ProductID
GROUP BY p.ProductID, p.Name, p.ListPrice
ORDER BY TotalQtySold DESC;


-- ─────────────────────────────────────────────────────────────
-- 3. Multi-table JOIN chain
-- Problem: Show each order line with: order number, product
--          name, subcategory, category, qty, unit price.
-- ─────────────────────────────────────────────────────────────
SELECT
    soh.SalesOrderNumber,
    soh.OrderDate,
    p.Name                  AS Product,
    ps.Name                 AS SubCategory,
    pc.Name                 AS Category,
    sod.OrderQty,
    sod.UnitPrice,
    sod.LineTotal
FROM Sales.SalesOrderDetail           sod
JOIN Sales.SalesOrderHeader           soh ON sod.SalesOrderID      = soh.SalesOrderID
JOIN Production.Product               p   ON sod.ProductID         = p.ProductID
LEFT JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN Production.ProductCategory   pc ON ps.ProductCategoryID   = pc.ProductCategoryID
ORDER BY soh.OrderDate DESC, sod.LineTotal DESC;


-- ─────────────────────────────────────────────────────────────
-- 4. SELF JOIN
-- Problem: Show each employee and the name of their manager
--          (manager is also an employee).
-- ─────────────────────────────────────────────────────────────
SELECT
    e.BusinessEntityID                              AS EmployeeID,
    pe.FirstName + ' ' + pe.LastName               AS EmployeeName,
    e.JobTitle,
    e.OrganizationLevel,
    m.BusinessEntityID                              AS ManagerID,
    pm.FirstName + ' ' + pm.LastName               AS ManagerName
FROM HumanResources.Employee   e
JOIN Person.Person             pe ON e.BusinessEntityID  = pe.BusinessEntityID
LEFT JOIN HumanResources.Employee m  ON e.OrganizationNode.GetAncestor(1) = m.OrganizationNode
LEFT JOIN Person.Person        pm ON m.BusinessEntityID  = pm.BusinessEntityID
ORDER BY e.OrganizationLevel, EmployeeName;


-- ─────────────────────────────────────────────────────────────
-- 5. FULL OUTER JOIN
-- Problem: Show all products and all order details side by side,
--          including products never ordered AND order details
--          whose product no longer exists.
-- ─────────────────────────────────────────────────────────────
SELECT
    p.ProductID,
    p.Name          AS ProductName,
    sod.SalesOrderID,
    sod.OrderQty
FROM Production.Product          p
FULL OUTER JOIN Sales.SalesOrderDetail sod ON p.ProductID = sod.ProductID
WHERE p.ProductID IS NULL OR sod.SalesOrderID IS NULL;  -- only the "gaps"


-- ─────────────────────────────────────────────────────────────
-- 6. GROUP BY + Aggregation
-- Problem: How much revenue did each product generate?
--          Show top 20 by total revenue.
-- ─────────────────────────────────────────────────────────────
SELECT TOP 20
    p.Name                          AS Product,
    SUM(sod.OrderQty)               AS UnitsSold,
    SUM(sod.LineTotal)              AS TotalRevenue,
    AVG(sod.UnitPrice)              AS AvgUnitPrice
FROM Sales.SalesOrderDetail sod
JOIN Production.Product     p   ON sod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY TotalRevenue DESC;


-- ─────────────────────────────────────────────────────────────
-- 7. GROUP BY + HAVING – Filter on aggregated results
-- Problem: Find customers who have placed more than 10 orders
--          with a total spend over $50,000.
-- ─────────────────────────────────────────────────────────────
SELECT
    p.FirstName + ' ' + p.LastName  AS CustomerName,
    COUNT(soh.SalesOrderID)         AS TotalOrders,
    SUM(soh.TotalDue)               AS TotalSpend
FROM Sales.SalesOrderHeader soh
JOIN Sales.Customer          c   ON soh.CustomerID  = c.CustomerID
JOIN Person.Person           p   ON c.PersonID      = p.BusinessEntityID
GROUP BY p.FirstName, p.LastName
HAVING COUNT(soh.SalesOrderID) > 10
   AND SUM(soh.TotalDue) > 50000
ORDER BY TotalSpend DESC;


-- ─────────────────────────────────────────────────────────────
-- 8. Non-Correlated Subquery – IN
-- Problem: Find all products that have been included in a
--          special offer (appear in SpecialOfferProduct).
-- ─────────────────────────────────────────────────────────────
SELECT
    ProductID,
    Name,
    ListPrice
FROM Production.Product
WHERE ProductID IN (
    SELECT ProductID
    FROM Sales.SpecialOfferProduct
)
ORDER BY ListPrice DESC;


-- ─────────────────────────────────────────────────────────────
-- 9. Correlated Subquery
-- Problem: For each product, show whether its list price is
--          above or below the average price for its subcategory.
-- ─────────────────────────────────────────────────────────────
SELECT
    p.Name,
    p.ListPrice,
    (
        SELECT AVG(p2.ListPrice)
        FROM Production.Product p2
        WHERE p2.ProductSubcategoryID = p.ProductSubcategoryID
    )                                       AS AvgSubcategoryPrice,
    CASE
        WHEN p.ListPrice > (
            SELECT AVG(p2.ListPrice)
            FROM Production.Product p2
            WHERE p2.ProductSubcategoryID = p.ProductSubcategoryID
        ) THEN 'Above Average'
        ELSE 'Below Average'
    END                                     AS PricePosition
FROM Production.Product p
WHERE p.ProductSubcategoryID IS NOT NULL
ORDER BY p.ProductSubcategoryID, p.ListPrice;


-- ─────────────────────────────────────────────────────────────
-- 10. EXISTS vs IN  (EXISTS is faster on large sets — no duplicates)
-- Problem: Find salespeople who have at least one order over
--          $10,000. Show EXISTS vs IN pattern.
-- ─────────────────────────────────────────────────────────────
-- Using EXISTS (preferred for performance):
SELECT
    sp.BusinessEntityID,
    p.FirstName + ' ' + p.LastName  AS SalesPersonName
FROM Sales.SalesPerson         sp
JOIN Person.Person             p  ON sp.BusinessEntityID = p.BusinessEntityID
WHERE EXISTS (
    SELECT 1
    FROM Sales.SalesOrderHeader soh
    WHERE soh.SalesPersonID = sp.BusinessEntityID
      AND soh.TotalDue > 10000
);

-- Using IN (equivalent but scans full subquery result):
SELECT
    sp.BusinessEntityID,
    p.FirstName + ' ' + p.LastName  AS SalesPersonName
FROM Sales.SalesPerson  sp
JOIN Person.Person      p ON sp.BusinessEntityID = p.BusinessEntityID
WHERE sp.BusinessEntityID IN (
    SELECT SalesPersonID
    FROM Sales.SalesOrderHeader
    WHERE TotalDue > 10000
);


-- ─────────────────────────────────────────────────────────────
-- 11. NOT EXISTS – Find "missing" data
-- Problem: Find products that have NEVER been sold.
-- ─────────────────────────────────────────────────────────────
SELECT
    p.ProductID,
    p.Name,
    p.ListPrice
FROM Production.Product p
WHERE NOT EXISTS (
    SELECT 1
    FROM Sales.SalesOrderDetail sod
    WHERE sod.ProductID = p.ProductID
)
ORDER BY p.Name;


-- ─────────────────────────────────────────────────────────────
-- 12. CASE expression – Inline conditional logic
-- Problem: Categorize each sales order by size:
--          Small (<$1K), Medium ($1K–$10K), Large (>$10K).
-- ─────────────────────────────────────────────────────────────
SELECT
    SalesOrderID,
    TotalDue,
    CASE
        WHEN TotalDue < 1000            THEN 'Small'
        WHEN TotalDue BETWEEN 1000 AND 10000 THEN 'Medium'
        ELSE                                  'Large'
    END                                 AS OrderSize,
    CASE Status
        WHEN 1 THEN 'In Process'
        WHEN 2 THEN 'Approved'
        WHEN 3 THEN 'Backordered'
        WHEN 4 THEN 'Rejected'
        WHEN 5 THEN 'Shipped'
        WHEN 6 THEN 'Cancelled'
        ELSE        'Unknown'
    END                                 AS StatusLabel
FROM Sales.SalesOrderHeader
ORDER BY TotalDue DESC;


-- ─────────────────────────────────────────────────────────────
-- 13. UNION ALL vs UNION
-- Problem: Combine the list of all customer contact email
--          addresses and all employee email addresses into
--          one result set.
-- ─────────────────────────────────────────────────────────────
-- UNION removes duplicates; UNION ALL keeps all rows (faster)
SELECT
    'Customer'      AS PersonType,
    p.FirstName + ' ' + p.LastName AS FullName,
    ea.EmailAddress
FROM Sales.Customer   c
JOIN Person.Person    p  ON c.PersonID         = p.BusinessEntityID
JOIN Person.EmailAddress ea ON p.BusinessEntityID = ea.BusinessEntityID

UNION ALL

SELECT
    'Employee'      AS PersonType,
    p.FirstName + ' ' + p.LastName AS FullName,
    ea.EmailAddress
FROM HumanResources.Employee e
JOIN Person.Person            p  ON e.BusinessEntityID = p.BusinessEntityID
JOIN Person.EmailAddress      ea ON p.BusinessEntityID = ea.BusinessEntityID

ORDER BY PersonType, FullName;


-- ─────────────────────────────────────────────────────────────
-- 14. INTERSECT and EXCEPT
-- Problem: INTERSECT — Find BusinessEntityIDs that are BOTH
--                       customers AND employees.
--          EXCEPT    — Find customers who are NOT employees.
-- ─────────────────────────────────────────────────────────────
-- People who are both customers and employees
SELECT PersonID AS BusinessEntityID FROM Sales.Customer WHERE PersonID IS NOT NULL
INTERSECT
SELECT BusinessEntityID FROM HumanResources.Employee;

-- Customers who are NOT employees
SELECT PersonID AS BusinessEntityID FROM Sales.Customer WHERE PersonID IS NOT NULL
EXCEPT
SELECT BusinessEntityID FROM HumanResources.Employee;


-- ─────────────────────────────────────────────────────────────
-- 15. Derived Table (Subquery in FROM)
-- Problem: Find the top 5 territories by total revenue,
--          then join back to get the territory name.
-- ─────────────────────────────────────────────────────────────
SELECT
    st.Name             AS Territory,
    st.CountryRegionCode,
    rev.TotalRevenue
FROM (
    SELECT
        TerritoryID,
        SUM(TotalDue)   AS TotalRevenue
    FROM Sales.SalesOrderHeader
    GROUP BY TerritoryID
) AS rev
JOIN Sales.SalesTerritory st ON rev.TerritoryID = st.TerritoryID
ORDER BY rev.TotalRevenue DESC;


-- ─────────────────────────────────────────────────────────────
-- 16. GROUP BY with ROLLUP – Subtotals and grand total
-- Problem: Show total sales by year and month, with a yearly
--          subtotal row and a grand total row.
-- ─────────────────────────────────────────────────────────────
SELECT
    ISNULL(CAST(YEAR(OrderDate) AS VARCHAR), 'Grand Total')     AS OrderYear,
    ISNULL(CAST(MONTH(OrderDate) AS VARCHAR), 'Year Total')     AS OrderMonth,
    COUNT(*)            AS OrderCount,
    SUM(TotalDue)       AS TotalRevenue
FROM Sales.SalesOrderHeader
GROUP BY ROLLUP(YEAR(OrderDate), MONTH(OrderDate))
ORDER BY YEAR(OrderDate), MONTH(OrderDate);


-- ─────────────────────────────────────────────────────────────
-- 17. CROSS JOIN – Cartesian product
-- Problem: Generate all combinations of product color and
--          product category (useful for reporting templates).
-- ─────────────────────────────────────────────────────────────
SELECT
    colors.Color,
    pc.Name AS Category
FROM (
    SELECT DISTINCT Color FROM Production.Product WHERE Color IS NOT NULL
) AS colors
CROSS JOIN Production.ProductCategory pc
ORDER BY pc.Name, colors.Color;


-- ─────────────────────────────────────────────────────────────
-- 18. Conditional Aggregation with CASE inside SUM/COUNT
-- Problem: Show each salesperson's order counts broken down
--          by order size (Small / Medium / Large) in one row.
-- ─────────────────────────────────────────────────────────────
SELECT
    p.FirstName + ' ' + p.LastName          AS SalesPerson,
    COUNT(*)                                AS TotalOrders,
    SUM(CASE WHEN TotalDue < 1000              THEN 1 ELSE 0 END) AS SmallOrders,
    SUM(CASE WHEN TotalDue BETWEEN 1000 AND 10000 THEN 1 ELSE 0 END) AS MediumOrders,
    SUM(CASE WHEN TotalDue > 10000             THEN 1 ELSE 0 END) AS LargeOrders,
    SUM(TotalDue)                           AS TotalRevenue
FROM Sales.SalesOrderHeader   soh
JOIN Sales.SalesPerson        sp ON soh.SalesPersonID     = sp.BusinessEntityID
JOIN Person.Person            p  ON sp.BusinessEntityID   = p.BusinessEntityID
WHERE soh.SalesPersonID IS NOT NULL
GROUP BY p.FirstName, p.LastName
ORDER BY TotalRevenue DESC;

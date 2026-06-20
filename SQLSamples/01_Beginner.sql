-- ============================================================
-- AdventureWorks2022DB  |  SQL SAMPLES  |  BEGINNER LEVEL
-- Database: AdventureWorks2022DB
-- ============================================================
-- Concepts covered:
--   SELECT, WHERE, ORDER BY, TOP, DISTINCT, Aliases,
--   NULL handling, Basic string/date/math functions,
--   BETWEEN, IN, LIKE, Wildcard searches
-- ============================================================

USE AdventureWorks2022DB;
GO

-- ─────────────────────────────────────────────────────────────
-- 1. BASIC SELECT
-- Problem: Retrieve the first 10 products with their name,
--          color and list price.
-- ─────────────────────────────────────────────────────────────
SELECT TOP 10
    ProductID,
    Name,
    Color,
    ListPrice
FROM Production.Product;


-- ─────────────────────────────────────────────────────────────
-- 2. COLUMN ALIASES
-- Problem: Show product name and list price with friendlier
--          column headings.
-- ─────────────────────────────────────────────────────────────
SELECT
    Name        AS ProductName,
    ListPrice   AS Price
FROM Production.Product
ORDER BY ListPrice DESC;


-- ─────────────────────────────────────────────────────────────
-- 3. WHERE – Filtering rows
-- Problem: Find all products whose list price is over $1,000.
-- ─────────────────────────────────────────────────────────────
SELECT
    Name,
    ListPrice
FROM Production.Product
WHERE ListPrice > 1000
ORDER BY ListPrice DESC;


-- ─────────────────────────────────────────────────────────────
-- 4. BETWEEN
-- Problem: List products priced between $500 and $1,500.
-- ─────────────────────────────────────────────────────────────
SELECT
    Name,
    ListPrice
FROM Production.Product
WHERE ListPrice BETWEEN 500 AND 1500
ORDER BY ListPrice;


-- ─────────────────────────────────────────────────────────────
-- 5. IN operator
-- Problem: Retrieve orders with Status 1 (In Process),
--          3 (Cancelled) or 5 (Shipped).
-- ─────────────────────────────────────────────────────────────
SELECT
    SalesOrderID,
    OrderDate,
    Status,
    TotalDue
FROM Sales.SalesOrderHeader
WHERE Status IN (1, 3, 5)
ORDER BY OrderDate DESC;


-- ─────────────────────────────────────────────────────────────
-- 6. LIKE – Wildcard search
-- Problem: Find all products whose name starts with "Mountain".
-- ─────────────────────────────────────────────────────────────
SELECT
    Name,
    ProductNumber,
    ListPrice
FROM Production.Product
WHERE Name LIKE 'Mountain%';


-- ─────────────────────────────────────────────────────────────
-- 7. LIKE – Contains pattern
-- Problem: Find employees whose job title contains the word
--          "Manager".
-- ─────────────────────────────────────────────────────────────
SELECT
    BusinessEntityID,
    JobTitle,
    HireDate
FROM HumanResources.Employee
WHERE JobTitle LIKE '%Manager%'
ORDER BY JobTitle;


-- ─────────────────────────────────────────────────────────────
-- 8. NULL handling – IS NULL / IS NOT NULL
-- Problem: Find all products that have no color assigned.
-- ─────────────────────────────────────────────────────────────
SELECT
    Name,
    Color,
    ListPrice
FROM Production.Product
WHERE Color IS NULL;

-- Products that DO have a color
SELECT
    Name,
    Color,
    ListPrice
FROM Production.Product
WHERE Color IS NOT NULL
ORDER BY Color;


-- ─────────────────────────────────────────────────────────────
-- 9. ISNULL / COALESCE – Replace NULLs with a default
-- Problem: Display product color; if NULL show "No Color".
-- ─────────────────────────────────────────────────────────────
SELECT
    Name,
    ISNULL(Color, 'No Color')       AS Color,       -- SQL Server specific
    COALESCE(Color, 'No Color')     AS ColorCoalesce -- ANSI standard
FROM Production.Product
ORDER BY Name;


-- ─────────────────────────────────────────────────────────────
-- 10. DISTINCT
-- Problem: What distinct colors exist in the product catalog?
-- ─────────────────────────────────────────────────────────────
SELECT DISTINCT
    Color
FROM Production.Product
WHERE Color IS NOT NULL
ORDER BY Color;


-- ─────────────────────────────────────────────────────────────
-- 11. ORDER BY – Multiple columns, ASC / DESC
-- Problem: List the top 20 most expensive products; break
--          ties by name alphabetically.
-- ─────────────────────────────────────────────────────────────
SELECT TOP 20
    Name,
    Color,
    ListPrice
FROM Production.Product
ORDER BY ListPrice DESC, Name ASC;


-- ─────────────────────────────────────────────────────────────
-- 12. Basic Math in SELECT
-- Problem: Show each product's list price, a 10% discount
--          amount, and the final price after discount.
-- ─────────────────────────────────────────────────────────────
SELECT
    Name,
    ListPrice,
    ROUND(ListPrice * 0.10, 2)          AS Discount,
    ROUND(ListPrice - ListPrice * 0.10, 2) AS FinalPrice
FROM Production.Product
WHERE ListPrice > 0
ORDER BY ListPrice DESC;


-- ─────────────────────────────────────────────────────────────
-- 13. String Functions
-- Problem: Display each person's full name in UPPER case,
--          their first name length, and a substring
--          of their last name (first 4 chars).
-- ─────────────────────────────────────────────────────────────
SELECT TOP 20
    UPPER(FirstName + ' ' + LastName)       AS FullNameUpper,
    LEN(FirstName)                          AS FirstNameLength,
    SUBSTRING(LastName, 1, 4)               AS LastNameShort,
    LTRIM(RTRIM(FirstName))                 AS TrimmedFirst
FROM Person.Person
ORDER BY LastName;


-- ─────────────────────────────────────────────────────────────
-- 14. Date Functions
-- Problem: For each sales order, show the order date, due date,
--          the year and month of order, and how many days
--          between order and due date.
-- ─────────────────────────────────────────────────────────────
SELECT TOP 20
    SalesOrderID,
    OrderDate,
    DueDate,
    YEAR(OrderDate)                         AS OrderYear,
    MONTH(OrderDate)                        AS OrderMonth,
    DAY(OrderDate)                          AS OrderDay,
    FORMAT(OrderDate, 'MMM yyyy')           AS OrderMonthName,
    DATEDIFF(DAY, OrderDate, DueDate)       AS DaysUntilDue
FROM Sales.SalesOrderHeader
ORDER BY OrderDate DESC;


-- ─────────────────────────────────────────────────────────────
-- 15. CAST and CONVERT
-- Problem: Show TotalDue as a formatted string (currency),
--          and convert OrderDate to a date-only string.
-- ─────────────────────────────────────────────────────────────
SELECT TOP 10
    SalesOrderID,
    '$' + CAST(CAST(TotalDue AS DECIMAL(10,2)) AS VARCHAR(20))  AS TotalDueFormatted,
    CONVERT(VARCHAR(10), OrderDate, 101)                         AS OrderDateUS,   -- MM/DD/YYYY
    CONVERT(VARCHAR(10), OrderDate, 120)                         AS OrderDateISO   -- YYYY-MM-DD
FROM Sales.SalesOrderHeader
ORDER BY TotalDue DESC;


-- ─────────────────────────────────────────────────────────────
-- 16. AND / OR – Compound conditions
-- Problem: Find red or black bikes priced over $800.
-- ─────────────────────────────────────────────────────────────
SELECT
    p.Name,
    p.Color,
    p.ListPrice,
    ps.Name AS SubCategory
FROM Production.Product p
JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory    pc ON ps.ProductCategoryID   = pc.ProductCategoryID
WHERE pc.Name = 'Bikes'
  AND p.Color IN ('Red', 'Black')
  AND p.ListPrice > 800
ORDER BY p.ListPrice DESC;


-- ─────────────────────────────────────────────────────────────
-- 17. COUNT – How many rows exist?
-- Problem: How many products are in the catalog?
--          How many have a list price greater than zero?
-- ─────────────────────────────────────────────────────────────
SELECT
    COUNT(*)                            AS TotalProducts,
    COUNT(Color)                        AS ProductsWithColor,   -- NULLs excluded
    COUNT(DISTINCT Color)               AS DistinctColors,
    SUM(CASE WHEN ListPrice > 0 THEN 1 ELSE 0 END) AS ProductsWithPrice
FROM Production.Product;


-- ─────────────────────────────────────────────────────────────
-- 18. SUM, AVG, MIN, MAX
-- Problem: What are the sales statistics (total, average,
--          min, max order value) for the year 2013?
-- ─────────────────────────────────────────────────────────────
SELECT
    COUNT(*)            AS TotalOrders,
    SUM(TotalDue)       AS TotalRevenue,
    AVG(TotalDue)       AS AvgOrderValue,
    MIN(TotalDue)       AS SmallestOrder,
    MAX(TotalDue)       AS LargestOrder
FROM Sales.SalesOrderHeader
WHERE YEAR(OrderDate) = 2013;

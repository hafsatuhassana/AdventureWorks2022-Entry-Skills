USE AdventureWorks2022;
GO

/* =========================================================
   PART A — Environment + Cleanup
========================================================= */

/* Drop tables safely (child -> parent order) */

IF OBJECT_ID('EntryTest.OrderItemMini', 'U') IS NOT NULL
    DROP TABLE EntryTest.OrderItemMini;

IF OBJECT_ID('EntryTest.OrderMini', 'U') IS NOT NULL
    DROP TABLE EntryTest.OrderMini;

IF OBJECT_ID('EntryTest.CustomerMini', 'U') IS NOT NULL
    DROP TABLE EntryTest.CustomerMini;
GO

/* Optional: Drop schema if empty */

IF EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'EntryTest'
)
AND NOT EXISTS (
    SELECT 1
    FROM sys.objects o
    INNER JOIN sys.schemas s
        ON o.schema_id = s.schema_id
    WHERE s.name = 'EntryTest'
)
BEGIN
    DROP SCHEMA EntryTest;
END;
GO


/* =========================================================
   PART B — DDL Tables + Constraints
========================================================= */

/* B1) Create schema if it doesn't exist */

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'EntryTest'
)
BEGIN
    EXEC('CREATE SCHEMA EntryTest');
END;
GO


/* B2) Create CustomerMini */

CREATE TABLE EntryTest.CustomerMini
(
    CustomerMiniID INT IDENTITY(1,1) PRIMARY KEY,

    CustomerID INT NOT NULL UNIQUE,

    AccountNumber NVARCHAR(10) NOT NULL,

    CustomerType NCHAR(1) NOT NULL
        CHECK (CustomerType IN ('I', 'S')),

    CreatedAt DATETIME2(0) NOT NULL
        DEFAULT SYSDATETIME()
);
GO


/* B3) Create OrderMini */

CREATE TABLE EntryTest.OrderMini
(
    OrderMiniID INT IDENTITY(1,1) PRIMARY KEY,

    SalesOrderID INT NOT NULL UNIQUE,

    CustomerID INT NOT NULL,

    OrderDate DATE NOT NULL,

    SubTotal MONEY NOT NULL
        CHECK (SubTotal >= 0),

    TaxAmt MONEY NOT NULL
        CHECK (TaxAmt >= 0),

    Freight MONEY NOT NULL
        CHECK (Freight >= 0),

    TotalDue MONEY NOT NULL
        CHECK (TotalDue >= 0)
);
GO


/* B4) Create OrderItemMini */

CREATE TABLE EntryTest.OrderItemMini
(
    OrderItemMiniID INT IDENTITY(1,1) PRIMARY KEY,

    SalesOrderID INT NOT NULL,

    SalesOrderDetailID INT NOT NULL,

    ProductID INT NOT NULL,

    OrderQty SMALLINT NOT NULL
        CHECK (OrderQty > 0),

    UnitPrice MONEY NOT NULL
        CHECK (UnitPrice >= 0),

    UnitPriceDiscount MONEY NOT NULL
        DEFAULT (0)
        CHECK (UnitPriceDiscount BETWEEN 0 AND 1),

    LineTotal MONEY NOT NULL
        CHECK (LineTotal >= 0),

    CONSTRAINT UQ_OrderItemMini
        UNIQUE (SalesOrderID, SalesOrderDetailID),

    CONSTRAINT FK_OrderItemMini_OrderMini
        FOREIGN KEY (SalesOrderID)
        REFERENCES EntryTest.OrderMini(SalesOrderID)
);
GO


/* =========================================================
   PART C — Basic DML
========================================================= */

/* C1) Insert exactly 50 customers */

INSERT INTO EntryTest.CustomerMini
(
    CustomerID,
    AccountNumber,
    CustomerType
)
SELECT TOP 50
    CustomerID,
    AccountNumber,
    CASE
        WHEN PersonID IS NOT NULL THEN 'I'
        WHEN StoreID IS NOT NULL THEN 'S'
    END AS CustomerType
FROM Sales.Customer
ORDER BY CustomerID ASC;
GO


/* C2) Insert exactly 200 most recent orders */

INSERT INTO EntryTest.OrderMini
(
    SalesOrderID,
    CustomerID,
    OrderDate,
    SubTotal,
    TaxAmt,
    Freight,
    TotalDue
)
SELECT TOP 200
    SalesOrderID,
    CustomerID,
    CAST(OrderDate AS DATE),
    SubTotal,
    TaxAmt,
    Freight,
    TotalDue
FROM Sales.SalesOrderHeader
ORDER BY OrderDate DESC,
         SalesOrderID DESC;
GO


/* C3) Insert order items */

INSERT INTO EntryTest.OrderItemMini
(
    SalesOrderID,
    SalesOrderDetailID,
    ProductID,
    OrderQty,
    UnitPrice,
    UnitPriceDiscount,
    LineTotal
)
SELECT
    sod.SalesOrderID,
    sod.SalesOrderDetailID,
    sod.ProductID,
    sod.OrderQty,
    sod.UnitPrice,
    sod.UnitPriceDiscount,
    sod.LineTotal
FROM Sales.SalesOrderDetail sod
INNER JOIN EntryTest.OrderMini om
    ON sod.SalesOrderID = om.SalesOrderID;
GO


/* =========================================================
   PART E — UNION / UNION ALL
========================================================= */

/* E1) UNION — Combined People Names */

SELECT NameValue
FROM
(
    SELECT TOP 10
        FirstName AS NameValue
    FROM Person.Person
    ORDER BY BusinessEntityID

    UNION

    SELECT TOP 10
        LastName AS NameValue
    FROM Person.Person
    ORDER BY BusinessEntityID
) AS CombinedNames
ORDER BY NameValue ASC;
GO


/* E2) UNION ALL — Two Product Lists */

SELECT
    'FinishedGoods' AS ListType,
    ProductID,
    Name
FROM
(
    SELECT TOP 10
        ProductID,
        Name
    FROM Production.Product
    WHERE FinishedGoodsFlag = 1
    ORDER BY ProductID ASC
) AS FinishedGoods

UNION ALL

SELECT
    'NotFinished' AS ListType,
    ProductID,
    Name
FROM
(
    SELECT TOP 10
        ProductID,
        Name
    FROM Production.Product
    WHERE FinishedGoodsFlag = 0
    ORDER BY ProductID ASC
) AS NotFinished;
GO


/* =========================================================
   PART F — JOIN Queries
========================================================= */

/* F1) INNER JOIN — Orders with Customer Info */

SELECT
    om.SalesOrderID,
    om.OrderDate,
    cm.CustomerID,
    cm.AccountNumber,
    om.TotalDue
FROM EntryTest.OrderMini om
INNER JOIN EntryTest.CustomerMini cm
    ON om.CustomerID = cm.CustomerID
ORDER BY om.OrderDate DESC;
GO


/* F2) LEFT JOIN — Customers with or without Orders */

SELECT
    cm.CustomerID,
    cm.AccountNumber,
    om.SalesOrderID,
    om.OrderDate
FROM EntryTest.CustomerMini cm
LEFT JOIN EntryTest.OrderMini om
    ON cm.CustomerID = om.CustomerID
ORDER BY cm.CustomerID ASC;
GO


/* F3) JOIN + GROUP BY — Order Totals per Customer */

SELECT
    cm.CustomerID,
    COUNT(om.SalesOrderID) AS OrderCount,
    SUM(om.TotalDue) AS TotalSpent
FROM EntryTest.CustomerMini cm
INNER JOIN EntryTest.OrderMini om
    ON cm.CustomerID = om.CustomerID
GROUP BY cm.CustomerID
ORDER BY cm.CustomerID ASC;
GO
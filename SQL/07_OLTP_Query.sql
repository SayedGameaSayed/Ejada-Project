USE [AdventureWorks-OLTP];
GO

SET STATISTICS TIME ON;

WITH OrderLines AS (
    SELECT
        soh.SalesOrderID,
        soh.OrderDate,
        addr.CountryRegion AS Country,
        pcatParent.Name AS Category,
        soh.TotalDue,
        soh.TaxAmt,
        soh.Freight,
        soh.BatchYear,
        soh.BatchMonth,
        soh.ShipDate,
        sod.UnitPriceDiscount,
        sod.OrderQty,
        sod.UnitPrice
    FROM SalesLT.SalesOrderHeader soh
    JOIN SalesLT.Customer c ON soh.CustomerID = c.CustomerID
    JOIN SalesLT.CustomerAddress ca ON ca.CustomerID = c.CustomerID
    JOIN SalesLT.Address addr ON addr.AddressID = ca.AddressID
    JOIN SalesLT.SalesOrderDetails sod ON sod.OrderID = soh.SalesOrderID
    JOIN SalesLT.Product p ON p.ProductID = sod.ProductID
    LEFT JOIN SalesLT.ProductCategory pcat ON pcat.ProductCategoryID = p.ProductCategoryID
    LEFT JOIN SalesLT.ProductCategory pcatParent ON pcat.ParentProductCategoryID = pcatParent.ProductCategoryID
    WHERE ca.AddressType = 'Main Office'
),
OrderAggregates AS (
    SELECT
        SalesOrderID,
        OrderDate,
        Country,
        Category,
        TotalDue,
        TaxAmt,
        Freight,
        BatchYear,
        BatchMonth,
        ShipDate,
        SUM(UnitPriceDiscount * OrderQty) AS TotalDiscount,
        SUM(UnitPrice * OrderQty) AS GrossAmount,
        SUM(OrderQty) AS TotalQty
    FROM OrderLines
    GROUP BY
        SalesOrderID, OrderDate, Country, Category,
        TotalDue, TaxAmt, Freight, BatchYear, BatchMonth, ShipDate
),
FinalAggregates AS (
    SELECT
        DATEPART(YEAR, OrderDate) AS Year,
        DATEPART(MONTH, OrderDate) AS Month,
        Country,
        Category,
        COUNT(*) AS OrderCount,
        SUM(TotalDue) AS TotalSales,
        SUM(GrossAmount) AS GrossSales,
        SUM(TotalDiscount) / NULLIF(SUM(TotalQty), 0) AS AvgDiscountPerUnit,
        AVG(DATEDIFF(DAY, EOMONTH(DATEFROMPARTS(BatchYear, BatchMonth, 1)), ShipDate)) AS AvgDaysToShip,
        SUM(TaxAmt) / NULLIF(SUM(TotalDue), 0) AS TaxRatio,
        SUM(Freight) / NULLIF(SUM(TotalDue), 0) AS FreightRatio
    FROM OrderAggregates
    GROUP BY DATEPART(YEAR, OrderDate), DATEPART(MONTH, OrderDate), Country, Category
)
SELECT * FROM FinalAggregates
ORDER BY Year, Month, Country, Category;

SET STATISTICS TIME OFF;

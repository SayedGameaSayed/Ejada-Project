USE [AdventureWorks-DW];
GO

SET STATISTICS TIME ON;

WITH OrderTaxFreight AS (
    SELECT
        SalesOrderID,
        MAX(Tax) AS TotalTax,
        MAX(Freight) AS TotalFreight
    FROM Sales.FactSales
    GROUP BY SalesOrderID
),
OrderDetails AS (
    SELECT
        fs.SalesOrderID,
        MAX(dd.FullDateAlternateKey) AS OrderDate,
        dc.Country,
        dp.Category,
        MAX(fs.TotalAmount) AS TotalAmount,
        SUM(fs.Discount * fs.Quantity) AS TotalDiscount,
        SUM(fs.UnitPrice * fs.Quantity) AS GrossAmount,
        SUM(fs.Quantity) AS TotalQty,
        AVG(DATEDIFF(DAY, EOMONTH(DATEFROMPARTS(fs.BatchYear, fs.BatchMonth, 1)), ds.FullDateAlternateKey)) AS AvgShipDays
    FROM Sales.FactSales fs
    JOIN Sales.DimCustomer dc ON fs.CustomerKey = dc.CustomerKey
    JOIN Sales.DimProduct dp ON fs.ProductKey = dp.ProductKey
    JOIN dbo.DimDate dd ON fs.OrderDateKey = dd.DateKey
    JOIN dbo.DimDate ds ON fs.ShipDateKey = ds.DateKey
    GROUP BY fs.SalesOrderID, dc.Country, dp.Category, fs.BatchYear, fs.BatchMonth
)
SELECT
    DATEPART(YEAR, OrderDate) AS Year,
    DATEPART(MONTH, OrderDate) AS Month,
    Country,
    Category,
    COUNT(*) AS OrderCount,
    SUM(TotalAmount) AS TotalSales,
    SUM(GrossAmount) AS GrossSales,
    SUM(TotalDiscount) / NULLIF(SUM(TotalQty), 0) AS AvgDiscountPerUnit,
    AVG(AvgShipDays) AS AvgDaysToShip,
    SUM(otf.TotalTax) / NULLIF(SUM(TotalAmount), 0) AS TaxRatio,
    SUM(otf.TotalFreight) / NULLIF(SUM(TotalAmount), 0) AS FreightRatio
FROM OrderDetails od
JOIN OrderTaxFreight otf ON od.SalesOrderID = otf.SalesOrderID
GROUP BY DATEPART(YEAR, OrderDate), DATEPART(MONTH, OrderDate), Country, Category
ORDER BY Year, Month, Country, Category;

SET STATISTICS TIME OFF;

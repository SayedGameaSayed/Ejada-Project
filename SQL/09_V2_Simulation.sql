USE [AdventureWorks-OLTP];
GO

-- ============================================================================
-- V2 Simulation  -  "OLTP Full (V1 + V2)"
-- Simulates a second data version arriving on the OLTP after Run I (V1):
--   * New orders dated 2023-01-01 .. 2026-12-15  (fact delta for Run II)
--   * New products (2023)                        (new DimProduct rows)
--   * Price/Cost increases on 680 / 706          (SCD2 new variants)
--   * SellEndDate set on 707 / 708               (overwrite across variants)
--   * New customers + Main Office addresses      (new DimCustomer rows)
--   * Changes on customers 29485/29486/29489     (SCD1 overwrite)
-- Every affected row carries ModifiedDate in 2023-2026 so an incremental run
-- with CurrentJobTime = 12-30-2026 picks it up.
-- ============================================================================
SET NOCOUNT ON;

-- ---------------------------------------------------------------------------
-- 1. New products  (identity: next IDs 1000 .. 1004)
-- ---------------------------------------------------------------------------
SET IDENTITY_INSERT SalesLT.Product ON;
INSERT INTO SalesLT.Product
  (ProductID, Name, ProductNumber, Color, StandardCost, ListPrice, Size, Weight,
   ProductCategoryID, ProductModelID, SellStartDate, SellEndDate, DiscontinuedDate,
   ThumbNailPhoto, ThumbnailPhotoFileName, rowguid, ModifiedDate)
VALUES
  (1000, N'Aero Road Frame 2023',      N'AR-2023-FRM', N'Blue',   310.00, 620.00, N'L',    5.60, 18,  6, '2023-01-01', NULL, NULL, NULL, NULL, NEWID(), '2023-01-05 00:00:00.000'),
  (1001, N'Trail Mountain Frame 2023', N'TM-2023-FRM', N'Green',  280.00, 560.00, N'M',    6.20, 16,  5, '2023-01-01', NULL, NULL, NULL, NULL, NEWID(), '2023-01-05 00:00:00.000'),
  (1002, N'Velocity Road Bike 2023',   N'VR-2023-BIK', N'Black',  900.00, 1800.00,N'58',  11.00, 6,  25, '2023-01-01', NULL, NULL, NULL, NULL, NEWID(), '2023-01-05 00:00:00.000'),
  (1003, N'Touring Expedition Bike 2023', N'TE-2023-BIK', N'Silver', 850.00, 1700.00, N'56', 12.50, 7, 35, '2023-01-01', NULL, NULL, NULL, NULL, NEWID(), '2023-01-05 00:00:00.000'),
  (1004, N'Aero Carbon Wheel 2023',    N'AC-2023-WHL', N'Carbon', 250.00, 500.00, N'700C', 1.40, 21, 42, '2023-01-01', NULL, NULL, NULL, NULL, NEWID(), '2023-01-05 00:00:00.000');
SET IDENTITY_INSERT SalesLT.Product OFF;
GO

-- ---------------------------------------------------------------------------
-- 2. Price / Cost increases  ->  SCD2 historical tracking of money attributes
-- ---------------------------------------------------------------------------
UPDATE SalesLT.Product
SET StandardCost = ROUND(StandardCost * 1.10, 4),
    ListPrice    = ROUND(ListPrice * 1.10, 4),
    ModifiedDate = '2023-03-01 00:00:00.000'
WHERE ProductID IN (680, 706);
GO

-- ---------------------------------------------------------------------------
-- 3. SellEndDate set  ->  overwritten across all product variants
-- ---------------------------------------------------------------------------
UPDATE SalesLT.Product
SET SellEndDate  = '2024-06-30 00:00:00.000',
    ModifiedDate = '2024-06-30 00:00:00.000'
WHERE ProductID IN (707, 708);
GO

-- ---------------------------------------------------------------------------
-- 4. New customers (identity 30119 .. 30123) + Main Office addresses
-- ---------------------------------------------------------------------------
SET IDENTITY_INSERT SalesLT.Customer ON;
INSERT INTO SalesLT.Customer
  (CustomerID, NameStyle, Title, FirstName, MiddleName, LastName, Suffix,
   CompanyName, SalesPerson, EmailAddress, Phone, PasswordHash, PasswordSalt,
   rowguid, ModifiedDate)
VALUES
  (30119, 0, N'Mr.', N'V2 Customer', NULL, N'Alpha',  NULL, N'Alpha Distribution 2023', NULL, N'alpha@v2.test',  N'1 (555) 610-0119', N'V2HASH', N'V2SALT', NEWID(), '2023-02-01 00:00:00.000'),
  (30120, 0, N'Mr.', N'V2 Customer', NULL, N'Bravo',  NULL, N'Bravo Imports 2023',      NULL, N'bravo@v2.test',  N'1 (555) 610-0120', N'V2HASH', N'V2SALT', NEWID(), '2023-02-01 00:00:00.000'),
  (30121, 0, N'Mr.', N'V2 Customer', NULL, N'Charlie',NULL, N'Charlie Retail 2023',     NULL, N'charlie@v2.test',N'1 (555) 610-0121', N'V2HASH', N'V2SALT', NEWID(), '2023-02-01 00:00:00.000'),
  (30122, 0, N'Mr.', N'V2 Customer', NULL, N'Delta',  NULL, N'Delta Supply Co 2023',    NULL, N'delta@v2.test',  N'1 (555) 610-0122', N'V2HASH', N'V2SALT', NEWID(), '2023-02-01 00:00:00.000'),
  (30123, 0, N'Mr.', N'V2 Customer', NULL, N'Echo',   NULL, N'Echo Logistics 2023',     NULL, N'echo@v2.test',   N'1 (555) 610-0123', N'V2HASH', N'V2SALT', NEWID(), '2023-02-01 00:00:00.000');
SET IDENTITY_INSERT SalesLT.Customer OFF;
GO

SET IDENTITY_INSERT SalesLT.Address ON;
INSERT INTO SalesLT.Address
  (AddressID, AddressLine1, AddressLine2, City, StateProvince, CountryRegion, PostalCode, rowguid, ModifiedDate)
VALUES
  (11383, N'2023 Innovation Drive', NULL, N'Austin',  N'Texas',        N'United States', N'73301', NEWID(), '2023-02-01 00:00:00.000'),
  (11384, N'2023 Innovation Drive', NULL, N'Denver',  N'Colorado',     N'United States', N'80201', NEWID(), '2023-02-01 00:00:00.000'),
  (11385, N'2023 Innovation Drive', NULL, N'Seattle', N'Washington',   N'United States', N'98101', NEWID(), '2023-02-01 00:00:00.000'),
  (11386, N'2023 Innovation Drive', NULL, N'Orlando', N'Florida',      N'United States', N'32801', NEWID(), '2023-02-01 00:00:00.000'),
  (11387, N'2023 Innovation Drive', NULL, N'Phoenix', N'Arizona',      N'United States', N'85001', NEWID(), '2023-02-01 00:00:00.000');
SET IDENTITY_INSERT SalesLT.Address OFF;
GO

INSERT INTO SalesLT.CustomerAddress (CustomerID, AddressID, AddressType, rowguid, ModifiedDate)
VALUES
  (30119, 11383, N'Main Office', NEWID(), '2023-02-01 00:00:00.000'),
  (30120, 11384, N'Main Office', NEWID(), '2023-02-01 00:00:00.000'),
  (30121, 11385, N'Main Office', NEWID(), '2023-02-01 00:00:00.000'),
  (30122, 11386, N'Main Office', NEWID(), '2023-02-01 00:00:00.000'),
  (30123, 11387, N'Main Office', NEWID(), '2023-02-01 00:00:00.000');
GO

-- ---------------------------------------------------------------------------
-- 5. Customer changes  ->  SCD1 overwrite (customer + Main Office address)
-- ---------------------------------------------------------------------------
UPDATE c
SET c.CompanyName   = c.CompanyName + N' - Renewed 2023',
    c.Phone         = N'1 (555) 600-' + RIGHT('0000' + CAST(c.CustomerID AS varchar(4)), 4),
    c.ModifiedDate  = '2023-04-10 00:00:00.000'
FROM SalesLT.Customer c
WHERE c.CustomerID IN (29485, 29486, 29489);
GO

UPDATE a
SET a.AddressLine1 = a.AddressLine1 + N' #2023',
    a.ModifiedDate = '2023-04-10 00:00:00.000'
FROM SalesLT.Address a
WHERE a.AddressID IN (1086, 621, 1069);
GO

UPDATE ca
SET ca.ModifiedDate = '2023-04-10 00:00:00.000'
FROM SalesLT.CustomerAddress ca
WHERE ca.CustomerID IN (29485, 29486, 29489) AND ca.AddressType = N'Main Office';
GO

-- ---------------------------------------------------------------------------
-- 6. New orders (5,000 headers / ~76,9k detail lines) dated 2023-01-01 ..
--    2026-12-15. Each order uses products from a single product category so
--    the OLTP/OLAP aggregate comparison stays exact.
-- ---------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Cat') IS NOT NULL DROP TABLE #Cat;
IF OBJECT_ID('tempdb..#CatProd') IS NOT NULL DROP TABLE #CatProd;

CREATE TABLE #Cat (Ord int, CatID int, CatCnt int);
INSERT INTO #Cat (Ord, CatID, CatCnt)
VALUES (1, 6, 43), (2, 18, 33), (3, 5, 32), (4, 16, 28), (5, 7, 22), (6, 20, 18), (7, 21, 14), (8, 41, 11);

CREATE TABLE #CatProd (CatID int, rn int, ProductID int, ListPrice decimal(19,4));
INSERT INTO #CatProd (CatID, rn, ProductID, ListPrice)
SELECT p.ProductCategoryID,
       ROW_NUMBER() OVER (PARTITION BY p.ProductCategoryID ORDER BY p.ProductID),
       p.ProductID, p.ListPrice
FROM SalesLT.Product p
WHERE p.SellEndDate IS NULL AND p.ProductCategoryID IN (SELECT CatID FROM #Cat);

DECLARE @StartOrderID int = (SELECT MAX(SalesOrderID) FROM SalesLT.SalesOrderHeader);  -- 88952
DECLARE @StartDetailID int = (SELECT MAX(SalesOrderDetailID) FROM SalesLT.SalesOrderDetails); -- 391443

;WITH
Nums AS (SELECT TOP (5000) n = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM sys.all_objects a CROSS JOIN sys.all_objects b),
Lines AS (SELECT TOP (16) j = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM sys.all_objects),
CustPool AS (
  SELECT c.CustomerID, rn = ROW_NUMBER() OVER (ORDER BY c.CustomerID)
  FROM SalesLT.Customer c
  WHERE EXISTS (SELECT 1 FROM SalesLT.CustomerAddress ca
                JOIN SalesLT.Address a ON ca.AddressID = a.AddressID
                WHERE ca.CustomerID = c.CustomerID AND ca.AddressType = N'Main Office')
),
OrderBase AS (
  SELECT n.n AS OrderN,
         k.CatID,
         k.CatCnt,
         DATEADD(DAY, (n.n - 1) % 1450, '2023-01-01') AS OrderDate,
         cp.CustomerID,
         DATEADD(DAY, 5 + ((n.n * 3) % 28), DATEADD(DAY, (n.n - 1) % 1450, '2023-01-01')) AS ShipDate
  FROM Nums n
  JOIN #Cat k ON k.Ord = ((n.n - 1) % 8) + 1
  JOIN CustPool cp ON cp.rn = ((n.n - 1) % 407) + 1
),
RowsGen AS (
  SELECT ob.OrderN, ob.OrderDate, ob.CustomerID, ob.ShipDate, ob.CatID, ob.CatCnt,
         l.j,
         pr.ProductID,
         pr.ListPrice AS UnitPrice,
         qty = 1 + ((ob.OrderN + l.j) % 20),
         disc = CASE WHEN l.j % 11 = 0 THEN 0.20 WHEN l.j % 6 = 0 THEN 0.10 ELSE 0.0 END
  FROM OrderBase ob
  CROSS JOIN Lines l
  JOIN #CatProd pr ON pr.CatID = ob.CatID AND pr.rn = ((ob.OrderN - 1 + l.j - 1) % ob.CatCnt) + 1
  WHERE l.j <= (CASE WHEN ob.CatCnt >= 16 THEN 16 ELSE ob.CatCnt END)
),
RowsMT AS (
  SELECT *, LineTotal = ROUND(UnitPrice * (1 - disc) * qty, 4) FROM RowsGen
),
OrderAgg AS (
  SELECT OrderN, SubTotal = ROUND(SUM(LineTotal), 4) FROM RowsMT GROUP BY OrderN
),
Final AS (
  SELECT m.OrderN, m.OrderDate, m.CustomerID, m.ShipDate, m.j, m.ProductID, m.UnitPrice, m.qty, m.disc, m.LineTotal,
         a.SubTotal,
         TaxAmt  = ROUND(a.SubTotal * (0.075 + ((m.OrderN % 15) * 0.001)), 4),
         Freight = ROUND(2.0 + (m.OrderN % 40) + ((m.OrderN * 3) % 100) / 100.0, 4)
  FROM RowsMT m
  JOIN OrderAgg a ON a.OrderN = m.OrderN
)
INSERT INTO SalesLT.SalesOrderHeader
  (SalesOrderID, SalesOrderNumber, rowguid, CustomerID, AccountNumber, PurchaseOrderNumber,
   OrderDate, ShipDate, BatchYear, BatchMonth, ModifiedDate, Status, RevisionNumber,
   OnlineOrderFlag, Comment, SubTotal, TaxAmt, Freight, TotalDue,
   BillToAddressID, ShipToAddressID, ShipMethodID, CreditCardID, CurrencyRateID,
   SalesPersonID, TerritoryID)
SELECT
   @StartOrderID + f.OrderN,
   N'SO' + CAST(@StartOrderID + f.OrderN AS varchar(12)),
   NEWID(),
   f.CustomerID,
   NULL, NULL,
   f.OrderDate, f.ShipDate, YEAR(f.OrderDate), MONTH(f.OrderDate), f.OrderDate,
   4, 0, 1, NULL,
   f.SubTotal, f.TaxAmt, f.Freight, ROUND(f.SubTotal + f.TaxAmt + f.Freight, 4),
   NULL, NULL, (f.OrderN % 6) + 1, NULL, NULL, NULL, (f.OrderN % 10) + 1
FROM (SELECT DISTINCT OrderN, OrderDate, CustomerID, ShipDate, SubTotal, TaxAmt, Freight FROM Final) f;

;WITH
Nums AS (SELECT TOP (5000) n = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM sys.all_objects a CROSS JOIN sys.all_objects b),
Lines AS (SELECT TOP (16) j = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM sys.all_objects),
CustPool AS (
  SELECT c.CustomerID, rn = ROW_NUMBER() OVER (ORDER BY c.CustomerID)
  FROM SalesLT.Customer c
  WHERE EXISTS (SELECT 1 FROM SalesLT.CustomerAddress ca
                JOIN SalesLT.Address a ON ca.AddressID = a.AddressID
                WHERE ca.CustomerID = c.CustomerID AND ca.AddressType = N'Main Office')
),
OrderBase AS (
  SELECT n.n AS OrderN,
         k.CatID, k.CatCnt,
         DATEADD(DAY, (n.n - 1) % 1450, '2023-01-01') AS OrderDate,
         cp.CustomerID,
         DATEADD(DAY, 5 + ((n.n * 3) % 28), DATEADD(DAY, (n.n - 1) % 1450, '2023-01-01')) AS ShipDate
  FROM Nums n
  JOIN #Cat k ON k.Ord = ((n.n - 1) % 8) + 1
  JOIN CustPool cp ON cp.rn = ((n.n - 1) % 407) + 1
),
RowsGen AS (
  SELECT ob.OrderN, ob.OrderDate, ob.CatID, ob.CatCnt,
         l.j,
         pr.ProductID,
         pr.ListPrice AS UnitPrice,
         qty = 1 + ((ob.OrderN + l.j) % 20),
         disc = CASE WHEN l.j % 11 = 0 THEN 0.20 WHEN l.j % 6 = 0 THEN 0.10 ELSE 0.0 END
  FROM OrderBase ob
  CROSS JOIN Lines l
  JOIN #CatProd pr ON pr.CatID = ob.CatID AND pr.rn = ((ob.OrderN - 1 + l.j - 1) % ob.CatCnt) + 1
  WHERE l.j <= (CASE WHEN ob.CatCnt >= 16 THEN 16 ELSE ob.CatCnt END)
)
INSERT INTO SalesLT.SalesOrderDetails
  (SalesOrderDetailID, OrderID, ProductID, OrderQty, UnitPrice, UnitPriceDiscount, LineTotal, ModifiedDate)
SELECT
   @StartDetailID + ROW_NUMBER() OVER (ORDER BY rg.OrderN, rg.j),
   @StartOrderID + rg.OrderN,
   rg.ProductID,
   rg.qty,
   rg.UnitPrice,
   rg.disc,
   ROUND(rg.UnitPrice * (1 - rg.disc) * rg.qty, 4),
   rg.OrderDate
FROM RowsGen rg;

DROP TABLE #Cat;
DROP TABLE #CatProd;
GO

-- ---------------------------------------------------------------------------
-- Summary of simulated V2 data
-- ---------------------------------------------------------------------------
SELECT 'OrdersV2' AS Metric, COUNT(*) AS V1, 0 AS V2 FROM SalesLT.SalesOrderHeader WHERE SalesOrderID <= 88952
UNION ALL
SELECT 'OrdersV2', 0, COUNT(*) FROM SalesLT.SalesOrderHeader WHERE SalesOrderID > 88952
UNION ALL
SELECT 'DetailsV2', 0, COUNT(*) FROM SalesLT.SalesOrderDetails WHERE SalesOrderDetailID > 391443
UNION ALL
SELECT 'ProductsNew', 0, COUNT(*) FROM SalesLT.Product WHERE ProductID >= 1000
UNION ALL
SELECT 'CustomersNew', 0, COUNT(*) FROM SalesLT.Customer WHERE CustomerID >= 30119;
GO

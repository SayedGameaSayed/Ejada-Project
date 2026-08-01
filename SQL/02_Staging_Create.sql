USE [master];
GO

DROP DATABASE IF EXISTS [AdventureWorks-Staging];
GO

CREATE DATABASE [AdventureWorks-Staging];
GO

USE [AdventureWorks-Staging];
GO

CREATE TABLE [dbo].[Address](
    [AddressID] [int] NULL,
    [Address] [nvarchar](60) NULL,
    [City] [nvarchar](30) NULL,
    [State] [nvarchar](50) NULL,
    [Region] [nvarchar](50) NULL,
    [Country] [nvarchar](50) NULL
) ON [PRIMARY];
GO

CREATE TABLE [dbo].[Customer](
    [CustomerID] [int] NULL,
    [Title] [nvarchar](8) NULL,
    [FirstName] [nvarchar](50) NULL,
    [MiddleName] [nvarchar](50) NULL,
    [LastName] [nvarchar](50) NULL,
    [Suffix] [nvarchar](10) NULL,
    [CompanyName] [nvarchar](128) NULL,
    [EmailAddress] [nvarchar](50) NULL,
    [Phone] [nvarchar](25) NULL,
    [ModifiedDate] [datetime] NULL
) ON [PRIMARY];
GO

CREATE TABLE [dbo].[Customer_Address](
    [CustomerID] [int] NULL,
    [AddressID] [int] NULL,
    [AddressType] [nvarchar](50) NULL
) ON [PRIMARY];
GO

CREATE TABLE [dbo].[Product](
    [ProductID] [int] NULL,
    [Name] [nvarchar](50) NULL,
    [ProductNumber] [nvarchar](25) NULL,
    [Color] [nvarchar](15) NULL,
    [StandardCost] [numeric](19, 4) NULL,
    [ListPrice] [numeric](19, 4) NULL,
    [Size] [nvarchar](5) NULL,
    [Weight] [numeric](8, 2) NULL,
    [ProductCategoryID] [int] NULL,
    [ProductModelID] [int] NULL,
    [SellStartDate] [datetime] NULL,
    [SellEndDate] [datetime] NULL,
    [ModifiedDate] [datetime] NULL
) ON [PRIMARY];
GO

CREATE TABLE [dbo].[ProductCategory](
    [ProductCategoryID] [int] NULL,
    [ParentProductCategoryID] [int] NULL,
    [Name] [nvarchar](50) NULL
) ON [PRIMARY];
GO

CREATE TABLE [dbo].[ProductDescription](
    [ProductDescriptionID] [int] NULL,
    [Description] [nvarchar](400) NULL
) ON [PRIMARY];
GO

CREATE TABLE [dbo].[ProductModel](
    [ProductModelID] [int] NULL,
    [Name] [nvarchar](50) NULL
) ON [PRIMARY];
GO

CREATE TABLE [dbo].[ProductModel_Description](
    [ProductModelID] [int] NULL,
    [ProductDescriptionID] [int] NULL,
    [Culture] [nvarchar](6) NULL
) ON [PRIMARY];
GO

CREATE TABLE [dbo].[SalesOrderDetails](
    [SalesOrderDetailID] [int] NULL,
    [OrderID] [int] NULL,
    [ProductID] [int] NULL,
    [OrderQty] [numeric](19, 4) NULL,
    [UnitPrice] [numeric](19, 4) NULL,
    [UnitPriceDiscount] [numeric](19, 4) NULL,
    [LineTotal] [numeric](19, 4) NULL,
    [ModifiedDate] [datetime] NULL
) ON [PRIMARY];
GO

CREATE TABLE [dbo].[SalesOrderHeader](
    [SalesOrderID] [int] NULL,
    [CustomerID] [int] NULL,
    [OrderDate] [datetime] NULL,
    [ShipDate] [datetime] NULL,
    [BatchYear] [int] NULL,
    [BatchMonth] [int] NULL,
    [SubTotal] [numeric](19, 4) NULL,
    [TaxAmt] [numeric](19, 4) NULL,
    [Freight] [numeric](19, 4) NULL,
    [TotalDue] [numeric](19, 4) NULL,
    [ModifiedDate] [datetime] NULL
) ON [PRIMARY];
GO

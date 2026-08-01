USE [master];
GO

DROP DATABASE IF EXISTS [AdventureWorks-DW];
GO

CREATE DATABASE [AdventureWorks-DW];
GO

USE [AdventureWorks-DW];
GO

CREATE SCHEMA [Sales];
GO

CREATE TABLE [dbo].[Watermark](
    [LastSuccessfulRun] [datetime] NULL
) ON [PRIMARY];
GO

INSERT INTO [dbo].[Watermark] (LastSuccessfulRun)
VALUES ('1900-01-01 00:00:00.000');
GO

CREATE TABLE [Sales].[DimCustomer](
    [CustomerKey] [int] PRIMARY KEY IDENTITY(1,1) NOT NULL,
    [CustomerAltKey] [int] NOT NULL,
    [CompanyName] [nvarchar](128) NULL,
    [Name] [nvarchar](50) NULL,
    [Title] [nvarchar](8) NULL,
    [Phone] [nvarchar](25) NULL,
    [Email] [nvarchar](50) NULL,
    [OfficeAddress] [nvarchar](60) NULL,
    [City] [nvarchar](50) NULL,
    [State] [nvarchar](50) NULL,
    [Country] [nvarchar](50) NULL
);
GO

CREATE TABLE [Sales].[DimProduct](
    [ProductKey] [int] IDENTITY(1,1) NOT NULL,
    [ProductAltKey] [int] NOT NULL,
    [ProductNumber] [nvarchar](400) NULL,
    [ProductName] [nvarchar](400) NULL,
    [ProductModel] [nvarchar](400) NULL,
    [Category] [nvarchar](400) NULL,
    [SubCategory] [nvarchar](400) NULL,
    [Description] [nvarchar](400) NULL,
    [SellStartDate] [datetime] NOT NULL,
    [SellEndDate] [datetime] NULL,
    [Size] [nvarchar](400) NULL,
    [Color] [nvarchar](400) NULL,
    [Weight] [decimal](18, 4) NULL,
    [Cost] [decimal](19, 4) NULL,
    [Price] [decimal](19, 4) NULL,
    [EffectiveStartDate] [datetime2](7) NOT NULL,
    [EffectiveEndDate] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED ([ProductKey] ASC)
) ON [PRIMARY];
GO

ALTER TABLE [Sales].[DimProduct] ADD DEFAULT ('1900-01-01 00:00:00.000') FOR [EffectiveStartDate];
GO

CREATE TABLE [dbo].[DimDate](
    [DateKey] [int] PRIMARY KEY NOT NULL,
    [FullDateAlternateKey] [date] NOT NULL,
    [DayNumberOfWeek] [tinyint] NOT NULL,
    [DayNameOfWeek] [nvarchar](10) NOT NULL,
    [DayNumberOfMonth] [tinyint] NOT NULL,
    [DayNumberOfYear] [smallint] NOT NULL,
    [WeekNumberOfYear] [tinyint] NOT NULL,
    [MonthName] [nvarchar](10) NOT NULL,
    [MonthNumberOfYear] [tinyint] NOT NULL,
    [CalendarQuarter] [tinyint] NOT NULL,
    [CalendarYear] [smallint] NOT NULL,
    [CalendarSemester] [tinyint] NOT NULL
);
GO

CREATE TABLE [Sales].[FactSales](
    [SalesOrderID] [int] NOT NULL,
    [SalesOrderDetailID] [int] NOT NULL,
    [BatchMonth] [int] NULL,
    [BatchYear] [int] NULL,
    [OrderDateKey] [int] NULL,
    [ShipDateKey] [int] NULL,
    [SubTotal] [decimal](19, 4) NULL,
    [Freight] [decimal](19, 4) NULL,
    [Tax] [decimal](19, 4) NULL,
    [TotalAmount] [decimal](19, 4) NULL,
    [CustomerKey] [int] NOT NULL,
    [ProductKey] [int] NOT NULL,
    [UnitPrice] [money] NULL,
    [Quantity] [int] NULL,
    [Discount] [money] NULL,
    [LineTotal] [money] NULL,
CONSTRAINT [PK_FactSales] PRIMARY KEY NONCLUSTERED ([SalesOrderID], [SalesOrderDetailID])
) ON [PRIMARY];
GO

CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactSales ON [Sales].[FactSales];
GO

ALTER TABLE [Sales].[FactSales] WITH NOCHECK ADD CONSTRAINT [FK_FactSales_DimCustomer] FOREIGN KEY([CustomerKey])
REFERENCES [Sales].[DimCustomer] ([CustomerKey]);
GO

ALTER TABLE [Sales].[FactSales] CHECK CONSTRAINT [FK_FactSales_DimCustomer];
GO

ALTER TABLE [Sales].[FactSales] WITH NOCHECK ADD CONSTRAINT [FK_FactSales_DimDateOrder] FOREIGN KEY([OrderDateKey])
REFERENCES [dbo].[DimDate] ([DateKey]);
GO

ALTER TABLE [Sales].[FactSales] CHECK CONSTRAINT [FK_FactSales_DimDateOrder];
GO

ALTER TABLE [Sales].[FactSales] WITH NOCHECK ADD CONSTRAINT [FK_FactSales_DimDateShip] FOREIGN KEY([ShipDateKey])
REFERENCES [dbo].[DimDate] ([DateKey]);
GO

ALTER TABLE [Sales].[FactSales] CHECK CONSTRAINT [FK_FactSales_DimDateShip];
GO

ALTER TABLE [Sales].[FactSales] WITH NOCHECK ADD CONSTRAINT [FK_FactSales_DimProduct] FOREIGN KEY([ProductKey])
REFERENCES [Sales].[DimProduct] ([ProductKey]);
GO

ALTER TABLE [Sales].[FactSales] CHECK CONSTRAINT [FK_FactSales_DimProduct];
GO

WITH Dates AS (
    SELECT CAST('2000-01-01' AS DATE) AS DateValue
    UNION ALL
    SELECT DATEADD(DAY, 1, DateValue)
    FROM Dates
    WHERE DateValue < '2030-12-31'
)
INSERT INTO [dbo].[DimDate] (
    [DateKey], [FullDateAlternateKey], [DayNumberOfWeek], [DayNameOfWeek],
    [DayNumberOfMonth], [DayNumberOfYear], [WeekNumberOfYear], [MonthName],
    [MonthNumberOfYear], [CalendarQuarter], [CalendarYear], [CalendarSemester]
)
SELECT
    CONVERT(INT, FORMAT(DateValue, 'yyyyMMdd')) AS DateKey,
    DateValue AS FullDateAlternateKey,
    DATEPART(WEEKDAY, DateValue) AS DayNumberOfWeek,
    DATENAME(WEEKDAY, DateValue) AS DayNameOfWeek,
    DAY(DateValue) AS DayNumberOfMonth,
    DATEPART(DAYOFYEAR, DateValue) AS DayNumberOfYear,
    DATEPART(WEEK, DateValue) AS WeekNumberOfYear,
    DATENAME(MONTH, DateValue) AS MonthName,
    MONTH(DateValue) AS MonthNumberOfYear,
    DATEPART(QUARTER, DateValue) AS CalendarQuarter,
    YEAR(DateValue) AS CalendarYear,
    CASE WHEN MONTH(DateValue) <= 6 THEN 1 ELSE 2 END AS CalendarSemester
FROM Dates
OPTION (MAXRECURSION 0);
GO

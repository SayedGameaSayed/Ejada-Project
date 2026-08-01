USE [AdventureWorks-DW];
GO

CREATE TABLE [Sales].[FactSales_BadRows](
    [SalesOrderID] [int] NULL,
    [SalesOrderDetailID] [int] NULL,
    [CustomerID] [int] NULL,
    [ProductID] [int] NULL,
    [OrderDate] [datetime] NULL,
    [ShipDate] [datetime] NULL,
    [ErrorDescription] [nvarchar](400) NULL,
    [ErrorTimestamp] [datetime] NOT NULL DEFAULT GETDATE()
) ON [PRIMARY];
GO

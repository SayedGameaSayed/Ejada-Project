USE [AdventureWorks-DW];
GO

ALTER TABLE [Sales].[FactSales] NOCHECK CONSTRAINT ALL;
GO

TRUNCATE TABLE [Sales].[FactSales];
DELETE FROM [Sales].[DimProduct];
DELETE FROM [Sales].[DimCustomer];
TRUNCATE TABLE [dbo].[Watermark];
GO

DELETE FROM [dbo].[DimDate];
GO

INSERT INTO [dbo].[Watermark] (LastSuccessfulRun)
VALUES ('1900-01-01 00:00:00.000');
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

ALTER TABLE [Sales].[FactSales] CHECK CONSTRAINT ALL;
GO

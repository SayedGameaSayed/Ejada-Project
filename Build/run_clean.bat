@echo off
"C:\Program Files\Microsoft SQL Server\170\DTS\Binn\DTExec.exe" /FILE "E:\Ejada Project\Claude_Auto_Project\AdventureWorks_OLAP\Load DW Pipeline.dtsx" /REPORTING V
echo VERBOSE_EXIT=%ERRORLEVEL%

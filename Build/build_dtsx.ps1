param([string]$InitialLoad = "True")
$ErrorActionPreference = "Stop"
$initLoadVal = if ($InitialLoad -eq "False") { "False" } else { "True" }
$out = "E:\Ejada Project\Claude_Auto_Project\AdventureWorks_OLAP\DailyETL.dtsx"

function EscText($s) { ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;') }
function EscAttr($s) { ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;') }
function EscSql($s) { $e = ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'); return ($e -replace "`r`n",'&#xA;' -replace "`r",'&#xA;' -replace "`n",'&#xA;') }
function GUID($name) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $h = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($name))
    return ("{" + [guid]::new($h).ToString().ToUpper() + "}")
}

# ---- type metadata helper: returns (dataType, typeExtra) ----
function ColAttrs($t) {
    switch ($t) {
        "i4"        { return @{ dt = "i4";         extra = "" } }
        "wstr"      { return @{} } # handled separately with length
        "dbTimeStamp"{ return @{ dt = "dbTimeStamp"; extra = "" } }
        "dbTimeStamp2"{ return @{ dt = "dbTimeStamp2"; extra = 'scale="7"' } }
        "money"     { return @{ dt = "cy";         extra = 'scale="4"' } }
        "i8"        { return @{ dt = "i8";         extra = "" } }
        "numeric"   { return @{} } # handled separately with precision/scale
    }
}

# Column spec helper: returns hash with dt and extra based on spec tuple
# spec: [name, type, (len | (precision,scale))...]
function MakeCol($spec) {
    $name = $spec[0]; $t = $spec[1]
    if ($t -eq "wstr") { return @{ name=$name; dt="wstr"; extra=('length="' + $spec[2] + '"') } }
    if ($t -eq "numeric") { return @{ name=$name; dt="numeric"; extra=('precision="' + $spec[2] + '" scale="' + $spec[3] + '"') } }
    return @{ name=$name; dt=$t; extra="" }
}

# cached attrs for inputColumn
function Cached($c) {
    if ($c.dt -eq "wstr") { return 'cachedLength="' + $c.extra.Substring(8).TrimEnd('"') + '" ' }
    if ($c.dt -eq "numeric") { $m = [regex]::Match($c.extra, 'precision="(\d+)" scale="(\d+)"'); return 'cachedPrecision="' + $m.Groups[1].Value + '" cachedScale="' + $m.Groups[2].Value + '" ' }
    if ($c.dt -eq "dbTimeStamp2") { return 'cachedScale="7" ' }
    return ""
}

$sb = New-Object System.Text.StringBuilder
function Add($s) { [void]$sb.Append($s) }

# =====================================================================
# PACKAGE ROOT
# =====================================================================
Add ('<?xml version="1.0"?>' + "`r`n")
Add ('<DTS:Executable xmlns:DTS="www.microsoft.com/SqlServer/Dts"' + "`r`n")
Add ('  DTS:refId="Package"' + "`r`n")
Add ('  DTS:CreationDate="7/31/2026 12:00:00 AM"' + "`r`n")
Add ('  DTS:CreationName="Microsoft.Package"' + "`r`n")
Add ('  DTS:CreatorComputerName="ETL-DEV"' + "`r`n")
Add ('  DTS:CreatorName="Claude_Auto_Project"' + "`r`n")
Add ('  DTS:DTSID="' + (GUID 'Package') + '"' + "`r`n")
Add ('  DTS:ExecutableType="Microsoft.Package"' + "`r`n")
Add ('  DTS:LastModifiedProductVersion="13.0.4001.0"' + "`r`n")
Add ('  DTS:LocaleID="1033"' + "`r`n")
Add ('  DTS:ObjectName="DailyETL"' + "`r`n")
Add ('  DTS:PackageType="5"' + "`r`n")
Add ('  DTS:ProtectionLevel="0"' + "`r`n")
Add ('  DTS:VersionBuild="1"' + "`r`n")
Add ('  DTS:VersionGUID="' + (GUID 'PackageVersionGUID') + '">' + "`r`n")
Add ('  <DTS:Property DTS:Name="PackageFormatVersion">8</DTS:Property>' + "`r`n")

# ---------------- Package Parameters ----------------
Add ('  <DTS:PackageParameters>' + "`r`n")
Add ('    <DTS:PackageParameter DTS:CreationName="" DTS:DataType="11" DTS:DTSID="' + (GUID 'Param-InitialLoad') + '" DTS:ObjectName="InitialLoad">' + "`r`n")
Add ('      <DTS:Property DTS:DataType="11" DTS:Name="ParameterValue">' + $initLoadVal + '</DTS:Property>' + "`r`n")
Add ('    </DTS:PackageParameter>' + "`r`n")
Add ('    <DTS:PackageParameter DTS:CreationName="" DTS:DataType="8" DTS:DTSID="' + (GUID 'Param-Language') + '" DTS:ObjectName="Language">' + "`r`n")
Add ('      <DTS:Property DTS:DataType="8" DTS:Name="ParameterValue">en</DTS:Property>' + "`r`n")
Add ('    </DTS:PackageParameter>' + "`r`n")
Add ('  </DTS:PackageParameters>' + "`r`n")

# ---------------- Connection Managers ----------------
Add ('  <DTS:ConnectionManagers>' + "`r`n")
$cms = @(
    @{ Name="OLTP";    Db="AdventureWorks-OLTP" },
    @{ Name="Staging"; Db="AdventureWorks-Staging" },
    @{ Name="DW";      Db="AdventureWorks-DW" }
)
foreach ($cm in $cms) {
    $cmId = GUID ("CM-" + $cm.Name)
Add ('    <DTS:ConnectionManager' + "`r`n")
Add ('      DTS:refId="Package.ConnectionManagers[' + $cm.Name + ']"' + "`r`n")
Add ('      DTS:CreationName="OLEDB"' + "`r`n")
Add ('      DTS:DTSID="' + $cmId + '"' + "`r`n")
Add ('      DTS:ObjectName="' + $cm.Name + '">' + "`r`n")
Add ('      <DTS:ObjectData>' + "`r`n")
Add ('        <DTS:ConnectionManager' + "`r`n")
Add ('          DTS:ConnectRetryCount="1"' + "`r`n")
Add ('          DTS:ConnectRetryInterval="5"' + "`r`n")
Add ('          DTS:ConnectionString="Data Source=localhost;Initial Catalog=' + $cm.Db + ';Provider=MSOLEDBSQL;Integrated Security=SSPI;Application Name=SSIS-Package-' + $cmId + $cm.Name + ';Auto Translate=False;" />' + "`r`n")
Add ('      </DTS:ObjectData>' + "`r`n")
Add ('    </DTS:ConnectionManager>' + "`r`n")
}
Add ('  </DTS:ConnectionManagers>' + "`r`n")

# ---------------- Variables ----------------
Add ('  <DTS:Variables>' + "`r`n")
$vars = @(
    @{ Name="CurrentJobTime"; DT="7"; Val="7/31/2026 12:00:00 AM" },
    @{ Name="LastJobTime";    DT="7"; Val="1900-01-01 00:00:00" },
    @{ Name="InitialLoad";    DT="11"; Val=$initLoadVal },
    @{ Name="Language";       DT="8"; Val="en" }
)
foreach ($v in $vars) {
Add ('    <DTS:Variable DTS:CreationName="" DTS:DTSID="' + (GUID ("Var-" + $v.Name)) + '" DTS:IncludeInDebugDump="6789" DTS:Namespace="User" DTS:ObjectName="' + $v.Name + '">' + "`r`n")
Add ('      <DTS:VariableValue DTS:DataType="' + $v.DT + '">' + $v.Val + '</DTS:VariableValue>' + "`r`n")
Add ('    </DTS:Variable>' + "`r`n")
}
Add ('  </DTS:Variables>' + "`r`n")

# variable GUID lookup for ParameterMapping
function VarId($n) { return (GUID ("Var-" + $n)).Trim('{}') }
$pmLast = '"@LastJobTime:Input",{' + (VarId 'LastJobTime') + '};'
$pmLang = '"@Language:Input",{' + (VarId 'Language') + '};'

# =====================================================================
# EXECUTABLE WRAPPERS
# =====================================================================
function OpenSeq($ref, $name, $dtsid) {
Add ('    <DTS:Executable' + "`r`n")
Add ('      DTS:refId="' + $ref + '"' + "`r`n")
Add ('      DTS:CreationName="STOCK:SEQUENCE"' + "`r`n")
Add ('      DTS:Description="Sequence Container"' + "`r`n")
Add ('      DTS:DTSID="' + $dtsid + '"' + "`r`n")
Add ('      DTS:ExecutableType="STOCK:SEQUENCE"' + "`r`n")
Add ('      DTS:LocaleID="-1"' + "`r`n")
Add ('      DTS:ObjectName="' + $name + '">' + "`r`n")
Add ('      <DTS:Variables />' + "`r`n")
Add ('      <DTS:Executables>' + "`r`n")
}
function CloseSeq {
Add ('      </DTS:Executables>' + "`r`n")
Add ('      <DTS:PrecedenceConstraints>' + "`r`n")
}
function EndSeq {
Add ('      </DTS:PrecedenceConstraints>' + "`r`n")
Add ('    </DTS:Executable>' + "`r`n")
}

function OpenTask($ref, $name, $dtsid, $type, $desc, $contact) {
Add ('        <DTS:Executable' + "`r`n")
Add ('          DTS:refId="' + $ref + '"' + "`r`n")
Add ('          DTS:CreationName="' + $type + '"' + "`r`n")
Add ('          DTS:Description="' + $desc + '"' + "`r`n")
Add ('          DTS:DTSID="' + $dtsid + '"' + "`r`n")
Add ('          DTS:ExecutableType="' + $type + '"' + "`r`n")
Add ('          DTS:LocaleID="-1"' + "`r`n")
Add ('          DTS:ObjectName="' + $name + '"' + "`r`n")
    if ($contact) { Add ('          DTS:TaskContact="' + $contact + '"' + "`r`n") }
Add ('          DTS:ThreadHint="0">' + "`r`n")
Add ('          <DTS:Variables />' + "`r`n")
Add ('          <DTS:ObjectData>' + "`r`n")
}
function CloseTask {
Add ('          </DTS:ObjectData>' + "`r`n")
Add ('        </DTS:Executable>' + "`r`n")
}

function SeqConstraint($seqRef, $from, $to, $dtsid, $objName) {
Add ('        <DTS:PrecedenceConstraint' + "`r`n")
Add ('          DTS:refId="' + $seqRef + '.PrecedenceConstraints[' + $objName + ']"' + "`r`n")
Add ('          DTS:CreationName=""' + "`r`n")
Add ('          DTS:DTSID="' + $dtsid + '"' + "`r`n")
Add ('          DTS:From="' + $from + '"' + "`r`n")
Add ('          DTS:LogicalAnd="True"' + "`r`n")
Add ('          DTS:ObjectName="' + $objName + '"' + "`r`n")
Add ('          DTS:To="' + $to + '" />' + "`r`n")
}

# =====================================================================
# DATA FLOW BUILDERS
# =====================================================================
$OLTPre = 'Package.ConnectionManagers[OLTP]'
$StaPre = 'Package.ConnectionManagers[Staging]'
$DWPRe  = 'Package.ConnectionManagers[DW]'

function OLEDBSource($ref, $name, $cmRef, $sql, $paramMap, $cols) {
    # $cols: array of MakeCol results
    $outRef = $ref + '.Outputs[OLE DB Source Output]'
    $errRef = $ref + '.Outputs[OLE DB Source Error Output]'
Add ('          <component refId="' + $ref + '" componentClassID="Microsoft.OLEDBSource" contactInfo="OLE DB Source;Microsoft Corporation; Microsoft SQL Server; (C) Microsoft Corporation; All Rights Reserved; http://www.microsoft.com/sql/support;7" description="OLE DB Source" name="' + $name + '" usesDispositions="true" version="7">' + "`r`n")
Add ('            <properties>' + "`r`n")
Add ('              <property dataType="System.Int32" description="The number of seconds before a command times out.  A value of 0 indicates an infinite time-out." name="CommandTimeout">0</property>' + "`r`n")
Add ('              <property dataType="System.String" description="Specifies the name of the database object used to open a rowset." name="OpenRowset"></property>' + "`r`n")
Add ('              <property dataType="System.String" description="Specifies the variable that contains the name of the database object used to open a rowset." name="OpenRowsetVariable"></property>' + "`r`n")
Add ('              <property dataType="System.String" description="The SQL command to be executed." name="SqlCommand" UITypeEditor="Microsoft.DataTransformationServices.Controls.ModalMultilineStringEditor">' + (EscText $sql) + '</property>' + "`r`n")
Add ('              <property dataType="System.String" description="The variable that contains the SQL command to be executed." name="SqlCommandVariable"></property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the column code page to use when code page information is unavailable from the data source." name="DefaultCodePage">1252</property>' + "`r`n")
Add ('              <property dataType="System.Boolean" description="Forces the use of the DefaultCodePage property value when describing character data." name="AlwaysUseDefaultCodePage">false</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the mode used to access the database." name="AccessMode" typeConverter="AccessMode">2</property>' + "`r`n")
Add ('              <property dataType="System.String" description="The mappings between the parameters in the SQL command and variables." name="ParameterMapping">' + (EscText $paramMap) + '</property>' + "`r`n")
Add ('            </properties>' + "`r`n")
Add ('            <connections>' + "`r`n")
Add ('              <connection refId="' + $ref + '.Connections[OleDbConnection]" connectionManagerID="' + $cmRef + '" connectionManagerRefId="' + $cmRef + '" description="The OLE DB runtime connection used to access the database." name="OleDbConnection" />' + "`r`n")
Add ('            </connections>' + "`r`n")
Add ('            <outputs>' + "`r`n")
Add ('              <output refId="' + $outRef + '" name="OLE DB Source Output">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
    foreach ($c in $cols) {
Add ('                  <outputColumn refId="' + $outRef + '.Columns[' + $c.name + ']" dataType="' + $c.dt + '" errorOrTruncationOperation="Conversion" errorRowDisposition="FailComponent" externalMetadataColumnId="' + $outRef + '.ExternalColumns[' + $c.name + ']" lineageId="' + $outRef + '.Columns[' + $c.name + ']" name="' + $c.name + '" truncationRowDisposition="FailComponent" ' + $c.extra + ' />' + "`r`n")
    }
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns isUsed="True">' + "`r`n")
    foreach ($c in $cols) {
Add ('                  <externalMetadataColumn refId="' + $outRef + '.ExternalColumns[' + $c.name + ']" dataType="' + $c.dt + '" name="' + $c.name + '" ' + $c.extra + ' />' + "`r`n")
    }
Add ('                </externalMetadataColumns>' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('              <output refId="' + $errRef + '" isErrorOut="true" name="OLE DB Source Error Output">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
    foreach ($c in $cols) {
Add ('                  <outputColumn refId="' + $errRef + '.Columns[' + $c.name + ']" dataType="' + $c.dt + '" lineageId="' + $errRef + '.Columns[' + $c.name + ']" name="' + $c.name + '" ' + $c.extra + ' />' + "`r`n")
    }
Add ('                  <outputColumn refId="' + $errRef + '.Columns[ErrorCode]" dataType="i4" lineageId="' + $errRef + '.Columns[ErrorCode]" name="ErrorCode" specialFlags="1" />' + "`r`n")
Add ('                  <outputColumn refId="' + $errRef + '.Columns[ErrorColumn]" dataType="i4" lineageId="' + $errRef + '.Columns[ErrorColumn]" name="ErrorColumn" specialFlags="2" />' + "`r`n")
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('            </outputs>' + "`r`n")
Add ('          </component>' + "`r`n")
}

function OLEDBDest($ref, $name, $cmRef, $table, $cols) {
    # $cols: array of hashes with name, dt, extra, and srcLineage (lineageId of upstream column)
    $inRef = $ref + '.Inputs[OLE DB Destination Input]'
    $errRef = $ref + '.Outputs[OLE DB Destination Error Output]'
Add ('          <component refId="' + $ref + '" componentClassID="Microsoft.OLEDBDestination" contactInfo="OLE DB Destination;Microsoft Corporation; Microsoft SQL Server; (C) Microsoft Corporation; All Rights Reserved; http://www.microsoft.com/sql/support;4" description="OLE DB Destination" name="' + $name + '" usesDispositions="true" version="4">' + "`r`n")
Add ('            <properties>' + "`r`n")
Add ('              <property dataType="System.Int32" description="The number of seconds before a command times out.  A value of 0 indicates an infinite time-out." name="CommandTimeout">0</property>' + "`r`n")
Add ('              <property dataType="System.String" description="Specifies the name of the database object used to open a rowset." name="OpenRowset">' + (EscText $table) + '</property>' + "`r`n")
Add ('              <property dataType="System.String" description="Specifies the variable that contains the name of the database object used to open a rowset." name="OpenRowsetVariable"></property>' + "`r`n")
Add ('              <property dataType="System.String" description="The SQL command to be executed." name="SqlCommand" UITypeEditor="Microsoft.DataTransformationServices.Controls.ModalMultilineStringEditor"></property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the column code page to use when code page information is unavailable from the data source." name="DefaultCodePage">1252</property>' + "`r`n")
Add ('              <property dataType="System.Boolean" description="Forces the use of the DefaultCodePage property value when describing character data." name="AlwaysUseDefaultCodePage">false</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the mode used to access the database." name="AccessMode" typeConverter="AccessMode">3</property>' + "`r`n")
Add ('              <property dataType="System.Boolean" description="Indicates whether the values supplied for identity columns will be copied to the destination. If false, values for identity columns will be auto-generated at the destination. Applies only if fast load is turned on." name="FastLoadKeepIdentity">false</property>' + "`r`n")
Add ('              <property dataType="System.Boolean" description="Indicates whether the columns containing null will have null inserted in the destination. If false, columns containing null will have their default values inserted at the destination. Applies only if fast load is turned on." name="FastLoadKeepNulls">false</property>' + "`r`n")
Add ('              <property dataType="System.String" description="Specifies options to be used with fast load.  Applies only if fast load is turned on." name="FastLoadOptions">CHECK_CONSTRAINTS</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies when commits are issued during data insertion.  A value of 0 specifies that one commit will be issued at the end of data insertion.  Applies only if fast load is turned on." name="FastLoadMaxInsertCommitSize">2147483647</property>' + "`r`n")
Add ('            </properties>' + "`r`n")
Add ('            <connections>' + "`r`n")
Add ('              <connection refId="' + $ref + '.Connections[OleDbConnection]" connectionManagerID="' + $cmRef + '" connectionManagerRefId="' + $cmRef + '" description="The OLE DB runtime connection used to access the database." name="OleDbConnection" />' + "`r`n")
Add ('            </connections>' + "`r`n")
Add ('            <inputs>' + "`r`n")
Add ('              <input refId="' + $inRef + '" errorOrTruncationOperation="Insert" errorRowDisposition="FailComponent" hasSideEffects="true" name="OLE DB Destination Input">' + "`r`n")
Add ('                <inputColumns>' + "`r`n")
    foreach ($c in $cols) {
        if ($c.srcLineage) {
Add ('                  <inputColumn refId="' + $inRef + '.Columns[' + $c.name + ']" cachedDataType="' + $c.dt + '" ' + (Cached $c) + 'cachedName="' + $c.name + '" externalMetadataColumnId="' + $inRef + '.ExternalColumns[' + $c.name + ']" lineageId="' + $c.srcLineage + '" />' + "`r`n")
        }
    }
Add ('                </inputColumns>' + "`r`n")
Add ('                <externalMetadataColumns isUsed="True">' + "`r`n")
    foreach ($c in $cols) {
        $extDt = if ($c.ext) { $c.ext } else { $c.dt }
        $scaleAttr = if ($c.scale) { ' scale="' + $c.scale + '"' } else { '' }
Add ('                  <externalMetadataColumn refId="' + $inRef + '.ExternalColumns[' + $c.name + ']" dataType="' + $extDt + '"' + $scaleAttr + ' name="' + $c.name + '" ' + $c.extra + ' />' + "`r`n")
    }
Add ('                </externalMetadataColumns>' + "`r`n")
Add ('              </input>' + "`r`n")
Add ('            </inputs>' + "`r`n")
Add ('            <outputs>' + "`r`n")
Add ('              <output refId="' + $errRef + '" exclusionGroup="1" isErrorOut="true" name="OLE DB Destination Error Output" synchronousInputId="' + $inRef + '">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
Add ('                  <outputColumn refId="' + $errRef + '.Columns[ErrorCode]" dataType="i4" lineageId="' + $errRef + '.Columns[ErrorCode]" name="ErrorCode" specialFlags="1" />' + "`r`n")
Add ('                  <outputColumn refId="' + $errRef + '.Columns[ErrorColumn]" dataType="i4" lineageId="' + $errRef + '.Columns[ErrorColumn]" name="ErrorColumn" specialFlags="2" />' + "`r`n")
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('            </outputs>' + "`r`n")
Add ('          </component>' + "`r`n")
}

function OpenDF($ref, $name, $dtsid) {
Add ('        <DTS:Executable' + "`r`n")
Add ('          DTS:refId="' + $ref + '"' + "`r`n")
Add ('          DTS:CreationName="Microsoft.Pipeline"' + "`r`n")
Add ('          DTS:Description="Data Flow Task"' + "`r`n")
Add ('          DTS:DTSID="' + $dtsid + '"' + "`r`n")
Add ('          DTS:ExecutableType="Microsoft.Pipeline"' + "`r`n")
Add ('          DTS:LocaleID="-1"' + "`r`n")
Add ('          DTS:ObjectName="' + $name + '"' + "`r`n")
Add ('          DTS:TaskContact="Performs high-performance data extraction, transformation and loading;Microsoft Corporation; Microsoft SQL Server; (C) 2007 Microsoft Corporation; All Rights Reserved;http://www.microsoft.com/sql/support/default.asp;1">' + "`r`n")
Add ('          <DTS:Variables />' + "`r`n")
Add ('          <DTS:ObjectData>' + "`r`n")
Add ('            <pipeline version="1">' + "`r`n")
Add ('              <components>' + "`r`n")
}
function CloseDF($dfRef, $paths) {
Add ('              </components>' + "`r`n")
Add ('              <paths>' + "`r`n")
    foreach ($p in $paths) {
Add ('                <path refId="' + $dfRef + '.Paths[' + $p.name + ']" endId="' + $p.to + '" name="' + $p.name + '" startId="' + $p.from + '" />' + "`r`n")
    }
Add ('              </paths>' + "`r`n")
Add ('            </pipeline>' + "`r`n")
Add ('          </DTS:ObjectData>' + "`r`n")
Add ('        </DTS:Executable>' + "`r`n")
}

function MkPath($name, $from, $to) { return @{ name=$name; from=$from; to=$to } }

# ------------------------------------------------------------
# Derived Column component
# $inCols: @{name; dt; len; lineage}  (referenced input columns)
# $outCols: @{name; dataType; extra; expr; friendly}  (new columns)
# ------------------------------------------------------------
function AddDerivedColumn($ref, $name, $inCols, $outCols) {
    $derOutRef = $ref + '.Outputs[Derived Column Output]'
Add ('          <component refId="' + $ref + '" componentClassID="Microsoft.DerivedColumn" contactInfo="Derived Column;Microsoft Corporation; Microsoft SQL Server; (C) Microsoft Corporation; All Rights Reserved; http://www.microsoft.com/sql/support;0" description="Creates new column values by applying expressions to transformation input columns. Create new columns or overwrite existing ones." name="' + $name + '" usesDispositions="true">' + "`r`n")
Add ('            <inputs>' + "`r`n")
Add ('              <input refId="' + $ref + '.Inputs[Derived Column Input]" description="Input to the Derived Column Transformation" name="Derived Column Input">' + "`r`n")
    if ($inCols.Count -gt 0) {
Add ('                <inputColumns>' + "`r`n")
        foreach ($c in $inCols) {
            $cachedL = if ($c.len) { 'cachedLength="' + $c.len + '" ' } else { '' }
Add ('                  <inputColumn refId="' + $ref + '.Inputs[Derived Column Input].Columns[' + $c.name + ']" cachedDataType="' + $c.dt + '" ' + $cachedL + 'cachedName="' + $c.name + '" lineageId="' + $c.lineage + '" />' + "`r`n")
        }
Add ('                </inputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
    } else {
Add ('                <externalMetadataColumns />' + "`r`n")
    }
Add ('              </input>' + "`r`n")
Add ('            </inputs>' + "`r`n")
Add ('            <outputs>' + "`r`n")
Add ('              <output refId="' + $derOutRef + '" description="Default Output of the Derived Column Transformation" exclusionGroup="1" name="Derived Column Output" synchronousInputId="' + $ref + '.Inputs[Derived Column Input]">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
    foreach ($o in $outCols) {
Add ('                  <outputColumn refId="' + $derOutRef + '.Columns[' + $o.name + ']" dataType="' + $o.dataType + '" errorOrTruncationOperation="Computation" errorRowDisposition="FailComponent" lineageId="' + $derOutRef + '.Columns[' + $o.name + ']" name="' + $o.name + '" truncationRowDisposition="FailComponent" ' + $o.extra + '>' + "`r`n")
Add ('                    <properties>' + "`r`n")
Add ('                      <property containsID="true" dataType="System.String" description="Derived Column Expression" name="Expression">' + (EscText $o.expr) + '</property>' + "`r`n")
Add ('                      <property containsID="true" dataType="System.String" description="Derived Column Friendly Expression" expressionType="Notify" name="FriendlyExpression">' + (EscText $o.friendly) + '</property>' + "`r`n")
Add ('                    </properties>' + "`r`n")
Add ('                  </outputColumn>' + "`r`n")
    }
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('              <output refId="' + $ref + '.Outputs[Derived Column Error Output]" description="Error Output of the Derived Column Transformation" exclusionGroup="1" isErrorOut="true" name="Derived Column Error Output" synchronousInputId="' + $ref + '.Inputs[Derived Column Input]">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
Add ('                  <outputColumn refId="' + $ref + '.Outputs[Derived Column Error Output].Columns[ErrorCode]" dataType="i4" lineageId="' + $ref + '.Outputs[Derived Column Error Output].Columns[ErrorCode]" name="ErrorCode" specialFlags="1" />' + "`r`n")
Add ('                  <outputColumn refId="' + $ref + '.Outputs[Derived Column Error Output].Columns[ErrorColumn]" dataType="i4" lineageId="' + $ref + '.Outputs[Derived Column Error Output].Columns[ErrorColumn]" name="ErrorColumn" specialFlags="2" />' + "`r`n")
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('            </outputs>' + "`r`n")
Add ('          </component>' + "`r`n")
}

# ------------------------------------------------------------
# Lookup component (full cache, no-match -> no match output)
# $inCols: @{name; dt; len; lineage; joinTo}  joinTo = reference column name
# $copyCols: @{name; dataType; extra; copyFrom}  reference columns to copy
# $refMeta: raw <referenceMetadata>...</referenceMetadata> string
# ------------------------------------------------------------
function AddLookup($ref, $name, $cmRef, $sqlCmd, $sqlCmdParam, $refMeta, $paramMapLineage, $inCols, $copyCols, $carrierCols = @()) {
    $lkInRef = $ref + '.Inputs[Lookup Input]'
    $lkMatch = $ref + '.Outputs[Lookup Match Output]'
    $lkNoMatch = $ref + '.Outputs[Lookup No Match Output]'
Add ('          <component refId="' + $ref + '" componentClassID="Microsoft.Lookup" contactInfo="Lookup;Microsoft Corporation; Microsoft SQL Server; (C) Microsoft Corporation; All Rights Reserved; http://www.microsoft.com/sql/support;6" description="Joins additional columns to the data flow by looking up values in a table." name="' + $name + '" usesDispositions="true" version="6">' + "`r`n")
Add ('            <properties>' + "`r`n")
Add ('              <property dataType="System.String" description="Specifies the SQL statement that generates the lookup table." expressionType="Notify" name="SqlCommand" UITypeEditor="Microsoft.DataTransformationServices.Controls.ModalMultilineStringEditor">' + (EscText $sqlCmd) + '</property>' + "`r`n")
Add ('              <property dataType="System.String" description="Specifies a SQL statement that uses parameters to generate the lookup table." expressionType="Notify" name="SqlCommandParam" UITypeEditor="Microsoft.DataTransformationServices.Controls.ModalMultilineStringEditor">' + (EscText $sqlCmdParam) + '</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the type of connection used to access the reference dataset." name="ConnectionType" typeConverter="LookupConnectionType">0</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the cache type of the lookup table." name="CacheType" typeConverter="CacheType">0</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies how the Lookup transformation handles rows without matching entries in the reference data set." name="NoMatchBehavior" typeConverter="LookupNoMatchBehavior">1</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the percentage of the cache that is allocated for rows with no matching entries in the reference dataset." name="NoMatchCachePercentage">0</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Maximum Memory Usage for Reference Cache on a 32 bit platform." name="MaxMemoryUsage">25</property>' + "`r`n")
Add ('              <property dataType="System.Int64" description="Maximum Memory Usage for Reference Cache on a 64 bit platform." name="MaxMemoryUsage64">25</property>' + "`r`n")
Add ('              <property dataType="System.String" description="Indicates whether to reference metadata in an XML format." name="ReferenceMetadataXml">' + (EscAttr $refMeta) + '</property>' + "`r`n")
Add ('              <property containsID="true" dataType="System.String" description="Specifies the list of lineage identifiers that map to the parameters that the SQL statement in the SQLCommand property uses. Entries in the list are separated by semicolons." name="ParameterMap">#{' + $paramMapLineage + '};</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the column code page to use when code page information is unavailable from the data source." name="DefaultCodePage">1252</property>' + "`r`n")
Add ('              <property dataType="System.Boolean" description="Determines whether duplicate keys in the reference data should be treated as errors when full cache mode is used." name="TreatDuplicateKeysAsError">false</property>' + "`r`n")
Add ('            </properties>' + "`r`n")
Add ('            <connections>' + "`r`n")
Add ('              <connection refId="' + $ref + '.Connections[OleDbConnection]" connectionManagerID="' + $cmRef + '" connectionManagerRefId="' + $cmRef + '" description="Connection manager used to access lookup data." name="OleDbConnection" />' + "`r`n")
Add ('            </connections>' + "`r`n")
Add ('            <inputs>' + "`r`n")
Add ('              <input refId="' + $lkInRef + '" name="Lookup Input">' + "`r`n")
Add ('                <inputColumns>' + "`r`n")
    foreach ($c in $inCols) {
        $cachedL = if ($c.len) { 'cachedLength="' + $c.len + '" ' } else { '' }
Add ('                  <inputColumn refId="' + $lkInRef + '.Columns[' + $c.name + ']" cachedDataType="' + $c.dt + '" ' + $cachedL + 'cachedName="' + $c.name + '" lineageId="' + $c.lineage + '">' + "`r`n")
Add ('                    <properties>' + "`r`n")
Add ('                      <property dataType="System.String" description="Specifies the column in the reference table that a column joins." name="JoinToReferenceColumn">' + $c.joinTo + '</property>' + "`r`n")
Add ('                      <property dataType="System.Null" description="Specifies the column in the reference table from which a column is copied." name="CopyFromReferenceColumn" />' + "`r`n")
Add ('                    </properties>' + "`r`n")
Add ('                  </inputColumn>' + "`r`n")
    }
Add ('                </inputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </input>' + "`r`n")
Add ('            </inputs>' + "`r`n")
Add ('            <outputs>' + "`r`n")
Add ('              <output refId="' + $lkMatch + '" errorOrTruncationOperation="Lookup" exclusionGroup="1" name="Lookup Match Output" synchronousInputId="' + $lkInRef + '">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
    foreach ($o in $copyCols) {
Add ('                  <outputColumn refId="' + $lkMatch + '.Columns[' + $o.name + ']" dataType="' + $o.dataType + '" errorOrTruncationOperation="Copy Column" lineageId="' + $lkMatch + '.Columns[' + $o.name + ']" name="' + $o.name + '" truncationRowDisposition="FailComponent" ' + $o.extra + '>' + "`r`n")
Add ('                    <properties>' + "`r`n")
Add ('                      <property dataType="System.String" description="Specifies the column in the reference table from which a column is copied." name="CopyFromReferenceColumn">' + $o.copyFrom + '</property>' + "`r`n")
Add ('                    </properties>' + "`r`n")
Add ('                  </outputColumn>' + "`r`n")
    }
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('              <output refId="' + $lkNoMatch + '" description="The Lookup output that handles rows with no matching entries in the reference dataset." exclusionGroup="1" name="Lookup No Match Output" synchronousInputId="' + $lkInRef + '">' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('              <output refId="' + $ref + '.Outputs[Lookup Error Output]" exclusionGroup="1" isErrorOut="true" name="Lookup Error Output" synchronousInputId="' + $lkInRef + '">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
Add ('                  <outputColumn refId="' + $ref + '.Outputs[Lookup Error Output].Columns[ErrorCode]" dataType="i4" lineageId="' + $ref + '.Outputs[Lookup Error Output].Columns[ErrorCode]" name="ErrorCode" specialFlags="1" />' + "`r`n")
Add ('                  <outputColumn refId="' + $ref + '.Outputs[Lookup Error Output].Columns[ErrorColumn]" dataType="i4" lineageId="' + $ref + '.Outputs[Lookup Error Output].Columns[ErrorColumn]" name="ErrorColumn" specialFlags="2" />' + "`r`n")
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('            </outputs>' + "`r`n")
Add ('          </component>' + "`r`n")
}

# =====================================================================
# 1) Initialize sequence
# =====================================================================
Add ('    <DTS:Executables>' + "`r`n")
OpenSeq 'Package\Initialize' 'Initialize' (GUID 'Seq-Initialize')

OpenTask 'Package\Initialize\Set Current Job Time' 'Set Current Job Time' (GUID 'Task-SetCurrentJobTime') 'Microsoft.ExecuteSQLTask' 'Execute SQL Task' 'Execute SQL Task; Microsoft Corporation; SQL Server 2016; c 2015 Microsoft Corporation; All Rights Reserved;http://www.microsoft.com/sql/support/default.asp;1'
Add ('            <SQLTask:SqlTaskData' + "`r`n")
Add ('              SQLTask:Connection="' + (GUID 'CM-DW') + '"' + "`r`n")
Add ('              SQLTask:SqlStatementSource="SELECT GETDATE() AS Now"' + "`r`n")
Add ('              SQLTask:ResultType="ResultSetType_SingleRow" xmlns:SQLTask="www.microsoft.com/sqlserver/dts/tasks/sqltask">' + "`r`n")
Add ('              <SQLTask:ResultBinding SQLTask:ResultName="Now" SQLTask:DtsVariableName="User::CurrentJobTime" />' + "`r`n")
Add ('            </SQLTask:SqlTaskData>' + "`r`n")
CloseTask

OpenTask 'Package\Initialize\Sync InitialLoad Parameter' 'Sync InitialLoad Parameter' (GUID 'Task-SyncInitialLoad') 'Microsoft.ExecuteSQLTask' 'Execute SQL Task' 'Execute SQL Task; Microsoft Corporation; SQL Server 2016; c 2015 Microsoft Corporation; All Rights Reserved;http://www.microsoft.com/sql/support/default.asp;1'
Add ('            <SQLTask:SqlTaskData' + "`r`n")
Add ('              SQLTask:Connection="' + (GUID 'CM-DW') + '"' + "`r`n")
Add ('              SQLTask:SqlStatementSource="SELECT CAST(? AS bit) AS V"' + "`r`n")
Add ('              SQLTask:ResultType="ResultSetType_SingleRow" xmlns:SQLTask="www.microsoft.com/sqlserver/dts/tasks/sqltask">' + "`r`n")
Add ('              <SQLTask:ParameterBinding SQLTask:ParameterName="0" SQLTask:DtsVariableName="$Package::InitialLoad" SQLTask:ParameterDirection="Input" SQLTask:DataType="11" SQLTask:ParameterSize="1" />' + "`r`n")
Add ('              <SQLTask:ResultBinding SQLTask:ResultName="V" SQLTask:DtsVariableName="User::InitialLoad" />' + "`r`n")
Add ('            </SQLTask:SqlTaskData>' + "`r`n")
CloseTask

OpenTask 'Package\Initialize\Debug Log State' 'Debug Log State' (GUID 'Task-DebugLog') 'Microsoft.ExecuteSQLTask' 'Execute SQL Task' 'Execute SQL Task; Microsoft Corporation; SQL Server 2016; c 2015 Microsoft Corporation; All Rights Reserved;http://www.microsoft.com/sql/support/default.asp;1'
Add ('            <SQLTask:SqlTaskData' + "`r`n")
Add ('              SQLTask:Connection="' + (GUID 'CM-DW') + '"' + "`r`n")
Add ('              SQLTask:SqlStatementSource="INSERT INTO [dbo].[DebugLog] ([Message]) VALUES (CONCAT(''IL='', CONVERT(nvarchar(5), ?), ''; LJ='', CONVERT(nvarchar(30), ?, 120)))"' + "`r`n")
Add ('              SQLTask:ResultType="ResultSetType_None" xmlns:SQLTask="www.microsoft.com/sqlserver/dts/tasks/sqltask">' + "`r`n")
Add ('              <SQLTask:ParameterBinding SQLTask:ParameterName="0" SQLTask:DtsVariableName="User::InitialLoad" SQLTask:ParameterDirection="Input" SQLTask:DataType="11" SQLTask:ParameterSize="1" />' + "`r`n")
Add ('              <SQLTask:ParameterBinding SQLTask:ParameterName="1" SQLTask:DtsVariableName="User::LastJobTime" SQLTask:ParameterDirection="Input" SQLTask:DataType="7" SQLTask:ParameterSize="16" />' + "`r`n")
Add ('            </SQLTask:SqlTaskData>' + "`r`n")
CloseTask

OpenTask 'Package\Initialize\Sync Language Parameter' 'Sync Language Parameter' (GUID 'Task-SyncLanguage') 'Microsoft.ExecuteSQLTask' 'Execute SQL Task' 'Execute SQL Task; Microsoft Corporation; SQL Server 2016; c 2015 Microsoft Corporation; All Rights Reserved;http://www.microsoft.com/sql/support/default.asp;1'
Add ('            <SQLTask:SqlTaskData' + "`r`n")
Add ('              SQLTask:Connection="' + (GUID 'CM-DW') + '"' + "`r`n")
Add ('              SQLTask:SqlStatementSource="SELECT CAST(? AS nvarchar(50)) AS V"' + "`r`n")
Add ('              SQLTask:ResultType="ResultSetType_SingleRow" xmlns:SQLTask="www.microsoft.com/sqlserver/dts/tasks/sqltask">' + "`r`n")
Add ('              <SQLTask:ParameterBinding SQLTask:ParameterName="0" SQLTask:DtsVariableName="$Package::Language" SQLTask:ParameterDirection="Input" SQLTask:DataType="130" SQLTask:ParameterSize="50" />' + "`r`n")
Add ('              <SQLTask:ResultBinding SQLTask:ResultName="V" SQLTask:DtsVariableName="User::Language" />' + "`r`n")
Add ('            </SQLTask:SqlTaskData>' + "`r`n")
CloseTask

OpenTask 'Package\Initialize\Read Watermark' 'Read Watermark' (GUID 'Task-ReadWatermark') 'Microsoft.ExecuteSQLTask' 'Execute SQL Task' 'Execute SQL Task; Microsoft Corporation; SQL Server 2016; c 2015 Microsoft Corporation; All Rights Reserved;http://www.microsoft.com/sql/support/default.asp;1'
Add ('            <SQLTask:SqlTaskData' + "`r`n")
Add ('              SQLTask:Connection="' + (GUID 'CM-DW') + '"' + "`r`n")
Add ('              SQLTask:SqlStatementSource="SELECT CASE WHEN ? = 1 THEN ''1900-01-01 00:00:00'' ELSE ISNULL(MAX(LastSuccessfulRun), ''1900-01-01 00:00:00'') END AS LastSuccessfulRun FROM dbo.Watermark"' + "`r`n")
Add ('              SQLTask:ResultType="ResultSetType_SingleRow" xmlns:SQLTask="www.microsoft.com/sqlserver/dts/tasks/sqltask">' + "`r`n")
Add ('              <SQLTask:ParameterBinding SQLTask:ParameterName="0" SQLTask:DtsVariableName="User::InitialLoad" SQLTask:ParameterDirection="Input" SQLTask:DataType="11" SQLTask:ParameterSize="1" />' + "`r`n")
Add ('              <SQLTask:ResultBinding SQLTask:ResultName="LastSuccessfulRun" SQLTask:DtsVariableName="User::LastJobTime" />' + "`r`n")
Add ('            </SQLTask:SqlTaskData>' + "`r`n")
CloseTask

$prepSQL = @'
IF ? = 1
BEGIN
    ALTER TABLE [Sales].[FactSales] NOCHECK CONSTRAINT ALL;
    DELETE FROM [Sales].[FactSales];
    DELETE FROM [Sales].[DimProduct];
    DELETE FROM [Sales].[DimCustomer];
    ALTER TABLE [Sales].[FactSales] WITH CHECK CHECK CONSTRAINT ALL;
END
'@
OpenTask 'Package\Initialize\Prepare DW (Initial Load)' 'Prepare DW (Initial Load)' (GUID 'Task-PrepareDW') 'Microsoft.ExecuteSQLTask' 'Execute SQL Task' 'Execute SQL Task; Microsoft Corporation; SQL Server 2016; c 2015 Microsoft Corporation; All Rights Reserved;http://www.microsoft.com/sql/support/default.asp;1'
Add ('            <SQLTask:SqlTaskData' + "`r`n")
Add ('              SQLTask:Connection="' + (GUID 'CM-DW') + '"' + "`r`n")
Add ('              SQLTask:SqlStatementSource="' + (EscSql $prepSQL) + '"' + "`r`n")
Add ('              SQLTask:ResultType="ResultSetType_None" xmlns:SQLTask="www.microsoft.com/sqlserver/dts/tasks/sqltask">' + "`r`n")
Add ('              <SQLTask:ParameterBinding SQLTask:ParameterName="0" SQLTask:DtsVariableName="User::InitialLoad" SQLTask:ParameterDirection="Input" SQLTask:DataType="11" SQLTask:ParameterSize="1" />' + "`r`n")
Add ('            </SQLTask:SqlTaskData>' + "`r`n")
CloseTask
CloseSeq

SeqConstraint 'Package\Initialize' 'Package\Initialize\Set Current Job Time' 'Package\Initialize\Sync InitialLoad Parameter' (GUID 'PC-Init-1') 'Set Current Job Time -> Sync InitialLoad Parameter'
SeqConstraint 'Package\Initialize' 'Package\Initialize\Sync InitialLoad Parameter' 'Package\Initialize\Debug Log State' (GUID 'PC-Init-2') 'Sync InitialLoad Parameter -> Debug Log State'
SeqConstraint 'Package\Initialize' 'Package\Initialize\Debug Log State' 'Package\Initialize\Sync Language Parameter' (GUID 'PC-Init-2b') 'Debug Log State -> Sync Language Parameter'
SeqConstraint 'Package\Initialize' 'Package\Initialize\Sync Language Parameter' 'Package\Initialize\Read Watermark' (GUID 'PC-Init-3') 'Sync Language Parameter -> Read Watermark'
SeqConstraint 'Package\Initialize' 'Package\Initialize\Read Watermark' 'Package\Initialize\Prepare DW (Initial Load)' (GUID 'PC-Init-4') 'Read Watermark -> Prepare DW (Initial Load)'
EndSeq

# =====================================================================
# 2) Load Staging sequence (10 data flows)
# =====================================================================
OpenSeq 'Package\Load Staging' 'Load Staging' (GUID 'Seq-LoadStaging')

OpenTask 'Package\Load Staging\Prepare Staging' 'Prepare Staging' (GUID 'Task-PrepareStaging') 'Microsoft.ExecuteSQLTask' 'Execute SQL Task' 'Execute SQL Task; Microsoft Corporation; SQL Server 2016; c 2015 Microsoft Corporation; All Rights Reserved;http://www.microsoft.com/sql/support/default.asp;1'
Add ('            <SQLTask:SqlTaskData' + "`r`n")
Add ('              SQLTask:Connection="' + (GUID 'CM-Staging') + '"' + "`r`n")
$truncSQL = 'TRUNCATE TABLE [dbo].[Address];TRUNCATE TABLE [dbo].[Customer];TRUNCATE TABLE [dbo].[Customer_Address];TRUNCATE TABLE [dbo].[Product];TRUNCATE TABLE [dbo].[ProductCategory];TRUNCATE TABLE [dbo].[ProductDescription];TRUNCATE TABLE [dbo].[ProductModel];TRUNCATE TABLE [dbo].[ProductModel_Description];TRUNCATE TABLE [dbo].[SalesOrderHeader];TRUNCATE TABLE [dbo].[SalesOrderDetails];'
Add ('              SQLTask:SqlStatementSource="' + (EscSql $truncSQL) + '"' + "`r`n")
Add ('              SQLTask:ResultType="ResultSetType_None" xmlns:SQLTask="www.microsoft.com/sqlserver/dts/tasks/sqltask">' + "`r`n")
Add ('            </SQLTask:SqlTaskData>' + "`r`n")
CloseTask

$staging = @(
    @{ DF="Stage Address";                Table="[dbo].[Address]"; Query=@'
SELECT A.AddressID, A.AddressLine1 AS Address, A.City, A.StateProvince AS State, A.CountryRegion AS Region, A.CountryRegion AS Country
FROM SalesLT.Address A
WHERE A.ModifiedDate > ?
'@; Cols=@(
        @("AddressID","i4"), @("Address","wstr","60"), @("City","wstr","30"), @("State","wstr","50"), @("Region","wstr","50"), @("Country","wstr","50")
    ) },
    @{ DF="Stage Customer";               Table="[dbo].[Customer]"; Query=@'
SELECT C.CustomerID, C.Title, C.FirstName, C.MiddleName, C.LastName, C.Suffix, C.CompanyName, C.EmailAddress, C.Phone, C.ModifiedDate
FROM SalesLT.Customer C
WHERE C.ModifiedDate > ?
'@; Cols=@(
        @("CustomerID","i4"), @("Title","wstr","8"), @("FirstName","wstr","50"), @("MiddleName","wstr","50"), @("LastName","wstr","50"), @("Suffix","wstr","10"), @("CompanyName","wstr","128"), @("EmailAddress","wstr","50"), @("Phone","wstr","25"), @("ModifiedDate","dbTimeStamp")
    ) },
    @{ DF="Stage Customer Address";       Table="[dbo].[Customer_Address]"; Query=@'
SELECT CA.CustomerID, CA.AddressID, CA.AddressType
FROM SalesLT.CustomerAddress CA
WHERE CA.ModifiedDate > ?
'@; Cols=@(
        @("CustomerID","i4"), @("AddressID","i4"), @("AddressType","wstr","50")
    ) },
    @{ DF="Stage Product";                Table="[dbo].[Product]"; Query=@'
SELECT P.ProductID, P.Name, P.ProductNumber, P.Color, P.StandardCost, P.ListPrice, P.Size, P.Weight, P.ProductCategoryID, P.ProductModelID, P.SellStartDate, P.SellEndDate, P.ModifiedDate
FROM SalesLT.Product P
WHERE P.ModifiedDate > ?
'@; Cols=@(
        @("ProductID","i4"), @("Name","wstr","50"), @("ProductNumber","wstr","25"), @("Color","wstr","15"), @("StandardCost","numeric","19","4"), @("ListPrice","numeric","19","4"), @("Size","wstr","5"), @("Weight","numeric","8","2"), @("ProductCategoryID","i4"), @("ProductModelID","i4"), @("SellStartDate","dbTimeStamp"), @("SellEndDate","dbTimeStamp"), @("ModifiedDate","dbTimeStamp")
    ) },
    @{ DF="Stage Product Category";       Table="[dbo].[ProductCategory]"; Query=@'
SELECT PC.ProductCategoryID, PC.ParentProductCategoryID, PC.Name
FROM SalesLT.ProductCategory PC
WHERE PC.ModifiedDate > ?
'@; Cols=@(
        @("ProductCategoryID","i4"), @("ParentProductCategoryID","i4"), @("Name","wstr","50")
    ) },
    @{ DF="Stage Product Description";    Table="[dbo].[ProductDescription]"; Query=@'
SELECT PD.ProductDescriptionID, PD.Description
FROM SalesLT.ProductDescription PD
WHERE PD.ModifiedDate > ?
'@; Cols=@(
        @("ProductDescriptionID","i4"), @("Description","wstr","400")
    ) },
    @{ DF="Stage Product Model";          Table="[dbo].[ProductModel]"; Query=@'
SELECT PM.ProductModelID, PM.Name
FROM SalesLT.ProductModel PM
WHERE PM.ModifiedDate > ?
'@; Cols=@(
        @("ProductModelID","i4"), @("Name","wstr","50")
    ) },
    @{ DF="Stage Product Model Description"; Table="[dbo].[ProductModel_Description]"; Query=@'
SELECT PMD.ProductModelID, PMD.ProductDescriptionID, PMD.Culture
FROM SalesLT.ProductModelDescription PMD
WHERE PMD.ModifiedDate > ?
'@; Cols=@(
        @("ProductModelID","i4"), @("ProductDescriptionID","i4"), @("Culture","wstr","6")
    ) },
    @{ DF="Stage Sales Order Header";     Table="[dbo].[SalesOrderHeader]"; Query=@'
SELECT SOH.SalesOrderID, SOH.CustomerID, SOH.OrderDate, SOH.ShipDate, SOH.BatchYear, SOH.BatchMonth, SOH.SubTotal, SOH.TaxAmt, SOH.Freight, SOH.TotalDue, SOH.ModifiedDate
FROM SalesLT.SalesOrderHeader SOH
WHERE SOH.ModifiedDate > ?
'@; Cols=@(
        @("SalesOrderID","i4"), @("CustomerID","i4"), @("OrderDate","dbTimeStamp"), @("ShipDate","dbTimeStamp"), @("BatchYear","i4"), @("BatchMonth","i4"), @("SubTotal","numeric","19","4"), @("TaxAmt","numeric","19","4"), @("Freight","numeric","19","4"), @("TotalDue","numeric","19","4"), @("ModifiedDate","dbTimeStamp")
    ) },
    @{ DF="Stage Sales Order Details";    Table="[dbo].[SalesOrderDetails]"; Query=@'
SELECT SOD.SalesOrderDetailID, SOD.OrderID, SOD.ProductID, SOD.OrderQty, SOD.UnitPrice, SOD.UnitPriceDiscount, SOD.LineTotal, SOD.ModifiedDate
FROM SalesLT.SalesOrderDetails SOD
WHERE SOD.ModifiedDate > ?
'@; Cols=@(
        @("SalesOrderDetailID","i4"), @("OrderID","i4"), @("ProductID","i4"), @("OrderQty","numeric","19","4"), @("UnitPrice","numeric","19","4"), @("UnitPriceDiscount","numeric","19","4"), @("LineTotal","numeric","19","4"), @("ModifiedDate","dbTimeStamp")
    ) }
)

foreach ($s in $staging) {
    $dfRef = 'Package\Load Staging\' + $s.DF
    $srcRef = $dfRef + '\OLE DB Source'
    $dstRef = $dfRef + '\OLE DB Destination'
    $cols = @()
    foreach ($spec in $s.Cols) { $cols += (MakeCol $spec) }
    # source lineage ids
    $srcCols = @()
    foreach ($c in $cols) { $srcCols += @{ name=$c.name; dt=$c.dt; extra=$c.extra; lineage=($srcRef + '.Outputs[OLE DB Source Output].Columns[' + $c.name + ']') } }
    # dest cols map to source lineage
    $dstCols = @()
    foreach ($c in $cols) { $dstCols += @{ name=$c.name; dt=$c.dt; extra=$c.extra; srcLineage=($srcRef + '.Outputs[OLE DB Source Output].Columns[' + $c.name + ']') } }

    OpenDF $dfRef $s.DF (GUID ("DF-" + $s.DF))
    OLEDBSource $srcRef 'OLE DB Source' $OLTPre $s.Query $pmLast $srcCols
    OLEDBDest $dstRef 'OLE DB Destination' $StaPre $s.Table $dstCols
    CloseDF $dfRef @( MkPath 'OLE DB Source Output' ($srcRef + '.Outputs[OLE DB Source Output]') ($dstRef + '.Inputs[OLE DB Destination Input]') )
}
CloseSeq
foreach ($s in $staging) {
    SeqConstraint 'Package\Load Staging' 'Package\Load Staging\Prepare Staging' ('Package\Load Staging\' + $s.DF) (GUID ("PC-Stage-" + $s.DF)) ('Prepare Staging -> ' + $s.DF)
}
EndSeq

# =====================================================================
# 3) Load DimCustomer (SCD1)
# =====================================================================
OpenSeq 'Package\Load DimCustomer (SCD1)' 'Load DimCustomer (SCD1)' (GUID 'Seq-DimCustomer')
$dfRef = 'Package\Load DimCustomer (SCD1)\Load DimCustomer'
$srcRef = $dfRef + '\OLE DB Source'
$derRef = $dfRef + '\Build Customer Name'
$lkRef  = $dfRef + '\Lookup Existing Customer'
$cmdRef = $dfRef + '\Update Customer (SCD1)'
$insRef = $dfRef + '\Insert New Customer'

$custQ = @'
SELECT C.CustomerID, C.Title, C.FirstName, C.MiddleName, C.LastName, C.CompanyName, C.EmailAddress AS Email, C.Phone, A.Address AS OfficeAddress, A.City, A.State, A.Country
FROM [dbo].[Customer] C
LEFT JOIN [dbo].[Customer_Address] CA ON C.CustomerID = CA.CustomerID AND CA.AddressType = 'Main Office'
LEFT JOIN [dbo].[Address] A ON CA.AddressID = A.AddressID
'@
$custCols = @(
    @{name='CustomerID';dt='i4';extra='';src=($srcRef+'.Outputs[OLE DB Source Output].Columns[CustomerID]')},
    @{name='Title';dt='wstr';extra='length="8"';src=($srcRef+'.Outputs[OLE DB Source Output].Columns[Title]')},
    @{name='FirstName';dt='wstr';extra='length="50"';src=($srcRef+'.Outputs[OLE DB Source Output].Columns[FirstName]')},
    @{name='MiddleName';dt='wstr';extra='length="50"';src=($srcRef+'.Outputs[OLE DB Source Output].Columns[MiddleName]')},
    @{name='LastName';dt='wstr';extra='length="50"';src=($srcRef+'.Outputs[OLE DB Source Output].Columns[LastName]')},
    @{name='CompanyName';dt='wstr';extra='length="128"';src=($srcRef+'.Outputs[OLE DB Source Output].Columns[CompanyName]')},
    @{name='Email';dt='wstr';extra='length="50"';src=($srcRef+'.Outputs[OLE DB Source Output].Columns[Email]')},
    @{name='Phone';dt='wstr';extra='length="25"';src=($srcRef+'.Outputs[OLE DB Source Output].Columns[Phone]')},
    @{name='OfficeAddress';dt='wstr';extra='length="60"';src=($srcRef+'.Outputs[OLE DB Source Output].Columns[OfficeAddress]')},
    @{name='City';dt='wstr';extra='length="30"';src=($srcRef+'.Outputs[OLE DB Source Output].Columns[City]')},
    @{name='State';dt='wstr';extra='length="50"';src=($srcRef+'.Outputs[OLE DB Source Output].Columns[State]')},
    @{name='Country';dt='wstr';extra='length="50"';src=($srcRef+'.Outputs[OLE DB Source Output].Columns[Country]')}
)
$nameLine = $derRef + '.Outputs[Derived Column Output].Columns[Name]'
$custKeyLine = $lkRef + '.Outputs[Lookup Match Output].Columns[CustomerKey]'

OpenDF $dfRef 'Load DimCustomer' (GUID 'DF-DimCustomer')
OLEDBSource $srcRef 'OLE DB Source' $StaPre $custQ $null ($custCols | ForEach-Object { @{name=$_.name;dt=$_.dt;extra=$_.extra} })

# Derived Column - Build Customer Name
$derOutRef = $derRef + '.Outputs[Derived Column Output]'
Add ('          <component refId="' + $derRef + '" componentClassID="Microsoft.DerivedColumn" contactInfo="Derived Column;Microsoft Corporation; Microsoft SQL Server; (C) Microsoft Corporation; All Rights Reserved; http://www.microsoft.com/sql/support;0" description="Creates new column values by applying expressions to transformation input columns. Create new columns or overwrite existing ones. For example, concatenate the values from the ' + "'" + 'first name' + "'" + ' and ' + "'" + 'last name' + "'" + ' column to make a ' + "'" + 'full name' + "'" + ' column." name="Build Customer Name" usesDispositions="true">' + "`r`n")
Add ('            <inputs>' + "`r`n")
Add ('              <input refId="' + $derRef + '.Inputs[Derived Column Input]" description="Input to the Derived Column Transformation" name="Derived Column Input">' + "`r`n")
Add ('                <inputColumns>' + "`r`n")
Add ('                  <inputColumn refId="' + $derRef + '.Inputs[Derived Column Input].Columns[FirstName]" cachedDataType="wstr" cachedLength="50" cachedName="FirstName" lineageId="' + $srcRef + '.Outputs[OLE DB Source Output].Columns[FirstName]" />' + "`r`n")
Add ('                  <inputColumn refId="' + $derRef + '.Inputs[Derived Column Input].Columns[LastName]" cachedDataType="wstr" cachedLength="50" cachedName="LastName" lineageId="' + $srcRef + '.Outputs[OLE DB Source Output].Columns[LastName]" />' + "`r`n")
Add ('                </inputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </input>' + "`r`n")
Add ('            </inputs>' + "`r`n")
Add ('            <outputs>' + "`r`n")
Add ('              <output refId="' + $derOutRef + '" description="Default Output of the Derived Column Transformation" exclusionGroup="1" name="Derived Column Output" synchronousInputId="' + $derRef + '.Inputs[Derived Column Input]">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
Add ('                  <outputColumn refId="' + $derOutRef + '.Columns[Name]" dataType="wstr" errorOrTruncationOperation="Computation" errorRowDisposition="FailComponent" length="50" lineageId="' + $derOutRef + '.Columns[Name]" name="Name" truncationRowDisposition="FailComponent">' + "`r`n")
Add ('                    <properties>' + "`r`n")
Add ('                      <property containsID="true" dataType="System.String" description="Derived Column Expression" name="Expression">(DT_WSTR,50)TRIM(#{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[FirstName]}) + " " + TRIM(#{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[LastName]})</property>' + "`r`n")
Add ('                      <property containsID="true" dataType="System.String" description="Derived Column Friendly Expression" expressionType="Notify" name="FriendlyExpression">(DT_WSTR,50)TRIM(FirstName) + " " + TRIM(LastName)</property>' + "`r`n")
Add ('                    </properties>' + "`r`n")
Add ('                  </outputColumn>' + "`r`n")
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('              <output refId="' + $derRef + '.Outputs[Derived Column Error Output]" description="Error Output of the Derived Column Transformation" exclusionGroup="1" isErrorOut="true" name="Derived Column Error Output" synchronousInputId="' + $derRef + '.Inputs[Derived Column Input]">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
Add ('                  <outputColumn refId="' + $derRef + '.Outputs[Derived Column Error Output].Columns[ErrorCode]" dataType="i4" lineageId="' + $derRef + '.Outputs[Derived Column Error Output].Columns[ErrorCode]" name="ErrorCode" specialFlags="1" />' + "`r`n")
Add ('                  <outputColumn refId="' + $derRef + '.Outputs[Derived Column Error Output].Columns[ErrorColumn]" dataType="i4" lineageId="' + $derRef + '.Outputs[Derived Column Error Output].Columns[ErrorColumn]" name="ErrorColumn" specialFlags="2" />' + "`r`n")
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('            </outputs>' + "`r`n")
Add ('          </component>' + "`r`n")

# Lookup - Existing Customer
$lkInRef = $lkRef + '.Inputs[Lookup Input]'
$lkMatch = $lkRef + '.Outputs[Lookup Match Output]'
$lkNoMatch = $lkRef + '.Outputs[Lookup No Match Output]'
Add ('          <component refId="' + $lkRef + '" componentClassID="Microsoft.Lookup" contactInfo="Lookup;Microsoft Corporation; Microsoft SQL Server; (C) Microsoft Corporation; All Rights Reserved; http://www.microsoft.com/sql/support;6" description="Joins additional columns to the data flow by looking up values in a table. For example, join to the ' + "'" + 'employee id' + "'" + ' column the employees table to get ' + "'" + 'hire date' + "'" + ' and ' + "'" + 'employee name' + "'" + '. We recommend this transformation when the lookup table can fit into memory." name="Lookup Existing Customer" usesDispositions="true" version="6">' + "`r`n")
Add ('            <properties>' + "`r`n")
Add ('              <property dataType="System.String" description="Specifies the SQL statement that generates the lookup table." expressionType="Notify" name="SqlCommand" UITypeEditor="Microsoft.DataTransformationServices.Controls.ModalMultilineStringEditor">SELECT        CustomerKey, CustomerAltKey
FROM            Sales.DimCustomer</property>' + "`r`n")
Add ('              <property dataType="System.String" description="Specifies a SQL statement that uses parameters to generate the lookup table." expressionType="Notify" name="SqlCommandParam" UITypeEditor="Microsoft.DataTransformationServices.Controls.ModalMultilineStringEditor">select * from (SELECT        CustomerKey, CustomerAltKey
FROM            Sales.DimCustomer) [refTable]
where [refTable].[CustomerAltKey] = ?</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the type of connection used to access the reference dataset." name="ConnectionType" typeConverter="LookupConnectionType">0</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the cache type of the lookup table." name="CacheType" typeConverter="CacheType">0</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies how the Lookup transformation handles rows without matching entries in the reference data set." name="NoMatchBehavior" typeConverter="LookupNoMatchBehavior">1</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the percentage of the cache that is allocated for rows with no matching entries in the reference dataset." name="NoMatchCachePercentage">0</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Maximum Memory Usage for Reference Cache on a 32 bit platform." name="MaxMemoryUsage">25</property>' + "`r`n")
Add ('              <property dataType="System.Int64" description="Maximum Memory Usage for Reference Cache on a 64 bit platform." name="MaxMemoryUsage64">25</property>' + "`r`n")
Add ('              <property dataType="System.String" description="Indicates whether to reference metadata in an XML format." name="ReferenceMetadataXml">&lt;referenceMetadata&gt;&lt;referenceColumns&gt;&lt;referenceColumn name="CustomerKey" dataType="DT_I4" precision="10" scale="0" codePage="0"/&gt;&lt;referenceColumn name="CustomerAltKey" dataType="DT_I4" precision="10" scale="0" codePage="0"/&gt;&lt;/referenceColumns&gt;&lt;/referenceMetadata&gt;</property>' + "`r`n")
Add ('              <property containsID="true" dataType="System.String" description="Specifies the list of lineage identifiers that map to the parameters that the SQL statement in the SQLCommand property uses. Entries in the list are separated by semicolons." name="ParameterMap">#{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[CustomerID]};</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the column code page to use when code page information is unavailable from the data source." name="DefaultCodePage">1252</property>' + "`r`n")
Add ('              <property dataType="System.Boolean" description="Determines whether duplicate keys in the reference data should be treated as errors when full cache mode is used." name="TreatDuplicateKeysAsError">false</property>' + "`r`n")
Add ('            </properties>' + "`r`n")
Add ('            <connections>' + "`r`n")
Add ('              <connection refId="' + $lkRef + '.Connections[OleDbConnection]" connectionManagerID="' + $DWPRe + '" connectionManagerRefId="' + $DWPRe + '" description="Connection manager used to access lookup data." name="OleDbConnection" />' + "`r`n")
Add ('            </connections>' + "`r`n")
Add ('            <inputs>' + "`r`n")
Add ('              <input refId="' + $lkInRef + '" name="Lookup Input">' + "`r`n")
Add ('                <inputColumns>' + "`r`n")
Add ('                  <inputColumn refId="' + $lkInRef + '.Columns[CustomerID]" cachedDataType="i4" cachedName="CustomerID" lineageId="' + $srcRef + '.Outputs[OLE DB Source Output].Columns[CustomerID]">' + "`r`n")
Add ('                    <properties>' + "`r`n")
Add ('                      <property dataType="System.String" description="Specifies the column in the reference table that a column joins." name="JoinToReferenceColumn">CustomerAltKey</property>' + "`r`n")
Add ('                      <property dataType="System.Null" description="Specifies the column in the reference table from which a column is copied." name="CopyFromReferenceColumn" />' + "`r`n")
Add ('                    </properties>' + "`r`n")
Add ('                  </inputColumn>' + "`r`n")
Add ('                </inputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </input>' + "`r`n")
Add ('            </inputs>' + "`r`n")
Add ('            <outputs>' + "`r`n")
Add ('              <output refId="' + $lkMatch + '" errorOrTruncationOperation="Lookup" exclusionGroup="1" name="Lookup Match Output" synchronousInputId="' + $lkInRef + '">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
Add ('                  <outputColumn refId="' + $lkMatch + '.Columns[CustomerKey]" dataType="i4" errorOrTruncationOperation="Copy Column" lineageId="' + $lkMatch + '.Columns[CustomerKey]" name="CustomerKey" truncationRowDisposition="FailComponent">' + "`r`n")
Add ('                    <properties>' + "`r`n")
Add ('                      <property dataType="System.String" description="Specifies the column in the reference table from which a column is copied." name="CopyFromReferenceColumn">CustomerKey</property>' + "`r`n")
Add ('                    </properties>' + "`r`n")
Add ('                  </outputColumn>' + "`r`n")
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('              <output refId="' + $lkNoMatch + '" description="The Lookup output that handles rows with no matching entries in the reference dataset. Use this output when the NoMatchBehavior property is set to &quot;Send rows with no matching entries to the no match output.&quot;" exclusionGroup="1" name="Lookup No Match Output" synchronousInputId="' + $lkInRef + '">' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('              <output refId="' + $lkRef + '.Outputs[Lookup Error Output]" exclusionGroup="1" isErrorOut="true" name="Lookup Error Output" synchronousInputId="' + $lkInRef + '">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
Add ('                  <outputColumn refId="' + $lkRef + '.Outputs[Lookup Error Output].Columns[ErrorCode]" dataType="i4" lineageId="' + $lkRef + '.Outputs[Lookup Error Output].Columns[ErrorCode]" name="ErrorCode" specialFlags="1" />' + "`r`n")
Add ('                  <outputColumn refId="' + $lkRef + '.Outputs[Lookup Error Output].Columns[ErrorColumn]" dataType="i4" lineageId="' + $lkRef + '.Outputs[Lookup Error Output].Columns[ErrorColumn]" name="ErrorColumn" specialFlags="2" />' + "`r`n")
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('            </outputs>' + "`r`n")
Add ('          </component>' + "`r`n")

# OLE DB Command - Update Customer (SCD1)
$cmdInRef = $cmdRef + '.Inputs[OLE DB Command Input]'
Add ('          <component refId="' + $cmdRef + '" componentClassID="Microsoft.OLEDBCommand" contactInfo="OLE DB Command;Microsoft Corporation; Microsoft SQL Server; (C) Microsoft Corporation; All Rights Reserved; http://www.microsoft.com/sql/support;2" description="Runs an SQL statement for each row in a data flow. For example, call a ' + "'" + 'new employee setup' + "'" + ' stored procedure for each row in the ' + "'" + 'new employees' + "'" + ' table. Note: running an SQL statement for each row of a large data flow may take a long time." name="Update Customer (SCD1)" usesDispositions="true" version="2">' + "`r`n")
Add ('            <properties>' + "`r`n")
Add ('              <property dataType="System.Int32" description="The number of seconds before a command times out.  A value of 0 indicates an infinite time-out." name="CommandTimeout">0</property>' + "`r`n")
Add ('              <property dataType="System.String" description="The SQL command to be executed." expressionType="Notify" name="SqlCommand" UITypeEditor="Microsoft.DataTransformationServices.Controls.ModalMultilineStringEditor">UPDATE Sales.DimCustomer' + "`r`n")
Add ('SET CompanyName=?, Name=?, Title=?, Phone=?, Email=?, OfficeAddress=?, City=?, State=?, Country=?' + "`r`n")
Add ('WHERE  CustomerAltKey=?</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the column code page to use when code page information is unavailable from the data source." name="DefaultCodePage">1252</property>' + "`r`n")
Add ('            </properties>' + "`r`n")
Add ('            <connections>' + "`r`n")
Add ('              <connection refId="' + $cmdRef + '.Connections[OleDbConnection]" connectionManagerID="' + $DWPRe + '" connectionManagerRefId="' + $DWPRe + '" description="The OLE DB runtime connection used to access the database." name="OleDbConnection" />' + "`r`n")
Add ('            </connections>' + "`r`n")
Add ('            <inputs>' + "`r`n")
Add ('              <input refId="' + $cmdInRef + '" errorOrTruncationOperation="Command Execution" errorRowDisposition="FailComponent" hasSideEffects="true" name="OLE DB Command Input">' + "`r`n")
Add ('                <inputColumns>' + "`r`n")
$cmdParams = @(
    @{n='CompanyName';   t='wstr';     l='128'; s=$srcRef+'.Outputs[OLE DB Source Output].Columns[CompanyName]' },
    @{n='Name';          t='wstr';     l='50';  s=$nameLine },
    @{n='Title';         t='wstr';     l='8';   s=$srcRef+'.Outputs[OLE DB Source Output].Columns[Title]' },
    @{n='Phone';         t='wstr';     l='25';  s=$srcRef+'.Outputs[OLE DB Source Output].Columns[Phone]' },
    @{n='Email';         t='wstr';     l='50';  s=$srcRef+'.Outputs[OLE DB Source Output].Columns[Email]' },
    @{n='OfficeAddress'; t='wstr';     l='60';  s=$srcRef+'.Outputs[OLE DB Source Output].Columns[OfficeAddress]' },
    @{n='City';          t='wstr';     l='50';  s=$srcRef+'.Outputs[OLE DB Source Output].Columns[City]' },
    @{n='State';         t='wstr';     l='50';  s=$srcRef+'.Outputs[OLE DB Source Output].Columns[State]' },
    @{n='Country';       t='wstr';     l='50';  s=$srcRef+'.Outputs[OLE DB Source Output].Columns[Country]' },
    @{n='CustomerID';    t='i4';       l='';    s=$srcRef+'.Outputs[OLE DB Source Output].Columns[CustomerID]' }
)
$i = 0
foreach ($p in $cmdParams) {
    $cachedL = if ($p.l) { 'cachedLength="' + $p.l + '" ' } else { '' }
    $extDt = if ($p.t -eq 'i4') { 'i4' } else { 'wstr' }
    $extL  = if ($p.l) { ' length="' + $p.l + '"' } else { '' }
Add ('                  <inputColumn refId="' + $cmdInRef + '.Columns[' + $p.n + ']" cachedDataType="' + $p.t + '" ' + $cachedL + 'cachedName="' + $p.n + '" externalMetadataColumnId="' + $cmdInRef + '.ExternalColumns[Param_' + $i + ']" lineageId="' + $p.s + '" />' + "`r`n")
    $i++
}
Add ('                </inputColumns>' + "`r`n")
Add ('                <externalMetadataColumns isUsed="True">' + "`r`n")
$i = 0
foreach ($p in $cmdParams) {
    $extDt = if ($p.t -eq 'i4') { 'i4' } else { 'wstr' }
    $extL  = if ($p.l) { ' length="' + $p.l + '"' } else { '' }
Add ('                  <externalMetadataColumn refId="' + $cmdInRef + '.ExternalColumns[Param_' + $i + ']" dataType="' + $extDt + '"' + $extL + ' name="Param_' + $i + '">' + "`r`n")
Add ('                    <properties>' + "`r`n")
Add ('                      <property dataType="System.Int32" description="Parameter information.  Matches OLE DB' + "'" + 's DBPARAMFLAGSENUM values." name="DBParamInfoFlags">65</property>' + "`r`n")
Add ('                    </properties>' + "`r`n")
Add ('                  </externalMetadataColumn>' + "`r`n")
    $i++
}
Add ('                </externalMetadataColumns>' + "`r`n")
Add ('              </input>' + "`r`n")
Add ('            </inputs>' + "`r`n")
Add ('            <outputs>' + "`r`n")
Add ('              <output refId="' + $cmdRef + '.Outputs[OLE DB Command Output]" exclusionGroup="1" name="OLE DB Command Output" synchronousInputId="' + $cmdInRef + '">' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('              <output refId="' + $cmdRef + '.Outputs[OLE DB Command Error Output]" exclusionGroup="1" isErrorOut="true" name="OLE DB Command Error Output" synchronousInputId="' + $cmdInRef + '">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
Add ('                  <outputColumn refId="' + $cmdRef + '.Outputs[OLE DB Command Error Output].Columns[ErrorCode]" dataType="i4" lineageId="' + $cmdRef + '.Outputs[OLE DB Command Error Output].Columns[ErrorCode]" name="ErrorCode" specialFlags="1" />' + "`r`n")
Add ('                  <outputColumn refId="' + $cmdRef + '.Outputs[OLE DB Command Error Output].Columns[ErrorColumn]" dataType="i4" lineageId="' + $cmdRef + '.Outputs[OLE DB Command Error Output].Columns[ErrorColumn]" name="ErrorColumn" specialFlags="2" />' + "`r`n")
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('            </outputs>' + "`r`n")
Add ('          </component>' + "`r`n")

# OLE DB Destination - Insert New Customer
$insCols = @()
$insCols += @{name='CustomerKey';     dt='i4';        extra='';                srcLineage=''}
$insCols += @{name='CustomerAltKey'; dt='i4'; extra=''; srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[CustomerID]'}
$insCols += @{name='CompanyName';    dt='wstr'; extra='length="128"'; srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[CompanyName]'}
$insCols += @{name='Name';           dt='wstr'; extra='length="50"';  srcLineage=$nameLine}
$insCols += @{name='Title';          dt='wstr'; extra='length="8"';   srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[Title]'}
$insCols += @{name='Phone';          dt='wstr'; extra='length="25"';  srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[Phone]'}
$insCols += @{name='Email';          dt='wstr'; extra='length="50"';  srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[Email]'}
$insCols += @{name='OfficeAddress';  dt='wstr'; extra='length="60"';  srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[OfficeAddress]'}
$insCols += @{name='City';           dt='wstr'; extra='length="50"';  srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[City]'}
$insCols += @{name='State';          dt='wstr'; extra='length="50"';  srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[State]'}
$insCols += @{name='Country';        dt='wstr'; extra='length="50"';  srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[Country]'}
OLEDBDest $insRef 'Insert New Customer' $DWPRe '[Sales].[DimCustomer]' $insCols

CloseDF $dfRef @(
    (MkPath 'OLE DB Source Output' ($srcRef + '.Outputs[OLE DB Source Output]') ($derRef + '.Inputs[Derived Column Input]')),
    (MkPath 'Derived Column Output' ($derRef + '.Outputs[Derived Column Output]') ($lkRef + '.Inputs[Lookup Input]')),
    (MkPath 'Lookup Match Output' ($lkRef + '.Outputs[Lookup Match Output]') ($cmdRef + '.Inputs[OLE DB Command Input]')),
    (MkPath 'Lookup No Match Output' ($lkRef + '.Outputs[Lookup No Match Output]') ($insRef + '.Inputs[OLE DB Destination Input]'))
)
CloseSeq
EndSeq

# =====================================================================
# 4) Load DimProduct (SCD2)
# =====================================================================
OpenSeq 'Package\Load DimProduct (SCD2)' 'Load DimProduct (SCD2)' (GUID 'Seq-DimProduct')
$dfRef = 'Package\Load DimProduct (SCD2)\Load DimProduct'
$srcRef = $dfRef + '\OLE DB Source'
$derRef = $dfRef + '\Add Effective Start Date'
$lkRef  = $dfRef + '\Lookup Current Product'
$spRef  = $dfRef + '\Detect Product Changes'
$cmdRef = $dfRef + '\Expire Current Version'
$insChgRef = $dfRef + '\Insert New Product Version'
$insNewRef = $dfRef + '\Insert New Product'

$prodQ = @'
SELECT P.ProductID, P.Name AS ProductName, P.ProductNumber, P.Color, P.Size, P.Weight, P.StandardCost AS Cost, P.ListPrice AS Price, P.SellStartDate, P.SellEndDate, PM.Name AS ProductModel, PC.Name AS Category, PC2.Name AS SubCategory, PD.Description
FROM [dbo].[Product] P
LEFT JOIN [dbo].[ProductModel] PM ON P.ProductModelID = PM.ProductModelID
LEFT JOIN [dbo].[ProductCategory] PC ON P.ProductCategoryID = PC.ProductCategoryID
LEFT JOIN [dbo].[ProductCategory] PC2 ON PC.ParentProductCategoryID = PC2.ProductCategoryID
LEFT JOIN [dbo].[ProductModel_Description] PMD ON P.ProductModelID = PMD.ProductModelID AND PMD.Culture = 'en'
LEFT JOIN [dbo].[ProductDescription] PD ON PMD.ProductDescriptionID = PD.ProductDescriptionID
'@
$prodCols = @(
    @{name='ProductID';    dt='i4';        extra=''},
    @{name='ProductName';  dt='wstr';      extra='length="50"'},
    @{name='ProductNumber';dt='wstr';      extra='length="25"'},
    @{name='Color';        dt='wstr';      extra='length="15"'},
    @{name='Size';         dt='wstr';      extra='length="5"'},
    @{name='Weight';       dt='numeric';   extra='precision="8" scale="2"'},
    @{name='Cost';         dt='numeric';   extra='precision="19" scale="4"'},
    @{name='Price';        dt='numeric';   extra='precision="19" scale="4"'},
    @{name='SellStartDate';dt='dbTimeStamp';extra=''},
    @{name='SellEndDate';  dt='dbTimeStamp';extra=''},
    @{name='ProductModel'; dt='wstr';      extra='length="50"'},
    @{name='Category';     dt='wstr';      extra='length="50"'},
    @{name='SubCategory';  dt='wstr';      extra='length="50"'},
    @{name='Description';  dt='wstr';      extra='length="400"'}
)

OpenDF $dfRef 'Load DimProduct' (GUID 'DF-DimProduct')
OLEDBSource $srcRef 'OLE DB Source' $StaPre $prodQ $null $prodCols

# Derived Column - EffectiveStartDate = CurrentJobTime
AddDerivedColumn $derRef 'Add Effective Start Date' @() @(
    @{name='EffectiveStartDate'; dataType='dbTimeStamp'; extra=''; expr='@[User::CurrentJobTime]'; friendly='@[User::CurrentJobTime]'}
)

# Lookup - current version by ProductAltKey (EffectiveEndDate IS NULL)
$prodRefCmd = @'
SELECT ProductKey, ProductAltKey, ProductName AS RefProductName, Price AS RefPrice, Cost AS RefCost, Category AS RefCategory, SubCategory AS RefSubCategory, Color AS RefColor, Size AS RefSize
FROM Sales.DimProduct
WHERE EffectiveEndDate IS NULL
'@
$prodRefCmdParam = @'
select * from (SELECT ProductKey, ProductAltKey, ProductName AS RefProductName, Price AS RefPrice, Cost AS RefCost, Category AS RefCategory, SubCategory AS RefSubCategory, Color AS RefColor, Size AS RefSize
FROM Sales.DimProduct
WHERE EffectiveEndDate IS NULL) [refTable]
where [refTable].[ProductAltKey] = ?
'@
$prodRefMeta = '<referenceMetadata><referenceColumns><referenceColumn name="ProductKey" dataType="DT_I4" precision="10" scale="0" codePage="0"/><referenceColumn name="ProductAltKey" dataType="DT_I4" precision="10" scale="0" codePage="0"/><referenceColumn name="RefProductName" dataType="DT_WSTR" length="400" precision="0" scale="0" codePage="0"/><referenceColumn name="RefPrice" dataType="DT_NUMERIC" precision="19" scale="4" codePage="0"/><referenceColumn name="RefCost" dataType="DT_NUMERIC" precision="19" scale="4" codePage="0"/><referenceColumn name="RefCategory" dataType="DT_WSTR" length="400" precision="0" scale="0" codePage="0"/><referenceColumn name="RefSubCategory" dataType="DT_WSTR" length="400" precision="0" scale="0" codePage="0"/><referenceColumn name="RefColor" dataType="DT_WSTR" length="400" precision="0" scale="0" codePage="0"/><referenceColumn name="RefSize" dataType="DT_WSTR" length="400" precision="0" scale="0" codePage="0"/></referenceColumns></referenceMetadata>'
AddLookup $lkRef 'Lookup Current Product' $DWPRe $prodRefCmd $prodRefCmdParam $prodRefMeta ($srcRef + '.Outputs[OLE DB Source Output].Columns[ProductID]') @(
    @{name='ProductID'; dt='i4'; len=''; lineage=($srcRef+'.Outputs[OLE DB Source Output].Columns[ProductID]'); joinTo='ProductAltKey'}
) @(
    @{name='ProductKey';      dataType='i4';     extra=''; copyFrom='ProductKey'},
    @{name='RefProductName';  dataType='wstr';   extra='length="400"'; copyFrom='RefProductName'},
    @{name='RefPrice';        dataType='numeric';extra='precision="19" scale="4"'; copyFrom='RefPrice'},
    @{name='RefCost';         dataType='numeric';extra='precision="19" scale="4"'; copyFrom='RefCost'},
    @{name='RefCategory';     dataType='wstr';   extra='length="400"'; copyFrom='RefCategory'},
    @{name='RefSubCategory';  dataType='wstr';   extra='length="400"'; copyFrom='RefSubCategory'},
    @{name='RefColor';        dataType='wstr';   extra='length="400"'; copyFrom='RefColor'},
    @{name='RefSize';         dataType='wstr';   extra='length="400"'; copyFrom='RefSize'}
)

# Conditional Split - Detect Product Changes
$spInRef = $spRef + '.Inputs[Conditional Split Input]'
$spExpr = '(ISNULL(#{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefProductName]}) ? "" : #{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefProductName]}) != (ISNULL(#{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[ProductName]}) ? "" : #{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[ProductName]}) || (ISNULL(#{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefPrice]}) ? 0 : #{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefPrice]}) != (ISNULL(#{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[Price]}) ? 0 : #{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[Price]}) || (ISNULL(#{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefCost]}) ? 0 : #{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefCost]}) != (ISNULL(#{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[Cost]}) ? 0 : #{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[Cost]}) || (ISNULL(#{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefCategory]}) ? "" : #{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefCategory]}) != (ISNULL(#{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[Category]}) ? "" : #{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[Category]}) || (ISNULL(#{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefSubCategory]}) ? "" : #{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefSubCategory]}) != (ISNULL(#{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[SubCategory]}) ? "" : #{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[SubCategory]}) || (ISNULL(#{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefColor]}) ? "" : #{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefColor]}) != (ISNULL(#{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[Color]}) ? "" : #{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[Color]}) || (ISNULL(#{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefSize]}) ? "" : #{' + $lkRef + '.Outputs[Lookup Match Output].Columns[RefSize]}) != (ISNULL(#{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[Size]}) ? "" : #{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[Size]})'
$spFriendly = '(ISNULL(RefProductName) ? "" : RefProductName) != (ISNULL(ProductName) ? "" : ProductName) || (ISNULL(RefPrice) ? 0 : RefPrice) != (ISNULL(Price) ? 0 : Price) || (ISNULL(RefCost) ? 0 : RefCost) != (ISNULL(Cost) ? 0 : Cost) || (ISNULL(RefCategory) ? "" : RefCategory) != (ISNULL(Category) ? "" : Category) || (ISNULL(RefSubCategory) ? "" : RefSubCategory) != (ISNULL(SubCategory) ? "" : SubCategory) || (ISNULL(RefColor) ? "" : RefColor) != (ISNULL(Color) ? "" : Color) || (ISNULL(RefSize) ? "" : RefSize) != (ISNULL(Size) ? "" : Size)'
Add ('          <component refId="' + $spRef + '" componentClassID="Microsoft.ConditionalSplit" contactInfo="Conditional Split;Microsoft Corporation; Microsoft SQL Server; (C) Microsoft Corporation; All Rights Reserved; http://www.microsoft.com/sql/support;0" description="Routes data rows to different outputs depending on the content of the data." name="Detect Product Changes" usesDispositions="true">' + "`r`n")
Add ('            <inputs>' + "`r`n")
Add ('              <input refId="' + $spInRef + '" description="Input to the Conditional Split Transformation" name="Conditional Split Input">' + "`r`n")
Add ('                <inputColumns>' + "`r`n")
$spInputCols = @(
    @{n='ProductName';  t='wstr';  len='50';  l=$srcRef+'.Outputs[OLE DB Source Output].Columns[ProductName]'},
    @{n='Price';        t='numeric'; len=''; l=$srcRef+'.Outputs[OLE DB Source Output].Columns[Price]'},
    @{n='Cost';         t='numeric'; len=''; l=$srcRef+'.Outputs[OLE DB Source Output].Columns[Cost]'},
    @{n='Category';     t='wstr';  len='50';  l=$srcRef+'.Outputs[OLE DB Source Output].Columns[Category]'},
    @{n='SubCategory';  t='wstr';  len='50';  l=$srcRef+'.Outputs[OLE DB Source Output].Columns[SubCategory]'},
    @{n='Color';        t='wstr';  len='15';  l=$srcRef+'.Outputs[OLE DB Source Output].Columns[Color]'},
    @{n='Size';         t='wstr';  len='5';   l=$srcRef+'.Outputs[OLE DB Source Output].Columns[Size]'},
    @{n='RefProductName'; t='wstr'; len='400'; l=$lkRef+'.Outputs[Lookup Match Output].Columns[RefProductName]'},
    @{n='RefPrice';     t='numeric'; len='';  l=$lkRef+'.Outputs[Lookup Match Output].Columns[RefPrice]'},
    @{n='RefCost';      t='numeric'; len='';  l=$lkRef+'.Outputs[Lookup Match Output].Columns[RefCost]'},
    @{n='RefCategory';  t='wstr';  len='400'; l=$lkRef+'.Outputs[Lookup Match Output].Columns[RefCategory]'},
    @{n='RefSubCategory'; t='wstr'; len='400'; l=$lkRef+'.Outputs[Lookup Match Output].Columns[RefSubCategory]'},
    @{n='RefColor';     t='wstr';  len='400'; l=$lkRef+'.Outputs[Lookup Match Output].Columns[RefColor]'},
    @{n='RefSize';      t='wstr';  len='400'; l=$lkRef+'.Outputs[Lookup Match Output].Columns[RefSize]'}
)
foreach ($ic in $spInputCols) {
    $cachedL = if ($ic.len) { 'cachedLength="' + $ic.len + '" ' } else { '' }
Add ('                  <inputColumn refId="' + $spInRef + '.Columns[' + $ic.n + ']" cachedDataType="' + $ic.t + '" ' + $cachedL + 'cachedName="' + $ic.n + '" lineageId="' + $ic.l + '" />' + "`r`n")
}
Add ('                </inputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </input>' + "`r`n")
Add ('            </inputs>' + "`r`n")
Add ('            <outputs>' + "`r`n")
Add ('              <output refId="' + $spRef + '.Outputs[Changed]" description="Output 1 of the Conditional Split Transformation" errorOrTruncationOperation="Computation" errorRowDisposition="FailComponent" exclusionGroup="1" name="Changed" synchronousInputId="' + $spInRef + '" truncationRowDisposition="FailComponent">' + "`r`n")
Add ('                <properties>' + "`r`n")
Add ('                  <property containsID="true" dataType="System.String" description="Specifies the expression. This expression version uses lineage identifiers instead of column names." name="Expression">' + (EscText $spExpr) + '</property>' + "`r`n")
Add ('                  <property containsID="true" dataType="System.String" description="Specifies the friendly version of the expression. This expression version uses column names." expressionType="Notify" name="FriendlyExpression">' + (EscText $spFriendly) + '</property>' + "`r`n")
Add ('                  <property dataType="System.Int32" description="Specifies the position of the condition in the list of conditions that the transformation evaluates. The evaluation order is from the lowest to the highest value." name="EvaluationOrder">0</property>' + "`r`n")
Add ('                </properties>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('              <output refId="' + $spRef + '.Outputs[Unchanged]" description="Default Output of the Conditional Split Transformation" exclusionGroup="1" name="Unchanged" synchronousInputId="' + $spInRef + '">' + "`r`n")
Add ('                <properties>' + "`r`n")
Add ('                  <property dataType="System.Boolean" name="IsDefaultOut">true</property>' + "`r`n")
Add ('                </properties>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('              <output refId="' + $spRef + '.Outputs[Conditional Split Error Output]" description="Error Output of the Conditional Split Transformation" exclusionGroup="1" isErrorOut="true" name="Conditional Split Error Output" synchronousInputId="' + $spInRef + '">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
Add ('                  <outputColumn refId="' + $spRef + '.Outputs[Conditional Split Error Output].Columns[ErrorCode]" dataType="i4" lineageId="' + $spRef + '.Outputs[Conditional Split Error Output].Columns[ErrorCode]" name="ErrorCode" specialFlags="1" />' + "`r`n")
Add ('                  <outputColumn refId="' + $spRef + '.Outputs[Conditional Split Error Output].Columns[ErrorColumn]" dataType="i4" lineageId="' + $spRef + '.Outputs[Conditional Split Error Output].Columns[ErrorColumn]" name="ErrorColumn" specialFlags="2" />' + "`r`n")
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('            </outputs>' + "`r`n")
Add ('          </component>' + "`r`n")

# OLE DB Command - Expire Current Version
$cmdInRef = $cmdRef + '.Inputs[OLE DB Command Input]'
Add ('          <component refId="' + $cmdRef + '" componentClassID="Microsoft.OLEDBCommand" contactInfo="OLE DB Command;Microsoft Corporation; Microsoft SQL Server; (C) Microsoft Corporation; All Rights Reserved; http://www.microsoft.com/sql/support;2" description="Runs an SQL statement for each row in a data flow." name="Expire Current Version" usesDispositions="true" version="2">' + "`r`n")
Add ('            <properties>' + "`r`n")
Add ('              <property dataType="System.Int32" description="The number of seconds before a command times out.  A value of 0 indicates an infinite time-out." name="CommandTimeout">0</property>' + "`r`n")
Add ('              <property dataType="System.String" description="The SQL command to be executed." expressionType="Notify" name="SqlCommand" UITypeEditor="Microsoft.DataTransformationServices.Controls.ModalMultilineStringEditor">UPDATE Sales.DimProduct' + "`r`n")
Add ('SET EffectiveEndDate=?' + "`r`n")
Add ('WHERE  ProductKey=? AND EffectiveEndDate IS NULL</property>' + "`r`n")
Add ('              <property dataType="System.Int32" description="Specifies the column code page to use when code page information is unavailable from the data source." name="DefaultCodePage">1252</property>' + "`r`n")
Add ('            </properties>' + "`r`n")
Add ('            <connections>' + "`r`n")
Add ('              <connection refId="' + $cmdRef + '.Connections[OleDbConnection]" connectionManagerID="' + $DWPRe + '" connectionManagerRefId="' + $DWPRe + '" description="The OLE DB runtime connection used to access the database." name="OleDbConnection" />' + "`r`n")
Add ('            </connections>' + "`r`n")
Add ('            <inputs>' + "`r`n")
Add ('              <input refId="' + $cmdInRef + '" errorOrTruncationOperation="Command Execution" errorRowDisposition="FailComponent" hasSideEffects="true" name="OLE DB Command Input">' + "`r`n")
Add ('                <inputColumns>' + "`r`n")
$expParams = @(
    @{n='EffectiveStartDate'; t='dbTimeStamp'; ext='dbTimeStamp2'; scale='7'; l=''; s=$derRef+'.Outputs[Derived Column Output].Columns[EffectiveStartDate]' },
    @{n='ProductKey';         t='i4';          ext='';             scale='';  l=''; s=$lkRef+'.Outputs[Lookup Match Output].Columns[ProductKey]' }
)
$i = 0
foreach ($p in $expParams) {
    $cachedL = if ($p.l) { 'cachedLength="' + $p.l + '" ' } else { '' }
Add ('                  <inputColumn refId="' + $cmdInRef + '.Columns[' + $p.n + ']" cachedDataType="' + $p.t + '" ' + $cachedL + 'cachedName="' + $p.n + '" externalMetadataColumnId="' + $cmdInRef + '.ExternalColumns[Param_' + $i + ']" lineageId="' + $p.s + '" />' + "`r`n")
    $i++
}
Add ('                </inputColumns>' + "`r`n")
Add ('                <externalMetadataColumns isUsed="True">' + "`r`n")
$i = 0
foreach ($p in $expParams) {
    $extT = if ($p.ext) { $p.ext } else { $p.t }
    $scaleAttr = if ($p.scale) { ' scale="' + $p.scale + '"' } else { '' }
Add ('                  <externalMetadataColumn refId="' + $cmdInRef + '.ExternalColumns[Param_' + $i + ']" dataType="' + $extT + '"' + $scaleAttr + ' name="Param_' + $i + '">' + "`r`n")
Add ('                    <properties>' + "`r`n")
Add ('                      <property dataType="System.Int32" description="Parameter information.  Matches OLE DB' + "'" + 's DBPARAMFLAGSENUM values." name="DBParamInfoFlags">65</property>' + "`r`n")
Add ('                    </properties>' + "`r`n")
Add ('                  </externalMetadataColumn>' + "`r`n")
    $i++
}
Add ('                </externalMetadataColumns>' + "`r`n")
Add ('              </input>' + "`r`n")
Add ('            </inputs>' + "`r`n")
Add ('            <outputs>' + "`r`n")
Add ('              <output refId="' + $cmdRef + '.Outputs[OLE DB Command Output]" exclusionGroup="1" name="OLE DB Command Output" synchronousInputId="' + $cmdInRef + '">' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('              <output refId="' + $cmdRef + '.Outputs[OLE DB Command Error Output]" exclusionGroup="1" isErrorOut="true" name="OLE DB Command Error Output" synchronousInputId="' + $cmdInRef + '">' + "`r`n")
Add ('                <outputColumns>' + "`r`n")
Add ('                  <outputColumn refId="' + $cmdRef + '.Outputs[OLE DB Command Error Output].Columns[ErrorCode]" dataType="i4" lineageId="' + $cmdRef + '.Outputs[OLE DB Command Error Output].Columns[ErrorCode]" name="ErrorCode" specialFlags="1" />' + "`r`n")
Add ('                  <outputColumn refId="' + $cmdRef + '.Outputs[OLE DB Command Error Output].Columns[ErrorColumn]" dataType="i4" lineageId="' + $cmdRef + '.Outputs[OLE DB Command Error Output].Columns[ErrorColumn]" name="ErrorColumn" specialFlags="2" />' + "`r`n")
Add ('                </outputColumns>' + "`r`n")
Add ('                <externalMetadataColumns />' + "`r`n")
Add ('              </output>' + "`r`n")
Add ('            </outputs>' + "`r`n")
Add ('          </component>' + "`r`n")

# Destinations
$prodInsCols = @()
$prodInsCols += @{name='ProductKey';        dt='i4';        extra='';                       srcLineage=''}
$prodInsCols += @{name='ProductAltKey';    dt='i4';        extra='';                       srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[ProductID]'}
$prodInsCols += @{name='EffectiveEndDate'; dt='dbTimeStamp';ext='dbTimeStamp2';scale='7';   extra='';                       srcLineage=''}
$prodInsCols += @{name='ProductNumber';    dt='wstr';      extra='length="400"';           srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[ProductNumber]'}
$prodInsCols += @{name='ProductName';      dt='wstr';      extra='length="400"';           srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[ProductName]'}
$prodInsCols += @{name='ProductModel';     dt='wstr';      extra='length="400"';           srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[ProductModel]'}
$prodInsCols += @{name='Category';         dt='wstr';      extra='length="400"';           srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[Category]'}
$prodInsCols += @{name='SubCategory';      dt='wstr';      extra='length="400"';           srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[SubCategory]'}
$prodInsCols += @{name='Description';      dt='wstr';      extra='length="400"';           srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[Description]'}
$prodInsCols += @{name='SellStartDate';    dt='dbTimeStamp';extra='';                      srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[SellStartDate]'}
$prodInsCols += @{name='SellEndDate';      dt='dbTimeStamp';extra='';                      srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[SellEndDate]'}
$prodInsCols += @{name='Size';             dt='wstr';      extra='length="400"';           srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[Size]'}
$prodInsCols += @{name='Color';            dt='wstr';      extra='length="400"';           srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[Color]'}
$prodInsCols += @{name='Weight';           dt='numeric';   extra='precision="18" scale="4"';srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[Weight]'}
$prodInsCols += @{name='Cost';             dt='numeric';   extra='precision="19" scale="4"';srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[Cost]'}
$prodInsCols += @{name='Price';            dt='numeric';   extra='precision="19" scale="4"';srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[Price]'}
$prodInsCols += @{name='EffectiveStartDate';dt='dbTimeStamp';ext='dbTimeStamp2';scale='7';extra='';                     srcLineage=$derRef+'.Outputs[Derived Column Output].Columns[EffectiveStartDate]'}
OLEDBDest $insChgRef 'Insert New Product Version' $DWPRe '[Sales].[DimProduct]' $prodInsCols
OLEDBDest $insNewRef 'Insert New Product' $DWPRe '[Sales].[DimProduct]' $prodInsCols

CloseDF $dfRef @(
    (MkPath 'OLE DB Source Output' ($srcRef + '.Outputs[OLE DB Source Output]') ($derRef + '.Inputs[Derived Column Input]')),
    (MkPath 'Derived Column Output' ($derRef + '.Outputs[Derived Column Output]') ($lkRef + '.Inputs[Lookup Input]')),
    (MkPath 'Lookup Match Output' ($lkRef + '.Outputs[Lookup Match Output]') ($spRef + '.Inputs[Conditional Split Input]')),
    (MkPath 'Changed' ($spRef + '.Outputs[Changed]') ($cmdRef + '.Inputs[OLE DB Command Input]')),
    (MkPath 'OLE DB Command Output' ($cmdRef + '.Outputs[OLE DB Command Output]') ($insChgRef + '.Inputs[OLE DB Destination Input]')),
    (MkPath 'Lookup No Match Output' ($lkRef + '.Outputs[Lookup No Match Output]') ($insNewRef + '.Inputs[OLE DB Destination Input]'))
)
CloseSeq
EndSeq

# =====================================================================
# 5) Load FactSales
# =====================================================================
OpenSeq 'Package\Load FactSales' 'Load FactSales' (GUID 'Seq-FactSales')
$dfRef = 'Package\Load FactSales\Load FactSales'
$srcRef = $dfRef + '\OLE DB Source'
$derRef = $dfRef + '\Prepare Fact Columns'
$lkCRef = $dfRef + '\Lookup Customer'
$lkPRef = $dfRef + '\Lookup Product'
$lkORef = $dfRef + '\Lookup Order Date'
$lkSRef = $dfRef + '\Lookup Ship Date'
$insRef = $dfRef + '\Load FactSales'
$b1Ref  = $dfRef + '\Bad Rows - Customer'
$b2Ref  = $dfRef + '\Bad Rows - Product'
$b3Ref  = $dfRef + '\Bad Rows - Order Date'
$b4Ref  = $dfRef + '\Bad Rows - Ship Date'

$factQ = @'
SELECT SOH.SalesOrderID, SOD.SalesOrderDetailID, SOH.CustomerID, SOD.ProductID, SOH.OrderDate, SOH.ShipDate, SOH.BatchYear, SOH.BatchMonth, SOH.SubTotal, SOH.TaxAmt, SOH.Freight, SOH.TotalDue, SOD.OrderQty, SOD.UnitPrice, SOD.UnitPriceDiscount, SOD.LineTotal
FROM [dbo].[SalesOrderHeader] SOH
INNER JOIN [dbo].[SalesOrderDetails] SOD ON SOH.SalesOrderID = SOD.OrderID
'@
$factCols = @(
    @{name='SalesOrderID';      dt='i4';      extra=''},
    @{name='SalesOrderDetailID';dt='i4';      extra=''},
    @{name='CustomerID';        dt='i4';      extra=''},
    @{name='ProductID';         dt='i4';      extra=''},
    @{name='OrderDate';         dt='dbTimeStamp';extra=''},
    @{name='ShipDate';          dt='dbTimeStamp';extra=''},
    @{name='BatchYear';         dt='i4';      extra=''},
    @{name='BatchMonth';        dt='i4';      extra=''},
    @{name='SubTotal';          dt='numeric'; extra='precision="19" scale="4"'},
    @{name='TaxAmt';            dt='numeric'; extra='precision="19" scale="4"'},
    @{name='Freight';           dt='numeric'; extra='precision="19" scale="4"'},
    @{name='TotalDue';          dt='numeric'; extra='precision="19" scale="4"'},
    @{name='OrderQty';          dt='numeric'; extra='precision="19" scale="4"'},
    @{name='UnitPrice';         dt='numeric'; extra='precision="19" scale="4"'},
    @{name='UnitPriceDiscount'; dt='numeric'; extra='precision="19" scale="4"'},
    @{name='LineTotal';         dt='numeric'; extra='precision="19" scale="4"'}
)

OpenDF $dfRef 'Load FactSales' (GUID 'DF-FactSales')
OLEDBSource $srcRef 'OLE DB Source' $StaPre $factQ $null $factCols

# Derived - ShipDateClean = ISNULL(ShipDate) ? OrderDate : ShipDate
AddDerivedColumn $derRef 'Prepare Fact Columns' @(
    @{name='ShipDate'; dt='dbTimeStamp'; len=''; lineage=($srcRef+'.Outputs[OLE DB Source Output].Columns[ShipDate]')},
    @{name='OrderDate'; dt='dbTimeStamp'; len=''; lineage=($srcRef+'.Outputs[OLE DB Source Output].Columns[OrderDate]')}
) @(
    @{name='ShipDateClean'; dataType='dbTimeStamp'; extra=''; expr='ISNULL(#{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[ShipDate]}) ? #{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[OrderDate]} : #{' + $srcRef + '.Outputs[OLE DB Source Output].Columns[ShipDate]}'; friendly='ISNULL(ShipDate) ? OrderDate : ShipDate'}
)

# Lookup Customer -> CustomerKey
$custRefCmd = 'SELECT CustomerKey, CustomerAltKey FROM Sales.DimCustomer'
$custRefCmdParam = 'select * from (SELECT CustomerKey, CustomerAltKey FROM Sales.DimCustomer) [refTable]' + "`n" + 'where [refTable].[CustomerAltKey] = ?'
$custRefMeta = '<referenceMetadata><referenceColumns><referenceColumn name="CustomerKey" dataType="DT_I4" precision="10" scale="0" codePage="0"/><referenceColumn name="CustomerAltKey" dataType="DT_I4" precision="10" scale="0" codePage="0"/></referenceColumns></referenceMetadata>'
AddLookup $lkCRef 'Lookup Customer' $DWPRe $custRefCmd $custRefCmdParam $custRefMeta ($srcRef + '.Outputs[OLE DB Source Output].Columns[CustomerID]') @(
    @{name='CustomerID'; dt='i4'; len=''; lineage=($srcRef+'.Outputs[OLE DB Source Output].Columns[CustomerID]'); joinTo='CustomerAltKey'}
) @(
    @{name='CustomerKey'; dataType='i4'; extra=''; copyFrom='CustomerKey'}
)

# Lookup Product -> ProductKey (current version only)
$prodRefCmd = 'SELECT ProductKey, ProductAltKey FROM Sales.DimProduct WHERE EffectiveEndDate IS NULL'
$prodRefCmdParam = 'select * from (SELECT ProductKey, ProductAltKey FROM Sales.DimProduct WHERE EffectiveEndDate IS NULL) [refTable]' + "`n" + 'where [refTable].[ProductAltKey] = ?'
$prodRefMeta = '<referenceMetadata><referenceColumns><referenceColumn name="ProductKey" dataType="DT_I4" precision="10" scale="0" codePage="0"/><referenceColumn name="ProductAltKey" dataType="DT_I4" precision="10" scale="0" codePage="0"/></referenceColumns></referenceMetadata>'
AddLookup $lkPRef 'Lookup Product' $DWPRe $prodRefCmd $prodRefCmdParam $prodRefMeta ($srcRef + '.Outputs[OLE DB Source Output].Columns[ProductID]') @(
    @{name='ProductID'; dt='i4'; len=''; lineage=($srcRef+'.Outputs[OLE DB Source Output].Columns[ProductID]'); joinTo='ProductAltKey'}
) @(
    @{name='ProductKey'; dataType='i4'; extra=''; copyFrom='ProductKey'}
)

# Lookup Order Date -> OrderDateKey
$dateRefCmd = 'SELECT DateKey AS OrderDateKey, CONVERT(DATETIME, FullDateAlternateKey) AS FullDateAlternateKey FROM dbo.DimDate'
$dateRefCmdParam = 'select * from (SELECT DateKey AS OrderDateKey, CONVERT(DATETIME, FullDateAlternateKey) AS FullDateAlternateKey FROM dbo.DimDate) [refTable]' + "`n" + 'where [refTable].[FullDateAlternateKey] = ?'
$dateRefMeta = '<referenceMetadata><referenceColumns><referenceColumn name="OrderDateKey" dataType="DT_I4" precision="10" scale="0" codePage="0"/><referenceColumn name="FullDateAlternateKey" dataType="DT_DBTIMESTAMP" precision="0" scale="0" codePage="0"/></referenceColumns></referenceMetadata>'
AddLookup $lkORef 'Lookup Order Date' $DWPRe $dateRefCmd $dateRefCmdParam $dateRefMeta ($srcRef + '.Outputs[OLE DB Source Output].Columns[OrderDate]') @(
    @{name='OrderDate'; dt='dbTimeStamp'; len=''; lineage=($srcRef+'.Outputs[OLE DB Source Output].Columns[OrderDate]'); joinTo='FullDateAlternateKey'}
) @(
    @{name='OrderDateKey'; dataType='i4'; extra=''; copyFrom='OrderDateKey'}
)

# Lookup Ship Date -> ShipDateKey (uses ShipDateClean)
$dateRefCmd2 = 'SELECT DateKey AS ShipDateKey, CONVERT(DATETIME, FullDateAlternateKey) AS FullDateAlternateKey FROM dbo.DimDate'
$dateRefCmdParam2 = 'select * from (SELECT DateKey AS ShipDateKey, CONVERT(DATETIME, FullDateAlternateKey) AS FullDateAlternateKey FROM dbo.DimDate) [refTable]' + "`n" + 'where [refTable].[FullDateAlternateKey] = ?'
$dateRefMeta2 = '<referenceMetadata><referenceColumns><referenceColumn name="ShipDateKey" dataType="DT_I4" precision="10" scale="0" codePage="0"/><referenceColumn name="FullDateAlternateKey" dataType="DT_DBTIMESTAMP" precision="0" scale="0" codePage="0"/></referenceColumns></referenceMetadata>'
AddLookup $lkSRef 'Lookup Ship Date' $DWPRe $dateRefCmd2 $dateRefCmdParam2 $dateRefMeta2 ($derRef + '.Outputs[Derived Column Output].Columns[ShipDateClean]') @(
    @{name='ShipDateClean'; dt='dbTimeStamp'; len=''; lineage=($derRef+'.Outputs[Derived Column Output].Columns[ShipDateClean]'); joinTo='FullDateAlternateKey'}
) @(
    @{name='ShipDateKey'; dataType='i4'; extra=''; copyFrom='ShipDateKey'}
)

# Main fact destination
$factInsCols = @()
$factInsCols += @{name='SalesOrderID';      dt='i4';      extra='';                       srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[SalesOrderID]'}
$factInsCols += @{name='SalesOrderDetailID';dt='i4';      extra='';                       srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[SalesOrderDetailID]'}
$factInsCols += @{name='BatchMonth';        dt='i4';      extra='';                       srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[BatchMonth]'}
$factInsCols += @{name='BatchYear';         dt='i4';      extra='';                       srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[BatchYear]'}
$factInsCols += @{name='OrderDateKey';      dt='i4';      extra='';                       srcLineage=$lkORef+'.Outputs[Lookup Match Output].Columns[OrderDateKey]'}
$factInsCols += @{name='ShipDateKey';       dt='i4';      extra='';                       srcLineage=$lkSRef+'.Outputs[Lookup Match Output].Columns[ShipDateKey]'}
$factInsCols += @{name='SubTotal';          dt='numeric'; extra='precision="19" scale="4"';srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[SubTotal]'}
$factInsCols += @{name='Freight';           dt='numeric'; extra='precision="19" scale="4"';srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[Freight]'}
$factInsCols += @{name='Tax';               dt='numeric'; extra='precision="19" scale="4"';srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[TaxAmt]'}
$factInsCols += @{name='TotalAmount';       dt='numeric'; extra='precision="19" scale="4"';srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[TotalDue]'}
$factInsCols += @{name='CustomerKey';       dt='i4';      extra='';                       srcLineage=$lkCRef+'.Outputs[Lookup Match Output].Columns[CustomerKey]'}
$factInsCols += @{name='ProductKey';        dt='i4';      extra='';                       srcLineage=$lkPRef+'.Outputs[Lookup Match Output].Columns[ProductKey]'}
$factInsCols += @{name='UnitPrice';         dt='cy';      extra='';                       srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[UnitPrice]'}
$factInsCols += @{name='Quantity';          dt='i4';      extra='';                       srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[OrderQty]'}
$factInsCols += @{name='Discount';          dt='cy';      extra='';                       srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[UnitPriceDiscount]'}
$factInsCols += @{name='LineTotal';         dt='cy';      extra='';                       srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[LineTotal]'}
OLEDBDest $insRef 'Load FactSales' $DWPRe '[Sales].[FactSales]' $factInsCols

# Bad-row destinations
$badCols = @()
$badCols += @{name='ErrorDescription';  dt='wstr';      extra='length="400"'; srcLineage=''}
$badCols += @{name='ErrorTimestamp';    dt='dbTimeStamp'; extra='';           srcLineage=''}
$badCols += @{name='SalesOrderID';      dt='i4';      extra=''; srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[SalesOrderID]'}
$badCols += @{name='SalesOrderDetailID';dt='i4';      extra=''; srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[SalesOrderDetailID]'}
$badCols += @{name='CustomerID';        dt='i4';      extra=''; srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[CustomerID]'}
$badCols += @{name='ProductID';         dt='i4';      extra=''; srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[ProductID]'}
$badCols += @{name='OrderDate';         dt='dbTimeStamp'; extra=''; srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[OrderDate]'}
$badCols += @{name='ShipDate';          dt='dbTimeStamp'; extra=''; srcLineage=$srcRef+'.Outputs[OLE DB Source Output].Columns[ShipDate]'}
OLEDBDest $b1Ref 'Bad Rows - Customer' $DWPRe '[Sales].[FactSales_BadRows]' $badCols
OLEDBDest $b2Ref 'Bad Rows - Product' $DWPRe '[Sales].[FactSales_BadRows]' $badCols
OLEDBDest $b3Ref 'Bad Rows - Order Date' $DWPRe '[Sales].[FactSales_BadRows]' $badCols
OLEDBDest $b4Ref 'Bad Rows - Ship Date' $DWPRe '[Sales].[FactSales_BadRows]' $badCols

CloseDF $dfRef @(
    (MkPath 'OLE DB Source Output' ($srcRef + '.Outputs[OLE DB Source Output]') ($derRef + '.Inputs[Derived Column Input]'))
    (MkPath 'Derived Column Output' ($derRef + '.Outputs[Derived Column Output]') ($lkCRef + '.Inputs[Lookup Input]'))
    (MkPath 'Lookup Customer Match Output' ($lkCRef + '.Outputs[Lookup Match Output]') ($lkPRef + '.Inputs[Lookup Input]'))
    (MkPath 'Lookup Product Match Output' ($lkPRef + '.Outputs[Lookup Match Output]') ($lkORef + '.Inputs[Lookup Input]'))
    (MkPath 'Lookup Order Date Match Output' ($lkORef + '.Outputs[Lookup Match Output]') ($lkSRef + '.Inputs[Lookup Input]'))
    (MkPath 'Lookup Ship Date Match Output' ($lkSRef + '.Outputs[Lookup Match Output]') ($insRef + '.Inputs[OLE DB Destination Input]'))
    (MkPath 'Lookup Customer No Match Output' ($lkCRef + '.Outputs[Lookup No Match Output]') ($b1Ref + '.Inputs[OLE DB Destination Input]'))
    (MkPath 'Lookup Product No Match Output' ($lkPRef + '.Outputs[Lookup No Match Output]') ($b2Ref + '.Inputs[OLE DB Destination Input]'))
    (MkPath 'Lookup Order Date No Match Output' ($lkORef + '.Outputs[Lookup No Match Output]') ($b3Ref + '.Inputs[OLE DB Destination Input]'))
    (MkPath 'Lookup Ship Date No Match Output' ($lkSRef + '.Outputs[Lookup No Match Output]') ($b4Ref + '.Inputs[OLE DB Destination Input]'))
)
CloseSeq
EndSeq

# =====================================================================
# 6) Post Load sequence
# =====================================================================
OpenSeq 'Package\Post Load' 'Post Load' (GUID 'Seq-PostLoad')
OpenTask 'Package\Post Load\Update Watermark' 'Update Watermark' (GUID 'Task-UpdateWatermark') 'Microsoft.ExecuteSQLTask' 'Execute SQL Task' 'Execute SQL Task; Microsoft Corporation; SQL Server 2016; c 2015 Microsoft Corporation; All Rights Reserved;http://www.microsoft.com/sql/support/default.asp;1'
Add ('            <SQLTask:SqlTaskData' + "`r`n")
Add ('              SQLTask:Connection="' + (GUID 'CM-DW') + '"' + "`r`n")
Add ('              SQLTask:SqlStatementSource="UPDATE [dbo].[Watermark] SET LastSuccessfulRun = ?"' + "`r`n")
Add ('              SQLTask:ResultType="ResultSetType_None" xmlns:SQLTask="www.microsoft.com/sqlserver/dts/tasks/sqltask">' + "`r`n")
Add ('              <SQLTask:ParameterBinding SQLTask:ParameterName="0" SQLTask:DtsVariableName="User::CurrentJobTime" SQLTask:ParameterDirection="Input" SQLTask:DataType="7" SQLTask:ParameterSize="16" />' + "`r`n")
Add ('            </SQLTask:SqlTaskData>' + "`r`n")
CloseTask
CloseSeq
EndSeq
Add ('    </DTS:Executables>' + "`r`n")

# =====================================================================
# Package-level precedence constraints
# =====================================================================
Add ('  <DTS:PrecedenceConstraints>' + "`r`n")
SeqConstraint 'Package' 'Package\Initialize' 'Package\Load Staging' (GUID 'PC-1') 'Initialize -> Load Staging'
SeqConstraint 'Package' 'Package\Load Staging' 'Package\Load DimCustomer (SCD1)' (GUID 'PC-2') 'Load Staging -> Load DimCustomer (SCD1)'
SeqConstraint 'Package' 'Package\Load DimCustomer (SCD1)' 'Package\Load DimProduct (SCD2)' (GUID 'PC-3') 'Load DimCustomer (SCD1) -> Load DimProduct (SCD2)'
SeqConstraint 'Package' 'Package\Load DimProduct (SCD2)' 'Package\Load FactSales' (GUID 'PC-4') 'Load DimProduct (SCD2) -> Load FactSales'
SeqConstraint 'Package' 'Package\Load FactSales' 'Package\Post Load' (GUID 'PC-5') 'Load FactSales -> Post Load'
Add ('  </DTS:PrecedenceConstraints>' + "`r`n")
Add ('  <DTS:DesignTimeProperties />' + "`r`n")
Add ('</DTS:Executable>' + "`r`n")

# ---------------- write output ----------------
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("Wrote " + $out)
Write-Host ("Size: " + $sb.Length + " chars")

<#
Functions:
    Private:
        R01 - Update-PowerStigCKL
        R02 - Set-PowerStigResultHashTable
        R03 - Get-PowerStigFindings
        R04 - Convert-PowerStigTest
        R05 - Import-PowerStigObject
    Public:
        R06 - New-PowerStigCKL
#>

#region Private

#R01
<#
.SYNOPSIS
Queries SQL for results based on date to generate .ckl file

.DESCRIPTION
Queries SQL for results based on date, if no date is given then the most recent results will be returned.
This uses a blank .CKL file as a base to generate a new file.

.PARAMETER Role
Type of CKL file that is to be generated such as DC for Domain Controller

.PARAMETER osVersion
Current version of Operating System that is being used on the target server

.PARAMETER TargetServerName
Name of the Server that was previously tested

.PARAMETER sqlInstance
Database instance holding the powerstig database

.PARAMETER OutPath
Location that the ckl file will be saved. Directory will be created if needed.

.EXAMPLE
Update-PowerStigCkl -Role DC -osVersion 2012R2 -TargetServerName TestDC1 -sqlInstance SqlTest,49314 -outPath C:\ckl\thisckl.ckl

.NOTES
General notes
#>
function Update-PowerStigCkl
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("MS","DC","IE11","DNS","FW","Client","DotNet","Excel2013","PowerPoint2013","Word2013","Outlook2013","Firefox","IIS","OracleJRE","SQL")]
        [String]$Role,

        [Parameter(Mandatory=$true)]
        [ValidateSet("2012R2","2016")]
        [String]$osVersion,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$TargetServerName,

        [Parameter(Mandatory=$false)]
        [String]$sqlInstance,

        [Parameter(Mandatory=$false)]
        [String]$DatabaseName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$outPath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$GUID
    )
    
    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($SqlInstance -eq $null -or $SqlInstance -eq '')
    {
        $SqlInstance = $iniVar.SqlInstanceName
    }
    if($DatabaseName -eq $null -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }


    # generate file name
    if($Role -ne "MS" -and $Role -ne "DC")
    {
        [String]$fileName = $Role + "Empty.ckl"
    }
    else
    {
        [String]$fileName = $osVersion + $Role + "Empty.ckl"
    }

    # Pull CKL to variable
    [xml]$CKL = Get-Content -Path "$(Split-Path $psCommandPath)\CKL\$fileName"
    # Without this line, Severity_override, severity_justification, comments, etc. will all format incorrectly.
    # And will not be able to sort by Category
    $CKL.PreserveWhitespace = $true

    # Strictly declare constants that are standard for CKL files
    $isNotAFinding = "NotAFinding"
    $isFinding = "Open"
    $isNull = "Not_Reviewed"

    # Gather the results from SQL and create hash table of the results based on VulnID and isFinding
    $Results = Set-PowerStigResultHashTable -inputObject (Get-PowerStigFindings -SqlInstance $SqlInstance -DatabaseName $DatabaseName -ServerName $TargetServerName -Guid $GUID)

    ## Each Rule is covered at $ckl.CHECKLIST.STIGS.iSTIG
    ## VulnID is under STIGDATA[0].ATTRIBUTE_DATA
    ## Finding is under Status    
    ## Search HashTable for VulnID
    foreach($i in $CKL.CHECKLIST.STIGS.iSTIG.Vuln)
    {
        #initiate variables for current rules being evaluated
        $boolNotAFinding = $null
        $currentRule = $i.STIG_DATA[0].ATTRIBUTE_DATA

        # $results.$currentRule will return either $true or $false if it exists as a result
        $boolNotAFinding = $results.$currentRule

        # if it didn't find a rule, ensure that there is not an entry type like V-####.a
        # if there are, evaluate all rules with the same number with a letter suffix and determine if all true
        # if there is one false, rule evaluates as false
        if($null -eq $boolNotAFinding)
        {
            $testRule = $results.keys | Where-Object {$_ -like "$currentRule.*"}
            if (-not($null -eq $testRule))
            {
                $ruleResult = $true
                foreach($tRule in $testRule)
                {
                    #if you evaluate one rule as false, output is a finding, break loop
                    if($results.$tRule -eq $false)
                    {
                        $ruleResult = $false
                        continue
                    }
                }
                $boolNotAFinding = $ruleResult
            }
        }
        # Set status field in xml
        if($boolNotAFinding -eq $true)
        {
            $i.STATUS = $isNotAFinding
        }
        elseif($boolNotAFinding -eq $false)
        {
            $i.STATUS = $isFinding
        }
        elseif($null -eq $boolNotAFinding)
        {
            $i.STATUS = $isNull
        }
    }

    if(-not(Test-Path -Path (Split-Path $outPath)))
    {
        New-Item -ItemType Directory -Path (Split-Path $outPath)
    }

    $CKL.save($outPath)
}

#R02
<#
.SYNOPSIS
Creates and returns a hashtable based on a input object generated from SQL results.

.DESCRIPTION
This function relies on database output being formated as Finding with type String and InDesiredState as type Boolean
Finding should be in the format V-##### with either four or five numbers and possibly appended by a dot letter.
Returns a hash table that can be easily searched for results

.PARAMETER inputObject
Object that includes database results, best used with the function Get-PowerStigFindings
#>
function Set-PowerStigResultHashTable
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [PSObject]$inputObject
    )
    
    $hash=@{}

    foreach($i in $inputObject)
    {
        $hash.add($($i.Finding),$($i.InDesiredState))
    }

    return $hash
}

#R03
<#
.SYNOPSIS
Retrieves the most recent PowerStig findings from the database and returns the database results.

.DESCRIPTION
Calls the database to retrieve the PowerStig findings for the target server. Returns two columns; Finding and InDesiredState.
Finding is a type String attribute. InDesiredState is a type Boolean attribute.
Is paired with Set-PowerStigResultHashTable to create a searchable object to generate ckl files.

.PARAMETER SqlInstance
Target SQL instance that holds the PowerStig database. 
If empty, will use the settings configured in the config.ini file located in the modulepath\common filepath 

.PARAMETER DatabaseName
Name of database on server that holds the PowerStig tables

.PARAMETER ServerName
Name of Server to retrieve results for.

.EXAMPLE
Get-PowerStigFindings -SqlInstance "SQL2012TEST,49314" -DatabaseName Master -ServerName dc2012test
#>
function Get-PowerStigFindings
{
    #Returns Columns Finding, InDesiredState
    #Finding is in format V-## - Type String
    #InDesiredState is in format True or False - Type Boolean :)
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [String]$SqlInstance,

        [Parameter(Mandatory=$false)]
        [String]$DatabaseName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$ServerName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$GUID
    )

    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($SqlInstance -eq $null -or $SqlInstance -eq '')
    {
        $SqlInstance = $iniVar.SqlInstanceName
    }
    if($DatabaseName -eq $null -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }

    $query = "PowerSTIG.GetComplianceStateByServer @TargetComputer = '$ServerName', @GUID = '$GUID'"
    $Results = Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $query

    Return $Results
}

#R04
function Convert-PowerStigTest
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSObject]$TestResults
    )

    $FullResults = $TestResults.ResourcesInDesiredState + $TestResults.ResourcesNotInDesiredState

    $OutputArr = @()

    $ScanDate = (Get-Date).ToString()

    foreach($i in $FullResults)
    {   
        $BoolState = $i.InDesiredState
         
        $strMod = $i.InstanceName
        $strMod = $strMod.Split("][")
        if($strMod[6] -eq "Skip")
        { Continue }
        Else
        {
            $VidOutPut = $strMod[1]
            $Severity = $strMod[3]
            $Definition = $strMod[5]
            $sType = $strMod[8]

            $propHash = @{
                VulnID = $VidOutPut
                DesiredState = $BoolState
                FindingSeverity = $Severity
                StigDefinition = $Definition
                StigType = $sType
                ScanDate = $ScanDate
            }

            $currentObj = New-Object PSObject -Property $propHash


            $outputArr += $currentObj
        }

        

    }

    Return $OutputArr


}

#R05
function Import-PowerStigObject
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName,

        [Parameter(Mandatory=$true)]
        [PSObject[]]$inputObj
    )

    $guid = New-Guid

    foreach($o in $inputObj)
    {
        $query = "EXEC PowerSTIG.sproc_InsertFindingImport @PSComputerName = `'$ServerName`', @VulnID = `'$($o.VulnID)`', @DesiredState = `'$($o.DesiredState)`', @FindingSeverity = `'$($o.FindingSeverity)`', @StigDefinition = `'$($o.StigDefinition)`', @StigType = `'$($o.StigType)`', @ScanDate = `'$($o.ScanDate)`', @GUID = `'$($guid.guid)`'"
        $Results = Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $query
    }

    #Process Finding
    $query = "EXEC PowerSTIG.sproc_ProcessFindings @GUID = `'$($guid.guid)`'"
    $Results = Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $query

}

#endregion Private

#region Public

#R06
<#
.SYNOPSIS
Generated a DISA Checklist file from scan results stored in the target SQL Database

.DESCRIPTION
Pulls PowerStig scan data from a SQL database and parses the information to populate a DISA checklist file.

.PARAMETER ServerName
The server name that the checklist will be generated for.

.PARAMETER osVersion
Version of the operating system that was present on the server. Valid options are 2012R2 and 2016

.PARAMETER Role
The role for which a checklist file is to be generated.

.PARAMETER outPath
File path for the finished checklist file, should end with <Filename>.ckl

.PARAMETER sqlInstance
SQL Instance to be queried for results. If this is left empty, it will use the entries in the config.ini in the ModuleBase\Common directory.

.PARAMETER DatabaseName

.EXAMPLE
#>
function New-PowerStigCkl
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$ServerName,

        [Parameter(Mandatory=$true)]
        [ValidateSet("2012R2","2016")]
        [String]$osVersion,

        [Parameter(Mandatory=$true)]
        [ValidateSet("MS","DC","FW","IE11","DNS","Client","Excel2013","PowerPoint2013","Word2013","Outlook2013","FireFox","DotNet","JRE","IIS","SQL")]
        [String]$Role,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$GUID,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [String]$outPath,
        
        [Parameter(Mandatory=$false)]
        [String]$sqlInstance,

        [Parameter(Mandatory=$false)]
        [String]$DatabaseName

    )
    
    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($sqlInstance -eq $null -or $sqlInstance -eq '')
    {
        $sqlInstance = $iniVar.SqlInstanceName
    }
    if($DatabaseName -eq $null -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }
    if($outPath -eq $null -or $outPath -eq '')
    {
        $outPath = $iniVar.CKLOutPath
    }


    Update-PowerStigCkl -TargetServerName $ServerName -osVersion $osVersion -Role $Role -OutPath $outPath -sqlInstance $sqlInstance -DatabaseName $DatabaseName -GUID $GUID
}

#endregion Public
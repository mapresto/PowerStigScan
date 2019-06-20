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
        [ValidateSet("2012R2","2016","10","All")]
        [String]$osVersion,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$ServerName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$Role,

        [Parameter(Mandatory=$true)]
        [HashTable]$InputObject,

        [Parameter(Mandatory=$true)]
        [HashTable]$SourceHash,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [String]$OutPath
    )

    
    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($null -eq $outPath -or $outPath -eq '')
    {
        $outPath = $iniVar.CKLOutPath
    }

    $Timestamp = (get-date).ToString("MMddyyyyHHmmss")
    $outFileName = $ServerName + "_" + $Role + "_" + $Timestamp + ".ckl"

    # generate file name
    If($role -notlike "WindowsServer*" -and $role -notlike "*WindowsDNSServer*")
    {
        [String]$fileName = $Role + "Empty.ckl"
    }
    elseif($Role -eq "WindowsDNSServer") 
    {    
        [String]$fileName = $osVersion + $role + "Empty.ckl"
    }
    elseif($Role -like "WindowsServer*")
    {
        if($osVersion -eq "2012R2")
        {
            [String]$fileName = $osVersion + $role + "Empty.ckl"
        }
        elseif($osVersion -eq '2016')
        {
        [String]$fileName = $osVersion + "WindowsServerEmpty.ckl"
        }
    }
    

    # Pull CKL to variable
    [xml]$CKL = Get-Content -Path "$(Split-Path $psCommandPath)\CKL\$fileName" -Encoding UTF8
    # Without this line, Severity_override, severity_justification, comments, etc. will all format incorrectly.
    # And will not be able to sort by Category
    $CKL.PreserveWhitespace = $true

    # Strictly declare constants that are standard for CKL files
    $isNotAFinding = "NotAFinding"
    $isFinding = "Open"
    $isNull = "Not_Reviewed"


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
        $boolNotAFinding = $InputObject.$currentRule

        # if it didn't find a rule, ensure that there is not an entry type like V-####.a
        # if there are, evaluate all rules with the same number with a letter suffix and determine if all true
        # if there is one false, rule evaluates as false
        if($null -eq $boolNotAFinding)
        {
            $testRule = $InputObject.keys | Where-Object {$_ -like "$currentRule.*"}
            if (-not($null -eq $testRule))
            {
                $ruleResult = $true
                foreach($tRule in $testRule)
                {
                    #if you evaluate one rule as false, output is a finding, break loop
                    if($InputObject.$tRule -eq $false)
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
            if($SourceHash."$currentRule" -eq "0")
            {
                $i.COMMENTS = "Result is from PowerStig"
            }
            elseif ($SourceHash."$CurrentRule" -eq "1") 
            {
                $i.COMMENTS = "Result is from SCAP"
            }
        }
        elseif($boolNotAFinding -eq $false)
        {
            $i.STATUS = $isFinding
            if($SourceHash."$currentRule" -eq "0")
            {
                $i.COMMENTS = "Result is from PowerStig"
            }
            elseif ($SourceHash."$CurrentRule" -eq "1") 
            {
                $i.COMMENTS = "Result is from SCAP"
            }
        }
        elseif($null -eq $boolNotAFinding)
        {
            $i.STATUS = $isNull
        }
    }

    if(-not(Test-Path -Path $outPath))
    {
        New-Item -ItemType Directory -Path $outPath -Force | Out-Null
    }

    $CKL.save("$outPath\$outFileName")
    
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

Function Set-PowerStigResultHashTableFromObject
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [PSObject]$InputObject
    )

    $outHash = @{}
    $tempHash = @{}
    [Regex]$VIDRegex = "V-([1-9}])[0-9]{3}[0-9]?"

    foreach($i in $InputObject)
    {
        [bool]$tempBool = $i.DesiredState
        $tempHash.add($($i.VulnID),$tempBool)
    }

    foreach($i in $tempHash.keys)
    {
        $vID = $VIDRegex.Matches($i).value
        
        $testRule = $tempHash.keys | Where-Object {$_ -like "$vID.*"}
        if($testRule.count -ge 2 -and $outHash.Contains($vID))
        {
            Continue
        }
        if (-not($null -eq $testRule))
        {
            $ruleResult = $true
            foreach($tRule in $testRule)
            {
                #if you evaluate one rule as false, output is a finding, break loop
                if($tempHash.$tRule -eq $false)
                {
                    $ruleResult = $false
                    continue
                }
            }
            $outHash.add($vID,$ruleResult)
        }
        else 
        {
            $outHash.add($i,$($tempHash.$i))
        }
    }


    Return $outHash
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

    if($null -eq $SqlInstance -or $SqlInstance -eq '')
    {
        $SqlInstance = $iniVar.SqlInstanceName
    }
    if($null -eq $DatabaseName -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }

    $query = "EXEC PowerSTIG.sproc_GetComplianceStateByServer @TargetComputer = '$ServerName', @GUID = '$GUID'"
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
    [Regex]$VIDRegex = "V-([1-9}])[0-9]{3}[0-9]?\.?[a-z]?"
    $FullResults = $TestResults.ResourcesInDesiredState + $TestResults.ResourcesNotInDesiredState

    $OutputArr = @()

    $ScanDate = (Get-Date).ToString()

    foreach($i in $FullResults)
    {   
        if($VIDRegex.match($i.InstanceName).success -eq $false)
        {
            Continue
        }
        $BoolState = $i.InDesiredState
         
        $strMod = $i.InstanceName
        $strMod = $strMod.Split("][")
        if($strMod[6] -eq "Skip")
        { Continue }
        Else
        {
            $VidOutPut = $VIDRegex.match($i.InstanceName).value

            $propHash = @{
                VulnID = $VidOutPut
                DesiredState = $BoolState
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
        [PSObject[]]$inputObj,

        # Role is not strictly defined due to SCAP
        [Parameter(Mandatory=$true)]
        [String]$Role,

        [Parameter(Mandatory=$true)]
        [ValidateSet('SCAP','POWERSTIG')]
        [String]$ScanSource,

        [Parameter(Mandatory=$true)]
        [String]$ScanVersion
    )

    $guid = New-Guid

    foreach($o in $inputObj)
    {
        $query = "EXEC PowerSTIG.sproc_InsertFindingImport @PSComputerName = `'$ServerName`', @VulnID = `'$($o.VulnID)`', @DesiredState = `'$($o.DesiredState)`', @ScanDate = `'$($o.ScanDate)`', @GUID = `'$($guid.guid)`', @StigType=`'$Role`', @ScanSource = `'$ScanSource`', @ScanVersion=`'$ScanVersion`'"
        Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $query | Out-Null
    }

    #Process Finding
    $query = "EXEC PowerSTIG.sproc_ProcessFindings @GUID = `'$($guid.guid)`'"
    Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $query | Out-Null

    return

}

#endregion Private

#region Public
#endregion Public
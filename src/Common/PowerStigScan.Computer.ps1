#region Private

#endregion Private

#region Public

#CM01
<#
.SYNOPSIS
Adds a new computer target to the PowerStig database

.DESCRIPTION
Adds a new computer target to the PowerStig database to be scanned with the -SQLBatch switch on Invoke-PowerStigScan

.PARAMETER ServerName
Name of server to add

.PARAMETER SqlInstance
SQL instance name that hosts the PowerStig database. If empty, this will use the settings in the ModuleBase\Common\config.ini file.

.PARAMETER DatabaseName
Name of the database that hosts the PowerStig tables. If empty, this will use the settings in the ModuleBase\Common\config.ini file.

.EXAMPLE
Add-PowerStigComputer -ServerName DC2012Test -SqlInstance SQLTest -DatabaseName Master
Add-PowerStigComputer -ServerName PowerStigTest

#>
function Add-PowerStigComputer
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$ServerName,

        [switch]$DebugScript,

        [Parameter(Mandatory=$false)]
        [String]$SqlInstance,

        [Parameter(Mandatory=$false)]
        [String]$DatabaseName
    )

    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($null -eq $sqlInstance -or $sqlInstance -eq '')
    {
        $sqlInstance = $iniVar.SqlInstanceName
    }
    if($null -eq $DatabaseName -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }

    

    $Query = "PowerSTIG.sproc_AddTargetComputer @TargetComputerName = `"$ServerName`""

    if($DebugScript)
    {
        Write-Host $query
    }
    $Results = Invoke-PowerStigSqlCommand -Query $Query -SqlInstance $SqlInstance -DatabaseName $DatabaseName
    return $Results 
    
}

#CM02
function Get-PowerStigComputer
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$DebugScript,

        [Parameter()]
        [String]$SqlInstance,
        
        [Parameter()]
        [String]$DatabaseName
        
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


    $GetAllServers = "EXEC PowerSTIG.sproc_GetActiveServers"
    if($DebugScript)
    {
        Write-Host $GetAllServers
    }
    $RunGetAllServers = (Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $GetAllServers)

    Return $RunGetAllServers
}

#CM03
function Set-PowerStigComputer
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName,

        [Parameter(Mandatory=$true)]
        [ValidateSet('2012R2','2016','10')]
        [String]$osVersion,

        [switch]$DebugScript,

        [Parameter()]
        [String]$SqlInstance,

        [Parameter()]
        [String]$DatabaseName
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


    $UpdateComputer = "EXEC PowerSTIG.sproc_UpdateTargetOS @TargetComputer=`"$ServerName`", @OSname=`"$osVersion`""
    Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $UpdateComputer
    
}

#CM04
function Remove-PowerStigComputer
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName,

        [Parameter()]
        [Switch]$Force,

        [switch]$DebugScript,

        [Parameter()]
        [String]$SqlInstance,

        [Parameter()]
        [String]$DatabaseName
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

    if(!($Force))
    {
        
        $readIn = Read-Host "This will remove $ServerName and all data related to the computer from the database. Continue?(Y/N)"
        do{
            if($readIn -eq "N")
            {
                Write-Host "Cancelling"
                Return
            }
            elseif($readIn -eq "Y")
            {
                $proceed = $true
            }
            else
            {
                $readIn = Read-Host "Invalid response. Do you want to remove $ServerName? (Y/N)"
            }
        }While($proceed -eq $false)
    }
    

    $deleteComputer = "EXEC PowerSTIG.sproc_DeleteTargetComputerAndData @TargetComputer = `'$ServerName`'"
    if($DebugScript)
    {
        Write-Host $deleteComputer
    }
    Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $deleteComputer 

}


#endregion Public
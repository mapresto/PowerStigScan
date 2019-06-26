#region Private

#endregion Private

#region Public


<#
.SYNOPSIS
Adds a new computer target to the PowerStig database

.DESCRIPTION
Adds a new computer target to the PowerStig database to be scanned with the -SQLBatch switch on Invoke-PowerStigScan

.PARAMETER ServerName
Name of the computer you would like to add.

.PARAMETER SqlInstanceName
SQL instance name that hosts the PowerStig database. If empty, this will use the settings in the ModuleBase\Common\config.ini file.

.PARAMETER DatabaseName
Name of the database that hosts the PowerStig tables. If empty, this will use the settings in the ModuleBase\Common\config.ini file.

.EXAMPLE
Add-PowerStigComputer -ComputerName DC2012Test -SqlInstanceName SQLTest -DatabaseName Master
Add-PowerStigComputer -ComputerName PowerStigTest
#>

function Add-PowerStigComputer
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$ComputerName,

        [switch]$DebugScript,

        [Parameter(Mandatory=$false)]
        [String]$SqlInstanceName,

        [Parameter(Mandatory=$false)]
        [String]$DatabaseName
    )

    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($null -eq $sqlInstanceName -or $sqlInstanceName -eq '')
    {
        $sqlInstanceName = $iniVar.SqlInstanceName
    }
    if($null -eq $DatabaseName -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }

    

    $Query = "PowerSTIG.sproc_AddTargetComputer @TargetComputerName = `"$ComputerName`""

    if($DebugScript)
    {
        Write-Host $query
    }
    $Results = Invoke-PowerStigSqlCommand -Query $Query -SqlInstance $SqlInstance -DatabaseName $DatabaseName
    return $Results 
    
}


<#
.SYNOPSIS
Retrieves the name of computers that are listed in SQL to scan against.

.DESCRIPTION
In order to use the SQL batch function of Invoke-PowerStigScan. You must prepopulate the table with computers that you want to scan. This functions lists the comptuers that will be targeted.

.PARAMETER SqlInstanceName
Name of the Sql Instance to connect to. If this is blank, the value in the config.ini file is used instead. This value can be seen by using Get-PowerStigConfig.

.PARAMETER DatabaseName
Name of the Database to connect to. If this is blank, the value in the config.ini file is used instead. This value can be seen by using Get-PowerStigConfig.

.EXAMPLE
Get-PowerStigComputer
#>

function Get-PowerStigComputer
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [String]$SqlInstanceName,
        
        [Parameter()]
        [String]$DatabaseName
        
    )

    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($null -eq $SqlInstanceName -or $SqlInstanceName -eq '')
    {
        $SqlInstanceName = $iniVar.SqlInstanceName
    }
    if($null -eq $DatabaseName -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }


    $GetAllServers = "EXEC PowerSTIG.sproc_GetActiveServers"

    $RunGetAllServers = (Invoke-PowerStigSqlCommand -SqlInstance $SqlInstanceName -DatabaseName $DatabaseName -Query $GetAllServers)

    Return $RunGetAllServers
}

#CM03
function Set-PowerStigComputer
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ComputerName,

        [Parameter(Mandatory=$true)]
        [ValidateSet('2012R2','2016','10')]
        [String]$osVersion,

        [Parameter()]
        [String]$SqlInstanceName,

        [Parameter()]
        [String]$DatabaseName
    )

    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($null -eq $SqlInstanceName -or $SqlInstanceName -eq '')
    {
        $SqlInstanceName = $iniVar.SqlInstanceName
    }
    if($null -eq $DatabaseName -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }


    $UpdateComputer = "EXEC PowerSTIG.sproc_UpdateTargetOS @TargetComputer=`"$ComputerName`", @OSname=`"$osVersion`""
    Invoke-PowerStigSqlCommand -SqlInstance $SqlInstanceName -DatabaseName $DatabaseName -Query $UpdateComputer
    
}


<#
.SYNOPSIS
Function to remove a computer from the database for any SQL batch runs

.DESCRIPTION
In order to use the SQL batch function of Invoke-PowerStigScan. You must prepopulate the table with computers that you want to scan. This function allows you to remove computers that you have added, all data associated to that computer will also be removed.

.PARAMETER ServerName
Name of the server you want to remove from the database

.PARAMETER Force
Removes the prompt to check that you meant to remove the computer or server.

.PARAMETER SqlInstanceName
Name of the Sql Instance to connect to. If this is blank, the value in the config.ini file is used instead. This value can be seen by using Get-PowerStigConfig.

.PARAMETER DatabaseName
Name of the Database to connect to. If this is blank, the value in the config.ini file is used instead. This value can be seen by using Get-PowerStigConfig.

.EXAMPLE
Remove-PowerStigComputer -ComputerName BadServer01 -Force
Remove-PowerStigComputer BadServer01
#>

function Remove-PowerStigComputer
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [String]$ComputerName,

        [Parameter()]
        [Switch]$Force,

        [Parameter()]
        [String]$SqlInstanceName,

        [Parameter()]
        [String]$DatabaseName
    )

    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($null -eq $SqlInstanceName -or $SqlInstanceName -eq '')
    {
        $SqlInstanceName = $iniVar.SqlInstanceName
    }
    if($null -eq $DatabaseName -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }

    if(!($Force))
    {
        
        $readIn = Read-Host "This will remove $ComputerName and all data related to the computer from the database. Continue?(Y/N)"
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
                $readIn = Read-Host "Invalid response. Do you want to remove $ComputerName? (Y/N)"
            }
        }While($proceed -eq $false)
    }
    

    $deleteComputer = "EXEC PowerSTIG.sproc_DeleteTargetComputerAndData @TargetComputer = `'$ComputerName`'"

    Invoke-PowerStigSqlCommand -SqlInstance $SqlInstanceName -DatabaseName $DatabaseName -Query $deleteComputer 

}


#endregion Public
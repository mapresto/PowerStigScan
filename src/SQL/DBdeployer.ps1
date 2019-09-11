# =================================================================================================================
# Purpose:
# Revisions:
# 05242019 - Kevin Barlett, Microsoft - v0.1 - Initial creation.
# 07092019 - Kevin Barlett, Microsoft - v0.2 - Added yes/no logic for database creation versus automatic creation.
# 09112019 - Kevin Barlett, Microsoft - v0.3 - Addition of query timeout to database connections.
# =================================================================================================================
# -----------------------------------------------------------------------------
#
# Copyright (C) 2019 Microsoft Corporation
#
# Disclaimer:
#   This is SAMPLE code that is NOT production ready. It is the sole intention of this code to provide a proof of concept as a
#   learning tool for Microsoft Customers. Microsoft does not provide warranty for or guarantee any portion of this code
#   and is NOT responsible for any affects it may have on any system it is executed on  or environment it resides within.
#   Please use this code at your own discretion!
# Additional legalese:
#   This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#   THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#   INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#   We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#   the object code form of the Sample Code, provided that You agree:
#       (i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#      (ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#     (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys' fees,
#           that arise or result from the use or distribution of the Sample Code.
# -----------------------------------------------------------------------------
param(
    [CmdletBinding()]
    [Parameter(ParameterSetName='Set1',Position=0,Mandatory=$true)][String]$DBserverName,
    [parameter(ParameterSetName='Set1',Position=1,Mandatory=$true)][String]$DatabaseName
#   [parameter(ParameterSetName='Set2',Position=2,Mandatory=$true)][String[]]$serverList
)
$Timestamp = (get-date).ToString("MMddyyyyHHmmss")
$CurTime = get-date
$LogFile = ".\DBdeployLog_$Timestamp.txt"
$QueryTimeoutSeconds=300
#========================================================================
# Create logging function
#========================================================================
function log($string, $color)
{
   if ($null -eq $color) {$color = "white"}
   #write-host $string -foregroundcolor $color
   $string | out-file -Filepath $logfile -append
}
$HeaderMessage = "
///////////////////////////////////////////////////////////////////////////////
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
                PowerSTIGscan Database Installer - v0.2
                    $CurTime
///////////////////////////////////////////////////////////////////////////////
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
        " #-foregroundcolor "Red"
        Write-Host $HeaderMessage -ForegroundColor Green
        Log $HeaderMessage
        #$UserContext = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        #$ServerName = $(Get-Content env:computername)
#========================================================================
#Scrub inputs
#========================================================================
$DBServerName = $DBServerName.trim()
#
$DatabaseName = $DatabaseName.trim()
#========================================================================
#Perform test connection
#========================================================================
If (Test-Connection $DBServerName -count 1 -quiet)
	{
        $CurTime = get-date
        [console]::ForegroundColor = "Green"
        $LogMessage = "---> Servername $DBServerName appears to be valid.  Continuing. . ."
            Write-Host $LogMessage
        [console]::ResetColor()
        #
        log [$CurTime]$LogMessage
	}
Else
	{
        $CurTime = get-date
        [console]::ForegroundColor = "Red"
        $LogMessage = "---> Servername $DBServerName appears to be invalid or the server is unavailable.  Please validate the specified SQL Server name.  Exiting."
	        Write-Host $LogMessage
        [console]::ResetColor()
        #
        log [$CurTime]$LogMessage
				EXIT
}
#========================================================================
#Validate database existence
#========================================================================
        $CurTime = get-date
        [console]::ForegroundColor = "Green"
        $LogMessage = "---> Checking for the existence of database [$DatabaseName]"
            Write-Host $LogMessage
        [console]::ResetColor()
        #
        log [$CurTime]$LogMessage


$DBexistsQuery = "SELECT 1 AS DatabaseExists FROM sys.databases
                            where [name] = '$DatabaseName' and [state] = 0 and is_read_only = 0"
                            $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
                            $SqlConnection.ConnectionString = "Server=$DBServerName;Database=master;Connect Timeout=$QueryTimeoutSeconds;Integrated Security=True"
                            $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                            $SqlCmd.CommandText = $DBexistsQuery
                            $SqlCmd.Connection = $SqlConnection
                            $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
                            $SqlAdapter.SelectCommand = $SqlCmd
                            $DataSet = New-Object System.Data.DataSet
                            [void]$SqlAdapter.Fill($DataSet)
                            $SqlConnection.Close()
                            
                            $DBexists =  $DataSet.Tables[0] | Select-Object DatabaseExists -ExpandProperty DatabaseExists
                  

if ($DBexists -ne 1)
    {
        [console]::ForegroundColor = "yellow"
        $LogMessage = "---> Specified database [$DatabaseName] was not found.  Type [Yes] to create the database or [No] to exit the DBdeployer utility and create the database manually."
        Write-Host $LogMessage
    [console]::ForegroundColor = "green"

    #
     $CreateDBchoice = read-host -prompt "Enter [Yes] or [No].  
        --> Yes = The DBdeployer utility will create a database named [$DatabaseName] 
        --> No = The DBdeployer utility will perform no actions and will exit.
        
        *****[Yes] or [No]***** --> "

        while("Yes","No" -notcontains $CreateDBchoice)
            {
                $CreateDBchoice = read-host -prompt "Enter [Yes] or [No].  
                     --> Yes = The DBdeployer utility will create a database named [$DatabaseName] 
                     --> No = The DBdeployer utility will perform no actions and will exit.
        
                  *****[Yes] or [No]***** --> "
            }

            $CreateDBchoice = $CreateDBchoice.Trim()

            # Exit the utility if No is specified.
            if ($CreateDBchoice -eq "No")
                {
                    $CurTime = get-date
                    [console]::ForegroundColor = "Yellow"
                    $LogMessage = "---> Specified database [$DatabaseName] was not found and [$CreateDBchoice] was specified.  No actions performed.  DBdeployer utility exiting."
                    Write-Host $LogMessage
                    [console]::ResetColor()
                    #
                    log [$CurTime]$LogMessage 
                    EXIT
                }
            
        $CurTime = get-date
        [console]::ForegroundColor = "Yellow"
        $LogMessage = "---> Specified database [$DatabaseName] was not found and [$CreateDBchoice] was specified.  Creating database [$DatabaseName] now."
        Write-Host $LogMessage
        [console]::ResetColor()
        #
        log [$CurTime]$LogMessage                    
                        
    try
        {     
  
            $CreateDatabaseQuery = "
                DECLARE @DatabaseName varchar(256)
                SET @DatabaseName = '$DatabaseName'
                DECLARE @DefaultDataLoc varchar(256)
                DECLARE @DefaultLogLoc varchar(256)
                DECLARE @SQLCMD varchar(MAX)
                    SELECT
                    @DefaultDataLoc = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS varchar(256)),
                    @DefaultLogLoc = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS varchar(256))

                    --
                    SET @SQLCMD = 'CREATE DATABASE ['+@DatabaseName+'] ON  PRIMARY (NAME = '''+@DatabaseName+'_data'', FILENAME = '''+@DefaultDataLoc+''+@DatabaseName+'_data.mdf'' , SIZE = 128MB , MAXSIZE = UNLIMITED, FILEGROWTH = 128MB) LOG ON (NAME = '''+@DatabaseName+'_log'', FILENAME = '''+@DefaultLogLoc+''+@DatabaseName+'_log.ldf'' , SIZE = 128MB , MAXSIZE = 2048GB , FILEGROWTH =128MB)'
                    --PRINT @SQLCMD
                    EXEC(@SQLCMD)
                    --
                    SET @SQLCMD = 'ALTER DATABASE ['+@DatabaseName+'] SET RECOVERY SIMPLE'
                    --PRINT @SQLCMD
                    EXEC(@SQLCMD)	
                    --
                    SET @SQLCMD = 'ALTER DATABASE ['+@DatabaseName+'] SET PAGE_VERIFY CHECKSUM'
                    --PRINT @SQLCMD
                    EXEC(@SQLCMD)
                        "
                        $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
                        $SqlConnection.ConnectionString = "Server=$DBServerName;Database=master;Connect Timeout=$QueryTimeoutSeconds;Integrated Security=True"
                        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                        $SqlCmd.CommandText = $CreateDatabaseQuery
                        $SqlCmd.Connection = $SqlConnection
                        $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
                        $SqlAdapter.SelectCommand = $SqlCmd
                        $DataSet = New-Object System.Data.DataSet
                        [void]$SqlAdapter.Fill($DataSet)
                        $SqlConnection.Close()     

    
        $CurTime = get-date
        [console]::ForegroundColor = "Green"
        $LogMessage = "---> Database [$DatabaseName] created successfully."
        Write-Host $LogMessage
        [console]::ResetColor()
        #
        log [$CurTime]$LogMessage 
        }
    catch
        {

        $CurTime = get-date
        [console]::ForegroundColor = "Red"
        $LogMessage = "---> An error was encountered while creating database [$DatabaseName].  Please investigate."
        Write-Host $LogMessage
        [console]::ResetColor()
        #
        log [$CurTime]$LogMessage 


        }             
}       
                    
else
{
        $CurTime = get-date
        [console]::ForegroundColor = "Green"
        $LogMessage = "---> The specified database [$DatabaseName] already exists.  PowerSTIGscan deployment continuing."
        Write-Host $LogMessage
        [console]::ResetColor()
        #
        log [$CurTime]$LogMessage                         
}


#========================================================================
#Execute deployment scripts
#========================================================================
$DeployScripts = Get-ChildItem "$(Split-Path $PsCommandPath)\" | Where-Object {$_.Extension -eq ".sql"} | Sort-Object Name
  
        foreach ($Script in $DeployScripts)
            {
                try {
                    
                
                Write-Host "Executing Script: " $Script.Name -BackgroundColor DarkGreen -ForegroundColor White
                $scriptPath = $Script.FullName
                #write-host $script

                $DatabaseScript = Get-Content $ScriptPath | Out-String
                $ScriptBatches = $DatabaseScript -split "GO\r\n"
                    foreach ($Batch in $ScriptBatches)
                    {
                        
                        $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
                        $SqlConnection.ConnectionString = "Server=$DBServerName;Database=$DatabaseName;Connect Timeout=$QueryTimeoutSeconds;Integrated Security=True"
                        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                        $SqlCmd.CommandText = $Batch;
                        $SqlCmd.Connection = $SqlConnection
                        $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
                        $SqlAdapter.SelectCommand = $SqlCmd
                        $DataSet = New-Object System.Data.DataSet
                        [void]$SqlAdapter.Fill($DataSet)
                        #$SqlAdapter.Fill($DataSet) | Out-Null
                        $SqlConnection.Close()

                    }
                    $CurTime = get-date
                    [console]::ForegroundColor = "Green"
                    $LogMessage = "---> Script [$($script.Name)] executed successfully."
                    #Write-Host $LogMessage
                    [console]::ResetColor()
                    #
                    log [$CurTime]$LogMessage
                    #
                    Write-Host "Execution successful for script: $($Script.Name)" -BackgroundColor DarkGreen -ForegroundColor White
                }
            catch
                {
                        $UpdateApplied =  $DataSet.Tables[0] | Select-Object UpdateApplied -ExpandProperty UpdateApplied
                if ($UpdateApplied -eq 8675309){

                        $CurTime = get-date
                        $LogMessage = "---> Database update previously applied.  This is an informational message only."
                        log [$CurTime]$LogMessage
                        Write-Host $LogMessage -BackgroundColor Yellow -ForegroundColor Black
                }
            else
                {
                    $CurTime = get-date
                    [console]::ForegroundColor = "Green"
                    $LogMessage = "---> Error encountered executing script [$($script.name)].  Please investigate."
                    #Write-Host $LogMessage
                    [console]::ResetColor()
                    #
                    log [$CurTime]$LogMessage
                    #log [$CurTime]$PSItem
                    log [$CurTime]$_
                    #
                    Write-Host "Error encountered executing script: " $Script.Name -BackgroundColor Red -ForegroundColor White

                }
            }
    }
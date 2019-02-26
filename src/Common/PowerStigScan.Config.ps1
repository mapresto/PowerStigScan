<#
Functions:
    CN01 - Get-PowerStigSqlConfig
    CN02 - Set-PowerStigSqlConfig
    CN03 - Get-PowerStigConfig
    CN04 - Set-PowerStigConfig
#>

#region Private

#endregion Private

#region Public
#CN01
<#
.SYNOPSIS
Command to retrieve configuration data from the PowerStig database

.DESCRIPTION
Retrieves information from the ConfigData table in the PowerStig database. This can only retrieve one configuration setting at a time.

.PARAMETER OutputDropLoc
Location to scan for csv files to be imported into the database.

.PARAMETER OutputArchiveLoc
Location to store scanned csv files in compressed format after import.

.PARAMETER ArchiveDirectoryRetentionDays

.PARAMETER FindingRepoTableRetentionDays

.PARAMETER LastComplianceCheckAlert

.PARAMETER LastComplianceCheckInDays

.PARAMETER LastComplianceCheckAlertRecipients

.PARAMETER OutputFileExtension

.PARAMETER DuplicateFileExtension
Extension that will be added to potential duplicate files that are found in the OutputDropLoc

.PARAMETER DuplicateFileAlert

.PARAMETER DuplicateFileAlertRecipients

.PARAMETER ComplianceCheckLogTableRetentionDays

.PARAMETER FindingImportFilesTableRetentionDays

.PARAMETER MailProfileName

.PARAMETER CKLfileLoc

.PARAMETER CKLfileArchiveLoc

.PARAMETER SqlInstance
SQL instance name that hosts the PowerStig database. If empty, this will use the settings in the ModuleBase\Common\config.ini file. 

.PARAMETER DatabaseName
Name of the database that hosts the PowerStig tables. If empty, this will use the settings in the ModuleBase\Common\config.ini file.

.EXAMPLE
Get-PowerStigSqlConfig -SqlInstance TestSQL01 -DatabaseName Master -OutputFileLoc

Get-PowerStigSqlConfig -OutputFileLoc

#>
function Get-PowerStigSqlConfig
{
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName='1',Mandatory=$false)][switch]$FindingRepoRetentionDays,
        [Parameter(ParameterSetName='2',Mandatory=$false)][switch]$LastComplianceCheckAlert,
        [Parameter(ParameterSetName='3',Mandatory=$false)][switch]$LastComplianceCheckInDays,
        [Parameter(ParameterSetName='4',Mandatory=$false)][switch]$LastComplianceCheckAlerRecipients,
        [Parameter(ParameterSetName='5',Mandatory=$false)][switch]$ComplianceCheckLogTableRetentionDays,
        [Parameter(ParameterSetName='6',Mandatory=$false)][switch]$FindingImportFilesTableRetentionDays,
        [Parameter(ParameterSetName='7',Mandatory=$false)][switch]$MailProfileName,
        [Parameter(ParameterSetName='8',Mandatory=$false)][switch]$CKLFileLoc,
        [Parameter(ParameterSetName='9',Mandatory=$false)][switch]$CKLFileArchiveLoc,
        [Parameter(ParameterSetName='10',Mandatory=$false)][switch]$ScanImportLogRetentionDays,
        [Parameter(ParameterSetName='11',Mandatory=$false)][switch]$ScanImportErrorLogRetentionDays,
        [Parameter(ParameterSetName='12',Mandatory=$false)][switch]$ConcurrentScans,
        [Parameter(ParameterSetName='13',Mandatory=$false)][switch]$ScanLogRetentionDays,

        [Parameter(Mandatory=$false)][switch]$DebugScript,
        
        [Parameter(Mandatory=$false)]
        [String]$SqlInstance,

        [Parameter(Mandatory=$false)]
        [String]$DatabaseName
    )
    
    $workingPath                = Split-Path $PsCommandPath
    $iniVar                     = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($null -eq $sqlInstance -or $sqlInstance -eq '')
    {
        $sqlInstance = $iniVar.SqlInstanceName
    }
    if($null -eq $DatabaseName -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }


    Switch($PSCmdlet.ParameterSetName){
        "1"     { $checkConfig = "FindingRepoRetentionDays" }
        "2"     { $checkConfig = "LastComplianceCheckAlert" }
        "3"     { $checkConfig = "LastComplianceCheckInDays" }
        "4"     { $checkConfig = "LastComplianceCheckAlerRecipients" }
        "5"     { $checkConfig = "ComplianceCheckLogTableRetentionDays" }
        "6"     { $checkConfig = "FindingImportFilesTableRetentionDays" }
        "7"     { $checkConfig = "MailProfileName" }
        "8"     { $checkConfig = "CKLFileLoc" }
        "9"     { $checkConfig = "CKLFileArchiveLoc" }
        "10"    { $checkConfig = "ScanImportLogRetentionDays" }
        "11"    { $checkConfig = "ScanImportErrorLogRetentionDays" }
        "12"    { $checkConfig = "ConcurrentScans" }
        "13"    { $checkConfig = "ScanLogRetentionDays" }
    }

    $Query = "powerstig.sproc_GetConfigSetting @ConfigProperty = $checkConfig"
    if($DebugScript)
    {
        Write-Host $Query
    }
    $Results = Invoke-PowerStigSqlCommand -Query $Query -SqlInstance $SqlInstance -DatabaseName $DatabaseName


    return $Results
    
}

#CN02
<#
.SYNOPSIS
Command to allow changes to the configuration database for PowerStig

.DESCRIPTION
Allows for changes to the ConfigData table in the PowerStig database. This can only impact one configuration setting at a time.

.PARAMETER OutputDropLoc
Location to scan for csv files to be imported into the database. Should be a folder path.

.PARAMETER OutputArchiveLoc
Location to store scanned csv files in compressed format after import. Should be a folder path. 

.PARAMETER ArchiveDirectoryRetentionDays

.PARAMETER FindingRepoTableRetentionDays

.PARAMETER LastComplianceCheckAlert

.PARAMETER LastComplianceCheckInDays

.PARAMETER LastComplianceCheckAlertRecipients

.PARAMETER OutputFileExtension

.PARAMETER DuplicateFileExtension
Extension that should be added to potential duplicate files that are found in the OutputDropLoc

.PARAMETER DuplicateFileAlert

.PARAMETER DuplicateFileAlertRecipients

.PARAMETER ComplianceCheckLogTableRetentionDays

.PARAMETER FindingImportFilesTableRetentionDays

.PARAMETER MailProfileName

.PARAMETER CKLfileLoc

.PARAMETER CKLfileArchiveLoc

.PARAMETER SqlInstance
SQL instance name that hosts the PowerStig database. If empty, this will use the settings in the ModuleBase\Common\config.ini file. 

.PARAMETER DatabaseName
Name of the database that hosts the PowerStig tables. If empty, this will use the settings in the ModuleBase\Common\config.ini file.

.EXAMPLE
Set-PowerStigSqlConfig -SqlInstance TestSQL01 -DatabaseName Master -OutputFileLoc C:\Temp\CSV

Set-PowerStigSqlConfig -OutputFileLoc C:\Temp\CSV


#>
function Set-PowerStigSqlConfig
{
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName='1',Mandatory=$false)][ValidateNotNullorEmpty()][String]$FindingRepoRetentionDays,
        [Parameter(ParameterSetName='2',Mandatory=$false)][ValidateNotNullorEmpty()][String]$LastComplianceCheckAlert,
        [Parameter(ParameterSetName='3',Mandatory=$false)][ValidateNotNullorEmpty()][String]$LastComplianceCheckInDays,
        [Parameter(ParameterSetName='4',Mandatory=$false)][ValidateNotNullorEmpty()][String]$LastComplianceCheckAlerRecipients,
        [Parameter(ParameterSetName='5',Mandatory=$false)][ValidateNotNullorEmpty()][String]$ComplianceCheckLogTableRetentionDays,
        [Parameter(ParameterSetName='6',Mandatory=$false)][ValidateNotNullorEmpty()][String]$FindingImportFilesTableRetentionDays,
        [Parameter(ParameterSetName='7',Mandatory=$false)][ValidateNotNullorEmpty()][String]$MailProfileName,
        [Parameter(ParameterSetName='8',Mandatory=$false)][ValidateNotNullorEmpty()][String]$CKLFileLoc,
        [Parameter(ParameterSetName='9',Mandatory=$false)][ValidateNotNullorEmpty()][String]$CKLFileArchiveLoc,
        [Parameter(ParameterSetName='10',Mandatory=$false)][ValidateNotNullorEmpty()][String]$ScanImportLogRetentionDays,
        [Parameter(ParameterSetName='11',Mandatory=$false)][ValidateNotNullorEmpty()][String]$ScanImportErrorLogRetentionDays,
        [Parameter(ParameterSetName='12',Mandatory=$false)][ValidateNotNullorEmpty()][String]$ConcurrentScans,
        [Parameter(ParameterSetName='13',Mandatory=$false)][ValidateNotNullorEmpty()][String]$ScanLogRetentionDays,

        [Parameter(Mandatory=$false)][switch]$DebugScript,
        
        [Parameter(Mandatory=$false)]
        [String]$SqlInstance,

        [Parameter(Mandatory=$false)]
        [String]$DatabaseName
    )
    
    $workingPath                = Split-Path $PsCommandPath
    $iniVar                     = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($null -eq $sqlInstance -or $sqlInstance -eq '')
    {
        $sqlInstance = $iniVar.SqlInstanceName
    }
    if($null -eq $DatabaseName -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }


    #Switch ParameterSet since each stored procedure can only handle a single change
    #TODO switch to a foreach loop per parameter
    Switch($PSCmdlet.ParameterSetName){
        "1"     { 
                    $setConfig = "FindingRepoRetentionDays" 
                    $newConfig = $FindingRepoRetentionDays
                }
        "2"     { 
                    $setConfig = "LastComplianceCheckAlert"
                    $newConfig = $LastComplianceCheckAlert
                }
        "3"     { 
                    $setConfig = "LastComplianceCheckInDays" 
                    $newConfig = $LastComplianceCheckInDays
                }
        "4"     { 
                    $setConfig = "LastComplianceCheckAlerRecipients"
                    $newConfig = $LastComplianceCheckAlerRecipients 
                }
        "5"     { 
                    $setConfig = "ComplianceCheckLogTableRetentionDays" 
                    $newConfig = $ComplianceCheckLogTableRetentionDays
                }
        "6"     { 
                    $setConfig = "FindingImportFilesTableRetentionDays" 
                    $newConfig = $FindingImportFilesTableRetentionDays  
                }
        "7"     { 
                    $setConfig = "MailProfileName" 
                    $newConfig = $MailProfileName
                }
        "8"     { 
                    $setConfig = "CKLFileLoc" 
                    $newConfig = $CKLFileLoc
                }
        "9"     { 
                    $setConfig = "CKLFileArchiveLoc" 
                    $newConfig = $CKLFileArchiveLoc
                }
        "10"    { 
                    $setConfig = "ScanImportLogRetentionDays" 
                    $newConfig = $ScanImportLogRetentionDays
                }
        "11"    { 
                    $setConfig = "ScanImportErrorLogRetentionDays" 
                    $newConfig = $ScanImportErrorLogRetentionDays
                }
        "12"    { 
                    $setConfig = "ConcurrentScans" 
                    $newConfig = $ConcurrentScans
                }
        "13"    { 
                    $setConfig = "ScanLogRetentionDays" 
                    $newConfig = $ScanLogRetentionDays
                }
    }

    # ' is escaped around $newConfig to prevent issues with Strings being passed, removal will cause filepaths to parse incorrectly
    $Query = "powerstig.sproc_UpdateConfig @ConfigProperty = $($setConfig), @NewConfigSetting = `'$newConfig`'"
    if($DebugScript)
    {
        Write-Host $Query
    }
    $Results = Invoke-PowerStigSqlCommand -Query $Query -SqlInstance $SqlInstance -DatabaseName $DatabaseName

    return $Results
    
}

#CN03
<#

#>
function Get-PowerStigConfig
{
    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    $configObject = New-Object PSobject
    Add-Member -InputObject $configObject -NotePropertyName "CKLOutPath" -NotePropertyValue $iniVar.CKLOutPath
    Add-Member -InputObject $configObject -NotePropertyName "LogPath" -NotePropertyValue $iniVar.LogPath
    Add-Member -InputObject $configObject -NotePropertyName "SQLInstanceName" -NotePropertyValue $iniVar.SQLInstanceName
    Add-Member -InputObject $configObject -NotePropertyName "DatabaseName" -NotePropertyValue $iniVar.DatabaseName

    Return $configObject
}

#CN04
<#

#>
function Set-PowerStigConfig
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [String]$CKLOutPath,
        
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [String]$LogPath,
        
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [String]$SqlInstanceName,
        
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [String]$DatabaseName 
    )

    # Pull the current config to cover any unchanged parameter
    $workingObj = Get-PowerStigConfig

    #check each potential parameter, if they are used check to make sure there is an ending dash then write the value
    #to the working object. Working Object will be used to generate the final config file
    if($CKLOutPath -ne '')
    {
        if (!($CKLOutPath.EndsWith("\")))
        {
            $CKLOutPath = $CKLOutPath + "\"
        }
        $workingObj.CKLOutPath = $CKLOutPath
    }
    if($LogPath -ne '')
    {
        if (!($LogPath.EndsWith("\")))
        {
            $LogPath = $LogPath + "\"
        }
        $workingObj.LogPath = $LogPath
    }
    if($SQLInstanceName -ne '')
    {
        $workingObj.SQLInstanceName = $SQLInstanceName
    }
    if($DatabaseName -ne '')
    {
        $workingObj.DatabaseName = $DatabaseName
    }

    $someFile = "; This file must be stored in the same path as the Invoke-PowerStigScan.ps1 file`r`n"
    $someFile += "; All Entries are space sensitive. Further versions will fix input validation.`r`n"
    $someFile += "; When changed, close all active sessions of powershell to reload entries`r`n"
    $someFile += "`r`n"
    $someFile += "[general]`r`n"
    $someFile += "CKLOutPath=$($workingObj.CKLOutPath)`r`n"
    $someFile += "LogPath=$($workingObj.LogPath)`r`n"
    $someFile += "`r`n"
    $someFile += "[database]`r`n"
    $someFile += "SQLInstanceName=$($workingObj.SQLInstanceName)`r`n"
    $someFile += "DatabaseName=$($workingObj.DatabaseName)`r`n"

    $workingPath = Split-Path $PsCommandPath
    $someFile | Out-File -FilePath $workingPath\Config.ini
}


#endregion Public
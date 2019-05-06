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
        [Parameter(ParameterSetName='1',Mandatory=$false)][switch]$OutputDropLoc,
        [Parameter(ParameterSetName='2',Mandatory=$false)][switch]$OutputArchiveLoc,
        [Parameter(ParameterSetName='3',Mandatory=$false)][switch]$ArchiveDirectoryRetentionDays,
        [Parameter(ParameterSetName='4',Mandatory=$false)][switch]$FindingRepoTableRetentionDays,
        [Parameter(ParameterSetName='5',Mandatory=$false)][switch]$LastComplianceCheckAlert,
        [Parameter(ParameterSetName='6',Mandatory=$false)][switch]$LastComplianceCheckInDays,
        [Parameter(ParameterSetName='7',Mandatory=$false)][switch]$LastComplianceCheckAlertRecipients,
        [Parameter(ParameterSetName='8',Mandatory=$false)][switch]$OutputFileExtension,
        [Parameter(ParameterSetName='9',Mandatory=$false)][switch]$DuplicateFileExtension,
        [Parameter(ParameterSetName='10',Mandatory=$false)][switch]$DuplicateFileAlert,
        [Parameter(ParameterSetName='11',Mandatory=$false)][switch]$DuplicateFileAlertRecipients,
        [Parameter(ParameterSetName='12',Mandatory=$false)][switch]$ComplianceCheckLogTableRetentionDays,
        [Parameter(ParameterSetName='13',Mandatory=$false)][switch]$FindingImportFilesTableRetentionDays,
        [Parameter(ParameterSetName='14',Mandatory=$false)][switch]$MailProfileName,
        [Parameter(ParameterSetName='15',Mandatory=$false)][switch]$CKLfileLoc,
        [Parameter(ParameterSetName='16',Mandatory=$false)][switch]$CKLfileArchiveLoc,
        [Parameter(ParameterSetName='17',Mandatory=$false)][switch]$ConcurrentScans,

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
        "1"     { $checkConfig = "OutputDropLoc" }
        "2"     { $checkConfig = "OutputArchiveLoc" }
        "3"     { $checkConfig = "ArchiveDirectoryRetentionDays" }
        "4"     { $checkConfig = "FindingRepoTableRetentionDays" }
        "5"     { $checkConfig = "LastComplianceCheckAlert" }
        "6"     { $checkConfig = "LastComplianceCheckInDays" }
        "7"     { $checkConfig = "LastComplianceCheckAlertRecipients" }
        "8"     { $checkConfig = "OutputFileExtension" }
        "9"     { $checkConfig = "DuplicateFileExtension" }
        "10"    { $checkConfig = "DuplicateFileAlert" }
        "11"    { $checkConfig = "DuplicateFileAlertRecipients" }
        "12"    { $checkConfig = "ComplianceCheckLogTableRetentionDays" }
        "13"    { $checkConfig = "FindingImportFilesTableRetentionDays" }
        "14"    { $checkConfig = "MailProfileName" }
        "15"    { $checkConfig = "CKLfileLoc" }
        "16"    { $checkConfig = "CKLfileArchiveLoc" }
        "17"    { $checkConfig = "ConcurrentScans" }
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
        [Parameter(ParameterSetName='1',Mandatory=$false)][ValidateNotNullorEmpty()][String]$OutputDropLoc,
        [Parameter(ParameterSetName='2',Mandatory=$false)][ValidateNotNullorEmpty()][String]$OutputArchiveLoc,
        [Parameter(ParameterSetName='3',Mandatory=$false)][ValidateNotNullorEmpty()][String]$ArchiveDirectoryRetentionDays,
        [Parameter(ParameterSetName='4',Mandatory=$false)][ValidateNotNullorEmpty()][String]$FindingRepoTableRetentionDays,
        [Parameter(ParameterSetName='5',Mandatory=$false)][ValidateNotNullorEmpty()][String]$LastComplianceCheckAlert,
        [Parameter(ParameterSetName='6',Mandatory=$false)][ValidateNotNullorEmpty()][String]$LastComplianceCheckInDays,
        [Parameter(ParameterSetName='7',Mandatory=$false)][ValidateNotNullorEmpty()][String]$LastComplianceCheckAlertRecipients,
        [Parameter(ParameterSetName='8',Mandatory=$false)][ValidateNotNullorEmpty()][String]$OutputFileExtension,
        [Parameter(ParameterSetName='9',Mandatory=$false)][ValidateNotNullorEmpty()][String]$DuplicateFileExtension,
        [Parameter(ParameterSetName='10',Mandatory=$false)][ValidateNotNullorEmpty()][String]$DuplicateFileAlert,
        [Parameter(ParameterSetName='11',Mandatory=$false)][ValidateNotNullorEmpty()][String]$DuplicateFileAlertRecipients,
        [Parameter(ParameterSetName='12',Mandatory=$false)][ValidateNotNullorEmpty()][String]$ComplianceCheckLogTableRetentionDays,
        [Parameter(ParameterSetName='13',Mandatory=$false)][ValidateNotNullorEmpty()][String]$FindingImportFilesTableRetentionDays,
        [Parameter(ParameterSetName='14',Mandatory=$false)][ValidateNotNullorEmpty()][String]$MailProfileName,
        [Parameter(ParameterSetName='15',Mandatory=$false)][ValidateNotNullorEmpty()][String]$CKLfileLoc,
        [Parameter(ParameterSetName='16',Mandatory=$false)][ValidateNotNullorEmpty()][String]$CKLfileArchiveLoc,
        [Parameter(ParameterSetName='17',Mandatory=$false)][ValidateNotNullorEmpty()][String]$ConcurrentScans,

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
                    $setConfig = "OutputDropLoc" 
                    $newConfig = $OutputDropLoc
                }
        "2"     { 
                    $setConfig = "OutputArchiveLoc"
                    $newConfig = $OutputArchiveLoc
                }
        "3"     { 
                    $setConfig = "ArchiveDirectoryRetentionDays" 
                    $newConfig = $ArchiveDirectoryRetentionDays
                }
        "4"     { 
                    $setConfig = "FindingRepoTableRetentionDays"
                    $newConfig = $FindingRepoTableRetentionDays 
                }
        "5"     { 
                    $setConfig = "LastComplianceCheckAlert" 
                    $newConfig = $LastComplianceCheckAlert
                }
        "6"     { 
                    $setConfig = "LastComplianceCheckInDays" 
                    $newConfig = $LastComplianceCheckInDays  
                }
        "7"     { 
                    $setConfig = "LastComplianceCheckAlertRecipients" 
                    $newConfig = $LastComplianceCheckAlertRecipients
                }
        "8"     { 
                    $setConfig = "OutputFileExtension" 
                    $newConfig = $OutputFileExtension
                }
        "9"     { 
                    $setConfig = "DuplicateFileExtension" 
                    $newConfig = $DuplicateFileExtension
                }
        "10"    { 
                    $setConfig = "DuplicateFileAlert" 
                    $newConfig = $DuplicateFileAlert
                }
        "11"    { 
                    $setConfig = "DuplicateFileAlertRecipients" 
                    $newConfig = $DuplicateFileAlertRecipients
                }
        "12"    { 
                    $setConfig = "ComplianceCheckLogTableRetentionDays" 
                    $newConfig = $ComplianceCheckLogTableRetentionDays
                }
        "13"    { 
                    $setConfig = "FindingImportFilesTableRetentionDays" 
                    $newConfig = $FindingImportFilesTableRetentionDays
                }
        "14"    { 
                    $setConfig = "MailProfileName" 
                    $newConfig = $MailProfileName
                }
        "15"    { 
                    $setConfig = "CKLfileLoc" 
                    $newConfig = $CKLfileLoc
                }
        "16"    { 
                    $setConfig = "CKLfileArchiveLoc" 
                    $newConfig = $CKLfileArchiveLoc
                }
        "17"    {
                    $setConfig = "ConcurrentScans"
                    $newConfig = $ConcurrentScans
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
    Add-Member -InputObject $configObject -NotePropertyName "ConcurrentScans" -NotePropertyValue $iniVar.ConcurrentScans
    Add-Member -InputObject $configObject -NotePropertyName "ScapProfile" -NotePropertyValue $iniVar.ScapProfile
    Add-Member -InputObject $configObject -NotePropertyName "ScapInstallDir" -NotePropertyValue $iniVar.ScapInstallDir
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
        [String]$ConcurrentScans,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [ValidateSet('CAT_I_Only',
                    'Disable_EMET',
                    'Disable_Slow_Rules',
                    'MAC-1_Classified',
                    'MAC-1_Public',
                    'MAC-1_Sensitive',
                    'MAC-2_Classified',
                    'MAC-2_Public',
                    'MAC-2_Sensitive',
                    'MAC-3_Classified',
                    'MAC-3_Public',
                    'MAC-3_Sensitive',
                    'no_profile_selected')]
        [String]$ScapProfile,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [String]$ScapInstallDir,
        
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
    if($ScapInstallDir -ne '')
    {
        if(!($LogPath.EndsWith("\")))
        {
            $ScapInstallDir = $ScapInstallDir + "\"
        }
        $workingObj.ScapInstallDir = $ScapInstallDir
    }
    if($SQLInstanceName -ne '')
    {
        $workingObj.SQLInstanceName = $SQLInstanceName
    }
    if($DatabaseName -ne '')
    {
        $workingObj.DatabaseName = $DatabaseName
    }
    if($ScapProfile -ne '')
    {
        $workingObj.ScapProfile = $ScapProfile
    }
    if($ConcurrentScans -ne '')
    {
        $workingObj.ConcurrentScans = $ConcurrentScans
    }

    $someFile += "; All Entries are space sensitive. Further versions will fix input validation.`r`n"
    $someFile += "; Concurrent scan option is only used here if you are running a standalone function`r`n"
    $someFile += "       ;   else it falls back to SQL configuration`r`n"
    $someFile += "`r`n"
    $someFile += "[general]`r`n"
    $someFile += "CKLOutPath=$($workingObj.CKLOutPath)`r`n"
    $someFile += "LogPath=$($workingObj.LogPath)`r`n"
    $someFile += "ConcurrentScans=$($workingObj.ConcurrentScans)`r`n"
    $someFile += "`r`n"
    $someFile += "[SCAP]`r`n"
    $someFile += "ScapProfile=$($WorkingObj.ScapProfile)`r`n"
    $someFile += "ScapInstallDir=$($workingObj.ScapInstallDir)`r`n"
    $someFile += "`r`n"
    $someFile += "[database]`r`n"
    $someFile += "SQLInstanceName=$($workingObj.SQLInstanceName)`r`n"
    $someFile += "DatabaseName=$($workingObj.DatabaseName)`r`n"

    $workingPath = Split-Path $PsCommandPath
    $someFile | Out-File -FilePath $workingPath\Config.ini
}

Function Get-PowerStigOrgSettings
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('2012R2','2016','10','All')]
        [String]$Version,

        [Parameter(Mandatory=$false)]
        [String]$OutPath,

        [Parameter(Mandatory=$false)]
        [String]$SqlInstanceName,

        [Parameter(Mandatory=$false)]
        [String]$DatabaseName
    )

    DynamicParam {
        $ParameterName = 'Role'
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.ParameterSetName = 'Role'
        $AttributeCollection.Add($ParameterAttribute)
        $roleSet = Import-CSV "$(Split-Path $PsCommandPath)\Roles.csv" -Header Role | Select-Object -ExpandProperty Role
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($roleSet)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin{
        $Role = $PSBoundParameters[$ParameterName]
    }

    process{

        $workingPath    = Split-Path $PsCommandPath
        $iniVar         = Import-PowerStigConfig -configFilePath $workingPath\Config.ini    

        if($null -eq $OutPath -or $OutPath -eq '')
        {
            $OutPath = "$($iniVar.LogPath)\PSOrgSettings\$($Role)_org.xml"
        }

        if($null -eq $sqlInstance -or $sqlInstance -eq '')
        {
            $sqlInstance = $iniVar.SqlInstanceName
        }
        if($null -eq $DatabaseName -or $DatabaseName -eq '')
        {
            $DatabaseName = $iniVar.DatabaseName
        }
    

        $complianceType = Convert-PowerStigRoleToSql -Role $Role
    
        $generateOrgXML = "PowerSTIG.sproc_GenerateORGxml @OSName = `"$Version`", @ComplianceType = `"$complianceType`""
        [xml]$orgFile = (Invoke-PowerStigSqlCommand -SqlInstance $SqlInstanceName -DatabaseName $DatabaseName -Query $GenerateOrgXML).OrgXML
    
        $orgFile.Save($OutPath) | Out-Null
    }

}
#endregion Public
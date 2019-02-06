# -----------------------------------------------------------------------------
#
# Copyright (C) 2018 Microsoft Corporation
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

<#
Functions:
    Private:
        M01 - Get-Time
        M02 - InsertLog
        M03 - Get-PowerStigXMLPath
        M04 - Get-PowerStigXMLVersion
    Public:
        M05 - Invoke-PowerStigScan
        M06 - Invoke-PowerStigBatch
#>

#region Private

#M01
function Get-Time
{
    return (get-date -UFormat %H:%M.%S)
}

#M02
function InsertLog 
{
    param( 
        [Parameter(Mandatory=$true)]
        [string]$LogEntryTitle,
        
        [Parameter(Mandatory=$true)]
        [string]$LogMessage,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet('Insert', 'Update', 'Delete', 'Deploy', 'Error')]
        [string]$ActionTaken,

        [Parameter(Mandatory=$true)]
        [String]$CMSserver,

        [Parameter(Mandatory=$true)]
        [String]$CMSDatabaseName
    )

    $InsertLog = "EXEC PowerSTIG.sproc_InsertScanLog  @LogEntryTitle = '$LogEntryTitle',@LogMessage = '$LogMessage',@ActionTaken = '$ActionTaken'"
    Invoke-PowerStigSqlCommand -SQLInstance $CMSserver -DatabaseName $CMSDatabaseName -query $InsertLog
}   

#M03
function Get-PowerStigXMLPath
{
    $powerStigXMLPath = "$($(get-module PowerSTIG).ModuleBase)\StigData\Processed"
    Return $powerStigXMLPath
}

#M04
<#
.SYNOPSIS
Determine the newest stig version that is in the PowerStig directory

.DESCRIPTION
Will pull the version number from the STIGs until the highest number is returned

.PARAMETER role
The role that is being tested, valid options are DC (Domain Controller), DNS, MS (Member Server), ADDomain, ADForest, IE11, and IE11

.PARAMETER osVersion
Operating System version that is being targeted. Valid options are 2012R2 and 2016

.EXAMPLE
Get-PowerStigXmlVersion -Role DC -osVersion 2012R2

#>
function Get-PowerStigXmlVersion
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("DC",
                    "DNS",
                    "MS",
                    "IE11",
                    "FW",
                    "Client",
                    "OracleJRE",
                    "IIS",
                    "SQL",
                    "Outlook2013",
                    "PowerPoint2013",
                    "Excel2013",
                    "Word2013",
                    "FireFox",
                    "DotNet")]
        [string]$role,

        [Parameter(Mandatory=$true)]
        [ValidateSet("2012R2","2016","Windows-10","All")]
        [string]$osVersion
    )
    [System.Array]$StigXmlBase = (get-childitem -path (Get-PowerStigXMLPath)).name
    # Regex pattern that tests for up to a two digit number followed by a decimal followed by up to a two digit number (i.e. 12.12,2.8,9.1)
    [regex]$RegexTest = "([1-9])?[0-9]\.[0-9]([0-9])?"
    # Holder variable for the current high value matching the previous regex
    $highVer = $null
    [System.Array]$StigXmlOs = @()

    # Test if the role is similar to ADDomain, ADForest, IE, or FW. If so then ensure that the OS Version is set to all
    if($role -eq "IE11" -or $role -eq "FW" -or $role -like "*2013" -or $role -eq "DotNet" -or $role -eq "FireFox" -or $role -eq "oracleJRE")
    {
        $osVersion = "All"
    }

    # Parse through repository for STIGs that match only the current OS that we are looking for
    foreach($a in $StigXMLBase)
    {
        if ($a -like "*$osVersion*")
        {
            $StigXmlOs += $a
        }
    }

    # If previous check returns nothing, notify the user and terminate the function
    if($StigXmlOs.Count -eq 0)
    {
        Write-Error -Message "No STIGs Matching Desired OS" 
        Return $null
    }

    foreach($g in $StigXmlOs)
    {
        if($g -like "*$role*")
        {
            if($g -match $RegexTest)
            {
                [version]$wStigVer = ($RegexTest.Matches($g)).value
            }

            if($null -eq $highVer)
            {
                [version]$highVer = $wStigVer
            }
            elseif ($wStigVer -gt $highVer)
            {
                $highVer = $wStigVer
            }
        }
    }
    $stringout = $highVer.Major.ToString() + "." + $highVer.Minor.ToString()
    
    Return $stringout
}

#endregion Private


#region Public

#M05
<#
.SYNOPSIS
Uses PowerStig and PowerStigDSC modules to scan a target server and return data as a CSV file

.DESCRIPTION
Uses PowerStig and PowerStigDSC modules to scan a target server and return the data as a CSV file. The file can then be processed by the related Import-PowerStigScans script to import results into SQL.

.PARAMETER ServerName
Short name or FQDN of server that is to be scanned. Should ensure that WinRM is enabled on the target server prior to running

.PARAMETER Role
Role that is being checked for compliance. Valid Roles include MemberServer2012Check, MemberServer2016Check, DNScheck, DC2012Check, DC2016Check, and IECheck

.EXAMPLE
Invoke-PowerStigScan -ServerName STIGDCTest01 -Role DC2012Check

Invoke-PowerStigScan -ServerName SQL2012Test -Role MemberServer2012Check

#>
function Invoke-PowerStigScan
{
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$ServerName,

        [Parameter(Mandatory=$true,ParameterSetName="Main")]
        [ValidateNotNullorEmpty()]
        [ValidateSet("MemberServer",
                    "DomainController",
                    "Client",
                    "Word",
                    "Excel",
                    "PowerPoint",
                    "Outlook",
                    "DNS",
                    "IE",
                    "DotNet",
                    "FireFox",
                    "Firewall")]
        [String]$Role,

        [Parameter(Mandatory=$true,ParameterSetName="IIS")]
        [ValidateNotNullorEmpty()]
        [ValidateSet("IIS")]
        [Switch]$IIS,

        [Parameter(Mandatory=$true,ParameterSetName="SQL")]
        [ValidateNotNullorEmpty()]
        [ValidateSet("SQL")]
        [Switch]$SQL,

        [Parameter(Mandatory=$true,ParameterSetName="IIS")]
        [ValidateNotNullOrEmpty()]
        [String]$WebsiteName,

        [Parameter(Mandatory=$true,ParameterSetName="IIS")]
        [ValidateNotNullOrEmpty()]
        [String]$WebAppPool,

        [Parameter(Mandatory=$true,ParameterSetName="SQL")]
        [ValidateNotNullorEmpty()]
        [String]$SqlInstance,

        [Parameter(Mandatory=$true,ParameterSetName="SQL")]
        [ValidateNotNullorEmpty()]
        [ValidateSet("Database","Instance")]
        [String]$SqlRole,

        [Parameter(Mandatory=$true,ParameterSetName="SQL")]
        [ValidateNotNullorEmpty()]
        [ValidateSet("2012")]
        [String]$SqlVersion,

        [Parameter(Mandatory=$true,ParameterSetName="SQL")]
        [ValidateNotNullorEmpty()]
        [String[]]$Database,

        [Parameter(Mandatory=$true,ParameterSetName="JRE")]
        [ValidateNotNullorEmpty()]
        [Switch]$JRE,

        [Parameter(Mandatory=$true,ParameterSetName="JRE")]
        [ValidateNotNullorEmpty()]
        [String]$ConfigurationPath,

        [Parameter(Mandatory=$true,ParameterSetName="JRE")]
        [ValidateNotNullorEmpty()]
        [String]$PropertiesPath,

        [Parameter(Mandatory=$false)]
        [Switch]$DebugScript

    )

    if($PSCmdlet.ParameterSetName -eq "SQL")
    {
        $Role = "SQL"
    }
    elseif ($PSCmdlet.ParameterSetName -eq "IIS") 
    {
        $Role = "IIS"    
    }
    elseif ($PSCmdlet.ParameterSetName -eq "JRE")
    {
        $Role = "JRE"
    }

    #########################
    #Initialize Variables   #
    #########################

    $workingPath                = Split-Path $PsCommandPath
    $iniVar                     = Import-PowerStigConfig -configFilePath $workingPath\Config.ini
    
    $logDate                    = get-date -UFormat %m%d
    $logFileName                = "PowerStig"+ $logDate + ".txt"
    $logPath                    = $iniVar.LogPath

    if(!(Test-Path -Path $logPath\$logFileName))
    {
        $logFilePath = new-item -ItemType File -Path $logPath\$logFileName -Force
    }
    else {
        $logFilePath = get-item -Path $logPath\$logFileName
    }
    #Initialize Logging
    Add-Content $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: New Scan - $ServerName"
    Add-Content $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: PowerStig scan started on $ServerName for role $Role."
    if($DebugScript)
    {
        Add-Content $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Debug]: Config.ini Variables Are: $iniVar"
        Add-Content $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Debug]: WorkingPath is: $workingPath"
    }

    ##############################
    #Initialize Logging Complete #
    ##############################

    ##############################
    #Check if currently supported#
    ##############################
    if($role -eq "SQL" -or $role -eq "IIS" -or $role -eq "JRE")
    {
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $Role is currently unavailable in this release. It will be added in an upcoming version."
        Return
    }

    ##############################
    #Test Connection to Server   #
    ##############################

    #Test Connection
    if($DebugScript)
    {
        Add-Content $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Debug]: Running (Test-NetConnection -ComputerName $serverName -CommonTCPPort WINRM).TcpTestSucceeded -eq `$false"
    }
    if((Test-NetConnection -ComputerName $serverName -CommonTCPPort WINRM).TcpTestSucceeded -eq $false)
    {
        Add-Content -path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Error]: Connection to $serverName Failed. Check network connectivity and that the server is listening for WinRM"
        Return
    }
    else 
    {
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: Connection to $serverName successful"
    }

    ###########################
    #Test Connection Complete #
    ###########################

    ###########################
    #Test WSMAN Settings      #
    ###########################

    if($ServerName -eq $ENV:ComputerName)
    {
        try {
            [int]$maxEnvelope = (get-childitem wsman:\localhost\MaxEnvelopeSizekb).value
        }
        catch {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$Servername][$Role][ERROR]: Query for WSMAN properties failed. Check user context that this is running under."
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
        
    }
    else
    {
        [int]$maxEnvelope = invoke-command -ComputerName $ServerName -ScriptBlock {((get-childitem wsman:\localhost\MaxEnvelopeSizekb).value)}
    }

    #Configure WSMAN if necessary
    if($maxEnvelope -lt 10000 -and $ServerName -ne $ENV:ComputerName)
    {
        Add-Content -path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Warning]: Attempting to set MaxEnvelopeSizeKb on $ServerName."
        try 
        {
            invoke-command -computername $serverName -ScriptBlock {Set-Item -Path WSMAN:\localhost\MaxEnvelopeSizekb -Value 10000}
            Add-Content -path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MaxEnvelopeSizeKb successfully configured on $ServerName."
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: Setting WSMAN failed on $ServerName."
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    elseif($maxEnvelope -lt 10000 -and $ServerName -eq $ENV:ComputerName)
    {
        Add-Content -path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Warning]: Attempting to set MaxEnvelopeSizeKb on $ServerName."
        try 
        {
            Set-Item -Path WSMAN:\localhost\MaxEnvelopeSizekb -Value 10000
            Add-Content -path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MaxEnvelopeSizeKb successfully configured on $ServerName."
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: Setting WSMAN failed on $ServerName."
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    else
    {
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: WSMan is correctly configured."
    }

    ###############################
    #Test WSMan Settings Complete #
    ###############################

    ###############################
    #Convert SqlRole to DSCRole   #
    ###############################

    #Determine STIG Version
    $dscRole = Convert-PowerStigSqlToRole -SqlRole $Role
    if($DebugScript)
    {
        Add-Content $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Debug]: DSCRole is $dscRole"
    }

    if(-not(test-path "$logPath\$ServerName"))
    {
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: Creating file path for this server at $logPath\$ServerName"
        New-Item -ItemType Directory -Path "$logpath\$ServerName"
    }

    ########################
    #Convert Role Complete #
    ########################

    ########################
    #Check OSVersion       #
    ########################

    
    [bool]$is2012 = $true
    if($Role -like "*2016*")
    {
            $is2012 = $false
    }
    elseif($role -eq "Client")
    {
        $osVersion = "Windows-10"
    }

    if($is2012 -eq $true -and $osVersion -ne "Windows-10")
    {
        $osVersion = "2012R2"
    }
    elseif($is2012 -eq $false -and $osVersion -ne "Windows-10")
    {
        $osVersion = "2016"
    }

    ###########################
    #Check OSVersion Complete #
    ###########################

    Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: OS Version is $osVersion"

    #Build MOF
    Push-Location $logPath\$serverName

    ##########################
    #Get Stig Version Number #
    ##########################

    try 
    {
        $stigVersion = Get-PowerStigXmlVersion -role $dscRole -osVersion $osVersion
    }
    catch 
    {
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: dscRole is $dscRole"
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: osVersion is $osVersion"
        Return
    }

    ############################
    #Get Stig Version Complete #
    ############################
    
    ############################
    #Create MOF                #
    ############################

    Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: Stig Version is $stigVersion"

    if($dscRole -eq "DNS")
    {
        #Run DNSDSC
        try 
        {
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Debug]: Running: $workingPath\DSCConfigurations\PowerStigDNSCall.ps1 -ComputerName $ServerName -OsVersion $osVersion -StigVersion $stigVersion"
            }
            & $workingPath\DSCConfigurations\PowerStigDNSCall.ps1 -ComputerName $ServerName -OsVersion $osVersion -StigVersion $stigVersion
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole"
            $mofPath = "$logPath\$ServerName\PowerStigDNSCall"
        }
        catch
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    elseif($dscRole -eq "IE11")
    {
        #run IEDSC
        try 
        {
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Debug]: Running: $workingPath\DSCConfigurations\PowerStigBrowserCall.ps1 -ComputerName $ServerName -Role $dscRole -StigVersion $stigVersion"
            }
            & $workingPath\DSCConfigurations\PowerStigBrowserCall.ps1 -ComputerName $ServerName -Role $dscRole -StigVersion $stigVersion
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole"
            $mofPath = "$logPath\$ServerName\PowerStigBrowserCall"
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    elseif($dscRole -eq "MS" -or $dscRole -eq "DC")
    {
        #run MSDCDSC
        try 
        {
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Debug]: Running: $workingPath\DSCConfigurations\PowerStigMSDCCall.ps1 -ComputerName $ServerName -Role $dscRole -OsVersion $osVersion -StigVersion $stigVersion"
            }
            & $workingPath\DSCConfigurations\PowerStigMSDCCall.ps1 -ComputerName $ServerName -Role $dscRole -OsVersion $osVersion -StigVersion $stigVersion
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole"
            $mofPath = "$logPath\$ServerName\PowerStigMSDCCall"
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    elseif($dscRole -eq "FW")
    {
        try
        {
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Debug]: Running: $workingPath\DSCConfigurations\PowerStigFWCall.ps1 -ComputerName $ServerName -StigVersion $stigVersion"
            }
            & $workingPath\DSCConfigurations\PowerStigFWCall.ps1 -ComputerName $ServerName -StigVersion $stigVersion
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole"
            $mofPath = "$logPath\$ServerName\PowerStigFWCall"
        }
        catch
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    elseif($dscRole -eq "Word2013")
    {
        try {
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName[$Role][Debug]: Running: $WorkingPath\DSCConfigurations\PowerStigOfficeCall.ps1 -ComputerName $ServerName -OfficeApp $app -StigVersion $stigVersion"
            }
            & $WorkingPath\DSCConfigurations\PowerStigOfficeCall.ps1 -ComputerName $ServerName -OfficeApp $dscRole -StigVersion $stigVersion
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole"
            $MofPath = "$logPath\$ServerName\PowerStigOfficeCall"
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    elseif($dscRole -eq "Excel2013")
    {
        try {
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName[$Role][Debug]: Running: $WorkingPath\DSCConfigurations\PowerStigOfficeCall.ps1 -ComputerName $ServerName -OfficeApp $app -StigVersion $stigVersion"
            }
            & $WorkingPath\DSCConfigurations\PowerStigOfficeCall.ps1 -ComputerName $ServerName -OfficeApp $dscRole -StigVersion $stigVersion
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole"
            $MofPath = "$logPath\$ServerName\PowerStigOfficeCall"
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    elseif($dscRole -eq "PowerPoint2013")
    {
        try {
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName[$Role][Debug]: Running: $WorkingPath\DSCConfigurations\PowerStigOfficeCall.ps1 -ComputerName $ServerName -OfficeApp $app -StigVersion $stigVersion"
            }
            & $WorkingPath\DSCConfigurations\PowerStigOfficeCall.ps1 -ComputerName $ServerName -OfficeApp $dscRole -StigVersion $stigVersion
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole"
            $MofPath = "$logPath\$ServerName\PowerStigOfficeCall"
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    elseif($dscRole -eq "Outlook2013")
    {
        try {
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName[$Role][Debug]: Running: $WorkingPath\DSCConfigurations\PowerStigOfficeCall.ps1 -ComputerName $ServerName -OfficeApp $app -StigVersion $stigVersion"
            }
            & $WorkingPath\DSCConfigurations\PowerStigOfficeCall.ps1 -ComputerName $ServerName -OfficeApp $dscRole -StigVersion $stigVersion
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole"
            $MofPath = "$logPath\$ServerName\PowerStigOfficeCall"
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    elseif($dscRole -eq "Client")
    {
        try {
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName[$Role][Debug]: Running: $WorkingPath\DSCConfigurations\PowerStigWinCliCall.ps1 -ComputerName $ServerName -StigVersion $stigVersion"
            }
            & $WorkingPath\DSCConfigurations\PowerStigWinCliCall.ps1 -ComputerName $ServerName -StigVersion $stigVersion
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole"
            $MofPath = "$logPath\$ServerName\PowerStigWinCliCall"
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    elseif($dscRole -eq "DotNet")
    {
        try {
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName[$Role][Debug]: Running: $WorkingPath\DSCConfigurations\PowerStigDotNetCall.ps1 -ComputerName $ServerName -StigVersion $stigVersion"
            }
            & $WorkingPath\DSCConfigurations\PowerStigDotNetCall.ps1 -ComputerName $ServerName -StigVersion $stigVersion
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole"
            $MofPath = "$logPath\$ServerName\PowerStigDotNetCall"
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    elseif($dscRole -eq "FireFox")
    {
        try
        {
            # Determine install Directory
            $InstallDirectory = Invoke-Command -ComputerName $Servername -Scriptblock {(get-itemproperty "HKLM:\Software\Mozilla\Mozilla Firefox\$((get-itemproperty "HKLM:\Software\Mozilla\Mozilla Firefox").currentversion)\Main")."Install Directory"}
            try {
                if($DebugScript)
                {
                    Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName[$Role][Debug]: Running: $WorkingPath\DSCConfigurations\PowerStigFiFoCall.ps1 -ComputerName $ServerName -StigVersion $stigVersion -InstallDirectory $InstallDirectory"
                }
                & $WorkingPath\DSCConfigurations\PowerStigFiFoCall.ps1 -ComputerName $ServerName -StigVersion $stigVersion -InstallDirectory $InstallDirectory
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole"
                $MofPath = "$logPath\$ServerName\PowerStigFiFoCall"
            }
            catch 
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
                Return
            }
        }
        catch
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    <#elseif($dscRole -eq "IIS")
    {
        try {
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName[$Role][Debug]: Running: $WorkingPath\DSCConfigurations\PowerStigOfficeCall.ps1 -ComputerName $ServerName -OfficeApp $app -StigVersion $stigVersion"
            }
            & $WorkingPath\DSCConfigurations\PowerStigOfficeCall.ps1 -ComputerName $ServerName -OfficeApp $app -StigVersion $stigVersion
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole"
            $tempMofPath = "$logPath\$ServerName\PowerStigOfficeCall"
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }#>
    elseif($dscRole -eq "OracleJRE")
    {
        try {
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName[$Role][Debug]: Running: $WorkingPath\DSCConfigurations\PowerStigOraJRECall.ps1 -ComputerName $ServerName -ConfigPath $ConfigurationPath -PropertiesPath $PropertiesPath -StigVersion $stigVersion"
            }
            & $WorkingPath\DSCConfigurations\PowerStigOraJRECall.ps1 -ComputerName $ServerName -ConfigPath $ConfigurationPath -PropertiesPath $PropertiesPath -StigVersion $stigVersion
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole"
            $MofPath = "$logPath\$ServerName\PowerStigOraJRECall"
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    elseif($dscRole -eq "SQL")
    {
        try {
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName[$Role][Debug]: Running: $WorkingPath\DSCConfigurations\PowerStigSqlSerCall.ps1  -ComputerName $ServerName -SqlVersion $SqlVersion -SqlRole $SqlRole -SqlInstance $SqlInstance -Database $Database -StigVersion $stigVersion"
            }
            & $WorkingPath\DSCConfigurations\PowerStigSqlSerCall.ps1 -ComputerName $ServerName -SqlVersion $SqlVersion -SqlRole $SqlRole -SqlInstance $SqlInstance -Database $Database -StigVersion $stigVersion
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: MOF Created for $ServerName for role $dscRole, Instance $SqlInstance, Database $Database"
            $MofPath = "$logPath\$ServerName\PowerStigSqlSerCall"
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
            Return
        }
    }
    else 
    {
        Add-content -Path $logFilePath -value "$(Get-Time):[$ServerName][$Role][Warning]: Skipping $dscRole on $ServerName. Role $dscRole is not a supported technology at this time."
        continue
    }
    if($DebugScript)
    {
        Add-Content -Path $logFilePath -value "$(Get-Time):[$ServerName][$Role][Debug]: mofPath is $mofPath"
    }
    Pop-Location

    #Run scan against target server
    $mof = get-childitem $mofPath
        
    Push-location $mofPath

    Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: Starting Scan for $mof"
    try 
    {
        $scanMof = (Get-ChildItem -Path $mofPath)[0]

        $scanObj = Test-DscConfiguration -ComputerName $ServerName -ReferenceConfiguration $scanMof
    }
    catch 
    {
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: mof variable is $mof"
        Return
    }

    Pop-Location

    Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: Converting results to PSObjects"

    try
    {
        $convertObj = Convert-PowerStigTest -TestResults $scanObj
    }
    catch
    {
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][ERROR]: $_"
        Return
    }
    if($DebugScript)
    {
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Debug]: Object Results:"
        Add-Content -Path $logFilePath -Value "DesiredState`tFindingSeverity,`tStigDefinition,`tStigType,`tScanDate"
        foreach($o in $convertObj)
        {
            Add-Content -Path $logFilePath -Value "$($o.DesiredState),`t$($o.FindingSeverity),`t$($o.StigDefinition),`t$($o.StigType),`t$($o.ScanDate)"
        }
    }

    Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][$Role][Info]: Importing Results to Database for $ServerName and role $Role."

    Import-PowerStigObject -Servername $ServerName -InputObj $convertObj

}

#M06
function Invoke-PowerStigBatch
{
    [CmdletBinding()]
    param(   
        [Parameter(ParameterSetName='Set1',Position=0,Mandatory=$false)]
        [String]$cmsServer,

        [parameter(ParameterSetName='Set1',Position=1,Mandatory=$false)]
        [String]$CMSDatabaseName
    )

    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($null -eq $cmsServer -or $cmsServer -eq '')
    {
        $cmsServer = $iniVar.SqlInstanceName
    }
    if($null -eq $CMSDatabaseName -or $CMSDatabaseName -eq '')
    {
        $CMSDatabaseName = $iniVar.DatabaseName
    }


    #========================================================================
    # Create logging functions
    #========================================================================


    #========================================================================
    # Name the PowerSTIG scan jobs
    #========================================================================
    # This needs to be "something else", like pulled from database or not sure in a future release
    $JobName = "$(get-date -uformat %m%d)_PowerSTIGscan"
    [int]$concurrentJobs = (Get-PowerStigSqlConfig -ConcurrentScans).ConfigSetting

    #========================================================================
    $StepName = 'Start queued scans'
    $StepMessage = 'Scans Started'
    #========================================================================
    #D
    try
    {
        #
        # Logging
        #
        InsertLog -LogEntryTitle $StepName -LogMessage $StepMessage -ActionTaken 'UPDATE' -CMSServer $cmsServer -CMSDatabase $CMSDatabaseName
        #
        $GetQueuedScans = "EXEC PowerStig.sproc_GetScanQueue"
        $RunGetQueuedScans = (Invoke-PowerStigSqlCommand -SqlInstance $cmsServer -DatabaseName $CMSDatabaseName -Query $GetQueuedScans )
        $QueuedScans = @($RunGetQueuedScans)
        $uniqueComplianceTypes = $QueuedScans | Select-Object ComplianceType -Unique

        foreach($ct in $uniqueComplianceTypes)
        {
            $compTypeJobs = @($QueuedScans | Where-Object {$_.compliancetype -eq $ct.ComplianceType.ToString()})
            $numJobs = $compTypeJobs.Length

            for($i = 0; $i -lt $numJobs;$i++)
            {
                While((Get-Job | Where-Object {$_.state -eq "Running" -and $_.name -like "*PowerSTIG*"}).count -ge $concurrentJobs)
                {
                    Start-Sleep -Seconds 10
                }
                try
                {
                    $stepMessage = "Starting Job $($i+1) of $numJobs for Role $($ct.ComplianceType)"
                    InsertLog -LogEntryTitle $StepName -LogMessage $StepMessage -ActionTaken 'UPDATE' -CMSServer $cmsServer -CMSDatabase $CMSDatabaseName

                    $TargetToScan = $compTypeJobs[$i].TargetComputer
                    $ComplianceType = $compTypeJobs[$i].ComplianceType

                    Start-Job -Name $JobName -scriptblock { Param ($TargetToScan, $ComplianceType) Invoke-PowerStigScan -Servername $TargetToScan -Role $ComplianceType} -ArgumentList $TargetToScan, $ComplianceType | Out-Null
                }
                catch
                {
                    $StepMessage = $_.Exception.Message
                    $StepMessage = $StepMessage -replace '['']',''
                    InsertLog -LogEntryTitle $StepName -LogMessage $StepMessage -ActionTaken 'ERROR' -CMSServer $cmsServer -CMSDatabase $CMSDatabaseName    
                }

            }

            $StepMessage = $null
            $JobCount = 0
            ## Wait for Jobs to Complete
            While((Get-Job | Where-Object {$_.state -eq "Running" -and $_.name -like "*PowerSTIG*"}).count -gt 0)
            {
                $JobCountNew = (Get-Job | Where-Object {$_.state -eq "Running" -and $_.name -like "*PowerSTIG*"}).count
                If($JobCountNew -ne $JobCount)
                {
                    $JobCount = $JobCountNew
                    $StepMessage = "Waiting on $JobCount jobs to finish for role $($ct.ComplianceType). Checking job status every 2 seconds."
                    InsertLog -LogEntryTitle $StepName -LogMessage $StepMessage -ActionTaken 'UPDATE' -CMSServer $cmsServer -CMSDatabase $CMSDatabaseName       
                }

                Start-Sleep -Seconds 2
            }
        }


        #
        # Logging
        #
        $StepMessage = "Scans Complete"
        InsertLog -LogEntryTitle $StepName -LogMessage $StepMessage -ActionTaken 'UPDATE' -CMSServer $cmsServer -CMSDatabase $CMSDatabaseName
        #

    }
    catch
    {
        #
        # Logging
        #
        $StepMessage = $_.Exception.Message
        $StepMessage = $StepMessage -replace '['']',''
        InsertLog -LogEntryTitle $StepName -LogMessage $StepMessage -ActionTaken 'ERROR' -CMSServer $cmsServer -CMSDatabase $CMSDatabaseName
        #
    }

    #========================================================================
    $StepName ='Retrieve CKL path'
    $StepMessage = 'Retrieving CKL path from config database'
    #========================================================================
    try
    {
        #
        # Logging
        #
        InsertLog -LogEntryTitle $StepName -LogMessage $StepMessage -ActionTaken 'UPDATE' -CMSServer $cmsServer -CMSDatabase $CMSDatabaseName
        #	
        $GetCKLpath = "EXEC PowerSTIG.sproc_GetConfigSetting @ConfigProperty = 'CKLfileLoc'"
        $RunGetCKLpath = (Invoke-PowerStigSqlCommand -SqlInstance $CMSserver -DatabaseName $CMSDatabaseName -Query $GetCKLpath )
        $CKLpath = @($RunGetCKLpath) | Select-Object -ExpandProperty ConfigSetting
        #
        # Logging
        #
        $StepMessage = "CKL Path retrieval complete"
        InsertLog -LogEntryTitle $StepName -LogMessage $StepMessage -ActionTaken 'UPDATE' -CMSServer $cmsServer -CMSDatabase $CMSDatabaseName
        #
    }
    catch
    {
        #
        # Logging
        #
        $StepMessage = $_.Exception.Message
        $StepMessage = $StepMessage -replace '['']',''
        InsertLog -LogEntryTitle $StepName -LogMessage $StepMessage -ActionTaken "ERROR" -CMSServer $cmsServer -CMSDatabase $CMSDatabaseName
        #
    }
    #========================================================================
    $StepName =  'Generate Checklist files (CKLs)'
    $StepMessage = 'Generating Checklist files'
    #========================================================================
    try
    {
        #
        # Logging
        #
        InsertLog -LogEntryTitle $StepName -LogMessage $StepMessage -ActionTaken "UPDATE" -CMSServer $cmsServer -CMSDatabase $CMSDatabaseName
        #	
            $GetLastCKLdata = "EXEC PowerStig.sproc_GetLastDataForCKL"
            $RunGetLastCKLdata = (Invoke-PowerStigSqlCommand -SqlInstance $CMSserver -DatabaseName $CMSDatabaseName -Query $GetLastCKLdata )
            $LastCKLdata = @($RunGetLastCKLdata)
            #
            foreach ($CKL in $LastCKLdata)
            {
                $TargetComputer = $CKL.TargetComputer
                $ComplianceType = $CKL.ComplianceType
                $Guid = $CKL.ScanGUID
                $Timestamp = (get-date).ToString("MMddyyyyHHmmss")
                $CKLfile = $CKLpath+$TargetComputer+"_"+$ComplianceType+"_"+$Timestamp+".CKL"

                $CKLRole = Convert-PowerStigSqlToRole -SqlRole $ComplianceType

                New-PowerStigCKL -Servername $TargetComputer -OSversion 2012R2 -Role $CKLRole -Outpath $CKLfile -GUID $Guid

            }
        #
        # Logging
        #
        InsertLog -LogEntryTitle $StepName -LogMessage $StepMessage -ActionTaken "UPDATE" -CMSServer $cmsServer -CMSDatabase $CMSDatabaseName
        #
    }
    catch
    {
        #
        # Logging
        #
        $StepMessage = $_.Exception.Message
        $StepMessage = $StepMessage -replace '['']',''
        InsertLog -LogEntryTitle $StepName -LogMessage $StepMessage -ActionTaken "ERROR" -CMSServer $cmsServer -CMSDatabase $CMSDatabaseName
        #
    }
}

#endregion Public
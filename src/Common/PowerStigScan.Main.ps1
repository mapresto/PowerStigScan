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
        M05 - Get-PowerStigServerRole
        M06 - Get-ServerVersion
        R01 - Get-PowerStigIsOffice
        R02 - Get-PowerStigIsIE
        R03 - Get-PowerStigIsDotNet
        R04 - Get-PowerStigIsFireFox
        R05 - Get-PowerStigIsFirewall
        R06 - Get-PowerStigIsIIS
        R07 - Get-PowerStigIsDNS
        R08 - Get-PowerStigIsSQL
        R09 - Get-PowerStigIsJRE
    Public:
        M07 - Invoke-PowerStigScan
        M08 - Invoke-PowerStigBatch
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
        [Parameter(Mandatory=$false)]
        [ValidateSet("2012R2","2016","10","All")]
        [string]$osVersion
    )

    DynamicParam {
        $ParameterName = 'Role'
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
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
        [System.Array]$StigXmlBase = (get-childitem -path (Get-PowerStigXMLPath)).name
        # Regex pattern that tests for up to a two digit number followed by a decimal followed by up to a two digit number (i.e. 12.12,2.8,9.1)
        [regex]$RegexTest = "([1-9])?[0-9]\.[0-9]([0-9])?"
        # Holder variable for the current high value matching the previous regex
        $highVer = $null
        [System.Array]$StigXmlOs = @()
    
        # Test if the role is similar to ADDomain, ADForest, IE, or FW. If so then ensure that the OS Version is set to all
        Switch($Role)
        {
            "DotNetFramework"           {$rRole = "DotNetFramework-4"}
            "FireFox"                   {$rRole = "FireFox-All"}
            "IISServer"                 {$rRole = "IISServer-8.5"}
            "IISSite"                   {$rRole = "IISSite-8.5"}
            "InternetExplorer"          {$rRole = "InternetExplorer-11"}
            "Excel2013"                 {$rRole = "Office-Excel2013"}
            "Outlook2013"               {$rRole = "Office-Outlook2013"}
            "PowerPoint2013"            {$rRole = "Office-PowerPoint2013"}
            "Word2013"                  {$rRole = "Office-Word2013"}
            "OracleJRE"                 {$rRole = "OracleJRE-8"}
            "SqlServer-2012-Database"   {$rRole = "SqlServer-2012-Database"}
            "SqlServer-2012-Instance"   {$rRole = "SqlServer-2012-Instance"}
            "SqlServer-2016-Instance"   {$rRole = "SqlServer-2016-Instance"}
            "WindowsClient"             {$rRole = "WindowsClient-10"}
            "WindowsDefender"           {$rRole = "WindowsDefender-All"}
            "WindowsDNSServer"          {$rRole = "WindowsDNSServer-2012R2"}
            "WindowsFirewall"           {$rRole = "WindowsFirewall-All"}
            "WindowsServer-DC"          {if($osVersion = "2012R2"){$rRole = "WindowsServer-2012R2-DC"}else{$rRole = "WindowsServer-2016-DC"}}
            "WindowsServer-MS"          {if($osVersion = "2012R2"){$rRole = "WindowsServer-2012R2-MS"}else{$rRole = "WindowsServer-2016-MS"}}
        }

        # Parse through repository for STIGs that match only the current OS that we are looking for
        if($osVersion -ne "" -and $null -ne $osVersion)
        {
            foreach($a in $StigXMLBase)
            {
                if ($a -like "*$osVersion*")
                {
                    $StigXmlOs += $a
                }
            }
        }
        else {
            $StigXMLOs = $StigXMLBase
        }
    
        # If previous check returns nothing, notify the user and terminate the function
        if($StigXmlOs.Count -eq 0)
        {
            Write-Error -Message "No STIGs Matching Desired OS" 
            Return $null
        }
    
        foreach($g in $StigXmlOs)
        {
            if($g -like "*$rRole*")
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

}

function Get-PowerStigServerRole
{
    param(
        [CmdletBinding()]
        [Parameter(Mandatory=$true)]
        [String]$ServerName
    )

    # Initialize Role Array
    $arrRole = @()

    # Gather domain role and OS version
    $domainRole = (Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ServerName).DomainRole
    $osVersion = (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ServerName).Version

    # Determine MemberServer/Client/DomainController
    if($domainRole -eq 4 -or $domainRole -eq 5)
    {
        $arrRole += "WindowsServer-DC"
        $outVersion = Get-ServerVersion -osVersion $osVersion
    }elseif($domainRole -eq 2 -or $domainRole -eq 3)
    {
        $arrRole += "WindowsServer-MS"
        $outVersion = Get-ServerVersion -osVersion $osVersion
    }elseif($domainRole -eq 0 -or $domainRole -eq 1)
    {
        $arrRole += "WindowsClient"
        if($osVersion -like "10.*")
        {
            $outVersion = "10"
        }else{
            Return 100
        }
    }

    if($arrRole -contains "WindowsServer-MS" -or $arrRole -contains "WindowsServer-DC")
    {
        if(Get-PowerStigIsOffice -ServerName $ServerName)
        {
            $arrRole += "Outlook2013"
            $arrRole += "PowerPoint2013"
            $arrRole += "Excel2013"
            $arrRole += "Word2013"
        }
        if(Get-PowerStigIsIE -ServerName $ServerName)
        {
            $arrRole += "InternetExplorer"
        }
        if(Get-PowerStigIsDotNet -ServerName $ServerName)
        {
            $arrRole += "DotNetFramework"
        }
        if(Get-PowerStigIsFireFox -ServerName $ServerName)
        {
            $arrRole += "FireFox"
        }
        if(Get-PowerStigIsFirewall -ServerName $ServerName)
        {
            $arrRole += "WindowsFirewall"
        }
        if(Get-PowerStigIsIIS -ServerName $ServerName) # MUSTREDO
        {
            $arrRole += "IISServer"
            $arrRole += "IISSite"
        }
        if(Get-PowerStigIsSQL -ServerName $ServerName) # MUSTREDO
        {
            $arrRole += "SQL"
        }
        if(Get-PowerStigIsJRE -ServerName $ServerName)
        {
            $arrRole += "OracleJRE"
        }
        if(Get-PowerStigIsDNS -ServerName $ServerName)
        {
            $arrRole += "WindowsDNSServer"
        }
    }elseif($arrRole -contains "WindowsClient")
    {
        if(Get-PowerStigIsOffice -ServerName $ServerName)
        {
            $arrRole += "Office2013"
            $arrRole += "PowerPoint2013"
            $arrRole += "Excel2013"
            $arrRole += "Word2013"
        }
        if(Get-PowerStigIsIE -ServerName $ServerName)
        {
            $arrRole += "InternetExplorer"
        }
        if(Get-PowerStigIsDotNet -ServerName $ServerName)
        {
            $arrRole += "DotNetFramework"
        }
        if(Get-PowerStigIsFireFox -ServerName $ServerName)
        {
            $arrRole += "FireFox"
        }
        if(Get-PowerStigIsFirewall -ServerName $ServerName)
        {
            $arrRole += "WindowsFirewall"
        }
        if(Get-PowerStigIsSQL -ServerName $ServerName) # MUSTREDO
        {
            $arrRole += "SQL"
        }
        if(Get-PowerStigIsJRE -ServerName $ServerName)
        {
            $arrRole += "OracleJRE"
        }
    }

    $outObj = New-Object -TypeName PSObject
    Add-Member -InputObject $outObj -NotePropertyName "Version" -NotePropertyValue $OutVersion
    Add-Member -InputObject $outObj -NotePropertyName "Roles" -NotePropertyValue $arrRole

    Return $outObj

}

# M06
function Get-ServerVersion
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$osVersion
    )

    if ($osVersion -like "6.3*")
    {
        Return "2012R2"
    }elseif ($osVersion -like "10.*")
    {
        Return "2016"
    }
}

# R01
function Get-PowerStigIsOffice
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName
    )

    $uninstallPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $keys = @(Invoke-Command -computername $ServerName -scriptblock {param($uninstallPath) Get-ChildItem -path $uninstallPath | Where-Object {$_.name -like "*0FF1CE}"}} -ArgumentList $uninstallPath)
    if($keys.count -ge 1)
    {
        Return $true
    }
    else {
        Return $false
    }
}

# R02
function Get-PowerStigIsIE
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName
    )

    Return (Invoke-Command -ComputerName $ServerName -Scriptblock {(Get-windowsoptionalfeature -FeatureName Internet-Explorer-Optional-amd64 -online).state -eq "Enabled"})
}

# R03
function Get-PowerStigIsDotNet
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName
    )

    # DotNet is currently unsupported by PowerStig. This will return false until further notice.

    Return $false
}

# R04
function Get-PowerStigIsFireFox
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName
    )

    Return Invoke-Command -ComputerName $ServerName -scriptblock {Test-Path -path "HKLM:\Software\Mozilla\Mozilla Firefox\"}
}

# R05
function Get-PowerStigIsFirewall
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName
    )

    Return $true
}

# R06
function Get-PowerStigIsIIS
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName
    )

    Return (Get-WindowsFeature -ComputerName $ServerName -Name Web-Server).installstate -eq "Installed"
}

# R07
function Get-PowerStigIsDNS
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName
    )

    Return (Get-WindowsFeature -ComputerName $ServerName -Name DNS).installstate -eq "Installed"
}

# R08
function Get-PowerStigIsSQL
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName
    )

    Return $false
}

# R09
function Get-PowerStigIsJRE
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName
    )

    Return Invoke-Command -ComputerName $ServerName -ScriptBlock {if ((Test-Path -Path "HKLM:\SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment") -or (Test-Path -Path "HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment")){Return $true}else{Return $false}}
}
#endregion Private


#region Public

# M07
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
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [String]$ServerName,

        [Parameter(Mandatory=$false)]
        [Switch]$DebugScript

    )


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
    Add-Content $logFilePath -Value "$(Get-Time):[$ServerName][Info]: New Scan - $ServerName"
    if($DebugScript)
    {
        Add-Content $logFilePath -Value "$(Get-Time):[$ServerName][Debug]: Config.ini Variables Are: $iniVar"
        Add-Content $logFilePath -Value "$(Get-Time):[$ServerName][Debug]: WorkingPath is: $workingPath"
    }

    ##############################
    #Initialize Logging Complete #
    ##############################

    ##############################
    #Test Connection to Server   #
    ##############################

    #Test Connection
    if($DebugScript)
    {
        Add-Content $logFilePath -Value "$(Get-Time):[$ServerName][Debug]: Running (Test-NetConnection -ComputerName $serverName -CommonTCPPort WINRM).TcpTestSucceeded -eq `$false"
    }
    if((Test-NetConnection -ComputerName $serverName -CommonTCPPort WINRM).TcpTestSucceeded -eq $false)
    {
        Add-Content -path $logFilePath -Value "$(Get-Time):[$ServerName][Error]: Connection to $serverName Failed. Check network connectivity and that the server is listening for WinRM"
        Return
    }
    else 
    {
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][Info]: Connection to $serverName successful"
    }

    ###########################
    #Test Connection Complete #
    ###########################

    ###########################
    #Get server roles
    ###########################

    $roles = Get-PowerStigServerRole -ServerName $ServerName
    Add-Content $logFilePath -Value "$(Get-Time):[$ServerName][Info]: PowerStig scan started on $ServerName for role $($roles.roles) and version $($roles.version)."

    ###########################
    #Test WSMAN Settings      #
    ###########################

    if($ServerName -eq $ENV:ComputerName)
    {
        try {
            [int]$maxEnvelope = (get-childitem wsman:\localhost\MaxEnvelopeSizekb).value
        }
        catch {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$Servername][ERROR]: Query for WSMAN properties failed. Check user context that this is running under."
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][ERROR]: $_"
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
        Add-Content -path $logFilePath -Value "$(Get-Time):[$ServerName][Warning]: Attempting to set MaxEnvelopeSizeKb on $ServerName."
        try 
        {
            invoke-command -computername $serverName -ScriptBlock {Set-Item -Path WSMAN:\localhost\MaxEnvelopeSizekb -Value 10000}
            Add-Content -path $logFilePath -Value "$(Get-Time):[$ServerName][Info]: MaxEnvelopeSizeKb successfully configured on $ServerName."
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][ERROR]: Setting WSMAN failed on $ServerName."
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][ERROR]: $_"
            Return
        }
    }
    elseif($maxEnvelope -lt 10000 -and $ServerName -eq $ENV:ComputerName)
    {
        Add-Content -path $logFilePath -Value "$(Get-Time):[$ServerName][Warning]: Attempting to set MaxEnvelopeSizeKb on $ServerName."
        try 
        {
            Set-Item -Path WSMAN:\localhost\MaxEnvelopeSizekb -Value 10000
            Add-Content -path $logFilePath -Value "$(Get-Time):[$ServerName][Info]: MaxEnvelopeSizeKb successfully configured on $ServerName."
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][ERROR]: Setting WSMAN failed on $ServerName."
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][ERROR]: $_"
            Return
        }
    }
    else
    {
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][Info]: WSMan is correctly configured."
    }

    ###############################
    #Test WSMan Settings Complete #
    ###############################

    if(-not(test-path "$logPath\$ServerName"))
    {
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][Info]: Creating file path for this server at $logPath\$ServerName"
        New-Item -ItemType Directory -Path "$logpath\$ServerName"
    }

    ########################
    #Check OSVersion       #
    ########################

    $osVersion = $roles.version

    ###########################
    #Check OSVersion Complete #
    ###########################

    Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][Info]: OS Version is $osVersion"

    #Build MOF
    

    ############################
    #Create MOF                #
    ############################
    foreach($r in $roles.Roles)
    {
        Push-Location $logPath\$serverName
        try
        {
            $OrgSettings    = $null
            $SkipRule       = $null
        }
        catch
        {
            Write-Host "This shouldn't show..."
        }

        try
        {
            $RunExpression = "& `"$workingPath\DSCCall.ps1`" -ComputerName $ServerName -osVersion $osVersion -Role $r -LogPath $logFilePath"
            if($null -ne $OrgSettings -and $OrgSettings -ne "")
            {
                $RunExpression += " -OrgSettingsFilePath $OrgSettings"
            }
            if($null -ne $SkipRule -and $SkipRule -ne "")
            {
                $RunExpression += " -SkipRules $SkipRule"
            }
            Invoke-Expression -Command $RunExpression
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][Info]: MOF Created for $ServerName for role $r"
            $mofPath = "$logPath\$ServerName\PowerSTIG\"
        }
        catch
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][ERROR]: mof generation failed when running:"
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][ERROR]: $RunExpression"
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][ERROR]: $_"
            Continue
        }
    

        if($DebugScript)
        {
            Add-Content -Path $logFilePath -value "$(Get-Time):[$ServerName][Debug]: mofPath is $mofPath"
        }
        Pop-Location

        #Run scan against target server
        $mof = get-childitem $mofPath
            
        Push-location $mofPath

        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][Info]: Starting Scan for $mof"
        try 
        {
            $scanMof = (Get-ChildItem -Path $mofPath)[0]

            $scanObj = Test-DscConfiguration -ComputerName $ServerName -ReferenceConfiguration $scanMof
        }
        catch 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][ERROR]: $_"
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][ERROR]: mof variable is $mof"
            Continue
        }

        Pop-Location

        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][Info]: Converting results to PSObjects"

        try
        {
            $convertObj = Convert-PowerStigTest -TestResults $scanObj
        }
        catch
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][ERROR]: $_"
            Continue
        }
        if($DebugScript)
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][Debug]: Object Results:"
            Add-Content -Path $logFilePath -Value "DesiredState`tFindingSeverity,`tStigDefinition,`tStigType,`tScanDate"
            foreach($o in $convertObj)
            {
                Add-Content -Path $logFilePath -Value "$($o.DesiredState),`t$($o.FindingSeverity),`t$($o.StigDefinition),`t$($o.StigType),`t$($o.ScanDate)"
            }
        }

        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][Info]: Importing Results to Database for $ServerName and role $r."

        Import-PowerStigObject -Servername $ServerName -InputObj $convertObj
    }

}

# M08
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

function Invoke-PowerStigScanV2
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true,Position=0,ParameterSetName='ByName')]
        [ValidateNotNullorEmpty()]
        [String[]]$ServerName,

        [Parameter(Mandatory=$false,ParameterSetName='SqlBatch')]
        [Parameter(Mandatory=$false,ParameterSetName='ByName')]
        [Switch]$RunScap,

        [Parameter(Mandatory=$false,ParameterSetName='SqlBatch')]
        [Parameter(Mandatory=$false,ParameterSetName='ByName')]
        [Switch]$ScapConfigConfirmed,

        [Parameter(Mandatory=$true,ParameterSetName='SqlBatch')]
        [Switch]$SqlBatch,

        [Parameter(Mandatory=$false,ParameterSetName='SqlBatch')]
        [String]$SqlInstanceName,

        [Parameter(Mandatory=$false,ParameterSetName='SqlBatch')]
        [String]$DatabaseName,

        [Parameter(Mandatory=$false)]
        [Switch]$DebugScript
    )

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

    Add-Content $logFilePath -Value "$(Get-Time):[Info]: New Scan Started - $(Get-Time)"

    if($PSCmdlet.ParameterSetName -eq "SqlBatch")
    {
        if($null -eq $SqlInstanceName -or $SqlInstanceName -eq '')
        {
            $SqlInstanceName = $iniVar.SqlInstanceName
        }
        if($null -eq $DatabaseName -or $DatabaseName -eq '')
        {
            $DatabaseName = $iniVar.DatabaseName
        }

        $ServerName = Get-PowerStigComputer -All | Select-Object -ExpandProperty TargetComputer
    }

    foreach($s in $ServerName)
    {
        # Check connection to remote server on WinRM
        Add-Content $logFilePath -Value "$(Get-Time):[$s][Info]: Testing Connectivity on port 5985 (WinRM)"

        if((Test-NetConnection -ComputerName $s -CommonTCPPort WINRM).TcpTestSucceeded -eq $false)
        {
            Add-Content -path $logFilePath -Value "$(Get-Time):[$s][Error]: Connection to $s Failed. Check network connectivity and that the server is listening for WinRM"
            Return
        }
        else 
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Info]: Connection to $s successful"
        }
        # Check WSMan Settings
        Add-Content $logFilePath -Value "$(Get-Time):[$s][Info]: Testing WSMAN configuration on target server"

        if($s -eq $ENV:ComputerName)
        {
            try {
                [int]$maxEnvelope = (get-childitem wsman:\localhost\MaxEnvelopeSizekb).value
            }
            catch {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][ERROR]: Query for WSMAN properties failed. Check user context that this is running under."
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][ERROR]: $_"
                Return
            }
            
        }
        else
        {
            try{
                [int]$maxEnvelope = invoke-command -ComputerName $s -ScriptBlock {((get-childitem wsman:\localhost\MaxEnvelopeSizekb).value)}
            }
            catch {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][ERROR]: Query for WSMAN properties failed. Check user context that this is running under."
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][ERROR]: $_"
                Return
            }
        }
    
        #Configure WSMAN if necessary
        if($maxEnvelope -lt 10000 -and $s -ne $ENV:ComputerName)
        {
            Add-Content -path $logFilePath -Value "$(Get-Time):[$s][Warning]: Attempting to set MaxEnvelopeSizeKb on $s."
            try 
            {
                invoke-command -computername $s -ScriptBlock {Set-Item -Path WSMAN:\localhost\MaxEnvelopeSizekb -Value 10000}
                Add-Content -path $logFilePath -Value "$(Get-Time):[$s][Info]: MaxEnvelopeSizeKb successfully configured on $s."
            }
            catch 
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][ERROR]: Setting WSMAN failed on $s."
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][ERROR]: $_"
                Return
            }
        }
        elseif($maxEnvelope -lt 10000 -and $s -eq $ENV:ComputerName)
        {
            Add-Content -path $logFilePath -Value "$(Get-Time):[$s][Warning]: Attempting to set MaxEnvelopeSizeKb on $s."
            try 
            {
                Set-Item -Path WSMAN:\localhost\MaxEnvelopeSizekb -Value 10000
                Add-Content -path $logFilePath -Value "$(Get-Time):[$s][Info]: MaxEnvelopeSizeKb successfully configured on $s."
            }
            catch 
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][ERROR]: Setting WSMAN failed on $s."
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][ERROR]: $_"
                Return
            }
        }
        else
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Info]: WSMan is correctly configured."
        }
    
        ###############################
        #Test WSMan Settings Complete #
        ###############################
        
        $ServerFilePath = "$logpath\$s"
        # Prepare Staging location
        if(-not(test-path $ServerFilePath))
        {
            
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Info]: Creating file path for this server at $ServerFilePath"            
            New-Item -ItemType Directory -Path $ServerFilePath
        }
    
        # Gather Role information
        $roles = Get-PowerStigServerRole -ServerName $s
        Add-Content $logFilePath -Value "$(Get-Time):[$s][Info]: PowerStig scan started on $s for role $($roles.roles) and version $($roles.version)."
    

        # If Scap enabled -
        if($RunScap -eq $True)
        {
        #   Compare Versions per role
            foreach($r in $roles.roles)
            {
                if($null -ne (Convert-PowerStigRoleToScap -Role $r))
                {
                    $ContinueRun = $true
                    $scapVer    = Get-PowerStigScapVersion -Role $r
                    $PsXmlVersion  = Get-PowerStigScapVersion -OSversion $roles.version -Role $r
                    if($scapVer -ne $PsXmlVersion -and $ScapConfigConfirmed -ne $true)
                    {
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Error]: Version mismatch between SCAP and PowerStig."
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Error]: PowerStig Version for Role $r is $PsXmlVersion."
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Error]: Scap Version for role $r is $scapVer."
                        $ContinueRun = $False
                    }
                    elseif($scapVer -ne $PSVersion -and $ScapConfigConfirmed -eq $true)
                    {
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Warning]: Stig version mismatch confirmed for role $r"
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Warning]: PowerStig Version for Role $r is $PsXmlVersion."
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Warning]: Scap Version for role $r is $scapVer."
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Warning]: Scap Configuration confirmed... Continuing scan."
                    }
                    elseif($scapVer -eq $PsXmlVersion)
                    {
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Info]: Stig version for role $r match for SCAP and PowerSTIG."
                    }
                }
                if($ContinueRun -eq $false)
                {
                    Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Error]: There was a version mismatch detected between SCAP and PowerSTIG."
                    Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Error]: Please reconcile the errors higher in this log for SCAP configuration."
                    Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Error]: If the configuration is correct, run this command again with the `"-ScapConfigConfirmed`" switch."
                    Return
                }
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Info]: Scap/PowerStig compatibility check passed"
            }

            # Configure SCAP profile according to config file
            # We must assume that the content is correctly selected by the user... SPAWAR give no way to confirm
            $ScapProfile = $iniVar.$ScapProfile
            $ScapInstallDir = $iniVar.ScapInstallDir

            # .\cscc.exe --SetProfileAll MAC-3_Sensitive
            & $ScapInstallDir\cscc.exe --SetProfileAll $ScapProfile -q | out-null

            # Generate SCAP Options.xml
            # Start SCAP Scan as job, hold job name to check status after PowerStig Completion
            # & $ScapInstallDir\cscc.exe -h $s -u "$ServerFilePath\Scap\Results" -o $ServerFilePath\Scap\Options\options.xml
        }

        # Scan Role via PowerSTIG
        # Generate Org File information per role, store in temp folder in $ServerFilePath\PSOrgSettings\$r_org.xml
        
        # If Sql enabled - Import role results as completion occurs on DSC Scan before starting next
        #   Determine if holding result in memory is resonable with Scap - Assuming not
        #   If Scap enabled, hold DSC results in jobs until SCAP job completes
        #   If Scap and Sql enabled, process SCAP results into SQL followed by DSC jobs
        #   If Scap disabled, generate CKL prior to moving to next scan
    }

}

#endregion Public
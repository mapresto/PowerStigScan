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
            "DotNetFramework"           {$rRole = "DotNetFramework-4";      $osVersion = $null}
            "FireFox"                   {$rRole = "FireFox";                $osVersion = $null}
            "IISServer"                 {$rRole = "IISServer-8.5";          $osVersion = $null}
            "IISSite"                   {$rRole = "IISSite-8.5";            $osVersion = $null}
            "InternetExplorer"          {$rRole = "InternetExplorer-11";    $osVersion = $null}
            "Excel2013"                 {$rRole = "Office-Excel2013";       $osVersion = $null}
            "Outlook2013"               {$rRole = "Office-Outlook2013";     $osVersion = $null}
            "PowerPoint2013"            {$rRole = "Office-PowerPoint2013";  $osVersion = $null}
            "Word2013"                  {$rRole = "Office-Word2013";        $osVersion = $null}
            "OracleJRE"                 {$rRole = "OracleJRE-8";            $osVersion = $null}
            "SqlServer-2012-Database"   {$rRole = "SqlServer-2012-Database";$osVersion = $null}
            "SqlServer-2012-Instance"   {$rRole = "SqlServer-2012-Instance";$osVersion = $null}
            "SqlServer-2016-Instance"   {$rRole = "SqlServer-2016-Instance";$osVersion = $null}
            "WindowsClient"             {$rRole = "WindowsClient-10";       $osVersion = $null}
            "WindowsDefender"           {$rRole = "WindowsDefender-All";    $osVersion = $null}
            "WindowsDNSServer"          {$rRole = "WindowsDNSServer-2012R2";$osVersion = $null}
            "WindowsFirewall"           {$rRole = "WindowsFirewall-All";    $osVersion = $null}
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

function Get-PowerStigOSandFunction
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName
    )

    $osVersion = (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ServerName).Version
    $domainRole = (Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ServerName).DomainRole

    if($domainRole -eq 4 -or $domainRole -eq 5)
    {
        $role = "DC"
        $osVersion = Get-ServerVersion -osVersion $osVersion
    }
    elseif($domainRole -eq 2 -or $domainRole -eq 3)
    {
        $role = "MS"
        $osVersion = Get-ServerVersion -osVersion $osVersion
    }
    elseif($domainRole -eq 0 -or $domainRole -eq 1)
    {
        $role = "Client"
        $osVersion = "10"
    }

    Return New-Object -TypeName PSObject -Property @{
        Role=$role
        OSVersion=$osVersion
    }
}

function Get-PowerStigServerRole
{
    [CmdletBinding()]
    param(
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
    if($ServerName -eq $env:COMPUTERNAME)
    {
        $keys = @(Get-ChildItem -path $uninstallPath | Where-Object {$_.name -like "*0FF1CE}"})
    }
    else 
    {
        $keys = @(Invoke-Command -computername $ServerName -scriptblock {param($uninstallPath) Get-ChildItem -path $uninstallPath | Where-Object {$_.name -like "*0FF1CE}"}} -ArgumentList $uninstallPath)
    }
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

    if($ServerName -eq $env:COMPUTERNAME)
    {
        $outVal = (Get-windowsoptionalfeature -FeatureName Internet-Explorer-Optional-amd64 -online).state -eq "Enabled"
    }
    else 
    {
        $outVal = Invoke-Command -ComputerName $ServerName -Scriptblock {(Get-windowsoptionalfeature -FeatureName Internet-Explorer-Optional-amd64 -online).state -eq "Enabled"}
    }

    Return $outVal
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

    if($ServerName -eq $env:COMPUTERNAME)
    {
        $outVal = Test-Path -path "HKLM:\Software\Mozilla\Mozilla Firefox\"
    }
    else 
    {
        $outVal = Invoke-Command -ComputerName $ServerName -scriptblock {Test-Path -path "HKLM:\Software\Mozilla\Mozilla Firefox\"}
    }
    Return $outVal
}

function Get-PowerStigFireFoxDirectory
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName
    )
    $InstallDirectory = invoke-command -ComputerName $ServerName -scriptblock {(get-itemproperty "HKLM:\Software\Mozilla\Mozilla Firefox\$((get-itemproperty "HKLM:\Software\Mozilla\Mozilla Firefox").currentversion)\Main")."Install Directory"}

    Return $InstallDirectory
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

    Return $false #(Get-WindowsFeature -ComputerName $ServerName -Name Web-Server).installstate -eq "Installed"
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

    Return $false #Invoke-Command -ComputerName $ServerName -ScriptBlock {if ((Test-Path -Path "HKLM:\SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment") -or (Test-Path -Path "HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment")){Return $true}else{Return $false}}
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
        [Switch]$FullScap,

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

    if($FullScap -eq $true)
    {
        $RunScap = $true
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

        $ServerName = [string[]](Get-PowerStigComputer -All | Select-Object -ExpandProperty TargetComputer)
    }

    if($DebugScript)
    {
        Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Variables Initialized as follows:"
        Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: RunScap = $RunScap"
        Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: FullScap = $FullScap"
        Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: ScapConfigConfirmed = $ScapConfigConfirmed"
        Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: SqlBatch = $SqlBatch"
        if($SqlBatch)
        {
            Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: SqlInstanceName = $SqlInstanceName"
            Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: DatabaseName = $DatabaseName"
        }
    }

            # If Scap enabled -
    if($RunScap -eq $True)
    {   
        $ScapInstallDir = $iniVar.ScapInstallDir
        Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][Info]: SCAP Processing initialized."
        $scapPath = "$logPath\SCAP"

        if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: scapPath = $scapPath"}

        if(-not(Test-Path $scapPath))
        {
            New-Item -Path $scapPath -ItemType Directory | Out-Null
            Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][Info]: Created Scap Path at $scapPath"
        }

        $runList = @{
            "2012R2_MS" = 0
            "2012R2_DC" = 0
            "2016_MS"   = 0
            "2016_DC"   = 0
            "Client"    = 0
        }
        $2012MS = @()
        $2012DC = @()
        $2016MS = @()
        $2016DC = @()
        $Client = @()
        # Determing type of batch
        foreach($s in $ServerName)
        {
            if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Current Server is $s"}
            $tempInfo = Get-PowerStigOSandFunction -ServerName $s
            if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: $s version is $($s.OSVersion)"}
            if($tempInfo.OsVersion -eq "2012R2")
            {
                if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: $s is 2012R2 = True"}
                if($tempinfo.Role -eq "DC" -and $runList."2012R2_DC" -ne 1)
                {
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Toggle switch for 2012R2_DC"}
                    $runList."2012R2_DC" = 1
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Adding $s to variable 2012DC"}
                    $2012DC += $s
                }
                elseif($tempInfo.Role -eq "MS" -and $runList."2012R2_MS" -ne 1)
                {
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Toggle switch for 2012R2_MS"}
                    $runList."2012R2_MS" = 1
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Adding $s to variable 2012MS"}
                    $2012MS += $s
                }
                elseif($tempInfo.Role -eq "MS" -and $runList."2012R2_MS" -eq 1)
                {
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Adding $s to variable 2012MS"}
                    $2012MS += $s
                }
                elseif($tempInfo.Role -eq "DC" -and $runList."2012_DC" -eq 1)
                {
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Adding $s to variable 2012DC"}
                    $2012DC += $s
                }
            }
            elseif($tempInfo.OsVersion -eq "2016")
            {
                if($tempInfo.Role -eq "DC" -and $runList."2016_DC" -ne 1)
                {
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Toggle switch for 2016_DC"}
                    $runList."2016_DC" = 1
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Adding $s to variable 2016DC"}
                    $2016DC += $s
                }
                elseif($tempInfo.Role -eq "MS" -and $runList."2016_MS" -ne 1)
                {
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Toggle switch for 2016_MS"}
                    $runList."2016_MS" = 1
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Adding $s to variable 2016MS"}
                    $2016MS += $s
                }
                elseif($tempInfo.Role -eq "MS" -and $runlist."2016_MS" -eq 1)
                {
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Adding $s to variable 2016MS"}
                    $2016MS += $s
                }
                elseif($tempInfo.Role -eq "DC" -and $runList."2016_DC" -eq 1)
                {
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Adding $s to variable 2016DC"}
                    $2016DC += $s
                }
            }
            elseif($tempInfo.OsVersion -eq "10" -and $runList."Client" -ne 1)
            {
                if($runList."Client" -ne 1)
                {
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Toggle switch for Client"}
                    $runList."Client" = 1
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Adding $s to variable Client"}
                    $Client += $s
                }
                else 
                {
                    if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Adding $s to variable Client"}
                    $Client += $s
                }
            }
        }

        if($DebugScript)
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][DEBUG]: Setting base configuration for SCAP"
        }

        Set-PowerStigScapBasicOptions
        while(((Get-Process | Where-Object {$_.ProcessName -like "cscc*"}).count) -gt 0)
        {
            Start-Sleep -seconds 1
        }

        Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][Info]: The following option and hosts files will be generated and ran"
        foreach($r in $runList.Keys)
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][Info]: Processing $r"
            if(($runList.$r) -eq 1)
            {
                New-Item -Path "$LogPath\SCAP\$($r)_Hosts.txt" -ItemType File -Force | Out-Null
                if      ($r -eq "2012R2_MS")
                {
                    if($FullScap -eq $true)
                    {
                        Set-PowerStigScapRoleXML -OsVersion "2012R2" -isDomainController:$false -RunAll
                    }
                    else 
                    {
                        Set-PowerStigScapRoleXML -OsVersion "2012R2" -isDomainController:$false
                    }
                    Add-Content -Path "$scapPath\$($r)_Hosts.txt" -value $2012MS -Force
                    $params = " -f `"$scapPath\$($r)_Hosts.txt`" -o `"$scapPath\2012R2_MS_options.xml`" -q"
                    Add-Content -path $logFilePath -Value "$(Get-Time):[SCAP][Info]: Starting SCAP Scan for $r"
                    if($DebugScript){Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][DEBUG]: params = $params"}
                    Start-Job -Name "SCAP_2012R2_MS" -ScriptBlock {param($params,$ScapInstallDir)write-host "ScapInstallDir = $ScapInstallDir";Write-Host "Params = $params";Invoke-Expression "& `"$ScapInstallDir\Cscc.exe`"$params"} -ArgumentList $params,$ScapInstallDir | Out-Null
                }
                elseif  ($r -eq "2016_MS")  
                {
                    if($FullScap -eq $true)
                    {
                        Set-PowerStigScapRoleXML -OsVersion "2016" -isDomainController:$false -RunAll
                    }
                    else 
                    {
                        Set-PowerStigScapRoleXML -OsVersion "2016" -isDomainController:$false
                    }
                    Add-Content -Path "$scapPath\$($r)_Hosts.txt" -value $2016MS -Force
                    $params = " -f `"$scapPath\$($r)_Hosts.txt`" -o `"$scapPath\2016_MS_options.xml`" -q"
                    Add-Content -path $logFilePath -Value "$(Get-Time):[SCAP][Info]: Starting SCAP Scan for $r"
                    if($DebugScript){Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][DEBUG]: params = $params"}
                    Start-Job -Name "SCAP_2016_MS" -ScriptBlock {param($params,$ScapInstallDir)write-host "ScapInstallDir = $ScapInstallDir";Write-Host "Params = $params";Invoke-Expression "& `"$ScapInstallDir\Cscc.exe`"$params"} -ArgumentList $params,$ScapInstallDir | Out-Null
                }
                elseif  ($r -eq "2012R2_DC")
                {
                    if($FullScap -eq $true)
                    {
                        Set-PowerStigScapRoleXML -OsVersion "2012R2" -isDomainController:$true -RunAll
                    }
                    else 
                    {
                        Set-PowerStigScapRoleXML -OsVersion "2012R2" -isDomainController:$true
                    }
                    Add-Content -Path "$scapPath\$($r)_Hosts.txt" -value $2012DC -Force
                    $params = " -f `"$scapPath\$($r)_Hosts.txt`" -o `"$scapPath\2012R2_DC_options.xml`" -q"
                    Add-Content -path $logFilePath -Value "$(Get-Time):[SCAP][Info]: Starting SCAP Scan for $r"
                    if($DebugScript){Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][DEBUG]: params = $params"}
                    Start-Job -Name "SCAP_2012R2_DC" -ScriptBlock {param($params,$ScapInstallDir)write-host "ScapInstallDir = $ScapInstallDir";Write-Host "Params = $params";Invoke-Expression "& `"$ScapInstallDir\Cscc.exe`"$params"} -ArgumentList $params,$ScapInstallDir | Out-Null
                }
                elseif  ($r -eq "2016_DC")  
                {
                    if($FullScap -eq $true)
                    {
                        Set-PowerStigScapRoleXML -OsVersion "2016" -isDomainController:$true -RunAll
                    }
                    else 
                    {
                        Set-PowerStigScapRoleXML -OsVersion "2016" -isDomainController:$true
                    }
                    Add-Content -Path "$scapPath\$($r)_Hosts.txt" -value $2016DC -Force
                    $params = " -f `"$scapPath\$($r)_Hosts.txt`" -o `"$scapPath\2016_DC_options.xml`" -q"
                    Add-Content -path $logFilePath -Value "$(Get-Time):[SCAP][Info]: Starting SCAP Scan for $r"
                    if($DebugScript){Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][DEBUG]: params = $params"}
                    Start-Job -Name "SCAP_2016_DC" -ScriptBlock {param($params,$ScapInstallDir)write-host "ScapInstallDir = $ScapInstallDir";Write-Host "Params = $params";Invoke-Expression "& `"$ScapInstallDir\Cscc.exe`"$params"} -ArgumentList $params,$ScapInstallDir | Out-Null
                }
                elseif  ($r -eq "Client")   
                {
                    if($FullScap -eq $true)
                    {
                        Set-PowerStigScapRoleXML -OsVersion "10" -isDomainController:$false -RunAll
                    }
                    else 
                    {
                        Set-PowerStigScapRoleXML -OsVersion "10" -isDomainController:$false
                    }
                    Add-Content -Path "$scapPath\$($r)_Hosts.txt" -Value $Client -Force
                    $params = " -f `"$scapPath\$($r)_Hosts.txt`" -o `"$scapPath\Client_options.xml`" -q"
                    Add-Content -path $logFilePath -Value "$(Get-Time):[SCAP][Info]: Starting SCAP Scan for $r"
                    if($DebugScript){Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][DEBUG]: params = $params"}
                    Start-Job -Name "SCAP_Client" -ScriptBlock {param($params,$ScapInstallDir)write-host "ScapInstallDir = $ScapInstallDir";Write-Host "Params = $params";Invoke-Expression "& `"$ScapInstallDir\Cscc.exe`"$params"} -ArgumentList $params,$ScapInstallDir | Out-Null
                }
            }
        }

        Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][Info]: SCAP has started to run. Waiting until all jobs complete."

        while (((Get-Process | Where-Object {$_.ProcessName -like "cscc*"}).count) -gt 0 -or (Get-Job | Where-Object {$_.state -eq "Running" -and $_.name -like "SCAP*"}).count -gt 0)
        {
            Start-Sleep -Seconds 2
        }

        if($DebugScript){Write-Host "SCAP has ended."}
        
        Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][Info]: SCAP scans have finished."

        if($SqlBatch -eq $true)
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][Info]: Attempting to import SCAP results to database"

            $scapResultXccdf = Get-Childitem -path C:\Temp\PowerStig\SCC\Results -Include "*Xccdf*" -Recurse
            $scapTech = Get-PowerStigScapVersionMap


            foreach($x in $scapResultXccdf)
            {
                $isDC = $false
                $splitSeparator = "_XCCDF-Results_"
                $sScap = ($x.Name -Split $splitSeparator)[0]
                $workingRole = ($x.Name -Split $splitSeparator)[1]
                $importRole=$null
            
                foreach($k in $scapTech.keys)
                {
                    [regex]$RoleMatch = $k
                    if($RoleMatch.Matches($workingRole).Success -eq $true)
                    {
                        $importRole = $RoleMatch.Matches($workingRole).value
                        Continue
                    }
                }

                if($importRole -eq "Windows_Server_2016")
                {
                    $tempObj = Get-PowerStigOSandFunction -ServerName $sScap
                    if($tempObj.Role -eq "DC")
                    {
                        $isDC = $true
                    }
                }
            
                $psRole = Convert-ScapRoleToPowerStig -Role $importRole -isDomainController:$isDC
                if($null -ne $psRole -and $psRole -ne '')
                {
                    $pStigVersion = Get-PowerStigXmlVersion -Role $psRole
                }
                else 
                {
                    $psRole = $importRole
                    $pStigVersion = $scapTech.$importRole
                }

                Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][Info]: Adding results for $psRole for $sScap"

                if($debugScript)
                {
                    Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][DEBUG]: sScap=$sScap"
                    Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][DEBUG]: workingRole=$workingRole"
                    Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][DEBUG]: importRole=$importRole"
                    Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][DEBUG]: isDC=$isDC"
                    Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][DEBUG]: pStigVersion=$pStigVersion"
                    Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][DEBUG]: psRole=$psRole"
                }

                $scapResults = Get-PowerStigScapResults -ScapResultsXccdf $x.FullName

                Import-PowerStigObject -ServerName $sScap -InputObj $scapResults -Role $psRole -ScanSource 'SCAP' -ScanVersion $pStigVersion
            }
        }
    }# End SCAP run job

    #initialize Hashtable to test for orgSettings creation. Prevents duplicate effort
    $orgSettingsProcessed = @{}

    $evalServers = @()
    # Start of PowerStig scans as traditional means.
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
            $evalServers += $s
        }
        # Check WSMan Settings
        Add-Content $logFilePath -Value "$(Get-Time):[$s][Info]: Testing WSMAN configuration on target server"

        if($s -eq $ENV:ComputerName)
        {
            try {
                [int]$maxEnvelope = (get-childitem "wsman:\localhost\MaxEnvelopeSizekb").value
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
                [int]$maxEnvelope = invoke-command -ComputerName $s -ScriptBlock {((get-childitem "wsman:\localhost\MaxEnvelopeSizekb").value)}
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
                invoke-command -computername $s -ScriptBlock {Set-Item -Path "WSMAN:\localhost\MaxEnvelopeSizekb" -Value 10000}
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
                Set-Item -Path "WSMAN:\localhost\MaxEnvelopeSizekb" -Value 10000
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
            New-Item -ItemType Directory -Path $ServerFilePath | Out-Null
        }
    
        # Gather Role information
        $roles = Get-PowerStigServerRole -ServerName $s
        Add-Content $logFilePath -Value "$(Get-Time):[$s][Info]: PowerStig scan started on $s for role $($roles.roles) and version $($roles.version)."

        # If SQL - Update role and OS information
        if($SqlBatch -eq $true)
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Info]: Updating server information in SQL."
            Set-PowerStigComputer -ServerName $s -osVersion $roles.Version
        }

        
        $OrgPath = "$logPath\PSOrgSettings\"
        if(-not(Test-Path $OrgPath))
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Info]: Creating Org Settings path at $OrgPath"
            New-Item -Path $OrgPath -ItemType Directory -Force | Out-Null
        }
    
        # Scan Role via PowerSTIG
        # Generate Org File information per role, store in temp folder in $ServerFilePath\PSOrgSettings\$r_org.xml
        ##########################################################################################################
        # POWERSTIG PORTION ############################################################################ YAY #####
        ##########################################################################################################

        # This is the difficult spot, if SQL is enabled, store the data in the database and recall when scap is done
        # If +SQL+SCAP Stor and check if SCAP complete (should check only once per run). 
            # If not, dump var to retrieve from DB after all scanning complete
            # Control number of PS scans from DB controlled metric
        # If +SQL-SCAP Stor and process results into new CKL
            # Send results to DB and proceed to build CKL file from the data present.
            # Control number of PS scans from DB controlled metric
        # If -SQL-SCAP process results into new CKL
            # Control number of PS scans from config.ini controlled metric
        # If -SQL+SCAP....
            # Attempt to hold data in memory until SCAP completes?
            # Wait to start PowerStig until SCAP completes?
            # Write results to temp file until all scans complete?
            # Refuse configuration???? Cry in a corner???? Who would do such a thing? oh yeah... users.
        
        #If +SQL check for OrgSettings in Database, else see if there is a file generated in the local path.
        #if Neither database nor fileExists, copy from PowerSTIG module path to OrgPath. This will allow for a persistent
        #org settings file that can be reused, even after reinstall.
        foreach($r in $roles.roles)
        {
            $orgFileName = "$orgPath\$($r)_org.xml"
            try
            {
                # Do scripting magic to build the orgsettings from the database. However, if there is not a database run,
                # check the orgPath to determine if there was a previous org file for the role and use that first.
                # $OrgSettingsPath
                if ($SqlBatch -eq $true -and $orgSettingsProcessed.Contains("$r") -eq $false)
                {
                    try 
                    {
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][Info]: Creating OrgSettings file for $r at $orgFileName"
                        if($DebugScript)
                        {
                            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][DEBUG]: Command Passed is: Get-PowerStigOrgSettings -Version $($roles.Version) -Role $r -OutPath $orgFileName"
                        }
                        Get-PowerStigOrgSettings -Version $roles.Version -Role $r -OutPath $orgFileName
                        $orgSettingsProcessed.Add("$r","1")
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][Info]: Org Settings generate from Database"
                    }
                    catch 
                    {
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][ERROR]: OrgSettings failed to generate:"
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][ERROR]: $_"
                    }
                }
                
                if (-not(Test-Path $orgFileName))
                {
                    Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][Info]: Processing Org Settings from local machine."
                    # If OrgSettings file exist in $OrgPath, use that else, copy from PowerStig and use the copied version
                    if(Test-Path $orgFileName)
                    {
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][Info]: OrgSettings exist in $orgFileName"
                    }
                    elseif(-not(Test-Path $orgFileName))
                    {
                        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][Info]: No previous org files in location. Attempting to copy from default PowerStig Location ($(Get-PowerStigXMLPath)"
                        if($r -like "*WindowsServer*")
                        {
                            $xmlEval = $r.split("-")[0] + "-" + $roles.Version + "-" + $r.split("-")[1]
                            $highVer = Get-PowerStigXmlVersion -Role $r -osVersion $roles.Version
                            if($DebugScript)
                            {
                                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][DEBUG]: xml evaluation term is $xmlEval"
                                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][DEBUG]: High Version is $highVer"
                            }
                            $srcOrgFileName = Get-ChildItem -Path "$(Get-PowerStigXMLPath)" | Where-Object {$_.Name -like "*$xmlEval*" -and $_.Name -like "*$highVer*" -and $_.Name -like "*.org.default.xml"} | Select-Object -ExpandProperty Name
                            if($DebugScript)
                            {
                                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][DEBUG]: Source xml file is $srcOrgFileName"
                            }
                            Copy-Item -Path "$(Get-PowerStigXMLPath)\$srcOrgFileName" -Destination $orgFileName
                            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][Info]: Org Settings Copied from PowerStig Directory"
                        }
                        else
                        {
                            $highVer = Get-PowerStigXmlVersion -Role $r -osVersion $roles.Version
                            if($DebugScript)
                            {
                                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][DEBUG]: High Version is $highVer"
                            }
                            $srcOrgFileName = Get-ChildItem -Path "$(Get-PowerStigXMLPath)" | Where-Object {$_.Name -like "*$r*" -and $_.Name -like "*$highVer*" -and $_.Name -like "*.org.default.xml"} | Select-Object -ExpandProperty Name
                            if($DebugScript)
                            {
                                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][DEBUG]: Source xml file is $srcOrgFileName"
                            }
                            Copy-Item -Path "$(Get-PowerStigXMLPath)\$srcOrgFileName" -Destination $orgFileName
                            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][Info]: Org Settings Copied from PowerStig Directory"
                        }
                    }
                }
                
                # This is here for future development.
                $arrSkipRule = $null
            }
            catch
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][ERROR]: OrgSettings failed when running:"
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][ERROR]: $_"
            }

            Push-Location $ServerFilePath
            try
            {
                $RunExpression = "& `"$workingPath\DSCCall.ps1`" -ComputerName $s -osVersion $($roles.Version) -Role $r -LogPath $logFilePath  -OrgSettingsFilePath $orgFileName"
                if($null -ne $arrSkipRule -and $arrSkipRule -ne "")
                {
                    $RunExpression += " -SkipRules $arrSkipRule"
                }
                Invoke-Expression -Command $RunExpression
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][Info]: MOF Created for $s for role $r"
                $mofPath = "$ServerFilePath\PowerStig\"
                $origMof = Get-ChildItem $mofPath | Where-Object {$_.Name -like "$s.mof"} | Select-Object -ExpandProperty FullName
                $mofName = $origMof.Replace(".mof","_$r.mof")
                Move-Item -path $origMof -Destination $mofName -Force
            }
            catch
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][ERROR]: mof generation failed when running:"
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][ERROR]: $RunExpression"
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][ERROR]: $_"
                Continue
            }
        

            if($DebugScript)
            {
                Add-Content -Path $logFilePath -value "$(Get-Time):[$s][$r][Debug]: mofName is $mofName"
            }
            Pop-Location


        }

    }

    ##############################################################################################
    #
    Continue
    #
    ##############################################################################################
    
    

    foreach ($s in $evalServers)
    {
        # Start Job that will retrieve test results.
        # Job must build the final results as well as import to SQL and create CKL
        
    }

    <#foreach($s in $ServerName)
    {
            #Run scan against target server      
            Push-location $mofPath

            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][Info]: Starting Scan for $mof"
            try 
            {
                if($DebugScript)
                {
                    Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][DEBUG]: Command to run is Test-DscConfiguration -ComputerName $s -ReferenceConfiguration $mofName"
                }
                $scanObj = Test-DscConfiguration -ComputerName $s -ReferenceConfiguration $mofName
            }
            catch 
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][ERROR]: $_"
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][ERROR]: mof variable is $mofName"
                Continue
            }

            Pop-Location




            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][Info]: Converting results to PSObjects"

            try
            {
                $convertObj = Convert-PowerStigTest -TestResults $scanObj
            }
            catch
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][ERROR]: $_"
                Continue
            }
            if($DebugScript)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Debug]: Object Results:"
                Add-Content -Path $logFilePath -Value "VulnID`tDesiredState`tFindingSeverity,`tStigDefinition,`tStigType,`tScanDate"
                foreach($o in $convertObj)
                {
                    Add-Content -Path $logFilePath -Value "$($o.VulnID),`t$($o.DesiredState),`t$($o.FindingSeverity),`t$($o.StigDefinition),`t$($o.StigType),`t$($o.ScanDate)"
                }
            }

            # If Sql enabled - Import role results as completion occurs on DSC Scan before starting next
            if($SqlBatch -eq $true)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Info]: Importing Results to Database for $s and role $r."

                Import-PowerStigObject -Servername $s -InputObj $convertObj -ScanSource 'POWERSTIG'
            }
        

    }#>

    Return $convertObj

    # ToDO!!!!
    # Switch PowerStigScan portion to Jobs to allow for parallel
    # foreach server/role
    # retrieve ScapScan result, 

}

Function Start-PowerStigDSCScan
{
    #The goal of this script is to take a MOF file and Generate results
    #params required include logging information, is it SCAP/SQL based, MofName, ServerName
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName,

        [Parameter(Mandatory=$true)]
        [String]$logFilePath,

        [Parameter(Mandatory=$false)]
        [Switch]$isScap,

        [Parameter(Mandatory=$false)]
        [Switch]$isSql,

        [Parameter(Mandatory=$false)]
        [Switch]$DebugScript
    )

    $workingPath                = Split-Path $PsCommandPath
    $iniVar                     = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($isSql)
    {
        $SqlInstanceName = $iniVar.SqlInstanceName
        $DatabaseName    = $iniVar.DatabaseName
    }

    Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][Info]: Starting DSC Scan for $ServerName"
    if($DebugScript)
    {
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: Initialized Values:"
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: isScap is $isScap"
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: isSql is $isSql"
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: SqlInstanceName is $SqlInstanceName"
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: DatabaseName is $DatabaseName"
    }

    $mofList = get-childitem -Path "C:\Temp\PowerStig\*" -Include "$ServerName*.mof" -Recurse

    if($DebugScript)
    {
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: Found the following mofs"
        foreach($m in $mofList)
        {
            $tech = $m.Name.split("_")[$m.Name.Split("_").count - 1].replace(".mof","")
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: $tech"
        }
    }

    foreach($m in $mofList)
    {
        $r = $m.Name.split("_")[$m.Name.Split("_").count - 1].replace(".mof","")
        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][DSC]: Starting scan for $r on $ServerName"
        if($DebugScript)
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][DSC][DEBUG]: Test-DscConfiguration -ComputerName $s -ReferenceConfiguration $($m.FullName)"
        }
        try
        {
            $ScanObj = Test-DscConfiguration -ComputerName $ServerName -ReferenceConfiguration $m.FullName
        }
        catch
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][ERROR]: $_"
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][ERROR]: mof variable is $($m.FullName)"
            Continue
        }

        Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][Info]: Converting results to PSObjects"

        try
        {
            $convertObj = Convert-PowerStigTest -TestResults $scanObj
        }
        catch
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][$r][ERROR]: $_"
            Continue
        }

        if($isSql)
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Info]: Importing Results to Database for $s and role $r."

            Import-PowerStigObject -Servername $s -InputObj $convertObj -ScanSource 'POWERSTIG'
        }

        if($isScap)
        {

        } #End isScap - Compare/Create Results
        else 
        {
            
        } #End -not isScap - Compare/Create Results
    }
}

#endregion Public
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
            "Excel2016"                 {$rRole = "Office-Excel2016";       $osVersion = $null}
            "Outlook2016"               {$rRole = "Office-Outlook2016";     $osVersion = $null}
            "PowerPoint2016"            {$rRole = "Office-PowerPoint2016";  $osVersion = $null}
            "Word2016"                  {$rRole = "Office-Word2016";        $osVersion = $null}
            "OracleJRE"                 {$rRole = "OracleJRE-8";            $osVersion = $null}
            "SqlServer-2012-Database"   {$rRole = "SqlServer-2012-Database";$osVersion = $null}
            "SqlServer-2012-Instance"   {$rRole = "SqlServer-2012-Instance";$osVersion = $null}
            "SqlServer-2016-Instance"   {$rRole = "SqlServer-2016-Instance";$osVersion = $null}
            "WindowsClient"             {$rRole = "WindowsClient-10";       $osVersion = $null}
            "WindowsDefender"           {$rRole = "WindowsDefender-All";    $osVersion = $null}
            "WindowsDNSServer"          {$rRole = "WindowsDNSServer-2012R2";$osVersion = $null}
            "WindowsFirewall"           {$rRole = "WindowsFirewall-All";    $osVersion = $null}
            "WindowsServer-DC"          {if($osVersion -eq "2012R2"){$rRole = "WindowsServer-2012R2-DC"}else{$rRole = "WindowsServer-2016-DC"}}
            "WindowsServer-MS"          {if($osVersion -eq "2012R2"){$rRole = "WindowsServer-2012R2-MS"}else{$rRole = "WindowsServer-2016-MS"}}
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
        $isOffice = Get-PowerStigIsOffice -ServerName $ServerName
        if($null -ne $isOffice)
        {
            if($isOffice -eq '2013')
            {
                $arrRole += "Outlook2013"
                $arrRole += "PowerPoint2013"
                $arrRole += "Excel2013"
                $arrRole += "Word2013"
            }
            elseif($isOffice -eq '2016')
            {
                $arrRole += "Outlook2016"
                $arrRole += "PowerPoint2016"
                $arrRole += "Excel2016"
                $arrRole += "Word2016" 
            }
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
        if((Get-PowerStigIsDNS -ServerName $ServerName) -and $osVersion -notlike "10.*")
        {
            $arrRole += "WindowsDNSServer"
        }
    }elseif($arrRole -contains "WindowsClient")
    {
        $isOffice = Get-PowerStigIsOffice -ServerName $ServerName
        if($null -ne $isOffice)
        {
            if($isOffice -eq '2013')
            {
                $arrRole += "Outlook2013"
                $arrRole += "PowerPoint2013"
                $arrRole += "Excel2013"
                $arrRole += "Word2013"
            }
            elseif($isOffice -eq '2016')
            {
                $arrRole += "Outlook2016"
                $arrRole += "PowerPoint2016"
                $arrRole += "Excel2016"
                $arrRole += "Word2016" 
            }
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
        if($keys.count -ge 1)
        {
            $highVersion = 0
            foreach($k in $keys)
            {
                [int]$workingVersion = Get-ItemProperty $k.toString().replace('HKEY_LOCAL_MACHINE','HKLM:') | Select-Object -ExpandProperty VersionMajor
                if($workingVersion -gt $highVersion)
                {
                    $highVersion = $workingVersion
                }
            }
            Switch($highVersion){
                '15' {Return '2013'}
                '16' {Return '2016'}
                'Default' {Return $null}
            }    
        }
        else 
        {
            Return $null
        }
    }
    else 
    {
        $keys = @(Invoke-Command -computername $ServerName -scriptblock {param($uninstallPath) Get-ChildItem -path $uninstallPath | Where-Object {$_.name -like "*0FF1CE}"}} -ArgumentList $uninstallPath)
        if($keys.count -ge 1)
        {
            $highVersion = 0
            foreach($k in $keys)
            {
                [int]$workingVersion =  Invoke-Command -computername $ServerName -scriptblock {param($keys)Get-ItemProperty $keys[0].toString().replace('HKEY_LOCAL_MACHINE','HKLM:') | Select-Object -ExpandProperty VersionMajor} -ArgumentList $keys
                if($workingVersion -gt $highVersion)
                {
                    $highVersion = $workingVersion
                }
            }
            Switch($highVersion){
                '15' {Return '2013'}
                '16' {Return '2016'}
                'Default' {Return $null}
            }    
        }
        else 
        {
            Return $null
        }
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
    $InstallDirectory = invoke-command -ComputerName $ServerName -scriptblock {(get-itemproperty "$((Get-ChildItem "HKLM:\SOFTWARE\Mozilla\Mozilla FireFox").Name.Replace("HKEY_LOCAL_MACHINE","HKLM:"))\Main")."Install Directory"}

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
    # Scan Role via PowerSTIG
    # Generate Org File information per role, store in temp folder in $ServerFilePath\PSOrgSettings\$r_org.xml
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

# M07
<#
.SYNOPSIS
Scans the target Computers with PowerStig reference configurations and, optionally, SCAP 5.1

.DESCRIPTION
This function will use PowerStig to build reference configurations for the roles that the server holds. These reference configurations will be used to determine if the Target has deviated from the expected configuration. A deviation is considered a finding when generating the checklist file. CKL files will be located in the location set in the CKLOutPath of the config.ini file in the $ModulePath\Common directory.

.PARAMETER ServerName
Short name or FQDN of server that is to be scanned. Should ensure that WinRM is enabled on the target server prior to running.

.PARAMETER RunScap
Utilizes SCAP 5.1 to run a scan against the target server. In order to run properly ensure that the ScapInstallDir and ScapProfile settings are set properly for the computer you are running this from and the environment that you are running against. Will only run Scans that have an equivilent PowerStig Scan.

.PARAMETER FullScap
Similar to RunScap, with the exception that it will run scans that do not match to a PowerStig scan as well, generating the checklists for those scans as well.

.PARAMETER SqlBatch
Will pull ServerNames from the Sql Database that is configured. This will also implement storage of findings for historical and reporting purposes.

.PARAMETER SqlInstanceName
Sql Instance to be used for the scan in coordination with SqlBatch. If no value is set, this will use the SqlInstanceName option in the config.ini in the $ModulePath\Common directory.

.PARAMETER DatabaseName
Database to be used for the scan in coordination with SqlBatch. If no value is set, this will use the DatabaseName option in the config.ini in the $ModulePath\Common directory.

.PARAMETER DebugScript
Enhanced logging is enabled for the PowerStig log located in the logPath configured in the $ModulePath\Common directory.

.EXAMPLE
Invoke-PowerStigScan -ServerName STIGDCTest01,Sql2012Test,Win10 -RunScap

Will run a scan against STIGDCTest01, Sql2012Test, and Win10 and will also run a SCAP scan at the same time. The Scap results will take precedence over the PowerStig results if there is a conflict

Invoke-PowerStigScan -SqlBatch -FullScap

Will run a scan against every target that exists in the database. This will also run a SCAP scan against all eligible SCAP compliance types and generate checklists for SCAP only and PowerStig/SCAP comparisons.

Invoke-PowerStigScan -SqlBatch

Will run only the PowerStig scans against every target in the database. This will generate a CKL file for each scan completed

#>
function Invoke-PowerStigScan
{
    # Two ways to get ServerName info is by Name or by SQL.
    # By Name can take an array of ServerNames passed to the property
    # Example: $ServerName = Get-AdComputer -filter * | Select-Object -ExpandProperty Name
    # RunScap will only run SCAP scans that coordinate with a PowerStig Scan
    # FullScap will run all valid SCAP scans on the target
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
    $cklOutPath                 = $iniVar.cklOutPath

    $Global:ProgressPreference = 'SilentlyContinue'

    $StartTime = Get-Date

    # Create the log path and file if they do not already exist.
    if(!(Test-Path -Path (Join-Path -Path $logPath -ChildPath $logFileName)))
    {
        $logFilePath = new-item -ItemType File -Path (Join-Path -Path $logPath -ChildPath $logFileName) -Force
    }
    else {
        $logFilePath = get-item -Path (Join-Path -Path $logPath -ChildPath $logFileName)
    }

    # If FullScap is selected, make RunScap true so any SCAP related items run for both options.
    if($FullScap -eq $true)
    {
        $RunScap = $true
    }

    Add-Content $logFilePath -Value "$(Get-Time):[Info]: New Scan Started - $(Get-Time)"

    # Initialize SQL options
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

        # Get list of Servers from SQL.
        # If you do not cast the result as [String[]], ServerName will not take it due to the Parameter value
        $ServerName = [string[]](Get-PowerStigComputer | Select-Object -ExpandProperty TargetComputer)
    }

    if($DebugScript)
    {
        Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Variables Initialized as follows:"
        Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: RunScap = $RunScap"
        Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: FullScap = $FullScap"
        Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: SqlBatch = $SqlBatch"
        if($SqlBatch)
        {
            Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: SqlInstanceName = $SqlInstanceName"
            Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: DatabaseName = $DatabaseName"
        }
    }

    Add-Content $logFilePath -Value "$(Get-Time):[Info]: Cleaning old files."
    Get-ChildItem $logPath -Directory -Recurse | Where-Object {$_.Name -notlike "*SCAP*" -and $_.Name -notlike "*SCC*" -and $CKLOutPath -notlike "$($_.FullName)*" -and $_.FullName -notlike "$CKLOutPath*" -and $_.Name -notlike "*PSOrgSettings*"} | Remove-Item -Force -Recurse
    
    # If Scap enabled
    if($RunScap -eq $True)
    {   
        # Initialize SCAP variables
        $ScapInstallDir = $iniVar.ScapInstallDir
        $ScapOnlyRoles = Get-ScapOnlyRoles
        
        Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][Info]: SCAP Processing initialized."
        # scapPath will hold SCAP settings such as hosts file and options.xml
        # logPath\SCC will hold all SCAP results. Remove the old results to ensure there are no conflicts
        ################  TODO  #####################
        #                                           #
        # Move Old SCAP results to compressed folder#
        #                                           #
        ################  END   #####################
        $scapPath = Join-Path -Path $logPath -ChildPath "SCAP"
        if(Test-Path (Join-Path -Path $logPath -ChildPath "SCC"))
        {
            Remove-Item (Join-Path -Path $logPath -ChildPath "SCC") -Recurse -Force
        }
        if(Test-Path $scapPath)
        {
            Remove-Item $scapPath -Recurse -Force
        }

        if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: scapPath = $scapPath"}

        # Create scapPath if it does not exist
        if(-not(Test-Path $scapPath))
        {
            New-Item -Path $scapPath -ItemType Directory | Out-Null
            Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][Info]: Created Scap Path at $scapPath"
        }

        # Initialize Hash Table to get list of SCAP scans that are required
        $runList = @{
            "2012R2_MS" = 0
            "2012R2_DC" = 0
            "2016_MS"   = 0
            "2016_DC"   = 0
            "Client"    = 0
        }
        # Initialize Arrays that will hold list of computers for each scan type to be added to hosts file consumed by SCAP
        $2012MS = @()
        $2012DC = @()
        $2016MS = @()
        $2016DC = @()
        $Client = @()
        
        # Determing type of batch
        foreach($s in $ServerName)
        {
            if($s -eq 'localhost')
            {
                $s = $ENV:ComputerName
            }
            # Get-PowerStigOSandFunction is the lightweight information grab that just returns OSVerion and domain role (DC,MS,Client)
            if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: Current Server is $s"}
            if((Test-NetConnection -ComputerName $s -CommonTCPPort WINRM -WarningAction SilentlyContinue).TcpTestSucceeded -eq $false)
            {
                Add-Content -Path $logFilePath -Value "$(Get-Time):[ERROR]: Could not connect to $s over WINRM. Moving to next server."
                Continue
            }
            $tempInfo = Get-PowerStigOSandFunction -ServerName $s
            if($DebugScript){Add-Content $logFilePath -Value "$(Get-Time):[DEBUG]: $s version is $($tempInfo.OSVersion)"}
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

        Add-Content -Path $logFilePath -Value "$(Get-Time):[SCAP][Info]: Processing SCAP results"

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

            if($SqlBatch -eq $true)
            {
                Import-PowerStigObject -ServerName $sScap -InputObj $scapResults -Role $psRole -ScanSource 'SCAP' -ScanVersion $pStigVersion
            }

            if($ScapOnlyRoles -contains $importRole)
            {
                $sourceHash = @{}
                $scapHash = Set-PowerStigResultHashTableFromObject -InputObject $scapResults
                $sInfo = Get-PowerStigOSandFunction -ServerName $sScap
                foreach($k in $scapHash.keys)
                {
                    $SourceHash.add("$k","1")
                }
                Update-PowerStigCkl -ServerName $sScap -Role $importRole -osVersion $sInfo.OSVersion -InputObject $scapHash -outPath $cklOutPath -SourceHash $SourceHash

            }
        }
        
    }# End SCAP run job

    #initialize Hashtable to test for orgSettings creation. Prevents duplicate effort
    $orgSettingsProcessed = @{}

    $evalServers = @()
    # Start of PowerStig scans as traditional means.
    ########################################################################
    ##
    ## Start of MOF Generation
    ##
    ########################################################################
    foreach($s in $ServerName)
    {
        if($s -eq 'localhost')
        {
            $s = $ENV:ComputerName
        }
        # Check connection to remote server on WinRM
        Add-Content $logFilePath -Value "$(Get-Time):[$s][Info]: Testing Connectivity on port 5985 (WinRM)"

        if((Test-NetConnection -ComputerName $s -CommonTCPPort WINRM -WarningAction SilentlyContinue).TcpTestSucceeded -eq $false)
        {
            Add-Content -path $logFilePath -Value "$(Get-Time):[$s][Error]: Connection to $s Failed. Check network connectivity and that the server is listening for WinRM"
            Continue
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
                Continue
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
                Continue
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
                Continue
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
                Continue
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
            Set-PowerStigComputer -ServerName $s -osVersion $roles.Version -DebugScript:$DebugScript
        }

        
        $OrgPath = "$logPath\PSOrgSettings\"
        if(-not(Test-Path $OrgPath))
        {
            Add-Content -Path $logFilePath -Value "$(Get-Time):[$s][Info]: Creating Org Settings path at $OrgPath"
            New-Item -Path $OrgPath -ItemType Directory -Force | Out-Null
        }
    
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
                Invoke-Expression -Command $RunExpression | Out-Null
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
                Pop-Location
                Continue
            }
        

            if($DebugScript)
            {
                Add-Content -Path $logFilePath -value "$(Get-Time):[$s][$r][Debug]: mofName is $mofName"
            }
            Pop-Location


        }

    }
    #####################################################################################################
    ##
    ##  End MOF Creation
    ##
    #####################################################################################################

    
    $concurrentScans = $iniVar.ConcurrentScans
    $jobCount = $evalServers.count
    

    foreach ($s in $evalServers)
    {
        $sOsVersion = (Get-PowerStigOSandFunction -ServerName $s).OSVersion
        $jobScript = {param($s,$sOsVersion,$RunScap,$SqlBatch,$DebugScript)Start-PowerStigDSCScan -ServerName $s -osVersion $sOsVersion -isScap:$RunScap -isSql:$SqlBatch -DebugScript:$DebugScript}

        Start-Job -Name "PowerStig_$s" -ScriptBlock $jobScript -ArgumentList $s,$sOsVersion,$RunScap,$SqlBatch,$DebugScript | Out-Null
        $jobCount -= 1

        Add-Content -Path $logFilePath -Value "$(Get-Time):[DSCMain][Info]: There are $jobCount jobs left to start"
        
        While((Get-Job | Where-Object {$_.state -eq "Running" -and $_.name -like "*PowerSTIG*"}).count -ge $concurrentScans)
        {
            Start-Sleep -Seconds 2
        }
    }

    $jobCount = (Get-Job | Where-Object {$_.state -eq "Running" -and $_.name -like "*PowerSTIG*"}).count
    $newJobCount = 0

    While((Get-Job | Where-Object {$_.state -eq "Running" -and $_.name -like "*PowerSTIG*"}).count -gt 0)
    {
        if($jobCount -ne $newJobCount)
        {
            $jobCount = (Get-Job | Where-Object {$_.state -eq "Running" -and $_.name -like "*PowerSTIG*"}).count
            Add-Content -Path $logFilePath -Value "$(Get-Time):[DSCMain][Info]: There are $jobCount jobs remaining."
        }
        Start-Sleep -Seconds 2
        $newJobCount = (Get-Job | Where-Object {$_.state -eq "Running" -and $_.name -like "*PowerSTIG*"}).count
    }

    $Timestamp = (get-date).ToString("yyyyMMdd")

    $FolderName = "Results_$TimeStamp"

    if(-not(Test-Path "$cklOutPath\$folderName"))
    {
        New-Item "$cklOutPath\$folderName" -ItemType Directory -Force | Out-Null
    }

    Get-ChildItem $cklOutPath | Where-Object {$_.mode -notlike "d*" -and $_.CreationTime -gt $startTime} | ForEach-Object {Move-Item -path $_.FullName -Destination "$cklOutPath\$folderName\$($_.Name)" -Force}

    Add-Content -Path $logFilePath -Value "$(Get-Time):[Info]: SCAN COMPLETE"

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
        [String]$osVersion,

        [Parameter(Mandatory=$false)]
        [Switch]$isScap,

        [Parameter(Mandatory=$false)]
        [Switch]$isSql,

        [Parameter(Mandatory=$false)]
        [Switch]$DebugScript
    )

    $workingPath    = Split-Path $PsCommandPath
    $iniVar         = Import-PowerStigConfig -configFilePath $workingPath\Config.ini
    $cklOutPath     = $iniVar.CKLOutPath
    $logPath        = $iniVar.LogPath
    $logDate        = get-date -UFormat %m%d
    $logFileName    = "PowerStigJobLog"+ $logDate + ".txt"
    
    if(!(Test-Path -Path "$logPath\$logFileName"))
    {
        $logFilePath = new-item -ItemType File -Path "$logPath\$logFileName" -Force
    }
    else {
        $logFilePath = get-item -Path "$logPath\$logFileName"
    }

    if($isSql)
    {
        $SqlInstanceName = $iniVar.SqlInstanceName
        $DatabaseName    = $iniVar.DatabaseName
    }

    Function Write-PowerStigPSLog
    {
        param(
            [String]$Path,
            [String]$Value
        )

        $mutex = [System.Threading.Mutex]::new($false,'LogWrite')

        $mutex.WaitOne() | Out-Null

        try{
            Add-Content -path $Path -Value $Value
        }
        catch{
            Write-Host "Logging failed due to process holding the log file open"
        }
        finally{
            $mutex.ReleaseMutex()
            $mutex.Dispose()
        }
    }

    Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][Info]: Starting DSC Scan for $ServerName"
    if($DebugScript)
    {
        Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: Initialized Values:"
        Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: isScap is $isScap"
        Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: isSql is $isSql"
        Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: SqlInstanceName is $SqlInstanceName"
        Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: DatabaseName is $DatabaseName"
        Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: cklOutPath is $cklOutPath"
    }

    $mofList = @(get-childitem -Path "C:\Temp\PowerStig\$ServerName\PowerStig\*" -Include "$ServerName*.mof" -Recurse)

    if($DebugScript)
    {
        Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: Found the following mofs"
        foreach($m in $mofList)
        {
            $tech = $m.Name.split("_")[$m.Name.Split("_").count - 1].replace(".mof","")
            Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][DSC][DEBUG]: $tech"
        }
    }

    foreach($m in $mofList)
    {
        $r = $m.Name.split("_")[$m.Name.Split("_").count - 1].replace(".mof","")
        Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][$r][DSC]: Starting scan for $r on $ServerName"
        if($DebugScript)
        {
            Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][$r][DSC][DEBUG]: Test-DscConfiguration -ComputerName $Servername -ReferenceConfiguration $($m.FullName)"
        }
        try
        {
            $ScanObj = Test-DscConfiguration -ComputerName $ServerName -ReferenceConfiguration $m.FullName
        }
        catch
        {
            Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][$r][ERROR]: $_"
            Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][$r][ERROR]: mof variable is $($m.FullName)"
            Continue
        }

        Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][$r][Info]: Converting results to PSObjects"

        try
        {
            $convertObj = Convert-PowerStigTest -TestResults $scanObj
            $resultHash = Set-PowerStigResultHashTableFromObject -InputObject $ConvertObj
        }
        catch
        {
            Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][$r][ERROR]: $_"
            Continue
        }

        if($isSql)
        {
            Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][Info]: Importing Results to Database for $ServerName and role $r."

            Import-PowerStigObject -Servername $ServerName -InputObj $convertObj -Role $r -ScanSource 'POWERSTIG' -ScanVersion (Get-PowerStigXmlVersion -Role $r -osVersion $osVersion)
        }

        $SourceHash = @{}
        $outHash    = @{}
        if($isScap)
        {
            $ScapRole   = Convert-PowerStigRoleToScap -OsVersion $osVersion -Role $r
            # SourceHash will hold the VulnID number with a 1(SCAP) or 0(PowerStig)
            
            if($Null -ne $ScapRole)
            {
                # Determine SCAP Results File or Pass Hash
                $ScapFile = Get-ChildItem "$logPath\SCC\Results\$ServerName\XML\" -Recurse | Where-Object {$_.Name -like "*XCCDF*" -and $_.Name -like "*$ScapRole*"}
                if($null -ne $ScapFile)
                {
                    $ScapHash = Get-PowerStigScapResults -ScapResultsXccdf $ScapFile.FullName -OutHash

                    foreach($k in $resultHash.Keys)
                    {
                        if($ScapHash.ContainsKey($k))
                        {
                            $outHash.add("$k",$($ScapHash.$k))
                            $SourceHash.add("$k","1")
                        }
                        else
                        {
                            $outHash.add("$k",$($resultHash.$k))
                            $SourceHash.add("$k","0")
                        }
                    }
                    if($DebugScript){Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][Debug]: SCAP and PowerShell results have been compared and hash tables created."}
                }
                else 
                {
                    foreach($k in $resultHash.keys)
                    {
                        Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][Warning]: SCAP results not found for $ServerName and role $r."
                        $SourceHash.add("$k","0")
                    }
                    $outHash = $resultHash 
                    if($DebugScript){Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][Debug]: Results Hash table created for $ServerName and $r created."}
                }

                # if DSC hash and SCAP hash has same key - Default to SCAP hash
                # if DSC hash only - Use that
                # if SCAP hash only - Use that
                # Pass hash to New-CKL
            }
            else 
            {
                foreach($k in $resultHash.keys)
                {
                    $SourceHash.add("$k","0")
                }
                $outHash = $resultHash
                if($DebugScript){Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][Debug]: Results Hash table created for $ServerName and $r created."}

            }

        } #End isScap - Compare/Create Results
        else
        {
            foreach($k in $resultHash.keys)
            {
                $SourceHash.add("$k","0")
            }
            $outHash = $resultHash
        }
        
        Update-PowerStigCkl -ServerName $ServerName -Role $r -osVersion $osVersion -InputObject $outHash -outPath $cklOutPath -SourceHash $SourceHash
        # End -not isScap - Compare/Create Results

        

    }

    Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ServerName][Info]: Job complete for server $ServerName"
}

Function Install-PowerStigSQLDatabase
{
    param(
        [Parameter(ParameterSetName='Set1',Position=0,Mandatory=$true)][String]$SqlInstanceName,
        [parameter(ParameterSetName='Set1',Position=1,Mandatory=$true)][String]$DatabaseName    
    )

    $PowerStigVersion = "3.2.0"
    $CopyTest = $false
    $ImportOrgXML = $true
    $workingPath    = Split-Path $PsCommandPath

    & $workingPath\..\SQL\DBdeployer.ps1 -DBServerName $SqlInstanceName -DatabaseName $DatabaseName

    Set-PowerStigConfig -SqlInstanceName $SqlInstanceName -DatabaseName $DatabaseName

    # TODO #
    # Add function to import org settings automatically
    $orgTest = Get-PowerStigOrgSettings -Version 2012R2 -Role WindowsServer-MS -ErrorAction SilentlyContinue

    if($null -eq $orgTest)
    {
        if($SqlInstanceName -like "*$env:COMPUTERNAME*")
        {
            $moduleTest = Get-Module -Name PowerStig -ListAvailable | Where-Object {$_.Version -eq $PowerStigVersion}
        }
        else 
        {
            if($SqlInstanceName -like "*\*")
            {
                $ServerName = $SqlInstanceName.Split("\")[0]
            }
            else 
            {
                $ServerName = $SqlInstanceName    
            }
            $moduleTest = Invoke-Command -ComputerName $ServerName -ScriptBlock {Get-Module -Name PowerStig -ListAvailable | Where-Object {$_.Version -eq "3.2.0"}}    
        }
        if($null -eq $moduleTest)
        {
            Write-Warning -Message "PowerStig $PowerStigVersion is not installed on the target server. Attempting to install via Install-Module."
            try 
            {
                if($SqlInstanceName -like "*$env:COMPUTERNAME*")
                {
                    Install-Module -Name PowerStig -RequiredVersion $PowerStigVersion -ErrorAction Stop
                }
                else 
                {
                    Invoke-Command -ComputerName $ServerName -ScriptBlock {param($PowerStigVersion)Install-Module -Name PowerStig -RequiredVersion $PowerStigVersion -ErrorAction Stop} -ArgumentList $PowerStigVersion -ErrorAction Stop
                }
            }
            catch 
            {
                Write-Warning -Message "PowerStig $PowerStigVersion could not be installed via Install-Module."
                $CopyTest = $true
            }

            if($ServerName -ne $env:COMPUTERNAME)
            {
                $localModTest = Get-Module -Name PowerStig -ListAvailable | Where-Object {$_.Version -eq $PowerStigVersion}
                if($null -ne $localModTest -and $CopyTest -eq $true)
                {
                    Write-Warning -Message "Attempting to copy PowerStig $PowerStigVersion from local machine."
                    try 
                    {
                        Copy-Item -Path (Get-Module PowerStig -listavailable| Where-Object {$_.Version -eq "3.2.0"} |Select-Object -ExpandProperty ModuleBase) -Destination "\\$ServerName\C$\Program Files\WindowsPowerShell\Modules\PowerStig\$PowerStigVersion\" -Recurse -Force
                    }
                    catch 
                    {
                        Write-Warning -Message "PowerStig $PowerStigVersion could not be copied to the target server."
                        $ImportOrgXML = $false
                    }
                }
            }
            if(-not $ImportOrgXML)
            {
                Write-Warning -Message "PowerStig $PowerStigVersion could not be installed on the target server. Organizational settings import cannot run until it is installed. PowerStigScan can still run using local Organizational Settings xml files from the PowerStig directory."
            }
        }
        if($ImportOrgXML)
        {
            Write-Warning -Message "Importing PowerStig Organizational Settings from PowerStig $PowerStigVersion module directory"
            $query = "EXEC PowerStig.sproc_ImportOrgSettingsXML"
            Invoke-PowerStigSqlCommand -SqlInstance $SqlInstanceName -DatabaseName $DatabaseName -Query $query | Out-Null   
            if($SqlInstanceName -like "*$env:COMPUTERNAME*")
            {
                $moduleTest = Get-Module -Name PowerStig -ListAvailable | Where-Object {$_.Version -eq $PowerStigVersion}
            }
            else 
            {
                if($SqlInstanceName -like "*\*")
                {
                    $ServerName = $SqlInstanceName.Split("\")[0]
                }
                else 
                {
                    $ServerName = $SqlInstanceName    
                }
                $moduleTest = Invoke-Command -ComputerName $ServerName -ScriptBlock {Get-Module -Name PowerStig -ListAvailable | Where-Object {$_.Version -eq "3.2.0"}}    
            }
            if($null -eq $moduleTest)
            {
                Write-Warning -Message "Organizational Settings were not imported into the Database. PowerStigScan can still function but the issue should be resolved to provide log term retention of organizational specific settings."
            }
            else 
            {
                Write-Warning -Message "Organizational Settings imported successfully."    
            }
        }
    }

    Write-Host "Database $DatabaseName on $SqlInstanceName has finished installing."
}

#endregion Public
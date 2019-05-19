function Get-PowerStigScapVersionMap
{
    $verHash= @{
        #PSTIGVer2.14 
        "Windows_2012_MS"="2.14"
        #PSTIGVer=2.15
        "Windows_2012_DC"="2.15"
        #PSTIGVer=1.7
        "Windows_Server_2016"="1.8"
        #PSTIGVer=1.7
        "Windows_Firewall"="1.7"
        #PSTIGVer=1.4
        "Windows_Defender_Antivirus"="1.1"
        #PSTIGVer=1.16 - There was not a new Benchmark to match January 2019 STIG release, defaulted to previous Benchmark
        "Windows_10"="1.13"
        #PSTIGVer=1.16
        "IE_11"="1.12"
        #PSTIGVer=1.6
        "MS_Dot_Net_Framework"="1.5"
        #Following does not have a corresponding PowerStig Equivilent
        #StigVer=1.4
        "Adobe_Acrobat_Reader_DC_Classic"="1.5"
        #StigVer=1.5
        "Adobe_Acrobat_Reader_DC_Continuous"="1.4"
        #StigVer=1.15
        "Google_Chrome"="1.11"
    }

    Return $verHash
   
}

Function Get-ScapOnlyRoles
{
    $sRoles =   "Adobe_Acrobat_Reader_DC_Classic",
                "Adobe_Acrobat_Reader_DC_Continuous",
                "Google_Chrome",
                "MS_Dot_Net_Framework"

    Return $sRoles
}




function Get-PowerStigScapResults
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ScapResultsXccdf,

        [Parameter(Mandatory=$false)]
        [Switch]$OutHash
    )

    [xml]$ScapXML = Get-Content -Path $ScapResultsXccdf
    $ScanDate = (Get-ChildItem $ScapResultsXccdf).LastWriteTime.ToString()

    #$ScapXML.Benchmark.TestResult.'rule-result'  #ruleID

    $ResultHash = @{}
    $VIDHash = @{}
    [Regex]$VIDRegex = "V-([1-9}])[0-9]{3}[0-9]?"

    foreach($r in $($ScapXML.Benchmark.TestResult.'rule-result'))
    {
        $boolOut = $false
        if($r.result -eq 'pass')
        {
            $boolOut = $true
        }

        $ResultHash.Add($($r.idref),$boolOut)
    }

    #EXAMPLE: $ResultHash."$($ScapXML.Benchmark.Group[0].rule.id[0])"
    #V-ID: $testXML.Benchmark.Group[0].id[0]

    foreach($g in $($ScapXML.Benchmark.Group))
    {
        if($ResultHash."$($g.rule.id[0])" -eq $true)
        {
            $gBoolOut = $true
            $vID = $VIDRegex.matches($($g.id[0])).Value
            $VIDHash.Add($vID,$gBoolOut)
        }
        elseif($ResultHash."$($g.rule.id[0])" -eq $false)
        {
            $gBoolOut = $false
            $vID = $VIDRegex.matches($($g.id[0])).Value
            $VIDHash.Add($vID,$gBoolOut)
        }
    }

    if($OutHash -eq $true)
    {
        Return $VIDHash
    }

    $outObj = @()

    foreach($i in $VIDHash.Keys)
    {
        $props = @{VulnID = $i;
             DesiredState = $VIDHash.$i;
                 ScanDate = $ScanDate}
        $outObj += New-Object -TypeName PSObject -Property $props
    }

    Return $outObj
}


function Get-PowerStigScapVersion
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ScapRole
    )

    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    $ScapInstallDir = $iniVar.ScapInstallDir

    $ScapContent = Get-ChildItem "$ScapInstallDir\Resources\Content\SCAP12_Content"

    [Regex]$VersionMatch = "V[1-9]?[0-9]R[0-9][0-9]?"

    foreach($c in $ScapContent)
    {
        if($c.name -like "*$scapRole*")
        {
            
            $fileVersion = ($VersionMatch.matches($c.name)).value
            [int32]$tempMaj = $fileVersion.Split("R")[0].replace("V","")
            [int32]$tempMin = $fileVersion.Split("R")[1]
            [Version]$tempVer = "$tempMaj.$tempMin"
            
            if($null -eq $testVer)
            {
                $testVer = $tempVer
            }
            elseif($tempVer -gt $testVer)
            {
                $testVer = $tempVer
            }
            
            
        }
    }
    
    Return $testVer
}

function Get-PowerScapOutputPath
{
    $workingPath                = Split-Path $PsCommandPath
    $iniVar                     = Import-PowerStigConfig -configFilePath $workingPath\Config.ini
    $scapPath = $iniVar.ScapInstallDir

    $results = & "$scapPath\cscc.exe --getopt userDataDirectory -q"

    $directory = $results[$results.count - 1].replace("userDataDirectory = ","")

    return $directory
}

function Convert-PowerStigRoleToScap
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("2016","2012R2","10","All")]
        [String]$OsVersion
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
        switch($Role)
        {
            "DotNetFramework"           {Return "MS_Dot_Net_Framework"}
            "FireFox"                   {Return $null}
            "IISServer"                 {Return $null}
            "IISSite"                   {Return $null}
            "InternetExplorer"          {Return "IE_11"}
            "Excel2013"                 {Return $null}
            "Outlook2013"               {Return $null}
            "PowerPoint2013"            {Return $null}
            "Word2013"                  {Return $null}
            "OracleJRE"                 {Return $null}
            "SqlServer-2012-Database"   {Return $null}
            "SqlServer-2012-Instance"   {Return $null}
            "SqlServer-2016-Instance"   {Return $null}
            "WindowsClient"             {Return "Windows_10"}
            "WindowsDefender"           {Return "Windows_Defender_Antivirus"}
            "WindowsDNSServer"          {Return $null}
            "WindowsFirewall"           {Return "Windows_Firewall"}
            "WindowsServer-DC"          {if($OsVersion -eq "2016"){Return "Windows_Server_2016"}
                                    elseif($OsVersion -eq "2012R2"){Return "Windows_2012_DC"} }
            "WindowsServer-MS"          {if($OsVersion -eq "2016"){Return "Windows_Server_2016"}
                                    elseif($OsVersion -eq "2012R2"){Return "Windows_2012_MS"} }
        }
    }
}

Function Convert-ScapRoleToPowerStig
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$Role,

        [Parameter(Mandatory=$false)]
        [Switch]$isDomainController
    )


    
    switch -Wildcard ($Role)
    {
        "*Windows_Server_2016*"           {if($isDomainController){Return "WindowsServer-DC"}else{Return "WindowsServer-MS"}}
        "*Windows_2012_MS*"               {Return "WindowsServer-MS"}
        "*Windows_2012_DC*"               {Return "WindowsServer-DC"}
        "*Windows_Firewall*"              {Return "WindowsFirewall"}
        "*Windows_Defender_Antivirus*"    {Return "WindowsDefender"}
        "*Windows_10*"                    {Return "WindowsClient"}
        "IE_11*"                          {Return "InternetExplorer"}
        "*MS_Dot_Net_Framework*"          {Return "DotNetFramework"}
    }

}

Function Set-PowerStigScapBasicOptions
{
    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini
    $basePath = $iniVar.LogPath

    $ScapInstallDir = $iniVar.ScapInstallDir
    $outputPath = Join-Path -Path $basepath -ChildPath "SCC"

    $ScapOptions = @{
        "scapScan"                          = "1"
        "ovalScan"                          = "0"
        "ocilScan"                          = "1"
        "allSettingsHTMLReport"             = "1"
        "allSettingsTextReport"             = "0"
        "nonComplianceHTMLReport"           = "0"
        "nonComplianceTextReport"           = "0"
        "allSettingsSummaryHTMLReport"      = "0"
        "allSettingsSummaryTextReport"      = "0"
        "nonComplianceSummaryHTMLReport"    = "0"
        "nonComplianceSummaryTextReport"    = "0"
        "keepXCCDFXML"                      = "1"
        "keepOVALXML"                       = "0"
        "keepOCILXML"                       = "0"
        "keepARFXML"                        = "0"
        "keepCPEXML"                        = "0"
        "userDataDirectory"                 = $outputPath
        "userDataDirectoryValue"            = "4"
        "dirResultsLogsEnabled"             = "1"
        "dirTargetNameEnabled"              = "1"
        "dirXMLEnabled"                     = "1"
        "dirStreamNameEnabled"              = "0"
        "dirContentTypeEnabled"             = "0"
        "dirTimestampEnabled"               = "0"
        "fileTargetNameEnabled"             = "1"
        "fileSCCVersionEnabled"             = "0"
        "fileContentVersionEnabled"         = "1"
        "fileTimestampEnabled"              = "0"
    }

    if(-not(Test-Path -Path $outPutPath))
    {
        New-Item -Path $outPutPath -ItemType Directory -force | Out-Null
    }

    $strSetOpt = ""
    foreach($sOpt in $($ScapOptions.Keys))
    {
        $strSetOpt += " --setOpt $sOpt $($ScapOptions.$sOpt)"
    }

    $exePath = Join-Path -Path $ScapInstallDir -ChildPath "cscc.exe"

    $cmdStart = "& `"" + $exePath + "`" "
    $configCommand = "$cmdStart$strSetOpt -q"    
    Invoke-Expression $configCommand | Out-Null
}

function Set-PowerStigScapRoleXML
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('2012R2','2016','10')]
        [String]$OsVersion,

        [Parameter(Mandatory=$false)]
        [switch]$isDomainController,

        [Parameter(Mandatory=$false)]
        [switch]$RunAll
    )

    
    $fileName = "$($OsVersion)_$(if($isDomainController){"DC"}else{"MS"})_options.xml"
    if($OsVersion -eq '10')
    {
        $fileName = "Client_options.xml"
    }
    $iniVar = Import-PowerStigConfig -configFilePath "$(Split-Path $PsCommandPath)\Config.ini"
    $scapInstallDir = $iniVar.ScapInstallDir
    $ScapProfile = $iniVar.ScapProfile
    $logPath = $iniVar.LogPath
    $outpath = Join-Path -Path $logPath -ChildPath "SCAP\"

    [xml]$configXML = Get-Content $ScapInstallDir\options.xml
    $configXML.PreserveWhitespace = $true
    $psRoles = Import-CSV "$(Split-Path $PsCommandPath)\Roles.csv" -Header Role | Select-Object -ExpandProperty Role

    $xmlRoles = @()

    # Determine which roles exist in Scap
    foreach($r in $psRoles)
    {
        if($r -like "WindowsServer-DC" -and $isDomainController -eq $false)
        {
            continue
        }
        elseif($r -like "WindowsServer-MS" -and $isDomainController -eq $true)
        {
            continue
        }
        elseif($r -like "*WindowsServer*")
        {
            $testRole = Convert-PowerStigRoleToScap -Role $r -OsVersion $OsVersion
            if($null -ne $testRole)
            {
                $xmlRoles += $testRole
            }
        }
        else 
        {
            $testRole = Convert-PowerStigRoleToScap -Role $r
            if($null -ne $testRole)
            {
                $xmlRoles += $testRole
            }
        }
        
    }

    $workingVersions = Get-PowerStigScapVersionMap

    foreach($i in $($configXML.options.contents.content))
    {
        
        $i.enabled = "0"
        if($i.benchmarkID -like "*USGCB*"){Continue}

        [Version]$iVer = $i.version

        if($RunAll -eq $true)
        {
            if($i.benchmarkID -like "*Windows_2012*" -or $i.benchmarkID -like "*Windows_10*" -or $i.benchmarkID -like "*Windows_Server*")
            {
                foreach($r in $xmlRoles)
                {
                    if($i.benchmarkID -like "*$r*" -and $iVer -eq $workingVersions."$r")
                    {
                        $i.enabled = "1"
                        $i.selectedProfile = "xccdf_mil.disa.stig_profile_$ScapProfile"
                    }
                }        
            }
            else 
            {
                $hashRole = $null
                $hashVer  = $null
                $hashRole = $workingVersions.keys.Where({$i.benchmarkID -like "*$_*"})
                $hashVer  = $workingVersions."$hashRole"
                if($iVer -eq $hashVer)
                {
                    $i.enabled = "1"
                    $i.selectedProfile = "xccdf_mil.disa.stig_profile_$ScapProfile"
                }
            }
        }elseif($RunAll -eq $false)
        {
            foreach($r in $xmlRoles)
            {
                if($i.benchmarkID -like "*$r*" -and $iVer -eq $workingVersions."$r" -and $runAll -eq $false)
                {
                    $i.enabled = "1"
                    $i.selectedProfile = "xccdf_mil.disa.stig_profile_$ScapProfile"
                }
            }
        }
    }

    if(-not(Test-Path -Path (Split-Path $outPath)))
    {
        New-Item -ItemType Directory -Path (Split-Path $outPath) -Force
    }

    if(Test-Path -Path "$outPath\$fileName")
    {
        Remove-Item "$outPath\$fileName" -Force
    }

    $configXML.save("$outPath\$fileName") | Out-Null

    return
}
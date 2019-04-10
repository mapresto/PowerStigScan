function Get-PowerStigScapResults
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ScapResultsXccdf
    )

    [xml]$ScapXML = Get-Content -Path $ScapResultsXccdf

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

    Return $VIDHash
}


function Get-PowerStigScapVersion
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('2016','2012R2','Other')]
        [String]$OsVerion,

        [Parameter(Mandatory=$false)]
        [String]$ScapInstallDir
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
        $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

        $scapRole = Convert-PowerStigRoleToScap -Role $role -OsVerion 

        if($ScapInstallDir -eq "" -or $null -eq $ScapInstallDir)
        {
            $ScapInstallDir = $iniVar.ScapInstallDir
        }

        $ScapContent = Get-ChildItem "$ScapInstallDir\Resources\Content\SCAP12_Content"

        [Regex]$VersionMatch = "V[1-9]?[0-9]R[0-9]{2}"

        foreach($c in $ScapContent)
        {
            if($c.name -like "*$scapRole*")
            {
                
                $fileVersion = ($VersionMatch.matches($c.name)).value
                $tempMaj = $fileVersion.Split("R")[0].replace("V","")
                $tempMin = $fileVersion.Split("R")[1]
                [Version]$tempVer = "$tempMaj.$tempMin.0.0"
                
                if($null -eq $testVer)
                {
                    $testVer = $tempVer
                }
                elseif($tempVer -gt $testVer)
                {
                    $testVer = $tempVer
                }
                
                Return $testVer
            }
        }
    }
}

function Get-PowerScapOutputPath
{
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini
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
            "DotNetFramework"           {Return "DotNet_Framework_4"}
            "FireFox"                   {Return $null}
            "IISServer"                 {Return $null}
            "IISSite"                   {Return $null}
            "InternetExplorer"          {Return "IE11"}
            "Excel2013"                 {Return $null}
            "Outlook2013"               {Return $null}
            "PowerPoint2013"            {Return $null}
            "Word2013"                  {Return $null}
            "OracleJRE"                 {Return $null}
            "SqlServer-2012-Database"   {Return $null}
            "SqlServer-2012-Instance"   {Return $null}
            "SqlServer-2016-Instance"   {Return $null}
            "WindowsClient"             {Return "Windows_10"}
            "WindowsDefender"           {Return "Windows_Defender_AV"}
            "WindowsDNSServer"          {Return $null}
            "WindowsFirewall"           {Return "Windows_Firewall"}
            "WindowsServer-DC"          {if($OsVersion -eq "2016"){Return "Windows_Server_2016"}
                                    elseif($OsVersion -eq "2012R2"){Return "Windows_2012_and_2012_R2_DC"} }
            "WindowsServer-MS"          {if($OsVersion -eq "2016"){Return "Windows_Server_2016"}
                                    elseif($OsVersion -eq "2012R2"){Return "Windows_2012_and_2012_R2_MS"} }
        }
    }
}
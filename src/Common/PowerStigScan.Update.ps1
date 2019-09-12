Function Get-ResourceOrgMappings
{
    Return @{
        "AccountPolicy"           = @("PolicyValue")
        "cAdministrativeTemplate" = @("ValueData")
        "Registry"                = @("ValueData")
        "SecurityOption"          = @("OptionValue")
        "Service"                 = @("ServiceName","ServiceState","StartupType")
        "UserRightsAssignment"    = @("Identity")
        "xWebAppPool"             = @("Value")
        "xWebConfigKeyValue"      = @("Value")
    }
}

Function Get-OrgValuesNeeded
{
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [String]$FilePath
    )

    $ruleMaps = @()
    $orgMap = Get-ResourceOrgMappings
    [xml]$inputXML = Get-Content $FilePath

    $ruleNodes = $inputXML.DISASTIG | get-Member | Where-Object {$_.name -like "*rule" -and ($_.name -ne "ManualRule" -and $_.name -ne "DocumentRule")} | Select-Object -ExpandProperty Name

    foreach($node in $ruleNodes)
    {
        foreach($rule in $inputXML.DISASTIG."$($node)".rule)
        {
            if($rule.OrganizationValueRequired -eq "True")
            {
                $tempRuleMap = [PSCustomObject]@{
                    "VID" = $rule.id
                    "ResourceType" = $rule.dscresource    
                }
                $valuesNeeded = @()
                $orgValues = $orgMap."$($TempRuleMap.ResourceType)"

                foreach($o in $orgValues)
                {
                    if($null -eq $rule."$($o)" -or $rule."$($o)" -eq '')
                    {
                        $valuesNeeded += $o
                    }
                }

                $ruleMaps += [PSCustomObject]@{
                    "VID" = $rule.id
                    "Values" = $valuesNeeded
                }
            }
        }
    }

    Return $ruleMaps
}

Function Get-OrgSettingsTestString
{
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [String]$FilePath,

        [Parameter(Mandatory=$true,Position=1)]
        [String]$VulnID
    )

    [xml]$StigXML = Get-Content $FilePath

    $ruleNodes = $StigXML.DISASTIG | get-Member | Where-Object {$_.name -like "*rule" -and ($_.name -ne "ManualRule" -and $_.name -ne "DocumentRule")} | Select-Object -ExpandProperty Name

    foreach($node in $ruleNodes)
    {
        foreach($rule in $StigXML.DISASTIG."$($node)".rule)
        {
            if($rule.id -eq $VulnID)
            {
                Return $rule.OrganizationValueTestString
            }
        }
    }
}

Function Get-OrgSettingsFromFile
{
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [String]$FilePath,

        [Parameter(Mandatory=$true,Position=1)]
        [String]$VulnID,

        [Parameter(Mandatory=$true,Position=2)]
        [ValidateSet('PolicyValue','ValueData','OptionValue','ServiceName','ServiceState','StartupType','Identity','Value')]
        [String]$DataType
    )

    [xml]$OrgXML = Get-Content $FilePath

    foreach($o in $OrgXML.OrganizationalSettings.OrganizationalSetting)
    {
        if($o.id -eq $VulnID)
        {
            Return $o."$($DataType)"
        }
    }
}

Function Set-OrganizationalSettings
{
    param(
        [Parameter(Mandatory=$true)]
        [String]$OsVersion,

        [Parameter(Mandatory=$false)]
        [Switch]$SqlConnected
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
        $workingPath = Split-Path $PsCommandPath
        $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

        $sqlInstanceName = $iniVar.SqlInstanceName
        $databaseName = $iniVar.DatabaseName
        
        #find the org settings and stig settings xml files with the newest version for role
        $orgFileRoleName = Get-PowerStigXMLRoleNames -Role $Role -osVersion $OsVersion
        [version]$xmlVersion = Get-PowerStigXmlVersion -OsVersion $OsVersion -Role $Role
        $stigTypeMap = Get-OrgValuesNeeded -FilePath (Get-ChildItem (Get-PowerStigXMLPath) | Where-Object {$_.name -like "*$orgFileRoleName*" -and `
                                                                                                 $_.name -like "*$($xmlVersion.ToString())*" -and `
                                                                                                 $_.name -notlike "*.org.default.xml"}).FullName 
        
        #Generate OrgFileName
        if($Role -like "*WindowsServer*")
        {
            $orgFileName = "$($OsVersion)_$($Role)_org.xml"
        }
        else {
            $orgFileName = "$($Role)_org.xml"
        }

        $notFound = $false
        if($SqlConnected -eq $true)
        {
            #TODO - Retrieve current settings from SQL for older version - Continue if no results
            $generateOrgXML = "PowerSTIG.sproc_GenerateORGxml @OSName = `"$OsVersion`", @ComplianceType = `"$Role`""
            [xml]$importedSettings = (Invoke-PowerStigSqlCommand -SqlInstance $SqlInstanceName -DatabaseName $DatabaseName -Query $GenerateOrgXML).OrgXML
            if($null -eq $importedSettings.OrganizationalSettings)
            {
                $notFound = $true
            }
        }

        if($null -eq $importedSettings -or $SqlConnected -eq $false)
        {
            # Check PSOrgSettings in LogPath for older versions of orgSettings, This should be overwritten at the end of the function
            if(Test-Path -Path "$($iniVar.LogPath)\PSOrgSettings\$($orgFileName)")
            {
                [xml]$importedSettings = Get-Content "$($iniVar.LogPath)\PSOrgSettings\$($orgFileName)"
            }
            else
            {
                $notFound = $true
            }
        }

        if($notFound -eq $false -and [Version]($importedSettings.OrganizationalSettings.fullversion) -eq $xmlVersion)
        {
            # Old org settings were found and the version has not changed.
            Return 5
        }
        elseif($notFound -eq $true)
        {
            #OrgSettings were not found, create new, import/generate xml
            #Determine location of Org Files
            [xml]$defaultOrg = Get-Content (Get-ChildItem (Get-PowerStigXMLPath) | Where-Object {$_.name -like "*$orgFileRoleName*" -and `
                                                                                                 $_.name -like "*$($xmlVersion.ToString())*" -and `
                                                                                                 $_.name -like "*.org.default.xml"}).FullName 
            
            # Retrieve Settings without values
            $vidGroup = @()
            foreach($i in $defaultOrg.OrganizationalSettings.OrganizationalSetting)
            {
                $vidType = $stigTypeMap | Where-Object {$_.VID -eq $i.id} | Select-Object -ExpandProperty Values
                foreach($v in $vidType)
                {
                    if($i."$v" -eq '' -or $null -eq $i."$v")
                    {
                        $testString = Get-OrgSettingsTestString -VulnID $i.id -FilePath (Get-ChildItem (Get-PowerStigXMLPath) | Where-Object {$_.name -like "*$orgFileRoleName*" -and `
                                                                                                        $_.name -like "*$($xmlVersion.ToString())*" -and `
                                                                                                        $_.name -notlike "*.org.default.xml"}).FullName 

                        $vidGroup += [PSCustomObject]@{
                            'VID' = $i.id
                            'Type' = $v
                            'TestString' = $testString
                        }
                    }
                }
            }

        }
        elseif([Version]($importedSettings.OrganizationalSettings.FullVersion) -ne $xmlVersion)
        {
            #Import old, compare values, compare teststring, create new, import/generate xml
        }

        Return 0
    }
}

Function Get-PowerStigXMLVersionList
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
        [System.Array]$StigXmlBase = (get-childitem -path (Get-PowerStigXMLPath) | Where-Object {$_.name -notlike "*.org.default.*"}).name
        # Regex pattern that tests for up to a two digit number followed by a decimal followed by up to a two digit number (i.e. 12.12,2.8,9.1)
        [regex]$RegexTest = "([1-9])?[0-9]\.[0-9]([0-9])?"
        [System.Array]$StigXmlOs = @()
    
        # Convert the role name from roles.csv to the name of the xml file that PowerStig uses.
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
        
        $outObj = @()

        foreach($g in $StigXmlOs)
        {
            if($g -like "*$rRole*")
            {
                if($g -match $RegexTest)
                {
                    # Version objects allow for more accurate comparisons between two versions such as 2.12 is higher than 2.2
                    # Casting to an array prior to grabbing the version. IIS has a the IIS version in the file name that breaks a more direct attempt.
                    $wObj = @($RegexTest.Matches($g).value)
                    [version]$wStigVer = $wObj[-1]
                }

                $outObj += [PSCustomObject]@{
                        'Version' = [version]$wStigVer
                }
    
            }
        }
        #convert the version object to the two part version/release number used by the STIG xml
        
        Return $outObj 

    }
}

Function Get-PowerStigXMLRoleNames
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
        Switch($Role)
        {
            "DotNetFramework"           {Return "DotNetFramework-4"}
            "FireFox"                   {Return "FireFox"}
            "IISServer"                 {Return "IISServer-8.5"}
            "IISSite"                   {Return "IISSite-8.5"}
            "InternetExplorer"          {Return "InternetExplorer-11"}
            "Excel2013"                 {Return "Office-Excel2013"}
            "Outlook2013"               {Return "Office-Outlook2013"}
            "PowerPoint2013"            {Return "Office-PowerPoint2013"}
            "Word2013"                  {Return "Office-Word2013"}
            "Excel2016"                 {Return "Office-Excel2016"}
            "Outlook2016"               {Return "Office-Outlook2016"}
            "PowerPoint2016"            {Return "Office-PowerPoint2016"}
            "Word2016"                  {Return "Office-Word2016"}
            "OracleJRE"                 {Return "OracleJRE-8"}
            "SqlServer-2012-Database"   {Return "SqlServer-2012-Database"}
            "SqlServer-2012-Instance"   {Return "SqlServer-2012-Instance"}
            "SqlServer-2016-Instance"   {Return "SqlServer-2016-Instance"}
            "WindowsClient"             {Return "WindowsClient-10"}
            "WindowsDefender"           {Return "WindowsDefender-All"}
            "WindowsDNSServer"          {Return "WindowsDNSServer-2012R2"}
            "WindowsFirewall"           {Return "WindowsFirewall-All"}
            "WindowsServer-DC"          {if($osVersion -eq "2012R2"){Return "WindowsServer-2012R2-DC"}else{Return "WindowsServer-2016-DC"}}
            "WindowsServer-MS"          {if($osVersion -eq "2012R2"){Return "WindowsServer-2012R2-MS"}else{Return "WindowsServer-2016-MS"}}
        }
    

    }
}
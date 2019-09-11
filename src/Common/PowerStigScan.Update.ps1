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

    $ruleNodes = $inputXML.DISASTIG | get-Member | Where-Object {$_.name -like "*rule" -and ($_.name -ne "ManualRule" -and $_.name -ne "DocumentRule")} | select -ExpandProperty Name

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
                    if($rule."$($o)" -eq $null -or $rule."$($o)" -eq '')
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

    $ruleNodes = $inputXML.DISASTIG | get-Member | Where-Object {$_.name -like "*rule" -and ($_.name -ne "ManualRule" -and $_.name -ne "DocumentRule")} | select -ExpandProperty Name

    foreach($node in $ruleNodes)
    {
        foreach($rule in $inputXML.DISASTIG."$($node)".rule)
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
        #find the org settings and stig settings xml files with the newest version for role
        $xmlPath    = Get-PowerStigXMLPath
        $xmlVersion = Get-PowerStigXmlVersion -OsVersion $OsVersion -Role $Role
    }
}
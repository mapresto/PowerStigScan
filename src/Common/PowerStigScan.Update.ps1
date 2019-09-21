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
        [Parameter(Mandatory=$true,ParameterSetName="Check")]
        [Parameter(Mandatory=$true,ParameterSetName="Import")]
        [String]$OsVersion,

        [Parameter(Mandatory=$false,ParameterSetName="Check")]
        [Switch]$SqlConnected,

        [Parameter(Mandatory=$true,ParameterSetName="Import")]
        [String]$CSVFilePath
    )

    DynamicParam {
        $ParameterName = 'Role'
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.ParameterSetName = "__AllParameterSets"
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

        if($SqlConnected -eq $false)
        {
            $savePath = Join-Path "$($iniVar.LogPath)" -ChildPath "\PSOrgSettings\"
        }
        else
        {
            $savePath = Join-Path "$($iniVar.LogPath)" -ChildPath "\PSOrgImport\"
        }

        if((Test-Path $savePath) -eq $false)
        {
            New-Item $savePath -ItemType Directory -Force | Out-Null
        }
        


        if($PSCmdlet.ParameterSetName -eq 'Import')
        {
            $tempObj = Import-Csv $CSVFilePath

            foreach($o in $tempObj)
            {
                if($o.TestString -like "*{0}*")
                {
                    $test = $o.TestString -f $o.value
                    if(-not (Invoke-Expression $test))
                    {
                        Write-Host "Invalid entry!"
                        Write-Host "Please ensure that the value for $($o.VulnID) meets the following"
                        Write-Host "$($o.TestString)"
                        Return
                    }
                }
                elseif($o.Type -eq "StartupType")
                {
                    $testString = '"{0}" -eq "Automatic" -or "{0}" -eq "Boot" -or "{0}" -eq "Disabled" -or "{0}" -eq "Manual" -or "{0}" -eq "System"'
                    $test = $testString -f $o.Value
                    if(-not (Invoke-Expression $test))
                    {
                        Write-Host "Invalid entry!"
                        Write-Host "Please ensure that the value for $($o.VulnID) meets the following"
                        Write-Host "$($o.TestString)"
                        Return
                    }
                }

            }

            if(Test-Path -Path "$($iniVar.LogPath)\PSOrgSettings\$($orgFileName)")
            {
                [xml]$workingOrgXML = Get-Content "$($iniVar.LogPath)\PSOrgSettings\$($orgFileName)" -Encoding UTF8
                $workingOrgXML.PreserveWhitespace = $true
                if($null -ne $workingOrgXML.OrganizationalSettings.OrganizationalSetting[0].value)
                {
                    $workingOrgValue = "value"
                }

                if([Version]$workingOrgXML.OrganizationalSettings.fullversion -ne $xmlVersion)
                {
                    [xml]$defaultOrg = Get-Content -Encoding UTF8 -Path (Get-ChildItem (Get-PowerStigXMLPath) | Where-Object {$_.name -like "*$orgFileRoleName*" -and `
                                                                                            $_.name -like "*$($xmlVersion.ToString())*" -and `
                                                                                            $_.name -like "*.org.default.xml"}).FullName
                    foreach($d in $defaultOrg.OrganizationalSettings.OrganizationalSetting)
                    {
                        
                        $workingDefaultType = @($stigTypeMap | where {$_.VID -eq $d.id} | Select-Object -ExpandProperty Values)
                        foreach($t in $workingDefaultType)
                        {
                            $testString = Get-OrgSettingsTestString -VulnID $d.ID -FilePath (Get-ChildItem (Get-PowerStigXMLPath) | Where-Object {$_.name -like "*$orgFileRoleName*" -and `
                                                            $_.name -like "*$($xmlVersion.ToString())*" -and `
                                                            $_.name -notlike "*.org.default.xml"}).FullName
                            if($null -ne ($tempObj | Where-Object {$_.VulnID -eq $d.id}))
                            {
                                $wValue = $tempObj | Where-Object {$_.VulnID -eq $d.id -and $_.Type -eq $t} | Select-Object -ExpandProperty Value
                            }
                            elseif($workingOrgXML.OrganizationalSettings.OrganizationalSetting | Where-Object {$_.id -eq $d.id})
                            {
                                $workingSection = $workingOrgXML.OrganizationalSettings.OrganizationalSetting | Where-Object {$_.id -eq $d.id}
                                if($workingOrgValue -eq 'value')
                                {
                                    $wValue = $workingSection | Select-Object -ExpandProperty value
                                }
                                else
                                {
                                    $wValue = $workingSection."$t"
                                }
                            }
                            else
                            {
                                $wValue = $d."$t"
                            }

                            $d."$t" = "$wValue"

                        }
  
                    }
                    $defaultOrg.Save($(Join-Path $savePath -ChildPath $orgFileName))
                    Return

                }
            }
            else
            {
                [xml]$workingOrgXML = Get-Content -Encoding UTF8 -Path (Get-ChildItem (Get-PowerStigXMLPath) | Where-Object {$_.name -like "*$orgFileRoleName*" -and `
                                                                                            $_.name -like "*$($xmlVersion.ToString())*" -and `
                                                                                            $_.name -like "*.org.default.xml"}).FullName
                $workingOrgXML.PreserveWhitespace = $true
            }

            foreach($i in $workingOrgXML.OrganizationalSettings.OrganizationalSetting)
            {
                if($null -ne ($tempObj | Where-Object {$_.vulnID -eq $i.id}))
                {
                    $wObj = $tempObj | Where-Object {$_.vulnID -eq $i.id}
                    foreach($t in $wObj.Type)
                    {
                        $i."$t" = "$(($wObj | Where-Object {$_.Type -eq $t}).value)"
                    }
                }
            }

            $toContinue = $false
            foreach($w in $workingOrgXML.OrganizationalSettings.OrganizationalSetting)
            {
                $workingType = $stigTypeMap | Where-Object {$_.VID -eq $w.id} 
                if(($null -eq $w."$workingType" -or $w."$workingType" -eq '') -and $toContinue -eq $false)
                {
                    #####TODO>>>>>#####
                    $sShell = New-Object -ComObject Wscript.Shell
                    $response = $sShell.Popup("There are Org Settings without value. Would you like to enter values now? ('No' will return to the prompt so that you can run the export again.)",0,"Important",1)
                }

            }

            $workingOrgXml.Save($(Join-Path $savePath -ChildPath $orgFileName))
            if($SqlConnected)
            {
                #TODO Trigger SQL Import
            }
            Return 10
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

        if($null -eq $importedSettings.OrganizationalSettings -or $SqlConnected -eq $false)
        {
            # Check PSOrgSettings in LogPath for older versions of orgSettings, This should be overwritten at the end of the function
            if(Test-Path -Path "$($iniVar.LogPath)\PSOrgSettings\$($orgFileName)")
            {
                [xml]$importedSettings = Get-Content "$($iniVar.LogPath)\PSOrgSettings\$($orgFileName)" -Encoding UTF8
                $importedSettings.PreserveWhitespace = $true
            }
            else
            {
                [xml]$importedSettings = Get-Content -Encoding UTF8 -Path (Get-ChildItem (Get-PowerStigXMLPath) | Where-Object {$_.name -like "*$orgFileRoleName*" -and `
                                                                                            $_.name -like "*$($xmlVersion.ToString())*" -and `
                                                                                            $_.name -like "*.org.default.xml"}).FullName
                $importedSettings.PreserveWhitespace = $true
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
            [xml]$defaultOrg = Get-Content -Encoding UTF8 -Path (Get-ChildItem (Get-PowerStigXMLPath) | Where-Object {$_.name -like "*$orgFileRoleName*" -and `
                                                                                                                $_.name -like "*$($xmlVersion.ToString())*" -and `
                                                                                                                $_.name -like "*.org.default.xml"}).FullName 
            $defaultOrg.PreserveWhitespace = $true 

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

            if($vidGroup.Count -gt 0)
            {
                #Prompt user
                $shell = New-Object -ComObject WScript.Shell
                $sInput = $shell.Popup("There are Org Settings without value. Do you want to export to a file? ('No' will proceed to prompt for information)",0,"Important",3)
                # Yes=6 No=7 Cancel=2
                if($sInput -eq 6)
                {
                    #TODO Out to CSV
                    $outPath = "$($iniVar.LogPath)\OrgFileUpdate"
                    $outFilename = "$($orgFileRoleName)_$($xmlVersion).csv"
                    if((Test-Path $outPath) -eq $false)
                    {
                        New-Item $outPath -ItemType Directory -Force | Out-Null
                    }
                    $tempObj =@()
                    foreach($a in $vidGroup)
                    {
                        $tempObj += [PSCustomObject]@{
                                'VulnID' = $a.VID
                                'Value'  = $null
                                'Type'   = $a.Type
                                'TestString' = $a.testString
                        }
                    }
                    $tempObj | Export-Csv -Path (Join-Path -Path $outPath -ChildPath $outFilename) -NoTypeInformation
                    Return
                }
                elseif($sInput -eq 7)
                {
                    $tempObj = @()
                    #TODO Prompt for input
                    Write-Host "Set configuration on $Role on $OsVersion"
                    foreach($a in $vidGroup)
                    {
                        Write-Host "`n`nVulnerability ID is: $($a.VID)"
                        Write-Host "Verification String is: $($a.testString)"
                        Write-Host "ValueType is: $($a.Type)`n"
                        $userInput = Read-Host "Please enter Value for $($a.VID)"
                        if($a.TestString -like "*{0}*")
                        {
                            $test = $a.TestString -f $userInput
                            while(-not(Invoke-Expression $test))
                            {
                                Write-Host "Invalid entry!"
                                Write-Host "Please ensure that the value meets the following"
                                Write-Host "$($a.TestString)"
                                $userInput = Read-Host "Please enter Value for $($a.VID)"
                                $test = $a.TestString -f $userInput
                            }
                        }
                        if($a.Type -eq "StartupType")
                        {
                            $testString = '"{0}" -eq "Automatic" -or "{0}" -eq "Boot" -or "{0}" -eq "Disabled" -or "{0}" -eq "Manual" -or "{0}" -eq "System"'
                            $test = $testString -f $userInput
                            while(-not(Invoke-Expression $test))
                            {
                                Write-Host "Invalid entry!"
                                Write-Host "Please ensure that the value meets the following"
                                Write-Host "$($testString)"
                                $userInput = Read-Host "Please enter Value for $($a.VID)"
                                $test = $testString -f $userInput
                            }
                        }

                        $tempObj += [PSCustomObject]@{
                            'VulnID' = $a.VID
                            'Value'  = $userInput
                            'Type'   = $a.Type
                            'TestString' = $a.testString
                        }
                    }
                }
                elseif($sInput -eq 2)
                {
                    # User Terminated
                    Write-Host "User Terminated Function. Exiting..."
                    Return
                }
            }

        }
        elseif([Version]($importedSettings.OrganizationalSettings.FullVersion) -ne $xmlVersion -and $null -ne ($importedSettings.OrganizationalSettings))
        {
            #Import old, compare values, compare teststring, create new, import/generate xml
            #old settings are in $importedSettings, check testvalue on old and new, if match, move old to new, if not check old value to new test, if good move to new, else prompt.
            #new settings are in $defaultOrg
            [xml]$defaultOrg = Get-Content -Encoding UTF8 -Path (Get-ChildItem (Get-PowerStigXMLPath) | Where-Object {$_.name -like "*$orgFileRoleName*" -and `
                                                                                                    $_.name -like "*$($xmlVersion.ToString())*" -and `
                                                                                                    $_.name -like "*.org.default.xml"}).FullName 
            $defaultOrg.PreserveWhitespace = $true 
            
            $oldObj      = @()
            $newObj      = @()
            $combinedObj = @()
            $toBeFilled  = @()
            foreach($i in $defaultOrg.OrganizationalSettings.OrganizationalSetting)
            {
                $workingType = $stigTypeMap | Where-Object {$_.VID -eq $i.id} | Select-Object -ExpandProperty Values
                if(($null -eq $i."$workingType" -or $i."$workingType" -eq '') -and $workingType -isnot [system.array] -and ($null -eq ($stigTypeMap | Where-Object {$_.VID -eq $i.id})))
                {
                    $workingValue = $i.value
                    $workingType = 'value'
                    $newObj += [PSCustomObject]@{
                        "VulnID" = $i.id
                        "Type"   = $workingType
                        "Value"  = $workingValue
                        }
                }
                elseif($workingType -isnot [system.array])
                {
                    $workingValue = $i."$workingType"
                    $newObj += [PSCustomObject]@{
                        "VulnID" = $i.id
                        "Type"   = $workingType
                        "Value"  = $workingValue
                        }
                }
                else{
                    foreach($w in $workingType)
                    {
                        $workingValue = $i."$w"
                        $newObj += [PSCustomObject]@{
                            "VulnID" = $i.id
                            "Type"   = $w
                            "Value"  = $workingValue
                            }
                    }
                }

            }
            foreach($i in $importedSettings.OrganizationalSettings.OrganizationalSetting)
            {
                $workingType = $stigTypeMap | Where-Object {$_.VID -eq $i.id} | Select-Object -ExpandProperty Values
                if($null -eq $i."$workingType" -or $i."$workingType" -eq '')
                {
                    $workingValue = $i.value
                    $workingType = 'value'
                }
                else
                {
                    $workingValue = $i."$workingType"
                }
                $oldObj += [PSCustomObject]@{
                        "VulnID" = $i.id
                        "Type"   = $workingType
                        "Value"  = $workingValue
                }
            }
            # Combined the values, testing the old value vs the TestString in the new STIG and attempting to transfer. If pass, take value. If fail, determine how to notify user.
            foreach($n in $newObj)
            {
                $testString = Get-OrgSettingsTestString -VulnID $n.VulnID -FilePath (Get-ChildItem (Get-PowerStigXMLPath) | Where-Object {$_.name -like "*$orgFileRoleName*" -and `
                                                                                                        $_.name -like "*$($xmlVersion.ToString())*" -and `
                                                                                                        $_.name -notlike "*.org.default.xml"}).FullName

                if($null -eq ($oldObj | Where-Object {$_.VulnID -eq $n.VulnID}).value -or ($oldObj | Where-Object {$_.VulnID -eq $n.VulnID}).value -eq '')
                {
                    $value = ($newObj | Where-Object {$_.VulnID -eq $n.VulnID -and $_.Type -eq $n.Type}).value
                }
                else
                {
                    $value = ($oldObj | Where-Object {$_.VulnID -eq $n.VulnID -and ($_.Type -eq $n.Type -or $_.Type -eq 'value')}).value
                }
                if($testString -like "*{0}*")
                {
                    $test = $testString -f $value

                    if(Invoke-Expression $test)
                    {
                        Write-Host Passed Test
                        $combinedObj += [PSCustomObject]@{
                                "VulnID" = $n.VulnId
                                "Type"   = ($newObj | Where-Object {$_.VulnID -eq $n.VulnID -and $_.Type -eq $n.Type}).type
                                "Value"  = $value
                        }
                    }
                    else
                    {
                        Write-host "$($n.VulnID) Failed Test"
                        $combinedObj += [PSCustomObject]@{
                                "VulnID" = $n.VulnId
                                "Type"   = ($newObj | Where-Object {$_.VulnID -eq $n.VulnID -and $_.Type -eq $n.Type}).type
                                "Value"  = $null
                        }
                    }
                }
                else
                {

                        $combinedObj += [PSCustomObject]@{
                                "VulnID" = $n.VulnId
                                "Type"   = ($newObj | Where-Object {$_.VulnID -eq $n.VulnID -and $_.Type -eq $n.Type}).type
                                "Value"  = $value
                        }

                }

                if(($combinedObj | Where-Object {$_.VulnID -eq $n.VulnID -and $_.Type -eq $n.Type}).value -eq '' -or $null -eq ($combinedObj | Where-Object {$_.VulnID -eq $n.VulnID -and $_.Type -eq $n.Type}).value)
                {
                    $toBeFilled += [PSCustomObject]@{
                            "VulnID"      = $n.VulnID
                            "Value"       = $null
                            "Type"        = $n.Type
                            "TestString"  = $testString
                    }
                }
            }
            if($toBeFilled.Count -gt 0)
            {
                #Prompt user
                $shell = New-Object -ComObject WScript.Shell
                $sInput = $shell.Popup("There are Org Settings without value. Do you want to export to a file? ('No' will proceed to prompt for information)",0,"Important",3)
                # Yes=6 No=7 Cancel=2
                if($sInput -eq 6)
                {
                    #TODO Out to CSV
                    $outPath = "$($iniVar.LogPath)\OrgFileUpdate"
                    $outFilename = "$($orgFileRoleName)_$($xmlVersion).csv"
                    if((Test-Path $outPath) -eq $false)
                    {
                        New-Item $outPath -ItemType Directory -Force | Out-Null
                    }
                    $toBeFilled | Export-Csv -Path (Join-Path -Path $outPath -ChildPath $outFilename) -NoTypeInformation
                    Write-Host "CSV has been saved to $(Join-Path -Path $outPath -ChildPath $outFileName)"
                    Write-Host "Fill empty values and use this command with the -CSVFilePath parameter to finish the upgrade"
                    Return
                }
                elseif($sInput -eq 7)
                {
                    $tempObj = @()
                    #TODO Prompt for input
                    Write-Host "Set configuration on $Role on $OsVersion"
                    foreach($a in $toBeFilled)
                    {
                        Write-Host "`n`nVulnerability ID is: $($a.VID)"
                        Write-Host "Verification String is: $($a.testString)"
                        Write-Host "ValueType is: $($a.Type)`n"
                        $userInput = Read-Host "Please enter Value for $($a.VID)"
                        if($a.TestString -like "*{0}*")
                        {
                            $test = $a.TestString -f $userInput
                            while(-not(Invoke-Expression $test))
                            {
                                Write-Host "Invalid entry!"
                                Write-Host "Please ensure that the value meets the following"
                                Write-Host "$($a.TestString)"
                                $userInput = Read-Host "Please enter Value for $($a.VID)"
                                $test = $a.TestString -f $userInput
                            }
                        }
                        if($a.Type -eq "StartupType")
                        {
                            $testString = '"{0}" -eq "Automatic" -or "{0}" -eq "Boot" -or "{0}" -eq "Disabled" -or "{0}" -eq "Manual" -or "{0}" -eq "System"'
                            $test = $testString -f $userInput
                            while(-not(Invoke-Expression $test))
                            {
                                Write-Host "Invalid entry!"
                                Write-Host "Please ensure that the value meets the following"
                                Write-Host "$($testString)"
                                $userInput = Read-Host "Please enter Value for $($a.VID)"
                                $test = $testString -f $userInput
                            }
                        }

                        $tempObj += [PSCustomObject]@{
                            'VulnID' = $a.VulnID
                            'Value'  = $userInput
                            'Type'   = $a.Type
                            'TestString' = $a.testString
                        }
                    }
                }
                elseif($sInput -eq 2)
                {
                    # User Terminated
                    Write-Host "User Terminated Function. Exiting..."
                    Return
                }

                foreach($t in ($combinedObj |Where-Object {$null -eq $_.Value -or $_.Value -eq ''}))
                {
                    $t.Value = ($tempObj | Where-Object {$_.Type -eq $t.Type -and $_.VulnID -eq $t.VulnID}).value
                }

                foreach($i in $defaultOrg.OrganizationalSettings.OrganizationalSetting)
                {
                        $wObj = $combinedObj | Where-Object {$_.vulnID -eq $i.id}
                        foreach($t in $wObj.Type)
                        {
                            $i."$t" = "$(($wObj | Where-Object {$_.Type -eq $t}).value)"
                        }
                }
                $defaultOrg.Save($(Join-Path $savePath -ChildPath $orgFileName)) 
            }
            
        }
        
        if($notFound -eq $true -and $tempObj.count -gt 0)
        {
            [xml]$workingOrgXML = Get-Content -Encoding UTF8 -Path (Get-ChildItem (Get-PowerStigXMLPath) | Where-Object {$_.name -like "*$orgFileRoleName*" -and `
                                                                                                                        $_.name -like "*$($xmlVersion.ToString())*" -and `
                                                                                                                        $_.name -like "*.org.default.xml"}).FullName
            $workingOrgXML.PreserveWhitespace = $true
            foreach($i in $workingOrgXML.OrganizationalSettings.OrganizationalSetting)
            {
                if($null -ne ($tempObj | Where-Object {$_.vulnID -eq $i.id}))
                {
                    $wObj = $tempObj | Where-Object {$_.vulnID -eq $i.id}
                    foreach($t in $wObj.Type)
                    {
                        $i."$t" = "$(($wObj | Where-Object {$_.Type -eq $t}).value)"
                    }
                }
            }

            
            
            $workingOrgXml.Save($(Join-Path $savePath -ChildPath $orgFileName))           
        }

        Return $tempObj
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
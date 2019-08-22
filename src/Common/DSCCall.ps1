# Consolidated resource for MOF generation
# IISObject must include WebsiteName + WebAppPool - Get-Website -> foreach($i in $sites) {(inv-cmd -comp $serv -scr {get-website $i}).applicationpool}
# SQLObject must include SqlVersion, SqlRole, ServerInstance, Database

param(

    [Parameter(Mandatory=$true,Position=0)]
    [String]
    $ComputerName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("2012R2","2016",'10')]
    [String]
    $OsVersion,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [String]
    $OrgSettingsFilePath,

    [Parameter(Mandatory=$false)]
    [String[]]
    $SkipRules,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [String]
    $LogPath

)

DynamicParam {
    $ParameterName = 'Role'
    $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
    $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
    $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
    $ParameterAttribute.Mandatory = $true
    $AttributeCollection.Add($ParameterAttribute)
    $roleSet = @(Import-CSV "$(Split-Path $PsCommandPath)\Roles.csv" -Header Role | Select-Object -ExpandProperty Role)
    $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($roleSet)
    $AttributeCollection.Add($ValidateSetAttribute)
    $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string[]], $AttributeCollection)
    $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
    return $RuntimeParameterDictionary
}


Begin
{
    #Bound the dynamic parameter to a new Variable
    $Role = $PSBoundParameters[$ParameterName]
    
    Function Write-PowerStigPSLog
    {
        param(
            [Parameter(Position=0)]
            [String]$Path,
            [String]$Value
        )

        $mutex = [System.Threading.Mutex]::new($false,'MainLogWrite')

        $mutex.WaitOne() | Out-Null

        try{
            Add-Content -path $Path -Value $Value -ErrorAction Stop
        }
        catch{
            
        }
        finally{
            $mutex.ReleaseMutex()
            $mutex.Dispose()
        }
    }
}

process
{

    if($null -ne $LogPath -and $LogPath -ne "")
    {
        Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Starting mof generation for $ComputerName"
    }

    Configuration PowerSTIG
    {
        Import-DscResource -ModuleName PowerStig -ModuleVersion '3.2.0'

        Node $ComputerName
        {
            # Org Settings will always be passed. Log file will be used.
            # Question will be if skip rule will be
            # if Skip rule is not empty/null do 1 else do 2
            Switch($Role){
                "WindowsServer-DC" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding DomainController Configuration"
                    WindowsServer DomainController
                    {
                        OsVersion       = $OsVersion
                        OsRole          = 'DC'
                        StigVersion     = (Get-PowerStigXMLVersion -Role "WindowsServer-DC" -OSVersion $osVersion)
                        OrgSettings     = $OrgSettingsFilePath
                    }
                    
                }
                "WindowsDNSServer" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding DNS Configuration"
                    WindowsDnsServer DNS
                    {
                        OsVersion       = $OsVersion
                        StigVersion     = (Get-PowerStigXMLVersion -Role "WindowsDNSServer" -OSVersion $osVersion)
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "WindowsServer-MS" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding MemberServer Configuration"
                    WindowsServer MemberServer
                    {
                        OsVersion       = $OsVersion
                        OsRole          = 'MS'
                        StigVersion     = (Get-PowerStigXMLVersion -Role "WindowsServer-MS" -OSVersion $osVersion)
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "InternetExplorer" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding InternetExplorer Configuration"
                    InternetExplorer IE
                    {
                        BrowserVersion  = '11'
                        StigVersion     = (Get-PowerStigXMLVersion -Role "InternetExplorer")
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "WindowsFirewall" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding FireWall Configuration"
                    WindowsFirewall Firewall
                    {
                        StigVersion     = (Get-PowerStigXMLVersion -Role "WindowsFirewall")
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "WindowsClient" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Windows10 Configuration"
                    WindowsClient Client
                    {
                        OsVersion       = '10'
                        StigVersion     = (Get-PowerStigXMLVersion -Role "WindowsClient" -OSVersion "10")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "OracleJRE" {

                    [Regex]$PropRegex = "file:\/\/\/[a-zA-Z]:[\/|\\]"

                    #######################
                    # Determin Install Path
                    #######################
                    if($ComputerName -eq $env:COMPUTERNAME)
                    {
                        if(Test-Path "HKLM:\\SOFTWARE\JavaSoft\Java RunTime Environment\1.8")
                        {
                            $installPath = (Get-ItemProperty "HKLM:\\SOFTWARE\JavaSoft\Java RunTime Environment\1.8").javahome
                        }
                        elseif(Test-Path "HKLM:\\SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment\1.8")
                        {
                            $installPath = (Get-ItemProperty "HKLM:\\SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment\1.8").javahome
                        }
                        else
                        {
                            Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][ERROR]: Unable to determine Java install path."
                            Return
                        }
                    }
                    else
                    {
                        if(Invoke-Command -ComputerName $ComputerName -ScriptBlock {Test-Path "HKLM:\\SOFTWARE\JavaSoft\Java RunTime Environment\1.8"})
                        {
                            $installPath = (Invoke-Command -ComputerName $ComputerName -ScriptBlock {(Get-ItemProperty "HKLM:\\SOFTWARE\JavaSoft\Java RunTime Environment\1.8").javahome})
                        }
                        elseif(Invoke-Command -ComputerName $ComputerName -ScriptBlock {Test-Path "HKLM:\\SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment\1.8"})
                        {
                            $installPath = (Invoke-Command -ComputerName $ComputerName -ScriptBlock {(Get-ItemProperty "HKLM:\\SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment\1.8").javahome})
                        }
                        else
                        {
                            Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][ERROR]: Unable to determine Java install path."
                            Return
                        }

                    }

                    #########################################################################################
                    # Determine location of Deployment.config, create it it doesnt exist, and get the content
                    #########################################################################################
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Testing Path to OracleJRE deployment.config file."
                    if($ComputerName -eq $env:COMPUTERNAME)
                    {
                        if(Test-Path "$installPath\lib\deployment.config")
                        {
                            $confPath = "$installPath\lib\deployment.config"
                            Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: deployment.config file exists. Checking for content."
                        }
                        elseif(Test-Path "$env:WINDIR\Sun\Java\Deployment\deployment.config")
                        {
                            $confPath = "$env:WINDIR\Sun\Java\Deployment\deployment.config"
                            Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: deployment.config file exists. Checking for content."
                        }
                        else
                        {
                            Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Warning]: deployment.config file does not exist. Creating file in $installPath"
                            $confPath = "$installPath\lib\deployment.config"
                            New-Item $confPath -ItemType File
                        }
                        $depConfCont = Get-Content $confPath
                    }
                    else
                    {
                        if(Invoke-Command -ComputerName $ComputerName -ScriptBlock {param($installPath)Test-Path "$installPath\lib\deployment.config"} -ArgumentList $installPath)
                        {
                            $confPath = "$installPath\lib\deployment.config"
                            Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: deployment.config file exists. Checking for content."
                        }
                        elseif(Invoke-Command -ComputerName $ComputerName -ScriptBlock {Test-Path "$env:WINDIR\Sun\Java\Deployment\deployment.config"})
                        {
                            $confPath = "$env:WINDIR\Sun\Java\Deployment\deployment.config"
                            Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: deployment.config file exists. Checking for content."
                        }
                        else
                        {
                            Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Warning]: deployment.config file does not exist. Creating file in $installPath"
                            $confPath = "$installPath\lib\deployment.config"
                            Invoke-Command -ComputerName $ComputerName -ScriptBlock {param($confPath)New-Item $confPath -ItemType File} -ArgumentList $confPath
                        }
                        $depConfCont = Invoke-Command -ComputerName $ComputerName -ScriptBlock {param($confPath)Get-Content $confPath} -ArgumentList $confPath
                    }

                    ###########################################################################################
                    # If the config file is empty, add a filler value or else the configuration/test will fail.
                    ###########################################################################################
                    if($depConfCont.count -eq 0)
                    {
                        Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Warning]: deployment.config file is empty."
                        [xml]$OracleJREXML   = Get-Content "$((get-module powerstig -ListAvailable | Sort-Object version -Descending | Select-Object -First 1).ModuleBase)\StigData\Processed\OracleJRE-8-1.5.xml"
                        # Properties path will be pulled from the STIG, file and path will be created for it.
                        $PropertiesPath = ($OracleJREXML.DISASTIG.FileContentRule.Rule | Where-Object {$_.value -like "*deployment.properties"} | Select-Object -expandproperty Value).replace("file:///","")
                        Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: PropertiesPath is set to $PropertiesPath"
                        if($ComputerName -eq $env:COMPUTERNAME)
                        {
                            Add-Content $ConfPath -Value "1"
                            
                        }
                        else
                        {
                            Invoke-Command -ComputerName $ComputerName -ScriptBlock {param($confPath)Add-Content -Path $confPath -Value "1"} -ArgumentList $confPath
                        }
                    }
                    else
                    {
                        Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: deployment.config file has content. Trying to determine properties path"
                        if(($depConfCont | Where-Object {$_ -like "deployment.system.config*" -and $_ -notlike "deployment.system.config.mandatory*"}).count -ne 0)
                        {
                            if((($depConfCont | Where-Object {$_ -like "deployment.system.config*" -and $_ -notlike "deployment.system.config.mandatory*"}) -split "=")[1] -match $PropRegex)
                            {
                                $PropertiesPath = (($depConfCont | Where-Object {$_ -like "deployment.system.config*" -and $_ -notlike "deployment.system.config.mandatory*"}) -split "=")[1].replace("file:///","")
                            }
                            else
                            {
                                Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Warning]: Property path in deployment.config has an incorrect syntax. Please check."
                                [xml]$OracleJREXML   = Get-Content "$((get-module powerstig -ListAvailable | Sort-Object version -Descending | Select-Object -First 1).ModuleBase)\StigData\Processed\OracleJRE-8-1.5.xml"
                                $PropertiesPath = ($OracleJREXML.DISASTIG.FileContentRule.Rule | Where-Object {$_.value -like "*deployment.properties"} | Select-Object -expandproperty Value).replace("file:///","")        
                            }
                        }
                        else
                        {
                            [xml]$OracleJREXML   = Get-Content "$((get-module powerstig -ListAvailable | Sort-Object version -Descending | Select-Object -First 1).ModuleBase)\StigData\Processed\OracleJRE-8-1.5.xml"
                            $PropertiesPath = ($OracleJREXML.DISASTIG.FileContentRule.Rule | Where-Object {$_.value -like "*deployment.properties"} | Select-Object -expandproperty Value).replace("file:///","")    
                        }
                        Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: PropertiesPath is set to $PropertiesPath"
                    }

                    if($ComputerName -eq $env:ComputerName)
                    {
                        if(-not (Test-Path $PropertiesPath))
                        {
                            New-Item -Path $PropertiesPath -ItemType File -Force | out-null
                        }

                        $PropertiesCont = Get-Content $PropertiesPath
                        if($PropertiesCont.count -eq 0)
                        {
                            Add-Content $PropertiesPath -Value "1"
                        }
                    }
                    else
                    {
                        if(-not(Invoke-Command -ComputerName $ComputerName -ScriptBlock {param($PropertiesPath)Test-Path $PropertiesPath} -ArgumentList $PropertiesPath))
                        {
                            Invoke-Command -ComputerName $Computername -ScriptBlock {param($PropertiesPath)New-Item $PropertiesPath -ItemType File -Force} -ArgumentList $PropertiesPath | out-null
                        }

                        $PropertiesCont = Invoke-Command -ComputerName $Computername -ScriptBlock {param($PropertiesPath)Get-Content $PropertiesPath} -ArgumentList $PropertiesPath
                        if($PropertiesCont.count -eq 0)
                        {
                            Invoke-Command -ComputerName $Computername -ScriptBlock {param($PropertiesPath)Add-Content $PropertiesPath -Value "1"} -ArgumentList $PropertiesPath
                        }
                    }


                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: Adding OracleJRE Configuration"
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: ConfigPath = $confPath"
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][JRE][Info]: PropertiesPath = $PropertiesPath"
                    OracleJRE JRE
                    {
                        ConfigPath      = $confPath
                        PropertiesPath  = $PropertiesPath
                        StigVersion     = (Get-PowerStigXMLVersion -Role "OracleJRE")
                        OrgSettings     = $OrgSettingsFilePath
                        Exception       = @{'V-66941.a'="file:///$PropertiesPath"}
                    }
                }
                {($_ -eq "IISServer") -or ($_ -eq "IISSite")} {
                    
                    $SiteAppHash = @{}
                    $SiteLogHash = @{}
                    if($ComputerName -eq $env:COMPUTERNAME)
                    {
                        Import-Module WebAdministration
                        $SiteList = @(Get-WebSite | Select-Object -ExpandProperty Name)
                        $ServerLogPath = (Get-Item IIS:\).SiteDefaults.LogFile.Directory
                        if($ServerLogPath -like "%*%*")
                        {
                            $tempLogPath = '$env:' + $ServerLogPath.replace("%","")
                            $ServerLogPath = Invoke-Expression "`"$tempLogPath`""
                        }
            
                        foreach($site in $SiteList)
                        {
                            $wAppPool = (Get-website $site).applicationpool
                            $wLogPath = (Get-Item IIS:\Sites\$site).logfile.directory
            
                            if($wLogPath -like "%*%*")
                            {
                                $tempLogPath = '$env:' + $wLogPath.replace("%","")
                                $wLogPath = Invoke-Expression "`"$tempLogPath`""
                            }
                            $SiteHash.add($Site,$wAppPool)
                            $SiteLogHash.add($Site,$wLogPath)
            
                        }
                    }
                    else
                    {
                        $session = New-PSSession -ComputerName $ComputerName
                        Invoke-Command -Session $session -ScriptBlock {Import-Module WebAdministration}
                        $ServerLogPath = Invoke-Command -Session $session -ScriptBlock {(get-item IIS:\).sitedefaults.logfile.directory}
                        if($ServerLogPath -like "%*%*")
                        {
                            $tempLogPath = '$env:' + $ServerLogPath.replace("%","")
                            # Weirdness in this string requires the second set of quotations within the expression for the $env to expand correctly
                            $ServerLogPath = Invoke-Command -Session $session -ScriptBlock {param($tempLogPath)invoke-expression "`"$tempLogPath`""} -ArgumentList $tempLogPath
                        }
                        
                        $SiteList = @(Invoke-Command -Session $session -ScriptBlock {Get-WebSite | Select-Object -ExpandProperty Name})
                        foreach ($site in $SiteList)
                        {
                            $wAppPool = Invoke-Command -Session $session -ScriptBlock {param($site)(Get-website $site).applicationpool} -ArgumentList $site
                            $wLogPath = Invoke-Command -Session $session -ScriptBlock {param($site)(Get-Item IIS:\Sites\$site).logfile.directory}
                            if($wLogPath -like "%*%*")
                            {
                                $tempLogPath = '$env:' + $wLogPath.replace("%","")
                                $wLogPath = Invoke-Command -Session $session -Scriptblockk {param($tempLogPath)Invoke-Expression "`"$tempLogPath`""} -ArgumentList $tempLogPath
                            } 
                            $SiteAppHash.add($Site,$wAppPool)
                            $SiteLogHash.add($Site,$wLogPath)
                        }
                    }
            
                    $IisSiteOrgFile   = "$(Split-Path $logPath)\PSOrgSettings\IISSite_org.xml"
                    $IisServerOrgFile = "$(Split-Path $logPath)\PSOrgSettings\IISServer_org.xml"

                    $ResourceName = "IIS-Server-$ComputerName"
                    IisServer $ResourceName
                    {
                        StigVersion     = (Get-PowerStigXMLVersion -Role "IISServer")
                        LogPath         = $ServerLogPath
                        IisVersion      = '8.5'
                        OrgSettings     = $IisServerOrgFile
                    }
                    foreach($Site in $SiteList)
                    {
                        $ResourceName = "$Site"
                        IisSite $ResourceName
                        {
                            WebsiteName     = $Site
                            WebAppPool      = $SiteAppHash.$Site
                            IisVersion      = '8.5'
                            StigVersion     = (Get-PowerStigXMLVersion -Role "IISSite")
                            OrgSettings     = $IisSiteOrgFile
                        }
                    }    
                }
                "SqlServer-2012-Database" {
                    #continue until finalized, must find instance and database relationships
                    Return
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding SQL Configuration"
                    SqlServer Sql-$Database
                    {
                        SqlVersion      = $SqlVersion
                        SqlRole         = $SqlRole
                        ServerInstance  = $SqlInstance
                        Database        = $Database
                        StigVersion     = (Get-PowerStigXMLVersion -Role "SqlServer-2012-Database")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "Outlook2013" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Outlook2013 Configuration"
                    Office Outlook
                    {
                        OfficeApp       = "Outlook2013"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "Outlook2013")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "PowerPoint2013"{
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding PowerPoint2013 Configuration"
                    Office PowerPoint
                    {
                        OfficeApp       = "PowerPoint2013"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "PowerPoint2013")
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "Excel2013" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Excel2013 Configuration"
                    Office Excel
                    {
                        OfficeApp       = "Excel2013"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "Excel2013")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "Word2013" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Word2013 Configuration"
                    Office Word
                    {
                        OfficeApp       = "Word2013"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "Word2013")
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "Outlook2016" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Outlook2016 Configuration"
                    Office Outlook
                    {
                        OfficeApp       = "Outlook2016"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "Outlook2016")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "PowerPoint2016"{
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding PowerPoint2016 Configuration"
                    Office PowerPoint
                    {
                        OfficeApp       = "PowerPoint2016"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "PowerPoint2016")
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "Excel2016" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Excel2016 Configuration"
                    Office Excel
                    {
                        OfficeApp       = "Excel2016"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "Excel2016")
                        OrgSettings     = $OrgSettingsFilePath
                    }
                }
                "Word2016" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Word2016 Configuration"
                    Office Word
                    {
                        OfficeApp       = "Word2016"
                        StigVersion     = (Get-PowerStigXMLVersion -Role "Word2016")
                        OrgSettings     = $OrgSettingsFilePath
                    } 
                }
                "FireFox" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding FireFox Configuration"
                    
                    try
                    {
                        $installDirectory = (Get-PowerStigFireFoxDirectory -ComputerName $ComputerName)
                    }
                    catch
                    {
                        Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ComputerName][FireFoxDSC][ERROR]:$_"
                        Return
                    }

                    if($null -eq $installDirectory -or $installDirectory -eq "")
                    {
                        Write-PowerStigPSLog -Path $logFilePath -Value "$(Get-Time):[$ComputerName][FireFoxDSC][ERROR]:Could not find FireFox install directory."
                        Return
                    }
                    
                    FireFox Firefox
                    {
                        StigVersion         = (Get-PowerStigXMLVersion -Role "FireFox")
                        InstallDirectory    = $installDirectory
                        OrgSettings         = $OrgSettingsFilePath
                    }
                }
                "DotNetFramework" {
                    Write-PowerStigPSLog -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding DotNet Configuration"
                    DotNetFramework DotNet
                    {
                        FrameworkVersion    = 'DotNet4'
                        StigVersion         = (Get-PowerStigXMLVersion -Role "DotNetFramework")
                        OrgSettings         = $OrgSettingsFilePath
                    }
                }
            }
        
        }
    }

    PowerSTIG
}
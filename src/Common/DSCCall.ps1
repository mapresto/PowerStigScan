# Consolidated resource for MOF generation
# IISObject must include WebsiteName + WebAppPool - Get-Website -> foreach($i in $sites) {(inv-cmd -comp $serv -scr {get-website $i}).applicationpool}
# SQLObject must include SqlVersion, SqlRole, ServerInstance, Database

param(

    [Parameter(Mandatory=$true,Position=1)]
    [String]
    $ComputerName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("2012R2","2016")]
    [String]
    $OsVersion,

    [Parameter(Mandatory=$false)]
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
}

process
{

    if($LogPath -ne $null -and $LogPath -ne "")
    {
        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Starting mof generation for $ComputerName"
    }

    Configuration PowerSTIG
    {
        Import-DscResource -ModuleName PowerStig -ModuleVersion 2.4.0.0

        Node $ComputerName
        {
            Switch($Role){
                "DC" {
                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding DomainController Configuration"
                    }
                
                    WindowsServer DomainController
                    {
                        OsVersion       = $OsVersion
                        OsRole          = 'DC'
                        StigVersion     = (Get-PowerStigXMLVersion -Role DC -OSVersion $osVersion)
                        if($role -contains "DNS")
                        {
                            DependsOn   = 'DNS'
                        }
                    } 
                }
                "DNS" {
                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding DNS Configuration"
                    }
                
                    WindowsDnsServer DNS
                    {
                        OsVersion   = $OsVersion
                        StigVersion = (Get-PowerStigXMLVersion -Role DNS -OSVersion $osVersion)
                    }
                }
                "MS" {
                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding MemberServer Configuration"
                    }
                
                    WindowsServer MemberServer
                    {
                        OsVersion       = $OsVersion
                        OsRole          = 'MS'
                        StigVersion     = (Get-PowerStigXMLVersion -Role MS -OSVersion $osVersion)
                    } 
                }
                "IE11" {
                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding InternetExplorer Configuration"
                    }
                
                    Browser IE
                    {
                        BrowserVersion = 'IE11'
                        StigVersion = (Get-PowerStigXMLVersion -Role IE11 -OSVersion "All")
                        SkipRule = 'V-46477'
                    } 
                }
                "FW" {
                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding FireWall Configuration"
                    }
                
                    WindowsFirewall Firewall
                    {
                        StigVersion = (Get-PowerStigXMLVersion -Role FW -OSVersion "All")
                    } 
                }
                "Client" {
                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Windows10 Configuration"
                    }
                
                    WindowsClient Client
                    {
                        OsVersion       = '10'
                        StigVersion     = (Get-PowerStigXMLVersion -Role Client -OSVersion "Windows-10")
                    }
                }
                "OracleJRE" {

                    #continue until this is finalized - must find config and properties path

                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding OracleJRE Configuration"
                    }
                
                    OracleJRE JRE
                    {
                        ConfigPath = $ConfigPath
                        PropertiesPath = $PropertiesPath
                        StigVersion = (Get-PowerStigXMLVersion -Role OracleJRE8 -OSVersion "All")
                    }
                }
                "IIS" {

                    #continue until this is finalized - must find app pool website relationships
                    continue

                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding IIS Configuration"
                    }
                
                    IisServer IIS-Server-$ComputerName
                    {
                        StigVersion = (Get-PowerStigXMLVersion -Role IISServer -OSVersion $osVersion)
                    }
                    IisSite IIS-Site-$WebsiteName
                    {
                        WebsiteName = $WebsiteName
                        WebAppPool = $WebAppPool
                        StigVersion = (Get-PowerStigXMLVersion -Role IISSite -OSVersion $osVersion)
                    } 
                }
                "SQL" {
                    #continue until finalized, must find instance and database relationships
                    continue

                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding SQL Configuration"
                    }
                
                    SqlServer Sql-$Database
                    {
                        SqlVersion = $SqlVersion
                        SqlRole = $SqlRole
                        ServerInstance = $SqlInstance
                        Database = $Database
                        StigVersion = (Get-PowerStigXMLVersion -Role SQL -OSVersion $SqlVersion)
                    }
                }
                "Outlook2013" {
                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Outlook2013 Configuration"
                    }
                
                    Office Outlook
                    {
                        OfficeApp       = "Outlook2013"
                        StigVersion     = (Get-PowerStigXMLVersion -Role Outlook2013 -OSVersion "All")
                    }
                }
                "PowerPoint2013"{
                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding PowerPoint2013 Configuration"
                    }
                
                    Office PowerPoint
                    {
                        OfficeApp       = "PowerPoint2013"
                        StigVersion     = (Get-PowerStigXMLVersion -Role PowerPoint2013 -OSVersion "All")
                    } 
                }
                "Excel2013" {
                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Excel2013 Configuration"
                    }
                
                    Office Excel
                    {
                        OfficeApp       = "Excel2013"
                        StigVersion     = (Get-PowerStigXMLVersion -Role Excel2013 -OSVersion "All")
                    }
                }
                "Word2013" {
                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding Word2013 Configuration"
                    }
                
                    Office Word
                    {
                        OfficeApp       = "Word2013"
                        StigVersion     = (Get-PowerStigXMLVersion -Role Word2013 -OSVersion "All")
                    } 
                }
                "FireFox" {
                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding FireFox Configuration"
                    }
                
                    FireFox Firefox
                    {
                        StigVersion         = (Get-PowerStigXMLVersion -Role FireFox -OSVersion "All")
                        InstallDirectory    = $InstallDirectory
                    }
                }
                "DotNet" {
                    if($LogPath -ne $null -and $LogPath -ne "")
                    {
                        Add-Content -Path $LogPath -Value "$(Get-Time):[$ComputerName][Info]: Adding DotNet Configuration"
                    }
                    DotNetFramework DotNet
                    {
                        FrameworkVersion    = 'DotNet4'
                        StigVersion         = (Get-PowerStigXMLVersion -Role DotNet -OSVersion "All")
                    }
                }
            }
        
        }
    }

    PowerSTIG
}
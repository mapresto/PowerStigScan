# Consolidated resource for MOF generation
# Roles done: 

param(

    [Parameter(Mandatory=$true,Position=1)]
    [String]
    $ComputerName,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("2012R2","2016")]
    [String]
    $OsVersion,

    [Parameter(Mandatory=$true)]
    [String]
    $StigVersion

)

DynamicParam {
    # Set the dynamic parameters' name
    $ParameterName = 'Role'

    # Create the dictionary 
    $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

    # Create the collection of attributes
    $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

    # Create and set the parameters' attributes
    $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
    $ParameterAttribute.Mandatory = $true

    # Add the attributes to the attributes collection
    $AttributeCollection.Add($ParameterAttribute)

    # Generate and set the ValidateSet 
    $roleSet = Import-CSV C:\Users\mapresto\desktop\DynamicParamTest\Roles.csv -Header Role | Select -ExpandProperty Role
    $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($roleSet)

    # Add the ValidateSet to the attributes collection
    $AttributeCollection.Add($ValidateSetAttribute)

    # Create and return the dynamic parameter
    $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
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
    Configuration PowerSTIG
    {
        Import-DscResource -ModuleName PowerStig -ModuleVersion 2.3.2.0

        Node $ComputerName
        {
            Switch($Role){
                "DC" {
                    WindowsServer DomainController
                    {
                        OsVersion       = $OsVersion
                        OsRole          = $Role
                        StigVersion     = $StigVersion
                    } 
                }
                "DNS" {
                    WindowsDnsServer DNS
                    {
                        OsVersion   = $OsVersion
                        StigVersion = $StigVersion
                    }
                }
                "MS" {
                    WindowsServer MemberServer
                    {
                        OsVersion       = $OsVersion
                        OsRole          = $Role
                        StigVersion     = $StigVersion
                    } 
                }
                "IE11" {
                    Browser IE
                    {
                        BrowserVersion = $Role
                        StigVersion = $StigVersion
                        SkipRule = 'V-46477'
                    } 
                }
                "FW" {
                    WindowsFirewall Firewall
                    {
                        StigVersion = $StigVersion
                    } 
                }
                "Client" {
                    WindowsClient Client
                    {
                        OsVersion       = '10'
                        StigVersion     = $StigVersion
                    }
                }
                "OracleJRE" {
                    OracleJRE JRE
                    {
                        ConfigPath = $ConfigPath
                        PropertiesPath = $PropertiesPath
                        StigVersion = $StigVersion
                    }
                }
                "IIS" {
                    IisServer IIS-Server
                    {
                        StigVersion = $StigVersion
                    }
                    IisSite IIS-Site
                    {
                        WebsiteName = $WebsiteName
                        WebAppPool = $WebAppPool
                        StigVersion = $StigVersion
                    } 
                }
                "SQL" {
                    SqlServer Sql
                    {
                        SqlVersion = $SqlVersion
                        SqlRole = $SqlRole
                        ServerInstance = $SqlInstance
                        Database = $Database
                        StigVersion = $StigVersion
                    }
                }
                "Outlook2013" {
                    Office Outlook
                    {
                        OfficeApp       = "Outlook2013"
                        StigVersion     = $StigVersion
                    }
                }
                "PowerPoint2013"{
                    Office PowerPoint
                    {
                        OfficeApp       = "PowerPoint2013"
                        StigVersion     = $StigVersion
                    } 
                }
                "Excel2013" {
                    Office Excel
                    {
                        OfficeApp       = "Excel2013"
                        StigVersion     = $StigVersion
                    }
                }
                "Word2013" {
                    Office Word
                    {
                        OfficeApp       = "Word2013"
                        StigVersion     = $StigVersion
                    } 
                }
                "FireFox" {
                    FireFox Firefox
                    {
                        StigVersion         = $StigVersion
                        InstallDirectory    = $InstallDirectory
                    }
                }
                "DotNet" {
                    DotNetFramework DotNet
                    {
                        FrameworkVersion    = 'DotNet4'
                        StigVersion         = $StigVersion
                    }
                }
            }
        
        }
    }
}
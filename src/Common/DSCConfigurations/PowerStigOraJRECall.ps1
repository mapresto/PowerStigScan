param(

    [Parameter(Mandatory=$true,Position=1)]
    [String]
    $ComputerName,

    [Parameter(Mandatory=$true)]
    [String]
    $ConfigPath,

    [Parameter(Mandatory=$true)]
    [String]
    $PropertiesPath,

    [Parameter(Mandatory=$false)]
    [String]
    $StigVersion

)



configuration PowerStigOraJreCall
{
    Import-DscResource -ModuleName PowerStig -ModuleVersion 2.3.2.0

    Node $ComputerName  
    {
        OracleJRE JRE
        {
            ConfigPath = $ConfigPath
            PropertiesPath = $PropertiesPath
            StigVersion = $StigVersion
        } 
    }
}

PowerStigOraJreCall
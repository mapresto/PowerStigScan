param(

    [Parameter(Mandatory=$true,Position=1)]
    [String]
    $ComputerName,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("2012R2")]
    [String]
    $OsVersion,

    [Parameter(Mandatory=$true)]
    [String]
    $StigVersion

)



configuration PowerStigDNSCall
{
    Import-DscResource -ModuleName PowerStig -ModuleVersion 2.4.0.0

    Node $ComputerName  
    {
        WindowsDnsServer DNS
        {
            OsVersion   = $OsVersion
            StigVersion = $StigVersion
        } 
    }
}

PowerStigDNSCall
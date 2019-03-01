param(

    [Parameter(Mandatory=$true,Position=1)]
    [String]
    $ComputerName,

    [Parameter(Mandatory=$false)]
    [String]
    $StigVersion

)

configuration PowerStigWinCliCall
{
    Import-DscResource -ModuleName PowerStig -ModuleVersion 2.4.0.0

    Node $ComputerName
    {
        WindowsClient Client
        {
            OsVersion       = '10'
            StigVersion     = $StigVersion
        } 
    }
}

PowerStigWinCliCall
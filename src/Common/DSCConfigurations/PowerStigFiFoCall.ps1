param(

    [Parameter(Mandatory=$true,Position=1)]
    [String]
    $ComputerName,

    [Parameter(Mandatory=$true)]
    [String]
    $InstallDirectory,

    [Parameter(Mandatory=$false)]
    [String]
    $StigVersion

)

configuration PowerStigFiFoCall
{
    Import-DscResource -ModuleName PowerStig -ModuleVersion 2.3.2.0

    Node $ComputerName
    {
        FireFox Firefox
        {
            StigVersion         = $StigVersion
            InstallDirectory    = $InstallDirectory
        } 
    }
}

PowerStigFiFoCall
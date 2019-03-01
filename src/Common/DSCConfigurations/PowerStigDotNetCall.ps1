param(

    [Parameter(Mandatory=$true,Position=1)]
    [String]
    $ComputerName,

    [Parameter(Mandatory=$false)]
    [String]
    $StigVersion

)

configuration PowerStigDotNetCall
{
    Import-DscResource -ModuleName PowerStig -ModuleVersion 2.4.0.0

    Node $ComputerName
    {
        DotNetFramework DotNet
        {
            FrameworkVersion    = 'DotNet4'
            StigVersion         = $StigVersion
        } 
    }
}

PowerStigDotNetCall
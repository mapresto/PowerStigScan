param(

    [Parameter(Mandatory=$true,Position=1)]
    [String]
    $ComputerName,

    [Parameter(Mandatory=$false)]
    [String]
    $StigVersion

)



configuration PowerStigFWCall
{
    Import-DscResource -ModuleName PowerStig -ModuleVersion 2.4.0.0

    Node $ComputerName  
    {
        WindowsFirewall Firewall
        {
            StigVersion = $StigVersion
        } 
    }
}

PowerStigFWCall
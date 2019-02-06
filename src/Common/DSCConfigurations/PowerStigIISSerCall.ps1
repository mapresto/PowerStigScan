param(

    [Parameter(Mandatory=$true,Position=1)]
    [String]
    $ComputerName,

    [Parameter(Mandatory=$false)]
    [String]
    $StigVersion

)



configuration PowerStigIISSerCall
{
    Import-DscResource -ModuleName PowerStig -ModuleVersion 2.3.2.0

    Node $ComputerName  
    {
        IisServer IIS-Server
        {
            StigVersion = $StigVersion
        } 
    }
}

PowerStigIISSerCall
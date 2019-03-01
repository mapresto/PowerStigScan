param(

    [Parameter(Mandatory=$true,Position=1)]
    [String]
    $ComputerName,

    [Parameter(Mandatory=$true)]
    [String]
    $StigVersion,

    [Parameter(Mandatory=$true)]
    [String]
    $WebAppPool,

    [Parameter(Mandatory=$true)]
    [String]
    $WebsiteName

)



configuration PowerStigIISSiteCall
{
    Import-DscResource -ModuleName PowerStig -ModuleVersion 2.4.0.0

    Node $ComputerName  
    {
        IisSite IIS-Site
        {
            WebsiteName = $WebsiteName
            WebAppPool = $WebAppPool
            StigVersion = $StigVersion
        } 
    }
}

PowerStigIISSiteCall
param(

    [Parameter(Mandatory=$true,Position=1)]
    [String]
    $ComputerName,

    [Parameter(Mandatory=$true)]
    [ValidateSet("DC","MS")]
    [String]
    $Role,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("2012R2","2016")]
    [String]
    $OsVersion,

    [Parameter(Mandatory=$true)]
    [String]
    $StigVersion

)

configuration PowerStigMSDCCall
{
    Import-DscResource -ModuleName PowerStig -ModuleVersion 2.4.0.0

    Node $ComputerName
    {
        if($Role -eq 'MS')
        {
            WindowsServer MemberServer
            {
                OsVersion       = $OsVersion
                OsRole          = $Role
                StigVersion     = $StigVersion
            } 
        }
        elseif($Role -eq 'DC')
        {
            WindowsServer DomainController
            {
                OsVersion       = $OsVersion
                OsRole          = $Role
                StigVersion     = $StigVersion
            } 
        }
        
    }
}

PowerStigMSDCCall
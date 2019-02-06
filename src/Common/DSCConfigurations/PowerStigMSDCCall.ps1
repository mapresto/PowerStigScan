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

## V-1073 and V-1081 are skipped due to issues with scripted resources
## V-3472.b is skipped due to issues with org settings in secure environment, to be fixed in org settings file

configuration PowerStigMSDCCall
{
    Import-DscResource -ModuleName PowerStig -ModuleVersion 2.3.2.0

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
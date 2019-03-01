param(

    [Parameter(Mandatory=$true,Position=1)]
    [String]
    $ComputerName,

    [Parameter(Mandatory=$true)]
    [String]
    $SqlVersion,

    [Parameter(Mandatory=$true)]
    [ValidateSet('Database','Instance')]
    [String]
    $SqlRole,

    [Parameter(Mandatory=$true)]
    [String]
    $SqlInstance,

    [Parameter(Mandatory=$false)]
    [String[]]
    $Database,

    [Parameter(Mandatory=$false)]
    [String]
    $StigVersion

)



configuration PowerStigSqlSerCall
{
    Import-DscResource -ModuleName PowerStig -ModuleVersion 2.4.0.0

    Node $ComputerName  
    {
        SqlServer Sql
        {
            SqlVersion = $SqlVersion
            SqlRole = $SqlRole
            ServerInstance = $SqlInstance
            Database = $Database
            StigVersion = $StigVersion
        } 
    }
}

PowerStigSqlSerCall
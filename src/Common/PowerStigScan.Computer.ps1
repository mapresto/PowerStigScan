<#
Functions:
    Public:
        CM01 - Add-PowerStigComputer
        CM02 - Get-PowerStigComputer
        CM03 - Set-PowerStigComputer
        CM04 - Remove-PowerStigComputer
#>

#region Private

#endregion Private

#region Public

#CM01
<#
.SYNOPSIS
Adds a new computer target to the PowerStig database

.DESCRIPTION
Adds a new computer target to the PowerStig database with the roles specified in the switches

.PARAMETER ServerName
Name of server to add

.PARAMETER OSVersion
Operating System installed on new server. Valid options are 2012R2 and 2016

.PARAMETER SqlInstance
SQL instance name that hosts the PowerStig database. If empty, this will use the settings in the ModuleBase\Common\config.ini file.

.PARAMETER DatabaseName
Name of the database that hosts the PowerStig tables. If empty, this will use the settings in the ModuleBase\Common\config.ini file.

.PARAMETER DomainController
Will flag the server as a domain controller. If member server is also marked, this switch will take precedence.

.PARAMETER MemberServer
Will flag the server as a member server. If domain controller is also marked, this switch will not take effect

.PARAMETER DNS
Will flag the server as a DNS server.

.PARAMETER IE
Will flag the server as having IE installed.

.EXAMPLE
Add-PowerStigComputer -ServerName DC2012Test -OSVersion 2012R2 -SqlInstance SQLTest -DatabaseName Master -DomainController -DNS -IE

#>
function Add-PowerStigComputer
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$ServerName,

        [Parameter(Mandatory=$true)]
        [ValidateSet("2012R2","2016")]
        [String]$OSVersion,

        [switch]$DebugScript,

        [Parameter(Mandatory=$false)]
        [String]$SqlInstance,

        [Parameter(Mandatory=$false)]
        [String]$DatabaseName
    )

    DynamicParam {
        $ParameterName = 'Role'
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $AttributeCollection.Add($ParameterAttribute)
        $roleSet = Import-CSV "$(Split-Path $PsCommandPath)\Roles.csv" -Header Role | Select-Object -ExpandProperty Role
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($roleSet)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string[]], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin{
        $Role = $PSBoundParameters[$ParameterName]
    }

    process {
        $workingPath = Split-Path $PsCommandPath
        $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

        if($null -eq $sqlInstance -or $sqlInstance -eq '')
        {
            $sqlInstance = $iniVar.SqlInstanceName
        }
        if($null -eq $DatabaseName -or $DatabaseName -eq '')
        {
            $DatabaseName = $iniVar.DatabaseName
        }

        #Initialize Values
        $DotNetFramework        = 0
        $FireFox                = 0
        $IISServer              = 0
        $IISSite                = 0
        $InternetExplorer       = 0
        $Excel2013              = 0
        $Outlook2013            = 0
        $PowerPoint2013         = 0
        $Word2013               = 0
        $OracleJRE              = 0
        $SqlServer2012Database  = 0
        $SqlServer2012Instance  = 0
        $SqlServer2016Instance  = 0
        $WindowsClient          = 0
        $WindowsDefender        = 0
        $WindowsDNSServer       = 0
        $WindowsFirewall        = 0
        $WindowsServerDC        = 0
        $WindowsServerMS        = 0

        Switch($Role)
        {
            "DotNetFramework"           {$DotNetFramework       = 1}
            "FireFox"                   {$FireFox               = 1}
            "IISServer"                 {$IISServer             = 1}
            "IISSite"                   {$IISSite               = 1}
            "InternetExplorer"          {$InternetExplorer      = 1}
            "Excel2013"                 {$Excel2013             = 1}
            "Outlook2013"               {$Outlook2013           = 1}
            "PowerPoint2013"            {$PowerPoint2013        = 1}
            "Word2013"                  {$Word2013              = 1}
            "OracleJRE"                 {$OracleJRE             = 1}
            "SqlServer-2012-Database"   {$SqlServer2012Database = 1}
            "SqlServer-2012-Instance"   {$SqlServer2012Instance = 1}
            "SqlServer-2016-Instance"   {$SqlServer2016Instance = 1}
            "WindowsClient"             {$WindowsClient         = 1}
            "WindowsDefender"           {$WindowsDefender       = 1}
            "WindowsDNSServer"          {$WindowsDNSServer      = 1}
            "WindowsFirewall"           {$WindowsFirewall       = 1}
            "WindowsServer-DC"          {$WindowsServerDC       = 1}
            "WindowsServer-MS"          {$WindowsServerMS       = 1}
        }

        $Query = "PowerSTIG.sproc_AddTargetComputer @TargetComputerName     = `"$ServerName`",`
                                                    @DotNetFramework        = $DotnetFramework,`
                                                    @FireFox                = $FireFox,`
                                                    @IISServer              = $IISServer,`
                                                    @IISSite                = $IISSite,`
                                                    @InternetExplorer       = $InternetExplorer,`
                                                    @Excel2013              = $Excel2013,`
                                                    @Outlook2013            = $Outlook2013,`
                                                    @PowerPoint2013         = $PowerPoint2013,`
                                                    @Word2013               = $Word2013,`
                                                    @OracleJRE              = $OracleJRE,`
                                                    @SqlServer2012Database  = $SqlServer2012Database,`
                                                    @SqlServer2012Instance  = $SqlServer2012Instance,`
                                                    @SqlServer2016Instance  = $SqlServer2016Instance,`
                                                    @WindowsClient          = $WindowsClient,`
                                                    @WindowsDefender        = $WindowsDefender,`
                                                    @WindowsDNSServer       = $WindowsDNSServer,`
                                                    @WindowsFirewall        = $WindowsFirewall,`
                                                    @WindowsServerDC        = $WindowsServerDC,`
                                                    @WindowsServerMS        = $WindowsServerMS"

        if($DebugScript)
        {
            Write-Host $query
        }
        $Results = Invoke-PowerStigSqlCommand -Query $Query -SqlInstance $SqlInstance -DatabaseName $DatabaseName
        return $Results 
    }
}

#CM02
function Get-PowerStigComputer
{
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName="ByName")]
        [ValidateNotNullorEmpty()]
        [String]$ServerName,

        [Parameter(ParameterSetName="GetAll")]
        [Switch]$All,

        [switch]$DebugScript,

        [Parameter()]
        [String]$SqlInstance,
        
        [Parameter()]
        [String]$DatabaseName
        
    )
    DynamicParam {
        $ParameterName = 'Role'
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.ParameterSetName = "ByRole"
        $AttributeCollection.Add($ParameterAttribute)
        $roleSet = Import-CSV "$(Split-Path $PsCommandPath)\Roles.csv" -Header Role | Select-Object -ExpandProperty Role
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($roleSet)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin{
        $Role = $PSBoundParameters[$ParameterName]
    }

    process{
        $workingPath = Split-Path $PsCommandPath
        $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

        if($null -eq $SqlInstance -or $SqlInstance -eq '')
        {
            $SqlInstance = $iniVar.SqlInstanceName
        }
        if($null -eq $DatabaseName -or $DatabaseName -eq '')
        {
            $DatabaseName = $iniVar.DatabaseName
        }

    
        Switch($PSCmdlet.ParameterSetName)
        {
            "ByName" {
                $GetComputerName = "EXEC PowerSTIG.sproc_GetRolesPerServer @TargetComputer = $ServerName"
                if($DebugScript)
                {
                    Write-Host $GetComputerName
                }
                $RunGetComputerName = (Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $GetComputerName )
                $Output = $RunGetComputerName
            }
            "ByRole" {
                $Role = Convert-PowerStigRoleToSql -Role $Role
                $GetRoleData = "EXEC PowerSTIG.sproc_GetActiveRoles  @ComplianceType = $Role"
                if($DebugScript)
                {
                    Write-Host $GetRoleData
                }
                $RunGetRoleData = (Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $GetRoleData )
                $Output = $RunGetRoleData
            }
            "GetAll" {
                $GetAllServers = "EXEC PowerSTIG.sproc_GetActiveServers"
                if($DebugScript)
                {
                    Write-Host $GetAllServers
                }
                $RunGetAllServers = (Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $GetAllServers)
                $Output = $RunGetAllServers
            }
        }
        Return $OutPut
    }
}

#CM03
function Set-PowerStigComputer
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName,

        [Parameter(Mandatory=$true,ParameterSetName="OS")]
        [ValidateSet('2012R2','2016','10')]
        [String]$osVersion,

        [Parameter(Mandatory=$true,ParameterSetName='Role')]
        [boolean]$Enable,

        [switch]$DebugScript,

        [Parameter()]
        [String]$SqlInstance,

        [Parameter()]
        [String]$DatabaseName
    )

    DynamicParam {
        $ParameterName = 'Role'
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.ParameterSetName = 'Role'
        $AttributeCollection.Add($ParameterAttribute)
        $roleSet = Import-CSV "$(Split-Path $PsCommandPath)\Roles.csv" -Header Role | Select-Object -ExpandProperty Role
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($roleSet)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string[]], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin{
        $Role = $PSBoundParameters[$ParameterName]
    }

    process{
        $workingPath = Split-Path $PsCommandPath
        $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

        if($null -eq $SqlInstance -or $SqlInstance -eq '')
        {
            $SqlInstance = $iniVar.SqlInstanceName
        }
        if($null -eq $DatabaseName -or $DatabaseName -eq '')
        {
            $DatabaseName = $iniVar.DatabaseName
        }

        if($PSCmdlet.ParameterSetName -eq "Role")
        {
            if($Enable -eq $true)
            {
                $UpdateAction = '1'
            }
            else {
                $UpdateAction = '0'
            }
            
            foreach ($r in $Role)
            {
                $updateRole = Convert-PowerStigRoleToSql -Role $r
                $UpdateComputer = "EXEC PowerSTIG.sproc_UpdateServerRoles  @TargetComputer = `"$ServerName`" ,@ComplianceType = `"$updateRole`",@UpdateAction=`"$UpdateAction`""
                if($DebugScript)
                {
                    Write-Host $UpdateComputer
                }
                Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $UpdateComputer 
            }
        }
        elseif($PSCmdlet.ParameterSetName -eq "OS")
        {
            $UpdateComputer = "EXEC PowerSTIG.sproc_UpdateTargetOS @TargetComputer=`"$ServerName`",@OSName=`"$osVersion`""
            Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $UpdateComputer
        }
    }
}

#CM04
function Remove-PowerStigComputer
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName,

        [Parameter()]
        [Switch]$Force,

        [switch]$DebugScript,

        [Parameter()]
        [String]$SqlInstance,

        [Parameter()]
        [String]$DatabaseName
    )

    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($null -eq $SqlInstance -or $SqlInstance -eq '')
    {
        $SqlInstance = $iniVar.SqlInstanceName
    }
    if($null -eq $DatabaseName -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }

    if(!($Force))
    {
        
        $readIn = Read-Host "This will remove $ServerName and all data related to the computer from the database. Continue?(Y/N)"
        do{
            if($readIn -eq "N")
            {
                Write-Host "Cancelling"
                Return
            }
            elseif($readIn -eq "Y")
            {
                $proceed = $true
            }
            else
            {
                $readIn = Read-Host "Invalid response. Do you want to remove $ServerName? (Y/N)"
            }
        }While($proceed -eq $false)
    }
    

    $deleteComputer = "EXEC PowerSTIG.sproc_DeleteTargetComputerAndData @TargetComputer = `'$ServerName`'"
    if($DebugScript)
    {
        Write-Host $deleteComputer
    }
    Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $deleteComputer 

}


#endregion Public
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

        [Parameter(Mandatory=$true)]
        [ValidateSet("MemberServer","DomainController","DotNet","Firefox","Firewall","IIS","Word","Excel","PowerPoint","Outlook","JRE","Sql","Client","DNS","IE")]
        [String[]]$Role,

        [switch]$DebugScript,

        [Parameter(Mandatory=$false)]
        [String]$SqlInstance,

        [Parameter(Mandatory=$false)]
        [String]$DatabaseName

    )

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
    $MSOut          = 0
    $DCOut          = 0
    $DNSOut         = 0
    $DotNetOut      = 0
    $FireFoxOut     = 0
    $FWOut          = 0
    $IISOut         = 0
    $WordOut        = 0
    $ExcelOut       = 0
    $PPOut          = 0
    $OutlookOut     = 0
    $JREOut         = 0
    $SqlOut         = 0
    $ClientOut      = 0
    $IEOut          = 0

    Switch($Role)
    {
        "MemberServer"      {$MSOut     =1}
        "DomainController"  {$DCOut     =1}
        "DotNet"            {$DotNetOut =1}
        "Firefox"           {$FireFoxOut=1}
        "Firewall"          {$FWOut     =1}
        "IIS"               {$IISOut    =1}
        "Word"              {$WordOut   =1}
        "Excel"             {$ExcelOut  =1}
        "PowerPoint"        {$PPOut     =1}
        "Outlook"           {$OutlookOut=1}
        "JRE"               {$JREOut    =1}
        "Sql"               {$SqlOut    =1}
        "Client"            {$ClientOut =1}
        "DNS"               {$DNSOut    =1}
        "IE"                {$IEOut     =1}
    }

    $Query = "PowerSTIG.sproc_AddTargetComputer @TargetComputerName     = $ServerName,`
                                                @MemberServer           = $MSOut,`
                                                @DomainController       = $DCOut,`
                                                @DotNet                 = $DotNetOut,`
                                                @Firefox                = $FireFoxOut,`
                                                @Firewall               = $FWOut,`
                                                @IIS                    = $IISOut,`
                                                @Word                   = $WordOut,`
                                                @Excel                  = $ExcelOut,`
                                                @PowerPoint             = $PPOut,`
                                                @Outlook                = $OutlookOut,`
                                                @JRE                    = $JREOut,`
                                                @Sql                    = $sqlOut,`
                                                @Client                 = $ClientOut,`
                                                @DNS                    = $DNSOut,`
                                                @IE                     = $IEOut"

    if($DebugScript)
    {
        Write-Host $query
    }
    $Results = Invoke-PowerStigSqlCommand -Query $Query -SqlInstance $SqlInstance -DatabaseName $DatabaseName
    return $Results 


}

#CM02
function Get-PowerStigComputer
{
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName="ByRole")]
        [ValidateSet("MemberServer","DomainController","DotNet","Firefox","Firewall","IIS","Word","Excel","PowerPoint","Outlook","JRE","Sql","Client","DNS","IE")]
        [String]$Role,

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

#CM03
function Set-PowerStigComputer
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerName,

        [Parameter(Mandatory=$true)]
        [ValidateSet("MemberServer","DomainController","DotNet","Firefox","Firewall","IIS","Word","Excel","PowerPoint","Outlook","JRE","Sql","Client","DNS","IE")]
        [String[]]$Role,

        [Parameter(Mandatory=$true)]
        [boolean]$Enable,

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


    if($Enable -eq $true)
    {
        $UpdateAction = '1'
    }
    else {
        $UpdateAction = '0'
    }
    
    foreach ($r in $Role)
    {
        
        $UpdateComputer = "EXEC PowerSTIG.sproc_UpdateServerRoles  @TargetComputer = $ServerName,@ComplianceType = $r,@UpdateAction=$UpdateAction"
        if($DebugScript)
        {
            Write-Host $UpdateComputer
        }
        Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $UpdateComputer 
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
    

    $deleteComputer = "EXEC PowerSTIG.sproc_DeleteTargetComputerAndData @TargetComputer = $ServerName"
    if($DebugScript)
    {
        Write-Host $deleteComputer
    }
    Invoke-PowerStigSqlCommand -SqlInstance $SqlInstance -DatabaseName $DatabaseName -Query $deleteComputer 

}


#endregion Public
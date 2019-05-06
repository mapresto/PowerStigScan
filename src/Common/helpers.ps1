# =================================================================================================================
# Purpose:
# Revisions:
# 06282018 - Matt Preston, Microsoft - Release 1
# =================================================================================================================
# -----------------------------------------------------------------------------
#
# Copyright (C) 2018 Microsoft Corporation
#
# Disclaimer:
#   This is SAMPLE code that is NOT production ready. It is the sole intention of this code to provide a proof of concept as a
#   learning tool for Microsoft Customers. Microsoft does not provide warranty for or guarantee any portion of this code
#   and is NOT responsible for any affects it may have on any system it is executed on  or environment it resides within.
#   Please use this code at your own discretion!
# Additional legalese:
#   This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#   THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#   INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#   We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#   the object code form of the Sample Code, provided that You agree:
#       (i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#      (ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#     (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys' fees,
#           that arise or result from the use or distribution of the Sample Code.
# -----------------------------------------------------------------------------

<#
Functions:
    Private:
        H01 - Convert-PowerStigRoleToSql
        H02 - Import-PowerStigConfig
        H03 - Invoke-PowerStigSqlCommand
#>
#H01
function Convert-PowerStigRoleToSql
{
    [cmdletBinding()]
    param()
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
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin{
        $Role = $PSBoundParameters[$ParameterName]
    }

    process{
        switch($Role)
        {
            "DotNetFramework"           {Return $Role}
            "FireFox"                   {Return $Role}
            "IISServer"                 {Return $Role}
            "IISSite"                   {Return $Role}
            "InternetExplorer"          {Return $Role}
            "Excel2013"                 {Return $Role}
            "Outlook2013"               {Return $Role}
            "PowerPoint2013"            {Return $Role}
            "Word2013"                  {Return $Role}
            "OracleJRE"                 {Return $Role}
            "SqlServer-2012-Database"   {Return "SqlServer2012Database"}
            "SqlServer-2012-Instance"   {Return "SqlServer2012Instance"}
            "SqlServer-2016-Instance"   {Return "SqlServer2016Instance"}
            "WindowsClient"             {Return $Role}
            "WindowsDefender"           {Return $Role}
            "WindowsDNSServer"          {Return $Role}
            "WindowsFirewall"           {Return $Role}
            "WindowsServer-DC"          {Return "WindowsServerDC"}
            "WindowsServer-MS"          {Return "WindowsServerMS"}
        }
    }
}


#H02
<#
.SYNOPSIS
Retrieves configuration data from a standard .ini file and returns it as a hashtable

.DESCRIPTION
Will cycle through each line of a standard .ini and store each configuration pair as a value/key pair in a hashtable

.PARAMETER configFilePath
Path to the .ini file to be put to a variable

.EXAMPLE
Import-PowerStigConfig -configFilePath C:\users\test.user\documents\config.ini
#>
function Import-PowerStigConfig 
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$configFilePath
    )

    $configDataText = Get-Content $configFilePath
    $variables = @{}

    # Cycle through each part of the config.ini file
    foreach($c in $configDataText)
    {
        # Split String at the "=", Left is config name, right is config setting, ignore lines with "[" and ";" 
        $splitVar = [regex]::split($c,'=')
        if(($splitVar[0].CompareTo("") -ne 0) -and ($splitVar[0].StartsWith("[") -ne $True) -and ($splitVar[0].StartsWith(";") -ne $True))
        { 
            $variables.Add($splitVar[0].trim(), $splitVar[1].trim()) | out-null
        } # End if
    } # End foreach

    # Return hashtable of config data
    Return $variables
} # End Import-PowerStigConfig

#H03
function Invoke-PowerStigSqlCommand
{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [String]$Query,

        [Parameter(Mandatory=$false)]
        [String]$SqlInstance,

        [Parameter(Mandatory=$false)]
        [String]$DatabaseName
    )

    $workingPath = Split-Path $PsCommandPath
    $iniVar = Import-PowerStigConfig -configFilePath $workingPath\Config.ini

    if($SqlInstance -eq $null -or $SqlInstance -eq '')
    {
        $SqlInstance = $iniVar.SqlInstanceName
    }
    if($DatabaseName -eq $null -or $DatabaseName -eq '')
    {
        $DatabaseName = $iniVar.DatabaseName
    }

    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=$SqlInstance;Database=$DatabaseName;Integrated Security=True"
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $Query
    $SqlCmd.Connection = $SqlConnection
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $SqlAdapter.SelectCommand = $SqlCmd
    $DataSet = New-Object System.Data.DataSet
    $SqlAdapter.Fill($DataSet) | Out-Null
    $SqlConnection.Close()
    
    return $DataSet.Tables[0]
}


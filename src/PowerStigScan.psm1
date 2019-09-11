Import-Module PowerStig -RequiredVersion 4.0.0

. $PsScriptRoot\Common\helpers.ps1
. $PsScriptRoot\Common\PowerStigScan.Computer.ps1
. $PsScriptRoot\Common\PowerStigScan.Config.ps1
. $PsScriptRoot\Common\PowerStigScan.Results.ps1
. $PsScriptRoot\Common\PowerStigScan.Scap.ps1
. $PsScriptRoot\Common\PowerStigScan.Main.ps1

Export-ModuleMember -Function @('Invoke-PowerStigScan','Add-PowerStigComputer','Get-PowerStigSqlConfig','Set-PowerStigSqlConfig',
                                'Get-PowerStigConfig','Get-PowerStigComputer','Set-PowerStigComputer','Set-PowerStigConfig',
                                'Remove-PowerStigComputer','Get-PowerStigOrgSettings','Start-PowerStigDSCScan','Install-PowerStigSQLDatabase')
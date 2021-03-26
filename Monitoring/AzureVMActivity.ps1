<#
This script retrieves information who started/stoped/restarted virtual machines and saves information as .csv

Input parameters: 
	1) $ResourceGroupName - Name of specific resource group (DefaultValue: null) (Mandatory)
	2) $OutputPath - Path and name of the file data to be save to (DefaultValue: null) (Mandatory)
	
Output parameters:
	Server Name, Time, Event initiator and Event
	
	** Only START event enabled. 
	** If you want to enable other events (example: STOP) change following line: 
		-> '$_.OperationName.LocalizedValue -match "Start" -and'
	    -> '$_.OperationName.LocalizedValue -match "Start|Deallocate" -and'

Author: Momcilo Savic
Date: 26-Mar-2021
Version: 0.2
#>

<#
$ResourceGroups = @("PROPHET-DEVELOPMENT", "PROPHET-DEVELOPMENT-NA2", "PROPHET-DEVELOPMENT2", "PROPHET-DEVELOPMENT2-NA2", "PROPHET-ENTERPRISE", "PROPHET-PRESALES-NA2", "PROPHET-PROFESSIONAL-NA2", "RISK-MANAGMENT-NA2", "SHERWOOD-SYSTEMS-GRP-4124.522150.9822..0000.0000.3388")
#>

param(
	[Parameter(Mandatory=$true)][String]$ResourceGroupName,
	[Parameter(Mandatory=$true)][String]$OutputPath
)

$logs
if($ResourceGroupName.Length -gt 0){
	$logs = Get-AzLog -ResourceGroup $ResourceGroupName -MaxRecord 100000 -StartTime (Get-Date).AddDays(-90) -Status "Succeeded" | 
		Where-Object {
			$_.OperationName.LocalizedValue -match "Start" -and
			$_.Status.LocalizedValue -match "Succeeded"
		}
}
else{
	$logs = Get-AzLog -MaxRecord 100000 -StartTime (Get-Date).AddDays(-90) -Status "Succeeded" | 
		Where-Object {
			$_.OperationName.LocalizedValue -match "Start" -and
			$_.Status.LocalizedValue -match "Succeeded"
		}
}

$res = @{}
ForEach($log in $logs){
	$ServerName = ($log.resourceid -split "/")[-1]
	if($res[$ServerName] -eq $null){
		$obj = $log |
			Select-Object @{
					name="ServerName"; 
					Expression = {
						$ServerName
					}
				},
				@{
					name="Time"
					Expression = {
						$_.EventTimeStamp
					}
				},
				@{
					name="Caller";
					Expression = {
						$_.Caller
					}
				},
				@{
					name="Operation"; 
					Expression = {
						$_.operationname.LocalizedValue#.split("/")[2]
					}
				},
				@{
					name="ResourceGroup"
					Expression = {
						$ResourceGroupName
					}
				}
		$res[$ServerName] = $obj
	}
}

$exportList = @()
ForEach($key in $res.keys){
	$exportList += $res[$key]# | Format-List
}
$exportList | Sort-Object ServerName | Export-Csv $OutputPath -NoTypeInformation

$Count = $exportList.Length
Write-Output "$ResourceGroupName resource group activity successfully exported to $OutputPath. $Count machines was active for last 90 days."
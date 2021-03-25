<#
This script retrieves information who started/stoped/restarted virtual machines.

Input parameters: 
	1) $ResourceGroupName - Name of specific resource group (DefaultValue: null)
	
Output parameters:
	Time, Event, Server name and Event initiator

Author: Momcilo Savic
Date: 25-Mar-2021
Version: 0.1
#>

param(
	[String]$ResourceGroupName
)

if($ResourceGroupName.Length -eq 0){
	Get-AzLog -ResourceGroup $ResourceGroupName | 
		Where-Object {
			$_.OperationName.LocalizedValue -match "Start|Stop" -and
			$_.Status.LocalizedValue -match "Succeeded"
		} |
		Format-List @{
				name="Time"
				Expression = {
					$_.EventTimeStamp
				}
			},
			@{
				name="Operation"; 
				Expression = {
					$_.operationname.LocalizedValue#.split("/")[2]
				}
			},
			@{
				name="ServerName"; 
				Expression = {
					($_.resourceid -split "/")[-1]
				}
			},
			@{
				name="Caller";
				Expression = {
					$_.Caller
				}
			}
}
else{
	Get-AzLog -ResourceGroup $ResourceGroupName | 
			Where-Object {
				$_.OperationName.LocalizedValue -match "Start|Stop" -and
				$_.Status.LocalizedValue -match "Succeeded"
			} |
			Format-List @{
					name="Time"
					Expression = {
						$_.EventTimeStamp
					}
				},
				@{
					name="Operation"; 
					Expression = {
						$_.operationname.LocalizedValue#.split("/")[2]
					}
				},
				@{
					name="ServerName"; 
					Expression = {
						($_.resourceid -split "/")[-1]
					}
				},
				@{
					name="Caller";
					Expression = {
						$_.Caller
					}
				}
}
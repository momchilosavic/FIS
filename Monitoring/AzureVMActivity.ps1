<#
This script retrieves information who and when started/stoped/restarted virtual machines in specific subscription and resource groups, and saves information as .csv file.

Input parameters: 
	1) $Subscription - Name or ID of Azure subscription passed Resource Groups belongs to (Type: String) (DefaultValue: null) (Mandatory)
	1) $hashTableourceGroupNames - Names of specific resource group (Type: String[]) (DefaultValue: null) (Mandatory)
	2) $OutputPath - Path where the files data to be save to (Type: String) (DefaultValue: null) (Mandatory)
	3) $SkipDays - How many past days to skip (Type: Int) (DefaultValue = 0)
	
Output parameters:
	Script creates file named by ResourceGroup in folder named by Subscription that is located in passed path: $OutputPath\$Subscription\$hashTableourceGroupName
	Output file contains list of Server Names, Time the event happened, Event initiator and Event
	
	** Only START event enabled. 
	** If you want to enable other events (example: STOP) change following line: 
		-> '$_.OperationName.LocalizedValue -match "Start" -and'
	    -> '$_.OperationName.LocalizedValue -match "Start|Deallocate" -and'

Author: Momcilo Savic
Date: 26-Mar-2021
Version: 0.3
#>

<#
Example:
$Subscription_ResourceGroups_Hashtable = @{
	"FIS Global - CIO - Dev - North America 1" = "PROPHET-DEVELOPMENT", "PROPHET-DEVELOPMENT2", "PROPHET-ENTERPRISE", "SHERWOOD-SYSTEMS-GRP-4124.522150.9822..0000.0000.3388"
	"FIS Global CIO Dev North America 2" = "PROPHET-DEVELOPMENT-NA2", "PROPHET-DEVELOPMENT2-NA2", "PROPHET-PRESALES-NA2", "PROPHET-PROFESSIONAL-NA2", "RISK-MANAGMENT-NA2"
}
ForEach($subscription in $Subscription_ResourceGroups_Hashtable.Keys){
	.\AzureVMActivity.ps1 -Subscription $s -ResourceGroupNames $Subscription_ResourceGroups_Hashtable[$subscription] -OutputPath C:\Users\Public
}
#>

param(
	[Parameter(Mandatory=$true)][String]$Subscription,
	[Parameter(Mandatory=$true)][String[]]$ResourceGroupNames,
	[Parameter(Mandatory=$true)][String]$OutputPath,
	[Int]$SkipDays = 0
)

### CONNECT TO AZURE ###
Connect-AzAccount -Subscription "$Subscription"

ForEach($ResourceGroupName in $ResourceGroupNames){

	### FETCH DATA FROM AZURE LOG AND STORE IT IN $logs ARRAY ###
	$logs = Get-AzLog -ResourceGroup $ResourceGroupName -MaxRecord 100000 -StartTime (Get-Date).AddDays(-90) -EndTime (Get-Date).AddDays(-$SkipDays) -Status "Succeeded" | 
		Where-Object {
			$_.OperationName.LocalizedValue -match "Start" -and
			$_.Status.LocalizedValue -match "Succeeded"
		}

	### GET ONLY LATEST ACTIVITY FOR EVERY SERVER AND PUT IT IN HASHTABLE: server name -> obj{servername; time; caller; operation; resourcegroup} 
	$hashTable = @{}
	ForEach($log in $logs){
		$ServerName = ($log.resourceid -split "/")[-1]
		if($hashTable[$ServerName] -eq $null){
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
							$hashTableourceGroupName
						}
					}
			$hashTable[$ServerName] = $obj
		}
	}

	### REPRESENT HASHTABLE AS LIST ###
	$exportList = @()
	ForEach($key in $hashTable.keys){
		$exportList += $hashTable[$key]# | Format-List
	}
	### CREATE PATH IF NOT EXISTS ###
	if(!(Test-Path "$OutputPath\$Subscription")){
		New-Item -ItemType Directory -Force -Path "$OutputPath\$Subscription"
	}
	### EXPORT LIST AS .CSV FILE ###
	$exportList | Sort-Object ServerName | Export-Csv "$OutputPath\$Subscription\$ResourceGroupName.csv" -NoTypeInformation
	### PRINT INFORMATION TO USER ###
	$Count = $exportList.Length
	Write-Output "$hashTableourceGroupName resource group activity successfully exported to $OutputPath\$Subscription\$ResourceGroupName. $Count machines activated for last 90 days."
}
### DISCONNECT FROM AZURE ###
Disconnect-AzAccount -Scope CurrentUser
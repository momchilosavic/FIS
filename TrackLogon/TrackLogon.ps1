<#
This script provides tacking logon activity on specific server.

Input parameters: 
	1) $Computer - Name of the computer you want to get info from (Default value: $env:COMPUTERNAME)
	2) $Days - Number of past days to get log info (Default value: 1)
	
Output parameters:
	Script returns Name, Time and Event (Login/Logoff)

Author: Momcilo Savic
Date: 24-Mar-2021
#>

param(
	[String]$Computer = $env:COMPUTERNAME, 
	[Int]$Days = 1
	)
	
$logs = Get-Eventlog System -ComputerName $Computer -source Microsoft-Windows-Winlogon -After (Get-Date).AddDays(-$Days);
$res = @(); 
ForEach ($log in $logs) {
	if($log.instanceid -eq 7001) {
		$type = "Logon"
	} 
	Elseif ($log.instanceid -eq 7002){
		$type="Logoff"
	} 
	Else {
		Continue
	} 
	$res += New-Object PSObject -Property @{
		Time = $log.TimeWritten; 
		"Event" = $type; 
		User = (New-Object System.Security.Principal.SecurityIdentifier $Log.ReplacementStrings[1])
			.Translate([System.Security.Principal.NTAccount])}};
$res

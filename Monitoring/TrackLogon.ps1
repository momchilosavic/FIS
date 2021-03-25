<#
This script provides tacking logon activity on specific server.

Input parameters: 
	1) $Days - Number of past days to get log info (Default value: 1)
	
Output parameters:
	Script returns Name, Time and Event (Login/Logoff)

Author: Momcilo Savic
Date: 24-Mar-2021
#>

param(
	[Int]$Days = 1
	)

$logs = Get-WinEvent -FilterHashTable @{
	LogName='Security';
	Id=4624;
	StartTime=(Get-Date).AddDays(-$Days)} |
	Where { $_.Message | Select-String "Logon Type:\s+7"}
$res = @();
ForEach($log in $logs){
	$message = $log | select -expand message | findstr /c:"Account Name:"
	
	if($prev){
		$span = NEW-TIMESPAN –Start $log.TimeCreated –End $prev.TimeCreated
		if($span.TotalSeconds -gt 1){
			$res += New-Object PSObject -Property @{
				Time = $log.TimeCreated
				User = $message[1] -replace '\s+', ' '
			}
		}
	}
	$prev = $log
}
$res
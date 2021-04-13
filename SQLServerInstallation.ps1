<#
This scripts downloads and/or installs MSSQL Server and SSMS tool

Input Parameters:
	1) $SQLServerSourceUrl - SQLServer download link (Default: link to SQLServer2019)
	2) $SSMSSourceUrl - SSMS download link
	3) $DownloadDirectory - Where to download files
	4) $Domain - Domain of Server Accounts
	5) $Username - Username of Server Accounts
	6) $SAPassword - Password of Server Accounts
	7) $Download - Do you want to download files first
	8) $InstanceName - Name of SQLServer instance

Author: Momcilo Savic
Date: 13-Apr-2021
#>

param(
	[string]
	$SQLServerSourceUrl = "https://go.microsoft.com/fwlink/?linkid=866658",
	
	[String]
	$SSMSSourceUrl = "https://aka.ms/ssmsfullsetup",
	
	[String]
	$DownloadDirectory = "$env:UserProfile\Downloads\SQLServer",
	
	[String]
	$Domain = $env:UserDomain,
	
	[String[]]
	$Usernames = @($env:UserName),
	
	[String]
	$SAPassword = "P1sawrpAssW0rd",
	
	[Switch]
	$Download,
	
	[String]
	$InstanceName = "SQLExpress"
)

if($Download){
	$path = $null;
	ForEach($folder in $DownloadDirectory.split("\")){
		$path += ($folder + "\")
		if(!(Test-Path $path)){
			New-Item -ItemType Directory -Force -Path $path
		}
	}

	try{
		Write-Host "Downloading SQLExpress installer from source: $SQLServerSourceUrl has started"
		Invoke-WebRequest -Uri $SQLServerSourceUrl -OutFile "$DownloadDirectory\SQLServer.exe"
		Write-Host "Downloading installer from source: $SQLServerSourceUrl succeded"
		Write-Host "File saved to: $DownloadDirectory\SQLServer.exe"
	
		Write-Host "Downloading SSMS from source: $SSMSSourceUrl has started"
		Invoke-WebRequest -Uri $SSMSSourceUrl -OutFile "$DownloadDirectory\SSMS.exe"
		Write-Host "Downloading SSMS from source: $SSMSSourceUrl succeded"
		Write-Host "File saved to: $DownloadDirectory\SSMS.exe"
		
		Write-Host "Downloading SQL Server Engine"
		Start-Process -FilePath "$DownloadDirectory\SQLServer.exe" -ArgumentList "/ACTION=download /MediaType=Advanced /MediaPath=$env:UserProfile\SQLSERVER /Quiet" -Wait
		Write-Host "Files saved to: $env:UserProfile\SQLSERVER\"
	}
	catch{
		if(Test-Path "$DownloadDirectory\SQLServer.exe"){
			Remove-Item "$DownloadDirectory\SQLServer.exe")
		}
		if(Test-Path "$DownloadDirectory\SSMS.exe"){
			Remove-Item "$DownloadDirectory\SSMS.exe"
		}
		if(Test-Path "$env:UserProfile\SQLSERVER"){
			Remove-Item "$env:UserProfile\SQLSERVER" -Force -Recurse
		}
		
		Write-Error "Download not succeeded. Removing all downloaded content and terminating script"
		return;
	}
}

$users = $null
ForEach($username in $Usernames){
	$users += "$Domain\$username "
}

try{
	Write-Host "Installing SQL Server"
	Start-Process -FilePath "$env:UserProfile\SQLSERVER\SQLEXPRADV_x64_ENU.exe" -ArgumentList "/ACTION=install /QS /IACCEPTSQLSERVERLICENSETERMS /UpdateEnabled /INDICATEPROGRESS /FEATURES=SQL,AS,IS,Tools /SECURITYMODE=SQL /SAPWD=$SAPassword /INSTANCENAME=$InstanceName /INSTANCEID=($InstanceName.ToUpper()) /SQLSVCACCOUNT=NT Service\MSSQL`$$InstanceName /SQLSVCPASSWORD=$SAPassword /SQLSYSADMINACCOUNTS=$users /AGTSVCACCOUNT=NT AUTHORITY\Network Service /AGTSVCPASSWORD=$SAPassword /ASSVCACCOUNT=$users /ASSVCPASSWORD=$SAPassword /ISSVCAccount=$users /ISSVCPASSWORD=$SAPassword /ASSYSADMINACCOUNTS=$users" -Wait
	Write-Host "SQLServer Installation done"
}
catch{
	Write-Error "SQLExpress installation not succeeded. Terminating script"
	return;
}

try{
	Write-Host "Installing SSMS" 
	Start-Process -FilePath "$DownloadDirectory\SSMS.exe" -ArgumentList "/install /passive /norestart" -Wait
	Write-Host "SSMS Installation done"
}
catch{
	Write-Error "SSMS installation not succeeded. Terminating script"
	return;
}
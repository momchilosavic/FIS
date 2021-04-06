<#
This script represents basic PE Grid Worker Setup.
1) It adds Administrator permissions to specific users
2) It enables Trusted Connection
3) It installs Visual Studio Build Tools

Input parameters: 
	1) $Members - List of groups that need to be grant administrator permissions (Default value: "FNFIS\PROPHET_QA", "FNFIS\PROPHET_SYSDEV")
	2) $TrustedHosts - List of hosts to be added as trusted (Default value: "")
	3) $BuildToolsVersions - List of Visual Studio Build Tool Versions to be installed (Default value: "2017", "2019")
	
	*Passing empty string as value will cause skiping execution of specific part of script
	
Output parameters:
	Script returns state after every line execution

Author: Momcilo Savic
Date: 09-Mar-2021
#>
param([String[]] $Members = @("FNFIS\PROPHET_QA", "FNFIS\PROPHET_SYSDEV"), [String] $TrustedHosts = "", [String[]] $BuildToolsVersions=@("2017", "2019"))

$group = "Administrators"

$path_pre = "\\vwmazprophst15\Software\VisualStudio\VS"
$path_suf = "BuildTools\vs_BuildTools.exe"
$error = 0
$error_msg = ""

"`n====================`nPEGrid Worker Setup started`n====================`n"											# PRINT

<# ADDING MEMBERS TO ADMINISTRATORS GROUP #>
if(-not (($Members.Length -eq 1) -and ($Members[0] -eq ""))){
	"`n`t--------------------Adding users to $group group started--------------------"									# PRINT
	foreach($member in $Members){
		"`n`t`tAdding $member to $group group"																			# PRINT
		Add-LocalGroupMember -Group $group -Member $member
		if(Get-LocalGroupMember -Group $group -Member $member){
			"`n`t`tUser $member successfully added to $group group"														# PRINT
		}
		else{
			$error = 1
		}
	}
	if($error -ne 1){
		"`n`t--------------------Adding users to Administrators group done--------------------`n"						# PRINT
	}
}

<# SETUP WinRM #>
if(-not ($TrustedHosts -eq "")){
	"`n`t--------------------WinRM Setup Started--------------------"											# PRINT
	"`n`t`tAdding $TrustedHosts as trusted host(s)"																# PRINT
	Set-Item WSMan:\localhost\Client\TrustedHosts $TrustedHosts
	Set-Item WSMan:\localhost\Client\AllowUnencrypted true
	Get-Service -Name WinRM | Restart-Service
	gci WSMan:\localhost\Client
	"`n`t--------------------WinRM Setup Done - CHECK IF HOST(S) LISTED !!! --------------------"				# PRINT
}

<# SOFTWARE INSTALL (VS BUILD TOOL) #>	
if(-not (($BuildToolsVersions.Length -eq 1) -and ($BuildToolsVersions[0] -eq ""))){
	"`n`t--------------------Installing software--------------------"												# PRINT
	foreach($version in $BuildToolsVersions){
		"`n`t`tInstalling $path_pre$version$path_suf"								# PRINT
		Start-Process -FilePath $path_pre$version$path_suf	-ArgumentList " --allWorkloads --includeRecommended --add Microsoft.VisualStudio.Workload.VCTools" -Wait # ADD --quite in arguments list for installation in backgdround. ADD update in argument list for update installation.
	}
	"`n`tSoftware installation done`n--------------------`n"						# PRINT
}

"`n====================`nPEGrid Worker Setup done`n====================`n" 		# PRINT
if($error -ne 0){
	"ERROR OCCURED DURING INSTALATION"
}
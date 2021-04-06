<#
This script represents basic PE Grid Web Server Setup.
1) It enables Trusted Connection
2) It imports and binds SSL certificate

Input parameters: 
	1) $TrustedHosts - List of hosts to be added as trusted (Default value: "")
	2) $CertName - Directory where certificate is located (Default value: $env:COMPUTERNAME)
	
	*Passing empty string as value will cause skiping execution of specific part of script
	
Output parameters:
	Script returns state after every line execution

Author: Momcilo Savic
Date: 09-Mar-2021
#>
param([String] $TrustedHosts = "", [String]$CertName = $env:COMPUTERNAME, [String]$CertPassword="3Xnsd87Q")

$CertPath = "\\vwmazprophst15\Admin\Certificates\$CertName.pfx"
$CertPath
<# SETUP WinRM #>
"`n`t--------------------WinRM Setup Started--------------------"
"`n`t`tAdding $TrustedHosts as trusted host(s)"
Set-Item WSMan:\localhost\Client\TrustedHosts $TrustedHosts
Set-Item WSMan:\localhost\Client\AllowUnencrypted true
Get-Service -Name WinRM | Restart-Service
gci WSMan:\localhost\Client
"`n`t--------------------WinRM Setup Done - CHECK IF HOST(S) LISTED !!! --------------------"


<# IMPORT CERTIFICATE #>
"`n`t--------------------Certificate Import Started--------------------"
$SecuredPassword = $CertPassword | ConvertTo-SecureString -AsPlainText -Force
Import-PfxCertificate -FilePath $CertPath -CertStoreLocation Cert:\LocalMachine\Root -Password $SecuredPassword
Import-PfxCertificate -FilePath $CertPath -CertStoreLocation Cert:\LocalMachine\My -Password $SecuredPassword
"`n`t--------------------Certificate Import Done--------------------"

<# BIND CERTIFICATE #>
"`n`t--------------------Certificate Binding Started--------------------"
$hostname = "*"
$iisSite = "Default Web Site"
"Host Name: " + $hostname
"Site Name: " + $iisSite
$cert = Get-ChildItem  -Path Cert:\LocalMachine\MY | Where-Object {$_.Subject -Match "Prophet"} | Select-Object Thumbprint

New-IISSiteBinding -Name $iisSite -BindingInformation "*:443:" -CertificateThumbPrint $cert.Thumbprint -CertStoreLocation "Cert:\LocalMachine\My" -Protocol https
"`n`t--------------------Certificate Binding Done--------------------"

<# SOFTWARE INSTALLATION #>
$path = "\\vwmazprophst15\Software\VisualStudio\"
$versions = @("VC_redist.x64", "VC_redist.x86")
foreach($version in $versions){
	Start-Process -FilePath "$path$version.exe"	-ArgumentList " --add Microsoft.VisualStudio.Workload.VCTools" -Wait # ADD --quite in arguments list for installation in backgdround
}


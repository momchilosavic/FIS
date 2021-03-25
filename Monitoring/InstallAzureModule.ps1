<#
This script installs required Azure Module.

Input parameters: 
	None
	
Output parameters:
	None
	
Author: Momcilo Savic
Date: 25-Mar-2021
#>

Register-PSRepository -Default -Verbose

Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force -AllowClobber

Connect-AzAccount
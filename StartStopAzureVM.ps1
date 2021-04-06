<# 
This script contains functions to log in to Azure and start or stop specified virtual machines.
After logging to passed Subscription, all passed vms will be started or stopped if they belong to passed subscription and resource group.
Resource groups and Resource names are passed as pairs and must have same length.
!!! Function installs Az Module if not existing on computer !!!

Functions:
    1) StartAzureVMs - Logs in to specific Azure subscription and start specified virtual machines.
        Input parameters: 
	        1) $Subscription   (Type: String)   - Azure Subscription name               (Mandatory) (Default: "")
            2) $ResoruceGroups (Type: String[]  - Azure Resource groups name            (Mandatory) (Default: "")
            3) $ResourceNames  (Type: String[]) - Azure Resource (Virtual Machine) name (Mandatory) (Default: "")
        Output parameters:
            1) $remainingResourceGroups (Type: String[]) - List of resource groups that with it's resource pair is not part of specified subscription
            2) $remainingResources      (Type: String[]) - List of resource names that with its's resource group is not part of specified subscription
	
    2) StopAzureVMs - Logs in to specific Azure subscription and stops specified virtual machines.
        Input parameters: 
	        1) $Subscription   (Type: String)   - Azure Subscription name               (Mandatory) (Default: "")
            2) $ResoruceGroups (Type: String[]  - Azure Resource groups name            (Mandatory) (Default: "")
            3) $ResourceNames  (Type: String[]) - Azure Resource (Virtual Machine) name (Mandatory) (Default: "")
        Output parameters:
            1) $remainingResourceGroups (Type: String[]) - List of resource groups that with it's resource pair is not part of specified subscription
            2) $remainingResources      (Type: String[]) - List of resource names that with its's resource group is not part of specified subscription

Author: Momcilo Savic
Date: 06-Apr-2021
#>

# Function to start VMs
function StartAzureVMs
{
    param(
        [Parameter(Mandatory)]
        [String]
        $Subscription,
        [Parameter(Mandatory)]
        [String[]]
        $ResourceGroups,
        [Parameter(Mandatory)]
        [String[]]
        $ResourceNames
    )
    # Install Az Module if not existing
    if (!(Get-Module -ListAvailable -Name Az.Accounts) -or !(Get-Module -ListAvailable -Name Az.Compute)){
        Write-Host "Module Az has to be installed first! Trying to install..."
        Install-Module -Name Az -Repository PSGallery -Force
    }
    # Check if parameters OK
    if(!($ResourceGroups.Count -eq $ResourceNames.Count)){
        Write-Error "ResourceGroups and ResourceNames parameters must have same length"
        return $null
    }

    .{
        $remainingResources = @()
        $remainingResourceGroups = @()
        # Log in to Azure
        Connect-AzAccount -Subscription "$Subscription"
        # Try to start every VM and save unsuccessful VMs
        For($I = 0; $I -lt $ResourceGroups.count; $I++){
            try{
                $res = Start-AzVM -ResourceGroupName $ResourceGroups[$I] -Name $ResourceNames[$I] -NoWait -ErrorAction SilentlyContinue -OutVariable $null
                if($res -eq $null){
                    throw WrongSubscriptionException
                }
            }
            catch{
                $remainingResources += $ResourceNames[$I]
                $remainingResourceGroups += $ResourceGroups[$I]
            }
        }
        # Log out off Azure
        Disconnect-AzAccount -Scope CurrentUser
    } | Out-Null
    # return
    return $remainingResourceGroups, $remainingResources
}

function StopAzureVMs
{
    param(
        [Parameter(Mandatory)]
        [String]
        $Subscription,
        [Parameter(Mandatory)]
        [String[]]
        $ResourceGroups,
        [Parameter(Mandatory)]
        [String[]]
        $ResourceNames
    )
    # Install Az module if not existing
    if (!(Get-Module -ListAvailable -Name Az.Accounts) -or !(Get-Module -ListAvailable -Name Az.Compute)){
        Write-Host "Module Az has to be installed first! Trying to install..."
        Install-Module -Name Az -Repository PSGallery -Force
    }
    # Check if parameters OK
    if(!($ResourceGroups.Count -eq $ResourceNames.Count)){
        Write-Error "ResoruceGroups and ResourceNames parameters must have same length"
        return $null
    }
    .{
        $remainingResources = @()
        $remainingResourceGroups = @()
        # Log in to Azure
        Connect-AzAccount -Subscription "$Subscription"
        # Try to stop every VM and save unsuccessful VMs
        For($I = 0; $I -lt $ResourceGroups.count; $I++){
            try{
                $res = Stop-AzVM -ResourceGroupName $ResourceGroups[$I] -Name $ResourceNames[$I] -NoWait -Force -ErrorAction SilentlyContinue -OutVariable $null
                if($res -eq $null){
                    throw WrongSubscriptionException
                }
            }
            catch{
                $remainingResources += $ResourceNames[$I]
                $remainingResourceGroups += $ResourceGroups[$I]
            }
        }
        # Log out of Azure
        Disconnect-AzAccount -Scope CurrentUser
    } | Out-Null
    # return
    return $remainingResourceGroups, $remainingResources
}
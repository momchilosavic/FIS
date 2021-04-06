<# 
This script contains functions to log in to Azure and start or stop specified virtual machines.
After logging to passed Subscription, all passed vms will be started or stopped if they belong to passed subscription and resource group.
Resource groups and Resource names are passed as pairs and must have same length.
!!! Any function call installs Az Module if not existing on computer !!!

Functions:
    1) StartAzureVMs - Logs in to specific Azure subscription and start specified virtual machines.
        Input parameters: 
	        1) $Subscription    (Type: String)   - Azure Subscription name                                 (Mandatory)
            2) $ResoruceGroups  (Type: String[]) - Azure Resource groups name                              (Mandatory)
            3) $ResourceNames   (Type: String[]) - Azure Resource (Virtual Machine) name                   (Mandatory)
            4) $WaitForResponse (Type: Boolean)  - If true, you will be notified when all machines started (Default: false)
        Output parameters:
            1) $remainingResourceGroups (Type: String[]) - List of resource groups that with it's resource pair is not part of specified subscription
            2) $remainingResources      (Type: String[]) - List of resource names that with its's resource group is not part of specified subscription
	
    2) StopAzureVMs - Logs in to specific Azure subscription and stops specified virtual machines.
        Input parameters: 
	        1) $Subscription    (Type: String)   - Azure Subscription name                                 (Mandatory)
            2) $ResoruceGroups  (Type: String[]) - Azure Resource groups name                              (Mandatory)
            3) $ResourceNames   (Type: String[]) - Azure Resource (Virtual Machine) name                   (Mandatory)
            4) $WaitForResponse (Type: Boolean)  - If true, you will be notified when all machines started (Default: false)
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
        $ResourceNames,
        [Parameter(HelpMessage='Turn on if you want to get notifyied when all machines are running')]
        [Boolean]
        $WaitForResponse = $false
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
        if($WaitForResponse -and ($ResourceNames.Count -gt $remainingResources.Count)){
            # Wait until all machines running
            Write-Host("`t->Waiting for all machines to start")
            $successfulResources = $ResourceNames | Where {$remainingResources -notcontains $_}
            $successfulResourceGroups = $ResourceGroups | Where {$remainingResourceGroups -notcontains $_}
            for($I = 0; $I -lt $succesfulResources.count; $I++){
                while(((Get-AzVM -Name $successfulResources[$I] -ResourceGroupName $successfulResourceGroups[$I] -Status).Statuses | Where Code -Like 'PowerState/*')[0].DisplayStatus -ne "VM running"){
                # empty loop wait for machine to start running
                }
            }
            Write-Host("`t->All machines are running and safe to use")
        }
        # Log out of Azure
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
        $ResourceNames,
        [Parameter(HelpMessage='Turn on if you want to get notifyied when all machines are running')]
        [Boolean]
        $WaitForResponse = $false
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
        if($WaitForResponse -and ($ResourceNames.Count -gt $remainingResources.Count)){
            # Wait until all machines stopped
            Write-Host("`t->Waiting for all machines to stop")
            $successfulResources = $ResourceNames | Where {$remainingResources -notcontains $_}
            $successfulResourceGroups = $ResourceGroups | Where {$remainingResourceGroups -notcontains $_}
            for($I = 0; $I -lt $successfulResources.count; $I++){
                while(((Get-AzVM -Name $successfulResources[$I] -ResourceGroupName $successfulResourceGroups[$I] -Status).Statuses | Where Code -Like 'PowerState/*')[0].DisplayStatus -ne "VM deallocated"){
                # empty loop
                }
            }
            Write-Host("`t->All machines are deallocated and will not be charged")
        }
        # Log out of Azure
        Disconnect-AzAccount -Scope CurrentUser
    } | Out-Null
    # return
    return $remainingResourceGroups, $remainingResources
}
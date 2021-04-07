<# 
This script contains functions to log in to Azure and start or stop specified virtual machines.
After logging to passed Subscription, all passed vms will be started or stopped if they belong to passed subscription and resource group.
Resource groups and Resource names are passed as pairs and must have same length.
!!! Any function call installs Az Module if not existing on computer !!!

Functions:
    1) StartAzureVMs - Logs in to specific Azure subscription and start specified virtual machines.
        Input parameters: 
	        1) $Subscription    (Type: String)       - Azure Subscription name                                 (Mandatory)
            2) $ResoruceGroups  (Type: String[])     - Azure Resource groups name                              (Mandatory)
            3) $ResourceNames   (Type: String[])     - Azure Resource (Virtual Machine) name                   (Mandatory)
            4) $WaitForResponse (Type: Boolean)      - If true, you will be notified when all machines started (Default: false)
            5) $PromptLogin     (Type: Boolean)      - If true you will be asked for credentials               (Default: true)
            6) $Credentials     (Type: PSCredential) - Object containing credentials for log in                
            7) $Tenant          (Type: String)       - Azure tenant ID
        Output parameters:
            1) $statuses                (Type: PSObject[]) - List of objects containing status of machines before starting
            2) $remainingResourceGroups (Type: String[])   - List of resource groups that with it's resource pair is not part of specified subscription
            3) $remainingResources      (Type: String[])   - List of resource names that with its's resource group is not part of specified subscription
	
    2) StopAzureVMs - Logs in to specific Azure subscription and stops specified virtual machines.
        Input parameters: 
	        1) $Subscription    (Type: String)       - Azure Subscription name                                 (Mandatory)
            2) $ResoruceGroups  (Type: String[])     - Azure Resource groups name                              (Mandatory)
            3) $ResourceNames   (Type: String[])     - Azure Resource (Virtual Machine) name                   (Mandatory)
            4) $WaitForResponse (Type: Boolean)      - If true, you will be notified when all machines stopped (Default: false)
            5) $PromptLogin     (Type: Boolean)      - If true you will be asked for credentials               (Default: true)
            6) $Credentials     (Type: PSCredential) - Object containing credentials for log in                
            7) $Tenant          (Type: String)       - Azure tenant ID
        Output parameters:
            1) $statuses                (Type: PSObject[]) - List of objects containing status of machines before deallocating
            2) $remainingResourceGroups (Type: String[])   - List of resource groups that with it's resource pair is not part of specified subscription
            3) $remainingResources      (Type: String[])   - List of resource names that with its's resource group is not part of specified subscription

Author: Momcilo Savic
Date: 06-Apr-2021
#>

<#
Credentials example:
    $Username = "xxx@xxxx.onmicrosoft.com"
    $Password = ConvertTo-SecureString -String "<Password>" -AsPlainText -Force
    $Tenant = "<tenant id>"
    $Subscription = "<subscription id>"
    $Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $Username,$Password
    Connect-AzAccount -Credential $Credentials -Tenant $Tenant -Subscription $Subscription
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

        [Parameter(HelpMessage='Turn on if you want to get notified when all machines are done')]
        [Boolean]
        $WaitForResponse = $false,

        [Boolean]
        $PromptLogin = $True,

        [System.Management.Automation.PSCredential]
        $Credentials,

        [String]
        $Tenant
    )
   
    # Check if parameters OK
    if(!($ResourceGroups.Count -eq $ResourceNames.Count)){
        Write-Error "ResourceGroups and ResourceNames parameters must have same length"
        return $null
    }
    if(!$PromptLogin -and (($Tenant -eq $null) -or ($Credentials -eq $null))){
        Write-Error "If PromptLogin is True then Tenant and Credentials parameters must not be null - $Tenant $Credentials" 
        return $null
    }

    # Install Az Module if not existing
    if (!(Get-Module -ListAvailable -Name Az.Accounts) -or !(Get-Module -ListAvailable -Name Az.Compute)){
        Write-Host "Module Az has to be installed first! Trying to install..."
        Install-Module -Name Az -Repository PSGallery -Force
    }

    .{
        $remainingResources = @()
        $remainingResourceGroups = @()
        $statuses = @()
        # Log in to Azure
        if($PromptLogin){
            Connect-AzAccount -Subscription "$Subscription"
        }
        else{
            Connect-AzAccount -Credential $Credentials -Tenant $Tenant -Subscription $Subscription -ServicePrincipal
        }
        # Try to start every VM and save unsuccessful requests
        For($I = 0; $I -lt $ResourceGroups.count; $I++){
            if($ResourceGroups.count -gt 0){
                Write-Progress -Id 1 -Activity "Sending requests to start machines" -Status "Completed machines: $($I + 1) of $($ResourceGroups.count)" -PercentComplete (($I + 1) / $ResourceGroups.count * 100);
            }
            try{
                $status = ((Get-AzVM -Name $ResourceNames[$I] -ResourceGroupName $ResourceGroups[$I] -Status).Statuses | Where Code -Like 'PowerState/*')[0].DisplayStatus
                if(($status -eq $null) -or ($status -eq "")){
                    throw WrongSubscriptionException
                }
                if($status -ne "VM running"){
                    Start-AzVM -ResourceGroupName $ResourceGroups[$I] -Name $ResourceNames[$I] -NoWait -ErrorAction SilentlyContinue -OutVariable $null
                    $statuses += Select-Object -InputObject "" @{
                            name = "ResourceName";
                            Expression = {
                                $ResourceNames[$I]
                            }
                        },
                        @{
                            name = "ResourceGroup";
                            Expression = {
                                $ResourceGroups[$I]
                            }
                        },
                        @{
                            name = "Subscription";
                            Expression = {
                                $Subscription
                            }
                        },
                        @{
                            name = "status";
                            Expression = {
                                $status
                            }
                        }
                }
            }
            catch{
                $remainingResources += $ResourceNames[$I]
                $remainingResourceGroups += $ResourceGroups[$I]
            }
        }
        if($ResourceGroups.count -gt 0){
            Write-Progress -Id 1 -Activity "Sending requests to start machines" -Status "Completed machines: $($I + 1) of $($ResourceGroups.count)" -PercentComplete 100 -Completed
        }
        if($WaitForResponse -and ($ResourceNames.Count -gt $remainingResources.Count)){
            # Wait until all machines running
            Write-Host("`t->Waiting for all machines to start")
            $successfulResources = $ResourceNames | Where {$remainingResources -notcontains $_}
            $successfulResourceGroups = $ResourceGroups | Where {$remainingResourceGroups -notcontains $_}
            for($I = 0; $I -lt $succesfulResources.count; $I++){
                if($succesfulResources.count -gt 0){ 
                    Write-Progress -Id 2 -Activity "Waiting for machines to be in running state" -Status "Running machines: $($I + 1) of $($succesfulResources.count)" -PercentComplete (($I + 1) / $succesfulResources.count * 100)
                }
                while(((Get-AzVM -Name $successfulResources[$I] -ResourceGroupName $successfulResourceGroups[$I] -Status).Statuses | Where Code -Like 'PowerState/*')[0].DisplayStatus -ne "VM running"){
                # empty loop wait for machine to start running
                }
            }
            if($succesfulResources.count -gt 0){ 
                Write-Progress -Id 2 -Activity "Waiting for machines to be in running state" -Status "Running machines: $($I + 1) of $($succesfulResources.count)" -PercentComplete 100 -Completed
            }
            Write-Host("`t->All machines are running and safe to use")
        }
        # Log out of Azure
        Disconnect-AzAccount -Scope CurrentUser
    } | Out-Null
    # return
    return $statuses, $remainingResourceGroups, $remainingResources
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
        $WaitForResponse = $false,

        [Boolean]
        $PromptLogin = $True,

        [System.Management.Automation.PSCredential]
        $Credentials,

        [String]
        $Tenant
    )
    
    # Check if parameters OK
    if(!($ResourceGroups.Count -eq $ResourceNames.Count)){
        Write-Error "ResourceGroups and ResourceNames parameters must have same length"
        return $null
    }
    if(!$PromptLogin -and (($Tenant -eq $null) -or ($Credentials -eq $null))){
        Write-Error "If PromptLogin is True then Tenant and Credentials parameters must not be null - $Tenant $Credentials" 
        return $null
    }

    # Install Az Module if not existing
    if (!(Get-Module -ListAvailable -Name Az.Accounts) -or !(Get-Module -ListAvailable -Name Az.Compute)){
        Write-Host "Module Az has to be installed first! Trying to install..."
        Install-Module -Name Az -Repository PSGallery -Force
    }

    .{
        $remainingResources = @()
        $remainingResourceGroups = @()
        # Log in to Azure
        if($PromptLogin){
            Connect-AzAccount -Subscription "$Subscription"
        }
        else{
            Connect-AzAccount -Credential $Credentials -Tenant $Tenant -Subscription $Subscription
        }
        # Try to stop every VM and save unsuccessful VMs
        For($I = 0; $I -lt $ResourceGroups.count; $I++){
            if($ResourceGroups.count -gt 0){
                Write-Progress -Id 1 -Activity "Sending requests to deallocate machines" -Status "Completed requests: $($I + 1) of $($ResourceGroups.count)" -PercentComplete (($I + 1) / $ResourceGroups.count * 100);
            }
            try{
                $status = ((Get-AzVM -Name $ResourceNames[$I] -ResourceGroupName $ResourceGroups[$I] -Status).Statuses | Where Code -Like 'PowerState/*')[0].DisplayStatus
                if(($status -eq $null) -or ($status -eq "")){
                    throw WrongSubscriptionException
                }
                if($status -ne "VM deallocated"){
                    Stop-AzVM -ResourceGroupName $ResourceGroups[$I] -Name $ResourceNames[$I] -NoWait -Force -ErrorAction SilentlyContinue -OutVariable $null
                    $statuses += Select-Object -InputObject "" @{
                            name = "ResourceName";
                            Expression = {
                                $ResourceNames[$I]
                            }
                        },
                        @{
                            name = "ResourceGroup";
                            Expression = {
                                $ResourceGroups[$I]
                            }
                        },
                        @{
                            name = "Subscription";
                            Expression = {
                                $Subscription
                            }
                        },
                        @{
                            name = "status";
                            Expression = {
                                $status
                            }
                        }
                }
            }
            catch{
                $remainingResources += $ResourceNames[$I]
                $remainingResourceGroups += $ResourceGroups[$I]
            }
        }
        if($ResourceGroups.count -gt 0){ 
            Write-Progress -Id 1 -Activity "Sending requests to deallocate machines" -Status "Completed requests: $($I + 1) of $($ResourceGroups.count)" -PercentComplete 100 -Completed
        }
        if($WaitForResponse -and ($ResourceNames.Count -gt $remainingResources.Count)){
            # Wait until all machines stopped
            Write-Host("`t->Waiting for all machines to stop")
            $successfulResources = $ResourceNames | Where {$remainingResources -notcontains $_}
            $successfulResourceGroups = $ResourceGroups | Where {$remainingResourceGroups -notcontains $_}
            for($I = 0; $I -lt $successfulResources.count; $I++){
                if($succesfulResources.count -gt 0){ 
                    Write-Progress -Id 2 -Activity "Waiting for machines" -Status "Complete: $($I + 1) of $($succesfulResources.count)" -PercentComplete (($I + 1) / $succesfulResources.count * 100)
                }
                while(((Get-AzVM -Name $successfulResources[$I] -ResourceGroupName $successfulResourceGroups[$I] -Status).Statuses | Where Code -Like 'PowerState/*')[0].DisplayStatus -ne "VM deallocated"){
                # empty loop
                } 
            }  
            if($succesfulResources.count -gt 0){ 
                Write-Progress -Id 2 -Activity "Waiting for machines" -Status "Complete: $($I + 1) of $($succesfulResources.count)" -PercentComplete 100 -Completed
            } 
            Write-Host("`t->All machines are deallocated and will not be charged")
        }
        # Log out of Azure
        Disconnect-AzAccount -Scope CurrentUser
    } | Out-Null
    # return
    return $statuses, $remainingResourceGroups, $remainingResources
}
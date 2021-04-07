<#
!!! StartStopAzureVM.ps1 SCRIPT IS NECCESSARY FOR EXECUTION OF THIS SCRIPT !!!

This script allows you to read table from excel table, extract VM name and VM resource group from the table and try to start or stop them all.
After converting data from excel table, using passed subscriptions, script will try to start or stop all VMs contained inside excel table.
!!! Any script call installs ImportExcel Module if not existing on computer !!!

Input parameters:
    1) $ScriptPath          (Type: String)   - Path to StartStopAzureVM.ps1 script               (Mandatory)
    2) $InputFilePath       (Type: String)   - Path to Excel file containing all neccessary data (Mandatory)
    3) $NameColumn          (Type: String)   - Name of column containing VM names                (Default: "Server")
    4) $ResourceGroupColumn (Type: String)   - Name of column containing VM's resource group     (Default: "Owner/Application validation contacts:")
    5) $Subscriptions       (Type: String[]) - Names of subscriptions to log in                  (Mandatory)
    6) $Operation           (Type: String)   - Operation to be performed on VM                   (Default: 'on')
    7) $GetNotified         (Type: Boolean)  - Get notified when action over all machines done   (Default: 'false')

Example:
    &.\StartMachines.ps1 -ScriptPath "C:\Users\e5639065\OneDrive - FIS\Documents\StartStopAzureVM.ps1" -InputFilePath "C:\Users\e5639065\OneDrive - FIS\Desktop\test.xlsx" -Subscriptions @("FIS Global - CIO - Dev - North America 1", "FIS Global CIO Dev North America 2") -Operation "on"

Author: Momcilo Savic
Date: 06-Apr-2021
#>
param(
    [Parameter(Mandatory, HelpMessage='Path to StartStopAzureVM.ps1 file')]
    [String]
    $ScriptPath,

    [Parameter(Mandatory, HelpMessage='Path to input Excel file')]
    [String]
    $InputFilePath,

    [Parameter(HelpMessage='Name of column containing VM name')]
    [String]
    $NameColumn = "Server",

    [Parameter(HelpMessage='Name of column containing VM resource group')]
    [String]
    $ResourceGroupColumn = "Owner/Application validation contacts:",

    [Parameter(Mandatory, HelpMessage='Path to output Excel file')]
    [String]
    $OutputFilePath,

    [Parameter(Mandatory)]
    [String[]]
    $Subscriptions,

    [Parameter(Mandatory, HelpMessage='Do you want to turn VMs on or off?[on/off](Default: on)')]
    [String]
    $Operation = 'on',

    [Parameter(HelpMessage='Get notified when actions over all machines are done')]
    [Boolean]
    $GetNotified = 'false'
)

if(!($Operation -eq 'off')){
    $Operation = 'on'
}

. $ScriptPath

if (!(Get-Module -ListAvailable -Name ImportExcel)){
    Write-Host "Module ImportExcel has to be installed first!"
    Install-Module -Name ImportExcel -Force
}

$table = Import-Excel $InputFilePath

$servers = @()
$resourceGroups = @()
$statuses = @()
foreach($row in $table){
    $servers += $row.$NameColumn
    $resourceGroups += $row.$ResourceGroupColumn  
}

foreach($subscription in $Subscriptions){
    $cnt = $servers.count
    Write-Host "Subscription: $subscription"
    if($Operation -eq 'on'){
        $statusesForThisSub, $resourceGroups, $servers = StartAzureVMs -Subscription $subscription -ResourceGroups $resourceGroups -ResourceNames $servers -WaitForResponse $GetNotified
    }
    else{
        $statusesForThisSub, $resourceGroups, $servers = StopAzureVMs -Subscription $subscription -ResourceGroups $resourceGroups -ResourceNames $servers -WaitForResponse $GetNotified
    }

    Write-Host "`t" ($cnt - $servers.count) " vms $Operation"
    Write-Host "`t" $servers.count " vms not part of this subscription" 

    $statuses += $statusesForThisSub
}

$statuses | Export-Excel -Path $OutputFilePath
#=====================================================================================================================================
#
# NAME: Start Azure VM via Webhook
#
# AUTHOR: Florent APPOINTAIRE
# DATE: 02/11/2015
# VERSION: 1.0
#
# COMMENT: The purpose of this script is to call an Azure Automation runbook via the webhook of the script to start a VM on Azure
# USING : Before starting using this script, make sur to have the Connect-AzureSubscription.ps1 script installed and configured
#         Configure the webhook of this runbook to start using it
#
#=====================================================================================================================================

param ( 
    [object]$WebhookData,
    [string]$AzureSubscriptionName="Use *Default Azure Subscription* Variable Value"
)


if ($WebhookData -ne $null) {   
	
    #Get the value that contains the VM Name
	$azureVMName = $WebhookData.RequestBody
    if ($azureVMName -eq $null) { throw "WebHook request has an empty body. Aborting" }

    # Ensures you do not inherit an AzureRMContext in your runbook
    Disable-AzureRmContextAutosave –Scope Process
 
    $connection = Get-AutomationConnection -Name AzureRunAsConnection
    $account = Connect-AzureRmAccount -ServicePrincipal -Tenant $connection.TenantID `
    -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint
	if($AzureSubscriptionName -eq "Use *Default Azure Subscription* Variable Value")
    {
        $AzureSubscriptionName = Get-AutomationVariable -Name "Default Azure Subscription"
        if($AzureSubscriptionName.length -gt 0)
        {
            Write-Output "Specified subscription name/ID: [$AzureSubscriptionName]"
        }
        else
        {
            throw "No subscription name was specified, and no variable asset with name 'Default Azure Subscription' was found. Either specify an Azure subscription name or define the default using a variable setting"
        }
    }

    # Validate subscription
    $subscriptions = @(Get-AzureRmSubscription | where {$_.SubscriptionName -eq $AzureSubscriptionName -or $_.SubscriptionId -eq $AzureSubscriptionName})
    if($subscriptions.Count -eq 1)
    {
        # Set working subscription
        $targetSubscription = $subscriptions | select -First 1
        $targetSubscription | Select-AzureRmSubscription

        # Connect via Azure Resource Manager 
        #$resourceManagerContext = Add-AzureRmAccount -Credential $azureCredential -SubscriptionId $targetSubscription.SubscriptionId 
        #$resourceManagerContext = Add-AzureRmAccount -SubscriptionId $targetSubscription.SubscriptionId 
        
        Write-Output "Working against subscription: $($targetSubscription.SubscriptionName) ($($targetSubscription.SubscriptionId))"
    }
    else
    {
        if($subscription.Count -eq 0)
        {
            throw "No accessible subscription found with name or ID [$AzureSubscriptionName]. Check the runbook parameters and ensure user is a co-administrator on the target subscription."
        }
        elseif($subscriptions.Count -gt 1)
        {
            throw "More than one accessible subscription found with name or ID [$AzureSubscriptionName]. Please ensure your subscription names are unique, or specify the ID instead"
        }
    }


    #Get the VM information based on the VM Name
	#$azureVM = Get-AzureVM |? {$_.name -like $azureVMName }
    
    $azureVM = Get-AzureRmResource | where {($_.ResourceType -like "Microsoft.*/virtualMachines") -and ($_.name -like $azureVMName)}
    $azureVM2 = Get-AzureRmVM -resourcegroup $azureVM.ResourceGroupName -Name $azureVM.name -status
    if ($azureVM2 -ne $null) {
        $vmStatus = ((($azureVM2 |select -expandproperty Statuses) |? {$_.code -like "PowerState*"} |select -expandproperty code) -split '/')[1]
        Write-Output "VM is currently $vmStatus"
        Write-Output "-----------------------"
        if ($vmStatus -ne "Running") {
            Write-Output "Starting VM"
            $azureVM2 |Start-AzureRmVM
        } else {
            Write-Output "VM Already running"
        }
        
    } else { 
        write-error "No VM found with name $azureVMName" 
        throw "No VM found with name $azureVMName"
    }
} else {
	
    Write-Error "Runbook meant to be started only from webhook." 	
} 
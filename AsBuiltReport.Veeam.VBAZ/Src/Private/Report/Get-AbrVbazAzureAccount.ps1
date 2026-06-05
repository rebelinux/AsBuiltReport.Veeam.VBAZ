function Get-AbrVbazAzureAccount {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Azure Service Accounts sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the Azure service accounts connected to the VBAZ appliance using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/acgdickie/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Infrastructure.Accounts -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazAzureAccount

    Section -Style Heading3 $LocalizedData.Heading {
        Add-AbrVbazTable -Name 'Azure Service Accounts' -InputObject (@($script:AbrVbazInventory.AzureServiceAccounts) | ForEach-Object {
            [pscustomobject][ordered]@{
                Name = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name 'name')
                Region = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name 'region')
                'Tenant ID' = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name 'tenantId')
                'Cloud State' = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name 'cloudState')
                'Azure Permissions State' = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name 'azurePermissionsState')
                'Used for Workers' = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name 'selectedForWorkermanagement')
                'Subscription for Worker Deployment' = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name 'subscriptionIdForWorkerDeployment')
            }
        })
    }
}

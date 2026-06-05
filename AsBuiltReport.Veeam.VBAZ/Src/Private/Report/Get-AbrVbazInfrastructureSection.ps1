function Get-AbrVbazInfrastructureSection {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Cloud Infrastructure section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Orchestrates the accounts, subscriptions, repositories, workers and discovery sub-sections using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/acgdickie/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Infrastructure.PSObject.Properties.Value -eq 0) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazInfrastructureSection

    Section -Style Heading2 $LocalizedData.Heading {
        Paragraph $LocalizedData.Paragraph
        BlankLine

        $Summary = @(
            New-AbrVbazCountObject -Name 'Azure Service Accounts' -Items $script:AbrVbazInventory.AzureServiceAccounts
            New-AbrVbazCountObject -Name 'Standard Accounts' -Items $script:AbrVbazInventory.StandardAccounts
            New-AbrVbazCountObject -Name 'Tenants' -Items $script:AbrVbazInventory.Tenants
            New-AbrVbazCountObject -Name 'Subscriptions' -Items $script:AbrVbazInventory.Subscriptions
            New-AbrVbazCountObject -Name 'Resource Groups' -Items @($script:AbrVbazInventory.ResourceGroups)
            New-AbrVbazCountObject -Name 'Repositories' -Items $script:AbrVbazInventory.Repositories
            New-AbrVbazCountObject -Name 'Workers' -Items $script:AbrVbazInventory.Workers
        )
        Add-AbrVbazTable -Name 'Cloud Infrastructure Summary' -InputObject $Summary
        $Chart = New-AbrVbazCountChart -Title 'Cloud Infrastructure Objects' -CountObjects $Summary
        if ($Chart) {
            Image -Text 'Cloud Infrastructure Chart' -Align Center -Percent 100 -Base64 $Chart
        }

        Get-AbrVbazTenant
        Get-AbrVbazSubscription
        Get-AbrVbazAzureAccount
        Get-AbrVbazStandardAccount
        Get-AbrVbazResourceGroup
        Get-AbrVbazRepository
        Get-AbrVbazWorker
        Get-AbrVbazDiscovery
    }
}

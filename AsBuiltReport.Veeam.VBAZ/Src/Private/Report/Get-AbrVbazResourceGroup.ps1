function Get-AbrVbazResourceGroup {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Resource Groups sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the Azure resource groups discovered by the VBAZ appliance, grouped by subscription, using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/acgdickie/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if (-not ($InfoLevel.Infrastructure.Subscriptions -ge 3 -or $InfoLevel.Infrastructure.Regions -ge 3)) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazResourceGroup
    $ResourceGroups = @($script:AbrVbazInventory.ResourceGroups)

    Section -Style Heading3 $LocalizedData.Heading {
        Paragraph $LocalizedData.Paragraph
        Add-AbrVbazTable -Name 'Resource Group Summary by Subscription' -InputObject (New-AbrVbazResourceGroupSubscriptionSummary -Items $ResourceGroups)
        if ($InfoLevel.Infrastructure.Subscriptions -ge 3) {
            Add-AbrVbazTable -Name 'Resource Groups' -InputObject ($ResourceGroups | ForEach-Object {
                [pscustomobject][ordered]@{
                    Name = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name 'name')
                    Subscription = ConvertTo-AbrVbazDisplayValue -InputObject (Resolve-AbrVbazSubscriptionName -SubscriptionId ([string](Get-AbrVbazPropertyValue -InputObject $_ -Name @('subscriptionName', 'subscriptionId'))))
                    State = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name 'state')
                }
            })
        }
    }
}

function Get-AbrVbazSubscription {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Subscriptions sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the Azure subscriptions connected to the VBAZ appliance using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/acgdickie/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Infrastructure.Subscriptions -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazSubscription

    Section -Style Heading3 $LocalizedData.Heading {
        Add-AbrVbazTable -Name 'Subscriptions' -InputObject (@($script:AbrVbazInventory.Subscriptions) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'id', 'tenantId', 'environment', 'status') })
    }
}

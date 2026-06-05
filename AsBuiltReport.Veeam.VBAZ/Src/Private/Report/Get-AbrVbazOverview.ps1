function Get-AbrVbazOverview {
    <#
    .SYNOPSIS
        Used by As Built Report to render the operational Overview sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the dashboard statistics, protected workloads, storage usage, top policies and bottlenecks using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/acgdickie/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Operations.Overview -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazOverview

    Section -Style Heading3 $LocalizedData.Heading {
        Add-AbrVbazTable -Name 'Overview Statistics' -InputObject (ConvertTo-AbrVbazOverviewStatisticsRows -Items $script:AbrVbazInventory.OverviewStatistics) -List
        if ($InfoLevel.Operations.Overview -ge 2) {
            Add-AbrVbazTable -Name 'Protected Workloads Overview' -InputObject (@($script:AbrVbazInventory.OverviewProtectedWorkloads) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('type', 'name', 'count', 'protected', 'unprotected') })
            Paragraph $LocalizedData.StorageUsageParagraph
            Add-AbrVbazTable -Name 'Storage Usage Overview' -InputObject (ConvertTo-AbrVbazStorageUsageRows -Items $script:AbrVbazInventory.OverviewStorageUsage)
            Add-AbrVbazTable -Name 'Top Policies Duration' -InputObject (@($script:AbrVbazInventory.OverviewTopPoliciesDuration) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('policyName', 'duration', 'lastRun', 'workloadType') })
            Add-AbrVbazTable -Name 'Bottlenecks Overview' -InputObject (@($script:AbrVbazInventory.OverviewBottlenecks) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'type', 'count', 'duration', 'percentage') })
        }
    }
}

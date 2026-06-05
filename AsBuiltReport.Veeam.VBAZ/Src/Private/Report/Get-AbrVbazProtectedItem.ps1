function Get-AbrVbazProtectedItem {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Protected Items sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the protected workloads (VMs, SQL databases, file shares, Cosmos DB and virtual networks) using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Protection.ProtectedItems -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazProtectedItem

    Section -Style Heading3 $LocalizedData.Heading {
        $ProtectedSummary = @(
            New-AbrVbazCountObject -Name 'Virtual Machines' -Items $script:AbrVbazInventory.ProtectedVirtualMachines
            New-AbrVbazCountObject -Name 'SQL Databases' -Items $script:AbrVbazInventory.ProtectedDatabases
            New-AbrVbazCountObject -Name 'File Shares' -Items $script:AbrVbazInventory.ProtectedFileShares
            New-AbrVbazCountObject -Name 'Cosmos DB Accounts' -Items $script:AbrVbazInventory.ProtectedCosmosDbAccounts
            New-AbrVbazCountObject -Name 'Virtual Networks' -Items $script:AbrVbazInventory.ProtectedVnet
        )
        Add-AbrVbazTable -Name 'Protected Workload Summary' -InputObject $ProtectedSummary
        $Chart = New-AbrVbazCountChart -Title 'Protected Workloads' -CountObjects $ProtectedSummary
        if ($Chart) {
            Image -Text 'Protected Workload Chart' -Align Center -Percent 100 -Base64 $Chart
        }
        if ($InfoLevel.Protection.ProtectedItems -ge 2) {
            Add-AbrVbazTable -Name 'Protected Virtual Machines' -InputObject (@($script:AbrVbazInventory.ProtectedVirtualMachines) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'osType', 'regionName', 'subscription', 'resourceGroup', 'vmSize', 'totalSizeInGB', 'lastBackup') })
            Add-AbrVbazTable -Name 'Protected SQL Databases' -InputObject (@($script:AbrVbazInventory.ProtectedDatabases) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'sqlServer', 'region', 'subscription', 'resourceGroup', 'sizeInMb', 'lastBackup') })
            Add-AbrVbazTable -Name 'Protected File Shares' -InputObject (@($script:AbrVbazInventory.ProtectedFileShares) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'storageAccount', 'region', 'subscription', 'resourceGroup', 'lastBackup') })
            if (@($script:AbrVbazInventory.ProtectedCosmosDbAccounts).Count -gt 0) {
                Add-AbrVbazTable -Name 'Protected Cosmos DB Accounts' -InputObject (@($script:AbrVbazInventory.ProtectedCosmosDbAccounts) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'region', 'subscription', 'resourceGroup', 'lastBackup') })
            }
            if (@($script:AbrVbazInventory.ProtectedVnet).Count -gt 0) {
                Add-AbrVbazTable -Name 'Protected Virtual Networks' -InputObject (@($script:AbrVbazInventory.ProtectedVnet) | ForEach-Object {
                    $LastBackup = Get-AbrVbazPropertyValue -InputObject $_ -Name @('lastBackup', 'lastBackupTime')
                    $Row = [ordered]@{
                        Name = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name @('name', 'virtualNetworkName'))
                        Subscription = ConvertTo-AbrVbazDisplayValue -InputObject (Resolve-AbrVbazSubscriptionName -SubscriptionId ([string](Get-AbrVbazPropertyValue -InputObject $_ -Name @('subscriptionName', 'subscriptionId'))))
                        Region = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name @('regionName', 'region'))
                    }
                    $Row["Last Backup Time ($(Get-AbrVbazDateTimeZoneLabel -Name 'lastBackup' -Value $LastBackup))"] = ConvertTo-AbrVbazDateTimeDisplayValue -InputObject $LastBackup
                    [pscustomobject]$Row
                })
            }
        }
    }
}

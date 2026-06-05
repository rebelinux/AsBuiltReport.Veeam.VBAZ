function Get-AbrVbazDiscovery {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Azure Discovery Inventory sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the counts of Azure resources discovered by the VBAZ appliance using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Infrastructure.Discovery -lt 3) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazDiscovery

    Section -Style Heading3 $LocalizedData.Heading {
        $Discovery = @(
            New-AbrVbazCountObject -Name 'Virtual Machines' -Items $script:AbrVbazInventory.VirtualMachines
            New-AbrVbazCountObject -Name 'Databases' -Items $script:AbrVbazInventory.Databases
            New-AbrVbazCountObject -Name 'File Shares' -Items $script:AbrVbazInventory.FileShares
            New-AbrVbazCountObject -Name 'Cosmos DB Accounts' -Items $script:AbrVbazInventory.CosmosDbAccounts
            New-AbrVbazCountObject -Name 'Storage Accounts' -Items $script:AbrVbazInventory.StorageAccounts
            New-AbrVbazCountObject -Name 'Virtual Networks' -Items $script:AbrVbazInventory.VirtualNetworks
            New-AbrVbazCountObject -Name 'Network Security Groups' -Items $script:AbrVbazInventory.NetworkSecurityGroups
            New-AbrVbazCountObject -Name 'Key Vaults' -Items $script:AbrVbazInventory.KeyVaults
            New-AbrVbazCountObject -Name 'SQL Servers' -Items $script:AbrVbazInventory.SqlServers
            New-AbrVbazCountObject -Name 'SQL Elastic Pools' -Items $script:AbrVbazInventory.SqlElasticPools
            New-AbrVbazCountObject -Name 'Availability Sets' -Items $script:AbrVbazInventory.AvailabilitySets
            New-AbrVbazCountObject -Name 'Availability Zones' -Items $script:AbrVbazInventory.AvailabilityZones
            New-AbrVbazCountObject -Name 'Resource Tags' -Items $script:AbrVbazInventory.Tags
        )
        Add-AbrVbazTable -Name 'Discovery Inventory Counts' -InputObject $Discovery
    }
}

function Get-AbrVbazRepository {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Repositories sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the backup repositories and Veeam vaults registered on the VBAZ appliance using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Infrastructure.Repositories -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazRepository

    Section -Style Heading3 $LocalizedData.Heading {
        $RepositorySummary = @($script:AbrVbazInventory.Repositories) | ForEach-Object {
            ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'repositoryType', 'status', 'storageTier', 'regionName', 'immutabilityEnabled')
        }
        if ($HealthCheck.Infrastructure.Repositories) {
            $RepositorySummary | Where-Object { $_.Status -match 'Failed|Unavailable|Error' -or $_.State -match 'Failed|Unavailable|Error' } | Set-Style -Style Critical -Property Status, State
        }
        Add-AbrVbazTable -Name 'Repositories' -InputObject $RepositorySummary

        if ($InfoLevel.Infrastructure.Repositories -ge 2) {
            Section -Style Heading4 $LocalizedData.RepositoryDetails {
                foreach ($Repository in @($script:AbrVbazInventory.Repositories | Sort-Object { Get-AbrVbazPropertyValue -InputObject $_ -Name 'name' })) {
                    $RepositoryName = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $Repository -Name 'name' -Default 'Repository')
                    $RepositoryRows = ConvertTo-AbrVbazTableObject -InputObject $Repository -PreferredProperties @('name', 'repositoryType', 'environment', 'status', 'storageTier', 'azureStorageAccountName', 'azureStorageContainer', 'azureStorageFolder', 'enableEncryption', 'immutabilityEnabled', 'regionName', 'repositoryOwnership')
                    Add-AbrVbazTable -Name "Repository - $RepositoryName" -InputObject $RepositoryRows -List
                }
            }
        }

        if ($InfoLevel.Infrastructure.Repositories -ge 2) {
            if (@($script:AbrVbazInventory.VeeamVaults).Count -gt 0) {
                Add-AbrVbazTable -Name 'Veeam Vaults' -InputObject (@($script:AbrVbazInventory.VeeamVaults) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'regionName', 'subscriptionName', 'status', 'state', 'capacity', 'usedSpace') })
            }
        }
    }
}

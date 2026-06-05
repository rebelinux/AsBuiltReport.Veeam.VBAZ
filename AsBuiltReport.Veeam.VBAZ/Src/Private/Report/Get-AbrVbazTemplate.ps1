function Get-AbrVbazTemplate {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Templates sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the SLA and storage templates registered on the VBAZ appliance using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Protection.Templates -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazTemplate

    if (@($script:AbrVbazInventory.SlaTemplates).Count -gt 0 -or @($script:AbrVbazInventory.StorageTemplates).Count -gt 0) {
        Section -Style Heading3 $LocalizedData.Heading {
            if (@($script:AbrVbazInventory.SlaTemplates).Count -gt 0) {
                Add-AbrVbazTable -Name 'SLA Templates' -InputObject (@($script:AbrVbazInventory.SlaTemplates) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'description', 'rpo', 'window', 'isDefault', 'assignedPoliciesCount') })
            }
            if (@($script:AbrVbazInventory.StorageTemplates).Count -gt 0) {
                Add-AbrVbazTable -Name 'Storage Templates' -InputObject (@($script:AbrVbazInventory.StorageTemplates) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'description', 'repositoryName', 'retention', 'isDefault', 'assignedPoliciesCount') })
            }
        }
    }
}

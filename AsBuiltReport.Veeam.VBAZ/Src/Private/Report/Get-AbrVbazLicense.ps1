function Get-AbrVbazLicense {
    <#
    .SYNOPSIS
        Used by As Built Report to render the license sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the VBAZ license summary and licensed resources using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.System.License -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazLicense

    Section -Style Heading3 $LocalizedData.Heading {
        $LicenseRows = @($script:AbrVbazInventory.License) | ForEach-Object {
            ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('licenseType', 'isFreeEdition', 'totalInstancesUses', 'vmsInstancesUses', 'sqlInstancesUses', 'fileShareInstancesUses', 'cosmosDbInstancesUses', 'instances', 'gracePeriodDays')
        }
        if ($HealthCheck.System.License) {
            $LicenseRows | Where-Object { $_.Status -match 'Expired|Invalid|Warning' -or $_.State -match 'Expired|Invalid|Warning' } | Set-Style -Style Critical -Property Status, State
        }
        Add-AbrVbazTable -Name 'VBAZ License' -InputObject $LicenseRows -List

        if ($InfoLevel.System.License -ge 2) {
            $Resources = @($script:AbrVbazInventory.LicenseResources) | ForEach-Object {
                ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'resourceType', 'lastBackupTime', 'licensedState', 'cost')
            }
            Add-AbrVbazTable -Name 'VBAZ Licensed Resources' -InputObject $Resources
            $Chart = New-AbrVbazCountChart -Title 'Licensed Resource Records' -CountObjects @(
                New-AbrVbazCountObject -Name 'License Resources' -Items $script:AbrVbazInventory.LicenseResources
            )
            if ($Chart) {
                Image -Text 'License Resource Chart' -Align Center -Percent 100 -Base64 $Chart
            }
        }
    }
}

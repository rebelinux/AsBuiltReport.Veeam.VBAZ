function Get-AbrVbazConfigurationBackup {
    <#
    .SYNOPSIS
        Used by As Built Report to render the configuration backup sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the VBAZ configuration backup settings and restore points using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.System.ConfigurationBackup -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazConfigurationBackup

    Section -Style Heading3 $LocalizedData.Heading {
        # Inventory-count fields from the stats payload are noise in a configuration-backup section.
        $ConfigBackupNoise = @(
            'productinformationcount', 'productinformation', 'serviceaccountcount', 'sessioncount', 'size',
            'protectionpolicyvmcount', 'standardrepositorycount', 'archiverepositorycount',
            'vmpolicycount', 'sqlpolicycount', 'filesharepolicycount', 'cosmosdbpolicycount'
        )
        $ConfigRows = @($script:AbrVbazInventory.ConfigurationBackupSettings + $script:AbrVbazInventory.ConfigurationBackupStats) | ForEach-Object {
            $Row = ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('isEnabled', 'enabled', 'lastResult', 'lastStatus', 'lastRun', 'nextRun', 'repositoryName', 'retentionPolicy', 'restorePointsCount')
            foreach ($PropertyName in @($Row.PSObject.Properties.Name)) {
                $Normalized = ($PropertyName -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
                if ($ConfigBackupNoise -contains $Normalized) {
                    $Row.PSObject.Properties.Remove($PropertyName)
                }
            }
            $Row
        }
        if ($HealthCheck.System.ConfigurationBackup) {
            $ConfigRows | Where-Object { $_.Enabled -eq 'No' -or $_.'Is Enabled' -eq 'No' } | Set-Style -Style Warning -Property Enabled, 'Is Enabled'
            $ConfigRows | Where-Object { $_.'Last Result' -match 'Failed|Error' -or $_.'Last Status' -match 'Failed|Error' } | Set-Style -Style Critical -Property 'Last Result', 'Last Status'
        }
        Add-AbrVbazTable -Name 'Configuration Backup Settings' -InputObject $ConfigRows -List

        if ($InfoLevel.System.ConfigurationBackup -ge 2) {
            if (@($script:AbrVbazInventory.ConfigurationBackupRestorePoints).Count -gt 0) {
                Add-AbrVbazTable -Name 'Configuration Backup Restore Points' -InputObject (@($script:AbrVbazInventory.ConfigurationBackupRestorePoints) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('creationTime', 'creationDate', 'description', 'repositoryName', 'size') })
            }
        }
    }
}

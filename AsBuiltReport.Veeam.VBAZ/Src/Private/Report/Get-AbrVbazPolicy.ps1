function Get-AbrVbazPolicy {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Policies sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the backup policies, their status and (at deep detail) their selected/excluded items using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Protection.Policies -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazPolicy

    $PolicySets = [ordered]@{
        'VM Policies' = $script:AbrVbazInventory.VmPolicies
        'SLA VM Policies' = $script:AbrVbazInventory.SlaVmPolicies
        'File Share Policies' = $script:AbrVbazInventory.FileSharePolicies
        'SQL Policies' = $script:AbrVbazInventory.SqlPolicies
        'Cosmos DB Policies' = $script:AbrVbazInventory.CosmosDbPolicies
        'VNet Policy' = $script:AbrVbazInventory.VnetPolicy
    }

    # Maps each policy display set to the inventory collection name used for level 3 child fan-out.
    $PolicyCollectionNames = @{
        'VM Policies' = 'VmPolicies'
        'SLA VM Policies' = 'SlaVmPolicies'
        'File Share Policies' = 'FileSharePolicies'
        'SQL Policies' = 'SqlPolicies'
        'Cosmos DB Policies' = 'CosmosDbPolicies'
    }

    Section -Style Heading3 $LocalizedData.Heading {
        foreach ($Key in $PolicySets.Keys) {
            if ($Key -in @('SLA VM Policies', 'Cosmos DB Policies') -and @($PolicySets[$Key]).Count -eq 0) {
                continue
            }
            if ($Key -eq 'VM Policies') {
                $Rows = @($PolicySets[$Key]) | ForEach-Object {
                    ConvertTo-AbrVbazVmPolicyTableObject -InputObject $_
                }
            } else {
                $Rows = @($PolicySets[$Key]) | ForEach-Object {
                    ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'priority', 'isEnabled', 'backupType', 'snapshotStatus', 'backupStatus', 'archiveStatus', 'healthCheckStatus', 'indexingStatus', 'nextExecutionTime', 'isScheduleConfigured', 'isBackupConfigured', 'isArchiveBackupConfigured', 'excludedItemsCount')
                }
            }
            if ($HealthCheck.Protection.Policies) {
                $Rows | Where-Object { $_.'Is Enabled' -eq 'No' -or $_.Enabled -eq 'No' } | Set-Style -Style Warning -Property 'Is Enabled', Enabled
                $Rows | Where-Object { $_.Status -match 'Failed|Error' -or $_.State -match 'Failed|Error' -or $_.'Last Result' -match 'Failed|Error' } | Set-Style -Style Critical -Property Status, State, 'Last Result'
            }
            if ($InfoLevel.Protection.Policies -ge 2 -and $Key -eq 'VM Policies') {
                $Chart = New-AbrVbazPolicyStatusChart -Title "$Key Status" -Items $PolicySets[$Key]
                if ($Chart) {
                    Image -Text "$Key Status Chart" -Align Center -Percent 100 -Base64 $Chart
                }
            }
            Add-AbrVbazTable -Name $Key -InputObject $Rows
            if ($InfoLevel.Protection.Policies -ge 2 -and $Key -ne 'VM Policies') {
                $Chart = New-AbrVbazPolicyStatusChart -Title "$Key Status" -Items $PolicySets[$Key]
                if ($Chart) {
                    Image -Text "$Key Status Chart" -Align Center -Percent 100 -Base64 $Chart
                }
            }

            if ($InfoLevel.Protection.Policies -ge 3 -and $PolicyCollectionNames[$Key]) {
                $CollectionName = $PolicyCollectionNames[$Key]
                foreach ($Policy in @($PolicySets[$Key])) {
                    $PolicyName = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $Policy -Name @('name', 'displayName') -Default 'Policy')
                    $SelectedItems = @(Get-AbrVbazPolicyChildItems -CollectionName $CollectionName -Policy $Policy -Child SelectedItems)
                    $ExcludedItems = @(Get-AbrVbazPolicyChildItems -CollectionName $CollectionName -Policy $Policy -Child ExcludedItems)
                    $RegionItems = @(Get-AbrVbazPolicyChildItems -CollectionName $CollectionName -Policy $Policy -Child Regions)
                    $ProtectedItems = @(Get-AbrVbazPolicyChildItems -CollectionName $CollectionName -Policy $Policy -Child ProtectedItems)
                    if (($SelectedItems.Count + $ExcludedItems.Count) -eq 0) {
                        continue
                    }
                    Section -Style Heading4 ($LocalizedData.Configuration -f $PolicyName) {
                        $BackupType = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $Policy -Name 'backupType' -Default '--')
                        $RegionList = @($RegionItems | ForEach-Object { ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name @('name', 'regionName', 'displayName')) } | Where-Object { Test-AbrVbazDisplayValue -Value $_ } | Sort-Object -Unique)
                        $RegionText = if ($RegionList.Count) { $RegionList -join ', ' } else { 'Not exposed by API' }
                        Paragraph ($LocalizedData.ConfigurationSummary -f $BackupType, $SelectedItems.Count, $ExcludedItems.Count, $ProtectedItems.Count, $RegionText)
                        if ($SelectedItems.Count -gt 0) {
                            Add-AbrVbazTable -Name "$PolicyName - Selected Items" -InputObject (@($SelectedItems) | ForEach-Object { ConvertTo-AbrVbazPolicyChildRow -InputObject $_ })
                        }
                        if ($ExcludedItems.Count -gt 0) {
                            Add-AbrVbazTable -Name "$PolicyName - Excluded Items" -InputObject (@($ExcludedItems) | ForEach-Object { ConvertTo-AbrVbazPolicyChildRow -InputObject $_ })
                        }
                    }
                }
            }
        }
    }
}

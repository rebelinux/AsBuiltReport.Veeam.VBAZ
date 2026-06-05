function Get-AbrVbazRestorePoint {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Restore Points sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the restore point inventory by workload and, when operational detail is enabled, the per-restore-point detail using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/acgdickie/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Operations.RestorePoints -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazRestorePoint

    Section -Style Heading3 $LocalizedData.Heading {
        $RestoreSummary = @(
            New-AbrVbazCountObject -Name 'Virtual Machine Restore Points' -Items $script:AbrVbazInventory.VmRestorePoints
            New-AbrVbazCountObject -Name 'SQL Restore Points' -Items $script:AbrVbazInventory.SqlRestorePoints
            New-AbrVbazCountObject -Name 'File Share Restore Points' -Items $script:AbrVbazInventory.FileShareRestorePoints
            New-AbrVbazCountObject -Name 'Cosmos DB Repository Restore Points' -Items $script:AbrVbazInventory.CosmosRepositoryRestorePoints
            New-AbrVbazCountObject -Name 'Cosmos DB Continuous Restore Points' -Items $script:AbrVbazInventory.CosmosContinuousRestorePoints
            New-AbrVbazCountObject -Name 'VNet Restore Points' -Items $script:AbrVbazInventory.VnetRestorePoints
        )
        Add-AbrVbazTable -Name 'Restore Point Summary' -InputObject $RestoreSummary
        $Chart = New-AbrVbazCountChart -Title 'Restore Points by Workload' -CountObjects $RestoreSummary
        if ($Chart) {
            Image -Text 'Restore Point Chart' -Align Center -Percent 100 -Base64 $Chart
        }

        if ($InfoLevel.Operations.RestorePoints -ge 2) {
            if (@($script:AbrVbazInventory.VmRestorePoints).Count -gt 0) {
                Add-AbrVbazTable -Name 'VM Restore Points by Policy' -InputObject (New-AbrVbazGroupSummary -Items $script:AbrVbazInventory.VmRestorePoints -GroupBy @('policyName', 'jobName', 'vmName', 'name') -GroupLabel 'Policy')
            }
            if (@($script:AbrVbazInventory.SqlRestorePoints).Count -gt 0) {
                Add-AbrVbazTable -Name 'SQL Restore Points by Policy' -InputObject (New-AbrVbazGroupSummary -Items $script:AbrVbazInventory.SqlRestorePoints -GroupBy @('policyName', 'jobName', 'databaseName', 'serverName', 'name') -GroupLabel 'Policy')
            }
            if (@($script:AbrVbazInventory.FileShareRestorePoints).Count -gt 0) {
                Add-AbrVbazTable -Name 'File Share Restore Points by Policy' -InputObject (New-AbrVbazGroupSummary -Items $script:AbrVbazInventory.FileShareRestorePoints -GroupBy @('policyName', 'jobName', 'fileShareName', 'name') -GroupLabel 'Policy')
            }
            if (@($script:AbrVbazInventory.VnetRestorePoints).Count -gt 0) {
                Add-AbrVbazTable -Name 'VNet Restore Points by Policy' -InputObject (New-AbrVbazGroupSummary -Items $script:AbrVbazInventory.VnetRestorePoints -GroupBy @('policyName', 'jobName', 'virtualNetworkName', 'name') -GroupLabel 'Policy')
            }
        }

        # Per-restore-point detail is rendered only when OperationsDetailMode is explicitly set to
        # 'Full'. By default the grouped summaries above are the right altitude for an as built report.
        if ((Get-AbrVbazOperationsDetailMode) -eq 'Full') {
            Section -Style Heading4 $LocalizedData.RestorePointDetails {
                if (@($script:AbrVbazInventory.VmRestorePoints).Count -gt 0) {
                    Section -Style NOTOCHeading5 'Virtual Machine Restore Points' {
                        Add-AbrVbazTable -Name 'Virtual Machine Restore Points' -InputObject (@($script:AbrVbazInventory.VmRestorePoints) | ForEach-Object { ConvertTo-AbrVbazRestorePointTableObject -InputObject $_ -WorkloadType VirtualMachine })
                    }
                }
                if (@($script:AbrVbazInventory.SqlRestorePoints).Count -gt 0) {
                    Section -Style NOTOCHeading5 'SQL Restore Points' {
                        Add-AbrVbazTable -Name 'SQL Restore Points' -InputObject (@($script:AbrVbazInventory.SqlRestorePoints) | ForEach-Object { ConvertTo-AbrVbazRestorePointTableObject -InputObject $_ -WorkloadType SQL })
                    }
                }
                if (@($script:AbrVbazInventory.FileShareRestorePoints).Count -gt 0) {
                    Section -Style NOTOCHeading5 'File Share Restore Points' {
                        Add-AbrVbazTable -Name 'File Share Restore Points' -InputObject (@($script:AbrVbazInventory.FileShareRestorePoints) | ForEach-Object { ConvertTo-AbrVbazRestorePointTableObject -InputObject $_ -WorkloadType FileShare })
                    }
                }
                $CosmosRestorePoints = @($script:AbrVbazInventory.CosmosRepositoryRestorePoints + $script:AbrVbazInventory.CosmosContinuousRestorePoints)
                if ($CosmosRestorePoints.Count -gt 0) {
                    Section -Style NOTOCHeading5 'Cosmos DB Restore Points' {
                        Add-AbrVbazTable -Name 'Cosmos DB Restore Points' -InputObject ($CosmosRestorePoints | ForEach-Object { ConvertTo-AbrVbazRestorePointTableObject -InputObject $_ -WorkloadType CosmosDb })
                    }
                }
                if (@($script:AbrVbazInventory.VnetRestorePoints).Count -gt 0) {
                    Section -Style NOTOCHeading5 'VNet Restore Points' {
                        Add-AbrVbazTable -Name 'VNet Restore Points' -InputObject (@($script:AbrVbazInventory.VnetRestorePoints) | ForEach-Object { ConvertTo-AbrVbazRestorePointTableObject -InputObject $_ -WorkloadType VNet })
                    }
                }
            }
        }
    }
}

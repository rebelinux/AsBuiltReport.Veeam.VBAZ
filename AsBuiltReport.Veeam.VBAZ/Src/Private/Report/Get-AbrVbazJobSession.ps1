function Get-AbrVbazJobSession {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Job Sessions sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the job session summaries and, when operational detail is enabled, the per-session run history using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/acgdickie/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Operations.Sessions -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazJobSession

    Section -Style Heading3 $LocalizedData.Heading {
        $SessionItems = @($script:AbrVbazInventory.JobSessions)
        $Chart = New-AbrVbazStatusChart -Title 'Job Session Results' -Items $script:AbrVbazInventory.JobSessions
        if ($Chart) {
            Image -Text 'Job Session Result Chart' -Align Center -Percent 100 -Base64 $Chart
        }
        Add-AbrVbazTable -Name 'Job Session Summary by Status' -InputObject (New-AbrVbazGroupSummary -Items $SessionItems -GroupBy @('lastStatus', 'status', 'state', 'result', 'lastResult') -GroupLabel 'Status')
        if ($InfoLevel.Operations.Sessions -ge 2) {
            Add-AbrVbazTable -Name 'Job Session Summary by Type' -InputObject (New-AbrVbazGroupSummary -Items $SessionItems -GroupBy @('type', 'sessionType', 'jobType') -GroupLabel 'Type')
        }
        # Per-session run history is operational data, not as built configuration. Following the
        # VBR report convention (operational detail is a deliberate opt-in, not a function of the
        # detail level), the full per-session tables are rendered only when OperationsDetailMode
        # is explicitly set to 'Full' - never as a side effect of raising InfoLevel to 3.
        if ((Get-AbrVbazOperationsDetailMode) -eq 'Full') {
            $SessionGroups = @($SessionItems | Group-Object -Property { Get-AbrVbazJobSessionType -InputObject $_ })
            $ExcludedGroups = @($SessionGroups | Where-Object { -not (Test-AbrVbazMeaningfulSessionType -Type $_.Name) })
            if ($ExcludedGroups.Count -gt 0) {
                $ExcludedCount = (@($ExcludedGroups) | Measure-Object -Property Count -Sum).Sum
                Paragraph ($LocalizedData.OmittedSessions -f $ExcludedCount, $ExcludedGroups.Count, ((@($ExcludedGroups.Name) | Sort-Object) -join ', '))
                BlankLine
            }
            # Policy/backup session types are split (fanned out) into a smaller table per policy/job.
            $FanOutSessionTypes = @('PolicySnapshot', 'PolicyBackup', 'FileSharePolicySnapshot', 'SqlPolicyBackup')
            $MeaningfulGroups = @($SessionGroups | Where-Object { Test-AbrVbazMeaningfulSessionType -Type $_.Name } | Sort-Object -Property @{ Expression = { Get-AbrVbazSessionTypeSortKey -Type $_.Name } })
            foreach ($SessionGroup in $MeaningfulGroups) {
                $HeadingLabel = if ($SessionGroup.Name -eq 'PolicySnapshot') { $LocalizedData.PolicySnapshotHeading } else { "$($SessionGroup.Name) Sessions" }
                Section -Style Heading4 $HeadingLabel {
                    if ($SessionGroup.Name -in $FanOutSessionTypes) {
                        $PolicyGroups = @($SessionGroup.Group | Group-Object -Property { Get-AbrVbazJobSessionPolicyName -InputObject $_ } | Sort-Object Name)
                        foreach ($PolicyGroup in $PolicyGroups) {
                            $SessionRows = @($PolicyGroup.Group | ForEach-Object { ConvertTo-AbrVbazJobSessionTableObject -InputObject $_ })
                            Set-AbrVbazSessionRowStyle -Rows $SessionRows
                            Add-AbrVbazTable -Name "$HeadingLabel - $($PolicyGroup.Name)" -InputObject $SessionRows
                        }
                    } else {
                        $SessionRows = @($SessionGroup.Group | ForEach-Object { ConvertTo-AbrVbazJobSessionTableObject -InputObject $_ })
                        Set-AbrVbazSessionRowStyle -Rows $SessionRows
                        Add-AbrVbazTable -Name $HeadingLabel -InputObject $SessionRows
                    }
                }
            }
        }
    }
}

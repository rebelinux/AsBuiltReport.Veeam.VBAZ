function Get-AbrVbazHealthCheckSection {
    <#
    .SYNOPSIS
        Used by As Built Report to render the consolidated health check summary for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the configuration and operational exceptions identified by the enabled health checks using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if (-not (Test-AbrVbazAnyHealthCheckEnabled)) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazHealthCheckSection
    $Findings = @(Get-AbrVbazHealthFindings)

    Section -Style Heading2 $LocalizedData.Heading {
        Paragraph $LocalizedData.Paragraph
        BlankLine
        if (-not $Findings) {
            Paragraph $LocalizedData.NoFindings
            return
        }
        foreach ($Finding in $Findings) {
            if ($Finding.Severity -eq 'Critical') {
                $Finding | Set-Style -Style Critical -Property 'Severity', 'Category', 'Item', 'Detail'
            } elseif ($Finding.Severity -eq 'Warning') {
                $Finding | Set-Style -Style Warning -Property 'Severity', 'Category', 'Item', 'Detail'
            }
        }
        Add-AbrVbazTable -Name 'Health Check Findings' -InputObject $Findings
    }
}

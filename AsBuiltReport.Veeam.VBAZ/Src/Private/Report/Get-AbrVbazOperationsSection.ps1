function Get-AbrVbazOperationsSection {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Operations section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Orchestrates the overview, job sessions and restore points sub-sections using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Operations.PSObject.Properties.Value -eq 0) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazOperationsSection

    Section -Style Heading2 $LocalizedData.Heading {
        Paragraph $LocalizedData.Paragraph
        BlankLine

        Get-AbrVbazOverview
        Get-AbrVbazJobSession
        Get-AbrVbazRestorePoint
    }
}

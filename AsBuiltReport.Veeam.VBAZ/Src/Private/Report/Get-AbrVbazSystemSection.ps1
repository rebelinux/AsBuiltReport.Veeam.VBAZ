function Get-AbrVbazSystemSection {
    <#
    .SYNOPSIS
        Used by As Built Report to render the System section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Orchestrates the appliance, license, configuration backup and security sub-sections using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/acgdickie/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.System.PSObject.Properties.Value -eq 0) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazSystemSection

    Section -Style Heading2 $LocalizedData.Heading {
        Paragraph $LocalizedData.Paragraph
        BlankLine

        Get-AbrVbazAppliance
        Get-AbrVbazLicense
        Get-AbrVbazConfigurationBackup
        Get-AbrVbazSecurity
    }
}

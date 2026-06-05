function Get-AbrVbazStandardAccount {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Standard Accounts sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the standard accounts stored on the VBAZ appliance using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Infrastructure.Accounts -lt 2) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazStandardAccount

    Section -Style Heading3 $LocalizedData.Heading {
        Add-AbrVbazTable -Name 'Standard Accounts' -InputObject (@($script:AbrVbazInventory.StandardAccounts) | ForEach-Object {
            [pscustomobject][ordered]@{
                ID = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name 'id')
                Kind = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name @('kind', 'type'))
                Name = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name 'name')
                Username = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name 'username')
            }
        })
    }
}

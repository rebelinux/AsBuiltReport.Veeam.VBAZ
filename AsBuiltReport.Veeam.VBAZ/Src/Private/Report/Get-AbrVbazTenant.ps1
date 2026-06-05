function Get-AbrVbazTenant {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Azure Tenants sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the Microsoft Entra tenants known to the VBAZ appliance through connected accounts using PScribo.
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

    $LocalizedData = $reportTranslate.GetAbrVbazTenant

    Section -Style Heading3 $LocalizedData.Heading {
        Paragraph $LocalizedData.Paragraph
        Add-AbrVbazTable -Name 'Tenants' -InputObject (@($script:AbrVbazInventory.Tenants) | ForEach-Object {
            $TenantId = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name @('tenantId', 'id'))
            $TenantName = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name @('tenantName', 'displayName', 'name'))
            if (-not (Test-AbrVbazDisplayValue -Value $TenantName) -or $TenantName -eq $TenantId) {
                $TenantName = 'Not exposed by API'
            }
            [pscustomobject][ordered]@{
                'Tenant Name' = $TenantName
                'Tenant ID' = $TenantId
                'Account Name' = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name 'accountName')
            }
        })
    }
}

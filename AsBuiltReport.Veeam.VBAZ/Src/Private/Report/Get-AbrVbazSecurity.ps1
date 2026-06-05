function Get-AbrVbazSecurity {
    <#
    .SYNOPSIS
        Used by As Built Report to render the security sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the VBAZ users, certificates and SAML identity provider configuration using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.System.Security -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazSecurity

    Section -Style Heading3 $LocalizedData.Heading {
        Add-AbrVbazTable -Name 'Users' -InputObject (@($script:AbrVbazInventory.Users) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'description', 'role', 'type', 'mfaEnabled', 'createdBy', 'creationTimeUtc') })
        if ($InfoLevel.System.Security -ge 2) {
            $Certificates = @($script:AbrVbazInventory.Certificates) | ForEach-Object {
                ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('name', 'subject', 'issuer', 'expirationDate', 'notAfter', 'thumbprint')
            }
            Add-AbrVbazTable -Name 'Certificates' -InputObject $Certificates -List
            if (@($script:AbrVbazInventory.SamlIdentityProvider).Count -gt 0) {
                $SamlRows = @($script:AbrVbazInventory.SamlIdentityProvider) | ForEach-Object {
                    ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('isEnabled', 'enabled', 'entityId', 'signOnUrl', 'certificateThumbprint')
                } | Where-Object {
                    @($_.PSObject.Properties | Where-Object { $_.Name -notlike '*__Style' -and (Test-AbrVbazDisplayValue -Value $_.Value) }).Count -gt 0
                }
                if ($SamlRows) {
                    Add-AbrVbazTable -Name 'SAML Identity Provider' -InputObject $SamlRows -List
                }
            }
        }
    }
}

function Get-AbrVbazAppliance {
    <#
    .SYNOPSIS
        Used by As Built Report to render the appliance sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the VBAZ appliance summary, support information and private deployment state using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.System.Appliance -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazAppliance

    Section -Style Heading3 $LocalizedData.Heading {
        $Rows = @()
        foreach ($Item in @($script:AbrVbazInventory.SystemAbout + $script:AbrVbazInventory.SystemServerInfo + $script:AbrVbazInventory.SystemStatus + $script:AbrVbazInventory.SystemTime)) {
            if ($Item) {
                $Rows += ConvertTo-AbrVbazTableObject -InputObject $Item -PreferredProperties @('serverName', 'serverVersion', 'workerVersion', 'flrVersion', 'azureRegionName', 'resourceGroup', 'azureEnvironment', 'state', 'serverTime', 'timeZoneId', 'databaseId')
            }
        }
        Add-AbrVbazTable -Name 'VBAZ Appliance Summary' -InputObject $Rows -List

        if ($InfoLevel.System.Appliance -ge 2) {
            Add-AbrVbazTable -Name 'VBAZ Support Information' -InputObject (@($script:AbrVbazInventory.SystemSupportInfo) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('supportId', 'installationId', 'environmentId', 'serverVersion', 'workerVersion', 'build') }) -List
            Add-AbrVbazTable -Name 'Private Deployment State' -InputObject (@($script:AbrVbazInventory.PrivateDeploymentState) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('state', 'status', 'enabled', 'message') }) -List
        }
    }
}

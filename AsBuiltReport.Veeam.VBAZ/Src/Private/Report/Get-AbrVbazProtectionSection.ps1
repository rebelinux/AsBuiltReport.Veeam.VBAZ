function Get-AbrVbazProtectionSection {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Protection section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Orchestrates the policies, protected items and templates sub-sections using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/acgdickie/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Protection.PSObject.Properties.Value -eq 0) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazProtectionSection

    Section -Style Heading2 $LocalizedData.Heading {
        Paragraph $LocalizedData.Paragraph
        BlankLine

        $PolicySets = [ordered]@{
            'VM Policies' = $script:AbrVbazInventory.VmPolicies
            'SLA VM Policies' = $script:AbrVbazInventory.SlaVmPolicies
            'File Share Policies' = $script:AbrVbazInventory.FileSharePolicies
            'SQL Policies' = $script:AbrVbazInventory.SqlPolicies
            'Cosmos DB Policies' = $script:AbrVbazInventory.CosmosDbPolicies
            'VNet Policy' = $script:AbrVbazInventory.VnetPolicy
        }

        $PolicySummary = foreach ($Key in $PolicySets.Keys) {
            New-AbrVbazCountObject -Name $Key -Items $PolicySets[$Key]
        }
        Add-AbrVbazTable -Name 'Protection Policy Summary' -InputObject $PolicySummary
        $PolicyChart = New-AbrVbazCountChart -Title 'Protection Policies by Workload' -CountObjects $PolicySummary
        if ($PolicyChart) {
            Image -Text 'Protection Policy Chart' -Align Center -Percent 100 -Base64 $PolicyChart
        }

        Get-AbrVbazPolicy
        Get-AbrVbazProtectedItem
        Get-AbrVbazTemplate
    }
}

function Get-AbrVbazWorker {
    <#
    .SYNOPSIS
        Used by As Built Report to render the Workers sub-section for Veeam Backup for Microsoft Azure.
    .DESCRIPTION
        Documents the worker network configuration, profiles, statistics and details used by the VBAZ appliance using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Veeam.VBAZ
    #>
    [CmdletBinding()]
    param ()

    if ($InfoLevel.Infrastructure.Workers -lt 1) {
        return
    }

    $LocalizedData = $reportTranslate.GetAbrVbazWorker

    Section -Style Heading3 $LocalizedData.Heading {
        if ($InfoLevel.Infrastructure.Workers -ge 2) {
            if (@($script:AbrVbazInventory.WorkerNetworkConfiguration).Count -gt 0) {
                Section -Style Heading4 $LocalizedData.WorkerNetworkConfiguration {
                    foreach ($WorkerNetwork in @($script:AbrVbazInventory.WorkerNetworkConfiguration | Sort-Object { Get-AbrVbazPropertyValue -InputObject $_ -Name @('regionName', 'virtualNetworkName', 'subnetName') })) {
                        $WorkerNetworkName = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $WorkerNetwork -Name @('regionName', 'virtualNetworkName', 'subnetName') -Default 'Worker Network')
                        Add-AbrVbazTable -Name "Worker Network - $WorkerNetworkName" -InputObject (ConvertTo-AbrVbazTableObject -InputObject $WorkerNetwork -PreferredProperties @('regionName', 'virtualNetworkName', 'subnetName', 'networkSecurityGroupName')) -List
                    }
                }
            }
            if (@($script:AbrVbazInventory.WorkerProfiles).Count -gt 0) {
                Section -Style Heading4 $LocalizedData.WorkerProfiles {
                    Add-AbrVbazTable -Name 'Worker Profiles' -InputObject (@($script:AbrVbazInventory.WorkerProfiles) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('regionName', 'vmSize', 'networkName', 'subnetName', 'resourceGroupName') })
                }
            }
            if (@($script:AbrVbazInventory.WorkerStatistics).Count -gt 0) {
                Section -Style Heading4 $LocalizedData.WorkerStatistics {
                    Add-AbrVbazTable -Name 'Worker Statistics' -InputObject (@($script:AbrVbazInventory.WorkerStatistics) | ForEach-Object { ConvertTo-AbrVbazTableObject -InputObject $_ -PreferredProperties @('regionName', 'region', 'runningWorkers', 'countOfWorkers', 'usedWorkers', 'deployedWorkers', 'failedWorkers', 'busyWorkers', 'idleWorkers', 'totalCycleTime') })
                }
            }
        }
        if (@($script:AbrVbazInventory.Workers).Count -gt 0) {
            Section -Style Heading4 $LocalizedData.WorkerDetails {
                foreach ($Worker in @($script:AbrVbazInventory.Workers | Sort-Object { Get-AbrVbazPropertyValue -InputObject $_ -Name @('name', 'host', 'region') })) {
                    $WorkerName = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $Worker -Name @('name', 'host', 'region') -Default 'Worker')
                    Add-AbrVbazTable -Name "Worker - $WorkerName" -InputObject (ConvertTo-AbrVbazTableObject -InputObject $Worker -PreferredProperties @('name', 'host', 'region', 'regionId', 'network', 'subnetName', 'instanceType', 'profile', 'status')) -List
                }
            }
        }
    }
}

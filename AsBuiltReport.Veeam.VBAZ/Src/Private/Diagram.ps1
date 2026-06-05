function New-AbrVbazDiagramInfo {
    [CmdletBinding()]
    param (
        $InputObject,
        [string[]] $Properties
    )

    $Info = [ordered]@{}
    foreach ($PropertyName in $Properties) {
        $Value = Get-AbrVbazPropertyValue -InputObject $InputObject -Name $PropertyName
        $DiagramValue = ConvertTo-AbrVbazDiagramValue -InputObject $Value
        if (Test-AbrVbazDisplayValue -Value $DiagramValue) {
            $Info[(Format-AbrVbazPropertyLabel -Name $PropertyName)] = $DiagramValue
        }
    }
    $Info
}

function ConvertTo-AbrVbazDiagramValue {
    [CmdletBinding()]
    param (
        $InputObject
    )

    if ($null -eq $InputObject -or $InputObject -eq '') {
        return $null
    }

    if ($InputObject -is [bool] -or $InputObject -is [datetime]) {
        return ConvertTo-AbrVbazDisplayValue -InputObject $InputObject
    }

    if ($InputObject -is [array]) {
        $Values = @($InputObject | ForEach-Object { ConvertTo-AbrVbazDiagramValue -InputObject $_ } | Where-Object { Test-AbrVbazDisplayValue -Value $_ })
        if (-not $Values) {
            return $null
        }
        return (($Values | Select-Object -First 3) -join ', ')
    }

    if ($InputObject -is [pscustomobject] -or $InputObject -is [hashtable]) {
        foreach ($Name in @('name', 'displayName', 'status', 'state', 'type')) {
            $Value = Get-AbrVbazPropertyValue -InputObject $InputObject -Name $Name
            if (Test-AbrVbazDisplayValue -Value $Value) {
                return ConvertTo-AbrVbazDiagramValue -InputObject $Value
            }
        }
        return $null
    }

    $Value = ([string]$InputObject) -replace '\s+', ' '
    $Value = $Value.Trim()
    if ($Value.Length -gt 80) {
        $Value = "$($Value.Substring(0, 77))..."
    }
    $Value
}

function New-AbrVbazDiagramItem {
    [CmdletBinding()]
    param (
        $InputObject,
        [string] $DefaultName,
        [string[]] $InfoProperties,
        [string] $IconType
    )

    $Name = ConvertTo-AbrVbazDiagramValue -InputObject (Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('name', 'displayName', 'serverName', 'repositoryName', 'regionName', 'type') -Default $DefaultName)
    [pscustomobject]@{
        Name = if ($Name) { $Name } else { $DefaultName }
        Info = New-AbrVbazDiagramInfo -InputObject $InputObject -Properties $InfoProperties
        IconType = $IconType
    }
}

function New-AbrVbazDiagramSummaryItem {
    [CmdletBinding()]
    param (
        [string] $Name,
        [int] $Total,
        [hashtable] $Info,
        [string] $IconType
    )

    [pscustomobject]@{
        Name = $Name
        Info = $Info
        Total = $Total
        IconType = $IconType
    }
}

function New-AbrVbazDiagramNodeTable {
    [CmdletBinding()]
    param (
        [string] $NodeName,
        [string] $Label,
        [object[]] $Items,
        [string] $IconType,
        [string] $SubgraphIconType,
        [int] $ColumnSize = 2,
        [string] $Fontcolor,
        [string] $TableBorderColor,
        [string] $MainGraphBGColor,
        [bool] $IconDebug
    )

    $ResolvedItems = @($Items | Where-Object { $_ -and (Test-AbrVbazDisplayValue -Value $_.Name) })
    if (-not $ResolvedItems) {
        $ResolvedItems = @([pscustomobject]@{
            Name = "No $Label"
            Info = @{}
        })
        # Keep the node's own icon for an empty category (e.g. an appliance with no restore points
        # yet) so the topology stays recognizable; only use the generic placeholder icon when the
        # node was not given an icon of its own.
        if (-not $IconType) {
            $IconType = 'VBAZ_No_Icon'
        }
    }

    $Names = @($ResolvedItems | Select-Object -ExpandProperty Name)
    # Per-item icons: use each item's own IconType where set, otherwise the node default icon.
    # A separate (untyped) variable is used so the value can be a string[] without the [string] cast.
    $IconList = $IconType
    if (@($ResolvedItems | Where-Object { $_.PSObject.Properties['IconType'] -and $_.IconType }).Count -gt 0) {
        $IconList = @($ResolvedItems | ForEach-Object {
                if ($_.PSObject.Properties['IconType'] -and $_.IconType) { $_.IconType } else { $IconType }
            })
    }
    $AdditionalInfo = [ordered]@{}
    $InfoKeys = @($ResolvedItems | ForEach-Object {
            if ($_.Info) {
                $_.Info.Keys
            }
        } | Select-Object -Unique)
    foreach ($InfoKey in $InfoKeys) {
        $Values = @($ResolvedItems | ForEach-Object {
                if ($_.Info -and $_.Info.Contains($InfoKey) -and (Test-AbrVbazDisplayValue -Value $_.Info[$InfoKey])) {
                    $_.Info[$InfoKey]
                } else {
                    ''
                }
            })
        if (@($Values | Where-Object { Test-AbrVbazDisplayValue -Value $_ }).Count -gt 0) {
            $AdditionalInfo[$InfoKey] = $Values
        }
    }

    $NodeLabelParams = [ordered]@{
        Name = $NodeName
        ImagesObj = $script:Images
        inputObject = $Names
        Align = 'Center'
        IconType = $IconList
        ColumnSize = $ColumnSize
        IconDebug = $IconDebug
        MultiIcon = $true
        Subgraph = $true
        SubgraphIconType = $SubgraphIconType
        SubgraphLabel = $Label
        SubgraphLabelPos = 'top'
        SubgraphTableStyle = 'dashed,rounded'
        TableBorderColor = $TableBorderColor
        TableBorder = '1'
        SubgraphLabelFontSize = 22
        FontSize = 16
        SubgraphFontBold = $true
        FontColor = $Fontcolor
        SubgraphLabelFontColor = $Fontcolor
        TableBackgroundColor = $MainGraphBGColor
        CellBackgroundColor = $MainGraphBGColor
    }
    if ($AdditionalInfo.Count -gt 0) {
        $NodeLabelParams['AditionalInfo'] = $AdditionalInfo
    }

    Node $NodeName @{
        Label = (Add-HtmlNodeTable @NodeLabelParams)
        shape = 'plain'
        fillColor = 'transparent'
        fontsize = 14
        fontname = 'Segoe Ui'
    }
}

function Get-AbrVbazDiagram {
    [CmdletBinding()]
    param ()

    if ($Options.EnableDiagramDebug) {
        $IconDebug = $true
    } else {
        $IconDebug = $false
    }

    if ($Options.DiagramTheme -eq 'Black') {
        $MainGraphBGColor = 'Black'
        $TableBorderColor = 'White'
        $Edgecolor = 'White'
        $Fontcolor = 'White'
        $ApplianceBGColor = 'Black'
    } elseif ($Options.DiagramTheme -eq 'Neon') {
        $MainGraphBGColor = 'grey14'
        $TableBorderColor = 'gold2'
        $Edgecolor = 'gold2'
        $Fontcolor = 'gold2'
        $ApplianceBGColor = 'grey14'
    } else {
        $MainGraphBGColor = 'White'
        $TableBorderColor = '#71797E'
        $Edgecolor = '#71797E'
        $Fontcolor = '#565656'
        $ApplianceBGColor = '#dbdddf'
    }

    $ApplianceName = Get-AbrVbazApplianceName -Default $script:AbrVbazTarget
    $ServerInfo = @{}
    foreach ($Source in @(
            ($script:AbrVbazInventory.SystemServerInfo | Select-Object -First 1),
            ($script:AbrVbazInventory.SystemAbout | Select-Object -First 1),
            ($script:AbrVbazInventory.SystemStatus | Select-Object -First 1)
        )) {
        foreach ($Entry in (New-AbrVbazDiagramInfo -InputObject $Source -Properties @('serverVersion', 'workerVersion', 'flrVersion', 'azureRegionName', 'resourceGroup', 'state')).GetEnumerator()) {
            if (-not $ServerInfo.ContainsKey($Entry.Key)) {
                $ServerInfo[$Entry.Key] = $Entry.Value
            }
        }
    }

    $AccountCount = @($script:AbrVbazInventory.AzureServiceAccounts).Count + @($script:AbrVbazInventory.StandardAccounts).Count
    $SubscriptionCount = @($script:AbrVbazInventory.Subscriptions).Count
    # Count regions actually in use (repositories, workers, resource groups) rather than every Azure region known to the appliance.
    $InUseRegions = @(@($script:AbrVbazInventory.Repositories) + @($script:AbrVbazInventory.Workers) + @($script:AbrVbazInventory.ResourceGroups) | ForEach-Object {
            ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name @('regionName', 'region', 'location'))
        } | Where-Object { Test-AbrVbazDisplayValue -Value $_ } | Sort-Object -Unique)
    $RegionCount = @($InUseRegions).Count
    if ($RegionCount -eq 0) {
        $RegionCount = @($script:AbrVbazInventory.Regions).Count
    }
    $RepositoryCount = @($script:AbrVbazInventory.Repositories).Count + @($script:AbrVbazInventory.VeeamVaults).Count
    $WorkerCount = @($script:AbrVbazInventory.Workers).Count
    $PolicyCount = @($script:AbrVbazInventory.VmPolicies).Count + @($script:AbrVbazInventory.SlaVmPolicies).Count + @($script:AbrVbazInventory.FileSharePolicies).Count + @($script:AbrVbazInventory.SqlPolicies).Count + @($script:AbrVbazInventory.CosmosDbPolicies).Count + @($script:AbrVbazInventory.VnetPolicy).Count
    $ProtectedCount = @($script:AbrVbazInventory.ProtectedVirtualMachines).Count + @($script:AbrVbazInventory.ProtectedDatabases).Count + @($script:AbrVbazInventory.ProtectedFileShares).Count + @($script:AbrVbazInventory.ProtectedCosmosDbAccounts).Count + @($script:AbrVbazInventory.ProtectedVnet).Count
    $RestorePointCount = @($script:AbrVbazInventory.VmRestorePoints).Count + @($script:AbrVbazInventory.SqlRestorePoints).Count + @($script:AbrVbazInventory.FileShareRestorePoints).Count + @($script:AbrVbazInventory.CosmosRepositoryRestorePoints).Count + @($script:AbrVbazInventory.CosmosContinuousRestorePoints).Count + @($script:AbrVbazInventory.VnetRestorePoints).Count

    $AzureItems = @(
        New-AbrVbazDiagramSummaryItem -Name 'Azure Accounts' -Total $AccountCount -Info @{ 'Total' = $AccountCount } -IconType 'VBAZ_Azure_Account'
        New-AbrVbazDiagramSummaryItem -Name 'Subscriptions' -Total $SubscriptionCount -Info @{ 'Total' = $SubscriptionCount } -IconType 'VBAZ_Azure_Subscription'
        New-AbrVbazDiagramSummaryItem -Name 'Regions' -Total $RegionCount -Info @{ 'Total' = $RegionCount } -IconType 'VBAZ_Azure_Region'
    )

    $RepositoryItems = @($script:AbrVbazInventory.Repositories | ForEach-Object {
            New-AbrVbazDiagramItem -InputObject $_ -DefaultName 'Repository' -InfoProperties @('repositoryType', 'storageTier', 'regionName', 'status', 'immutabilityEnabled', 'enableEncryption') -IconType 'VBAZ_Repository'
        })
    $RepositoryItems += @($script:AbrVbazInventory.VeeamVaults | ForEach-Object {
            New-AbrVbazDiagramItem -InputObject $_ -DefaultName 'Veeam Vault' -InfoProperties @('regionName', 'status', 'state', 'capacity', 'usedSpace') -IconType 'VBAZ_DataVault'
        })

    $WorkerItems = @($script:AbrVbazInventory.Workers | ForEach-Object {
            New-AbrVbazDiagramItem -InputObject $_ -DefaultName 'Worker' -InfoProperties @('region', 'regionId', 'instanceType', 'profile', 'status')
        })
    if (-not $WorkerItems) {
        $WorkerItems = @(
            New-AbrVbazDiagramSummaryItem -Name 'Workers' -Total $WorkerCount -Info @{ 'Total' = $WorkerCount }
        )
    }

    $PolicyItems = @(
        New-AbrVbazDiagramSummaryItem -Name 'VM Policies' -Total @($script:AbrVbazInventory.VmPolicies).Count -Info @{ 'Total' = @($script:AbrVbazInventory.VmPolicies).Count }
        New-AbrVbazDiagramSummaryItem -Name 'SLA VM Policies' -Total @($script:AbrVbazInventory.SlaVmPolicies).Count -Info @{ 'Total' = @($script:AbrVbazInventory.SlaVmPolicies).Count }
        New-AbrVbazDiagramSummaryItem -Name 'SQL Policies' -Total @($script:AbrVbazInventory.SqlPolicies).Count -Info @{ 'Total' = @($script:AbrVbazInventory.SqlPolicies).Count }
        New-AbrVbazDiagramSummaryItem -Name 'File Share Policies' -Total @($script:AbrVbazInventory.FileSharePolicies).Count -Info @{ 'Total' = @($script:AbrVbazInventory.FileSharePolicies).Count }
        New-AbrVbazDiagramSummaryItem -Name 'Cosmos DB Policies' -Total @($script:AbrVbazInventory.CosmosDbPolicies).Count -Info @{ 'Total' = @($script:AbrVbazInventory.CosmosDbPolicies).Count }
        New-AbrVbazDiagramSummaryItem -Name 'VNet Policy' -Total @($script:AbrVbazInventory.VnetPolicy).Count -Info @{ 'Total' = @($script:AbrVbazInventory.VnetPolicy).Count }
    ) | Where-Object { $_.Total -gt 0 }

    $ProtectedItems = @(
        New-AbrVbazDiagramSummaryItem -Name 'Virtual Machines' -Total @($script:AbrVbazInventory.ProtectedVirtualMachines).Count -Info @{ 'Total' = @($script:AbrVbazInventory.ProtectedVirtualMachines).Count } -IconType 'VBAZ_Workload_VM'
        New-AbrVbazDiagramSummaryItem -Name 'SQL Databases' -Total @($script:AbrVbazInventory.ProtectedDatabases).Count -Info @{ 'Total' = @($script:AbrVbazInventory.ProtectedDatabases).Count } -IconType 'VBAZ_Workload_SQL'
        New-AbrVbazDiagramSummaryItem -Name 'File Shares' -Total @($script:AbrVbazInventory.ProtectedFileShares).Count -Info @{ 'Total' = @($script:AbrVbazInventory.ProtectedFileShares).Count } -IconType 'VBAZ_Workload_FileShare'
        New-AbrVbazDiagramSummaryItem -Name 'Cosmos DB Accounts' -Total @($script:AbrVbazInventory.ProtectedCosmosDbAccounts).Count -Info @{ 'Total' = @($script:AbrVbazInventory.ProtectedCosmosDbAccounts).Count } -IconType 'VBAZ_Workload_CosmosDb'
        New-AbrVbazDiagramSummaryItem -Name 'Virtual Networks' -Total @($script:AbrVbazInventory.ProtectedVnet).Count -Info @{ 'Total' = @($script:AbrVbazInventory.ProtectedVnet).Count } -IconType 'VBAZ_Workload_VNet'
    ) | Where-Object { $_.Total -gt 0 }

    $RestorePointItems = @(
        New-AbrVbazDiagramSummaryItem -Name 'VM Restore Points' -Total @($script:AbrVbazInventory.VmRestorePoints).Count -Info @{ 'Total' = @($script:AbrVbazInventory.VmRestorePoints).Count }
        New-AbrVbazDiagramSummaryItem -Name 'SQL Restore Points' -Total @($script:AbrVbazInventory.SqlRestorePoints).Count -Info @{ 'Total' = @($script:AbrVbazInventory.SqlRestorePoints).Count }
        New-AbrVbazDiagramSummaryItem -Name 'File Share Restore Points' -Total @($script:AbrVbazInventory.FileShareRestorePoints).Count -Info @{ 'Total' = @($script:AbrVbazInventory.FileShareRestorePoints).Count }
        New-AbrVbazDiagramSummaryItem -Name 'Cosmos DB Restore Points' -Total (@($script:AbrVbazInventory.CosmosRepositoryRestorePoints).Count + @($script:AbrVbazInventory.CosmosContinuousRestorePoints).Count) -Info @{ 'Total' = (@($script:AbrVbazInventory.CosmosRepositoryRestorePoints).Count + @($script:AbrVbazInventory.CosmosContinuousRestorePoints).Count) }
        New-AbrVbazDiagramSummaryItem -Name 'VNet Restore Points' -Total @($script:AbrVbazInventory.VnetRestorePoints).Count -Info @{ 'Total' = @($script:AbrVbazInventory.VnetRestorePoints).Count }
    ) | Where-Object { $_.Total -gt 0 }

    & {
        Node Appliance @{
            Label = (Add-NodeIcon -AditionalInfo $ServerInfo -ImagesObj $script:Images -Name (ConvertTo-AbrVbazDiagramValue -InputObject $ApplianceName) -IconType 'VBAZ_Server' -Align 'Center' -IconDebug $IconDebug -FontSize 22 -FontColor $Fontcolor -TableBackgroundColor $ApplianceBGColor -CellBackgroundColor $ApplianceBGColor)
            shape = 'plain'
            fillColor = 'transparent'
            fontsize = 18
            fontname = 'Segoe Ui'
        }

        New-AbrVbazDiagramNodeTable -NodeName AzureScope -Label 'Azure Scope' -Items $AzureItems -IconType 'VBAZ_Azure' -SubgraphIconType 'VBAZ_Azure' -ColumnSize 3 -Fontcolor $Fontcolor -TableBorderColor $TableBorderColor -MainGraphBGColor $MainGraphBGColor -IconDebug $IconDebug
        New-AbrVbazDiagramNodeTable -NodeName Repositories -Label 'Backup Storage' -Items $RepositoryItems -IconType 'VBAZ_Repository' -SubgraphIconType 'VBAZ_Repository' -ColumnSize 2 -Fontcolor $Fontcolor -TableBorderColor $TableBorderColor -MainGraphBGColor $MainGraphBGColor -IconDebug $IconDebug
        New-AbrVbazDiagramNodeTable -NodeName Workers -Label 'Worker Infrastructure' -Items $WorkerItems -IconType 'VBAZ_Worker' -SubgraphIconType 'VBAZ_Worker' -ColumnSize 3 -Fontcolor $Fontcolor -TableBorderColor $TableBorderColor -MainGraphBGColor $MainGraphBGColor -IconDebug $IconDebug
        New-AbrVbazDiagramNodeTable -NodeName Policies -Label 'Protection Policies' -Items $PolicyItems -IconType 'VBAZ_Policy' -SubgraphIconType 'VBAZ_Policy' -ColumnSize 3 -Fontcolor $Fontcolor -TableBorderColor $TableBorderColor -MainGraphBGColor $MainGraphBGColor -IconDebug $IconDebug
        New-AbrVbazDiagramNodeTable -NodeName ProtectedWorkloads -Label 'Protected Workloads' -Items $ProtectedItems -IconType 'VBAZ_Workload' -SubgraphIconType 'VBAZ_Workload' -ColumnSize 3 -Fontcolor $Fontcolor -TableBorderColor $TableBorderColor -MainGraphBGColor $MainGraphBGColor -IconDebug $IconDebug
        New-AbrVbazDiagramNodeTable -NodeName RestorePoints -Label 'Restore Points' -Items $RestorePointItems -IconType 'VBAZ_RestorePoint' -SubgraphIconType 'VBAZ_RestorePoint' -ColumnSize 3 -Fontcolor $Fontcolor -TableBorderColor $TableBorderColor -MainGraphBGColor $MainGraphBGColor -IconDebug $IconDebug

        Edge -From Appliance -To AzureScope @{ Label = 'authenticates / discovers'; color = $Edgecolor; fontcolor = $Fontcolor; penwidth = 2 }
        Edge -From AzureScope -To Workers @{ Label = 'deploys'; color = $Edgecolor; fontcolor = $Fontcolor; penwidth = 2 }
        Edge -From AzureScope -To Repositories @{ Label = 'stores backups'; color = $Edgecolor; fontcolor = $Fontcolor; penwidth = 2 }
        Edge -From Appliance -To Policies @{ Label = 'manages'; color = $Edgecolor; fontcolor = $Fontcolor; penwidth = 2 }
        Edge -From Policies -To Workers @{ Label = 'uses'; color = $Edgecolor; fontcolor = $Fontcolor; penwidth = 2 }
        Edge -From Policies -To Repositories @{ Label = 'targets'; color = $Edgecolor; fontcolor = $Fontcolor; penwidth = 2 }
        Edge -From Policies -To ProtectedWorkloads @{ Label = "protects $ProtectedCount"; color = $Edgecolor; fontcolor = $Fontcolor; penwidth = 2 }
        Edge -From ProtectedWorkloads -To RestorePoints @{ Label = "creates $RestorePointCount"; color = $Edgecolor; fontcolor = $Fontcolor; penwidth = 2 }
    }
}

function Export-AbrVbazDiagram {
    [CmdletBinding()]
    param ()

    Write-PScriboMessage -Message "EnableDiagrams set to $($Options.EnableDiagrams)."
    if (-not $Options.EnableDiagrams) {
        return
    }

    $LocalizedData = $reportTranslate.ExportAbrVbazDiagram

    $script:Images = @{
        'VBAZ_Server' = 'Veeam_Appliance.png'
        'VBAZ_Azure' = 'Microsoft_Azure.png'
        'VBAZ_Azure_Account' = 'Azure_Account.png'
        'VBAZ_Azure_Subscription' = 'Azure_Subscription.png'
        'VBAZ_Azure_Region' = 'Azure_Resource_Group.png'
        'VBAZ_Repository' = 'Microsoft_Azure_Blob_Storage.png'
        'VBAZ_DataVault' = 'Veeam_Cloud_Connect.png'
        'VBAZ_Worker' = 'Worker_Proxy.png'
        'VBAZ_Policy' = 'Protection_Policy.png'
        'VBAZ_Workload' = 'Protected_Workloads.png'
        'VBAZ_Workload_VM' = 'VMware.png'
        'VBAZ_Workload_SQL' = 'MS_SQL.png'
        'VBAZ_Workload_FileShare' = 'File_Share.png'
        'VBAZ_Workload_CosmosDb' = 'Cosmos_DB.png'
        'VBAZ_Workload_VNet' = 'Veeam_PN.png'
        'VBAZ_RestorePoint' = 'Restore_Point.png'
        'VBAZ_No_Icon' = 'no_icon.png'
        'VBAZ_LOGO' = 'Veeam_logo_new.png'
        'VBAZ_LOGO_Footer' = 'verified_recoverability.png'
    }

    $RootPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    [System.IO.FileInfo]$IconPath = Join-Path $RootPath 'icons'

    $DiagramParams = @{
        FileName = 'AsBuiltReport.Veeam.VBAZ'
        OutputFolderPath = $OutputFolderPath
        Direction = 'top-to-bottom'
        MainDiagramLabel = 'Backup for Microsoft Azure'
        MainDiagramLabelFontsize = 38
        MainDiagramLabelFontcolor = '#565656'
        MainDiagramLabelFontname = 'Segoe UI Black'
        IconPath = $IconPath
        ImagesObj = $script:Images
        LogoName = 'VBAZ_LOGO'
        SignatureLogoName = 'VBAZ_LOGO_Footer'
        WaterMarkText = $Options.DiagramWaterMark
    }

    if ($Options.DiagramTheme -eq 'Black') {
        $DiagramParams['MainGraphBGColor'] = 'Black'
        $DiagramParams['Edgecolor'] = 'White'
        $DiagramParams['Fontcolor'] = 'White'
        $DiagramParams['NodeFontcolor'] = 'White'
        $DiagramParams['WaterMarkColor'] = 'White'
    } elseif ($Options.DiagramTheme -eq 'Neon') {
        $DiagramParams['MainGraphBGColor'] = 'grey14'
        $DiagramParams['Edgecolor'] = 'gold2'
        $DiagramParams['Fontcolor'] = 'gold2'
        $DiagramParams['NodeFontcolor'] = 'gold2'
        $DiagramParams['WaterMarkColor'] = '#FFD700'
    } else {
        $DiagramParams['WaterMarkColor'] = 'DarkGreen'
    }

    if ($Options.EnableDiagramDebug) {
        $DiagramParams['DraftMode'] = $true
    }
    if ($Options.EnableDiagramSignature) {
        $DiagramParams['Signature'] = $true
        $DiagramParams['AuthorName'] = $Options.SignatureAuthorName
        $DiagramParams['CompanyName'] = $Options.SignatureCompanyName
    }

    try {
        # The main diagram logo (Veeam logo and title at the top) is shown by default and can be
        # turned off by setting Options.EnableDiagramLogo to false in the report JSON.
        $DisableMainLogo = ($Options.EnableDiagramLogo -eq $false)

        if ($Options.ExportDiagrams) {
            $DiagramParams['Format'] = if ($Options.ExportDiagramsFormat) { $Options.ExportDiagramsFormat } else { 'png' }
            [void](New-AbrDiagram @DiagramParams -InputObject (Get-AbrVbazDiagram) -MainGraphLogoSizePercent 50 -DisableMainDiagramLogo:$DisableMainLogo)
        }

        $DiagramParams['Format'] = 'base64'
        $Diagram = New-AbrDiagram @DiagramParams -InputObject (Get-AbrVbazDiagram) -MainGraphLogoSizePercent 50 -DisableMainDiagramLogo:$DisableMainLogo
        if ($Diagram) {
            $BestAspectRatio = Get-BestImageAspectRatio -GraphObj $Diagram -MaxWidth 650 -MaxHeight 500
            Section -Style Heading2 $LocalizedData.Heading {
                Image -Base64 $Diagram -Text 'Veeam Backup for Microsoft Azure Diagram' -Width $BestAspectRatio.Width -Height $BestAspectRatio.Height -Align Center
            }
        }
    } catch {
        $Message = ($LocalizedData.DiagramError -f $_.Exception.Message)
        Write-PScriboMessage -IsWarning -Message $Message
        Section -Style Heading2 $LocalizedData.Heading {
            Paragraph $Message
        }
    }
}

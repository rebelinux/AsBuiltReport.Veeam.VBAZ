function Initialize-AbrVbazTls {
    [CmdletBinding()]
    param ()

    if ($script:AbrVbazTlsInitialized) {
        return
    }

    if ($Options.SkipCertificateCheck -and $PSVersionTable.PSEdition -ne 'Core') {
        if (-not ([System.Management.Automation.PSTypeName]'AbrVbazTrustAllCertsPolicy').Type) {
            Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class AbrVbazTrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
        }
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object AbrVbazTrustAllCertsPolicy
    }

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    $script:AbrVbazTlsInitialized = $true
}

function Connect-AbrVbazApi {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Target,

        [Parameter(Mandatory)]
        [PSCredential] $Credential
    )

    Initialize-AbrVbazTls

    $script:AbrVbazTarget = $Target
    $script:AbrVbazPort = if ($Options.ApiPort) { [int]$Options.ApiPort } else { 11005 }
    $script:AbrVbazApiVersion = if ($Options.ApiVersion) { [string]$Options.ApiVersion } else { 'v8.1' }
    $script:AbrVbazBaseUri = "https://$($Target):$($script:AbrVbazPort)/api/$($script:AbrVbazApiVersion)"

    $TokenUri = "https://$($Target):$($script:AbrVbazPort)/api/oauth2/token"
    Write-PScriboMessage -Message "Authenticating to VBAZ REST API token endpoint '$TokenUri'."
    $Body = @{
        grant_type = 'password'
        username = $Credential.UserName
        password = $Credential.GetNetworkCredential().Password
    }
    $Params = @{
        Method = 'Post'
        Uri = $TokenUri
        Body = $Body
        ContentType = 'application/x-www-form-urlencoded'
        ErrorAction = 'Stop'
    }
    if ($Options.SkipCertificateCheck -and (Get-Command Invoke-RestMethod).Parameters.ContainsKey('SkipCertificateCheck')) {
        $Params['SkipCertificateCheck'] = $true
    }

    $TokenResponse = Invoke-RestMethod @Params
    $AccessToken = Get-AbrVbazPropertyValue -InputObject $TokenResponse -Name 'access_token'
    if (-not $AccessToken) {
        throw 'Authentication succeeded but no access_token was returned.'
    }

    $script:AbrVbazHeaders = @{
        Authorization = "Bearer $AccessToken"
        Accept = 'application/json'
    }
}

function Disconnect-AbrVbazApi {
    [CmdletBinding()]
    param ()

    $script:AbrVbazHeaders = $null
    $script:AbrVbazInventory = $null
}

function Invoke-AbrVbazRestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Path,

        [hashtable] $Query
    )

    $UriBuilder = [System.UriBuilder]::new("$($script:AbrVbazBaseUri)$Path")
    if ($Query -and $Query.Count -gt 0) {
        $QueryPairs = foreach ($Key in $Query.Keys) {
            if ($null -ne $Query[$Key] -and $Query[$Key] -ne '') {
                '{0}={1}' -f [uri]::EscapeDataString([string]$Key), [uri]::EscapeDataString([string]$Query[$Key])
            }
        }
        $UriBuilder.Query = ($QueryPairs -join '&')
    }

    $Params = @{
        Method = 'Get'
        Uri = $UriBuilder.Uri.AbsoluteUri
        Headers = $script:AbrVbazHeaders
        ErrorAction = 'Stop'
    }
    if ($Options.SkipCertificateCheck -and (Get-Command Invoke-RestMethod).Parameters.ContainsKey('SkipCertificateCheck')) {
        $Params['SkipCertificateCheck'] = $true
    }

    try {
        Invoke-RestMethod @Params
    } catch {
        Write-PScriboMessage -IsWarning -Message "GET $Path failed: $($_.Exception.Message)"
        $null
    }
}

function Get-AbrVbazObjectCollection {
    [CmdletBinding()]
    [OutputType([object[]], [array])]
    param (
        $InputObject
    )

    if ($null -eq $InputObject) {
        return @()
    }

    $HasResponse = [bool]$InputObject.PSObject.Properties['response']
    $HasResponseBody = [bool]$InputObject.PSObject.Properties['responseBody']
    if ($HasResponse -and $InputObject.response) {
        $InputObject = $InputObject.response
    } elseif ($HasResponseBody -and $InputObject.responseBody) {
        $InputObject = $InputObject.responseBody
    } elseif ($HasResponse -or $HasResponseBody) {
        # Capture envelope with an empty response body (e.g. an unconfigured endpoint).
        # Return nothing rather than leaking the collector envelope metadata as data.
        return @()
    }

    foreach ($PropertyName in @('results', 'items', 'data', 'value', 'resources', 'restorePoints', 'policies', 'sessions')) {
        $Property = $InputObject.PSObject.Properties[$PropertyName]
        if ($Property -and $null -ne $Property.Value) {
            return @($Property.Value)
        }
    }

    if ($InputObject -is [array]) {
        return @($InputObject)
    }

    @($InputObject)
}

function Get-AbrVbazCollection {
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [Parameter(Mandatory)]
        [string] $Path,

        [hashtable] $Query
    )

    $PageSize = if ($Options.PageSize) { [int]$Options.PageSize } else { 500 }
    $AllItems = @()
    $Offset = 0
    $UsePaging = $true

    do {
        $CurrentQuery = @{}
        if ($Query) {
            foreach ($Key in $Query.Keys) {
                $CurrentQuery[$Key] = $Query[$Key]
            }
        }
        if ($UsePaging) {
            $CurrentQuery['limit'] = $PageSize
            $CurrentQuery['offset'] = $Offset
        }

        $Response = Invoke-AbrVbazRestMethod -Path $Path -Query $CurrentQuery
        $Items = @(Get-AbrVbazObjectCollection -InputObject $Response)
        if ($Items.Count -eq 1 -and $Items[0] -eq $Response -and $Offset -eq 0) {
            return $Items
        }

        $AllItems += $Items
        $Offset += $PageSize

        $Total = Get-AbrVbazPropertyValue -InputObject $Response -Name 'totalCount'
        if (-not $Total) {
            $Total = Get-AbrVbazPropertyValue -InputObject $Response -Name 'total'
        }

        if ($Total) {
            $Continue = $AllItems.Count -lt [int]$Total
        } else {
            $Continue = $Items.Count -eq $PageSize
        }
    } while ($UsePaging -and $Continue)

    $AllItems
}

function Get-AbrVbazPropertyValue {
    [CmdletBinding()]
    param (
        $InputObject,
        [Parameter(Mandatory)]
        [string[]] $Name,
        $Default = $null
    )

    if ($null -eq $InputObject) {
        return $Default
    }

    foreach ($Candidate in $Name) {
        $Property = $InputObject.PSObject.Properties | Where-Object { $_.Name -ieq $Candidate } | Select-Object -First 1
        if ($Property) {
            $Value = $Property.Value
            if ($null -ne $Value -and -not ($Value -is [string] -and $Value -eq '')) {
                return $Value
            }
        }
    }

    $Default
}

function ConvertTo-AbrVbazDisplayValue {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        $InputObject,
        [string] $Default = '--'
    )

    if ($null -eq $InputObject -or ($InputObject -is [string] -and $InputObject -eq '')) {
        return $Default
    }
    if ($InputObject -is [bool]) {
        if ($InputObject) { return 'Yes' } else { return 'No' }
    }
    if ($InputObject -is [datetime]) {
        return $InputObject.ToString('u')
    }
    if ($InputObject -is [array]) {
        if ($InputObject.Count -eq 0) {
            return $Default
        }
        return (($InputObject | ForEach-Object { ConvertTo-AbrVbazDisplayValue -InputObject $_ -Default $Default }) -join ', ')
    }
    if ($InputObject -is [pscustomobject] -or $InputObject -is [hashtable]) {
        $Summary = ConvertTo-AbrVbazObjectSummary -InputObject $InputObject
        if ($Summary) {
            return $Summary
        }
        foreach ($Name in @('name', 'displayName', 'currentOwnerName', 'id', 'status', 'state', 'type')) {
            $Value = Get-AbrVbazPropertyValue -InputObject $InputObject -Name $Name
            if ($Value) {
                return [string]$Value
            }
        }
        return ($InputObject | ConvertTo-Json -Compress -Depth 6)
    }

    if ($InputObject -is [double] -or $InputObject -is [decimal] -or $InputObject -is [single]) {
        $Decimal = [decimal]$InputObject
        if ([math]::Truncate($Decimal) -eq $Decimal) {
            return [string][long]$Decimal
        }
        return [string]$InputObject
    }

    [string]$InputObject
}

function ConvertTo-AbrVbazObjectSummary {
    [CmdletBinding()]
    param (
        $InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $CurrentOwnerName = Get-AbrVbazPropertyValue -InputObject $InputObject -Name 'currentOwnerName'
    if (Test-AbrVbazDisplayValue -Value $CurrentOwnerName) {
        $OwnerParts = @("Owner: $CurrentOwnerName")
        $HasAnotherOwnerProperty = $InputObject.PSObject.Properties | Where-Object { $_.Name -ieq 'hasAnotherOwner' } | Select-Object -First 1
        if ($HasAnotherOwnerProperty) {
            $OwnerParts += "Another Owner: $(ConvertTo-AbrVbazDisplayValue -InputObject $HasAnotherOwnerProperty.Value)"
        }
        return ($OwnerParts -join '; ')
    }

    $Pairs = [ordered]@{}
    foreach ($PropertyName in @(
            'productName', 'productVersion', 'flrVersion',
            'dailyType', 'selectedDays', 'dailyTime',
            'timeRetentionDuration', 'retentionDurationType',
            'currentOwnerName', 'currentOwnerIdentifier', 'hasAnotherOwner'
        )) {
        $Value = Get-AbrVbazPropertyValue -InputObject $InputObject -Name $PropertyName
        if (Test-AbrVbazDisplayValue -Value $Value) {
            $Pairs[(Format-AbrVbazPropertyLabel -Name $PropertyName)] = ConvertTo-AbrVbazDisplayValue -InputObject $Value
        }
    }

    if ($Pairs.Count -eq 0) {
        return $null
    }

    ($Pairs.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join '; '
}

function ConvertTo-AbrVbazByteSize {
    [CmdletBinding()]
    param (
        $Value
    )

    if (-not (Test-AbrVbazDisplayValue -Value $Value)) {
        return $null
    }

    try {
        $Bytes = [double]$Value
    } catch {
        return ConvertTo-AbrVbazDisplayValue -InputObject $Value
    }

    $Units = @('B', 'KB', 'MB', 'GB', 'TB', 'PB')
    $Index = 0
    while ($Bytes -ge 1024 -and $Index -lt ($Units.Count - 1)) {
        $Bytes = $Bytes / 1024
        $Index++
    }
    '{0:N1} {1}' -f $Bytes, $Units[$Index]
}

function ConvertTo-AbrVbazSizeFromUnit {
    [CmdletBinding()]
    param (
        $Value,
        [ValidateSet('MB', 'GB')]
        [string] $Unit
    )

    if (-not (Test-AbrVbazDisplayValue -Value $Value)) {
        return $null
    }

    try {
        $Number = [double]$Value
    } catch {
        return ConvertTo-AbrVbazDisplayValue -InputObject $Value
    }

    $Factor = if ($Unit -eq 'GB') { 1GB } else { 1MB }
    ConvertTo-AbrVbazByteSize -Value ($Number * $Factor)
}

function ConvertTo-AbrVbazDuration {
    [CmdletBinding()]
    param (
        $Value
    )

    if (-not (Test-AbrVbazDisplayValue -Value $Value)) {
        return $null
    }

    try {
        $Seconds = [double]$Value
        if ($Seconds -gt 1000000) {
            $Seconds = $Seconds / 1000
        }
        return ([timespan]::FromSeconds($Seconds)).ToString()
    } catch {
        return ConvertTo-AbrVbazDisplayValue -InputObject $Value
    }
}

function Get-AbrVbazServerTimeZoneLabel {
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    $TimeSource = @($script:AbrVbazInventory.SystemTime + $script:AbrVbazInventory.SystemServerInfo) | Where-Object { $_ } | Select-Object -First 1
    $TimeZoneId = Get-AbrVbazPropertyValue -InputObject $TimeSource -Name @('timeZoneId', 'timezoneId', 'timeZone', 'timezone')
    if (-not (Test-AbrVbazDisplayValue -Value $TimeZoneId)) {
        $TimeZoneId = [System.TimeZoneInfo]::Local.Id
    }

    switch -Regex ([string]$TimeZoneId) {
        'AUS Eastern|Australia/Sydney|AEST|AEDT' { return 'AEST/AEDT' }
        'UTC|Coordinated Universal' { return 'UTC' }
        default {
            if ([string]$TimeZoneId -match 'Standard Time$') {
                return ([string]$TimeZoneId -replace '\s*Standard Time$', '')
            }
            return [string]$TimeZoneId
        }
    }
}

function Test-AbrVbazDateTimeProperty {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [string] $Name
    )

    if ($Name -match '(?i)(duration|retention|count|days|months|size|status|state|result|cycle|timeZone)') {
        return $false
    }

    $Name -match '(?i)(time|date|lastBackupTime|lastBackup$|pointInTime|lastRun|nextRun)'
}

function Get-AbrVbazDateTimeZoneLabel {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [string] $Name,
        $Value
    )

    $StringValue = [string]$Value
    if ($Name -match '(?i)utc' -or $StringValue -match '(?i)Z$') {
        return 'UTC'
    }
    if ($Name -match '(?i)local' -or $StringValue -match '(?i)[+-]\d{2}:\d{2}$') {
        return (Get-AbrVbazServerTimeZoneLabel)
    }
    Get-AbrVbazServerTimeZoneLabel
}

function ConvertTo-AbrVbazDateTimeDisplayValue {
    [CmdletBinding()]
    param (
        $InputObject
    )

    if (-not (Test-AbrVbazDisplayValue -Value $InputObject)) {
        return $null
    }

    try {
        $DateTimeOffset = [datetimeoffset]::Parse([string]$InputObject, [System.Globalization.CultureInfo]::InvariantCulture)
        return $DateTimeOffset.ToString('yyyy-MM-dd HH:mm:ss')
    } catch {
        return ConvertTo-AbrVbazDisplayValue -InputObject $InputObject
    }
}

function ConvertTo-AbrVbazTableValue {
    [CmdletBinding()]
    param (
        [string] $PropertyName,
        $Value
    )

    if (Test-AbrVbazDateTimeProperty -Name $PropertyName) {
        return ConvertTo-AbrVbazDateTimeDisplayValue -InputObject $Value
    }
    if ($PropertyName -match '(?i)(bytes|sizeInBytes|backupSizeBytes)$') {
        return ConvertTo-AbrVbazByteSize -Value $Value
    }
    if ($PropertyName -match '(?i)sizeInMb$') {
        return ConvertTo-AbrVbazSizeFromUnit -Value $Value -Unit MB
    }
    if ($PropertyName -match '(?i)(sizeInGb|totalSizeInGb)$') {
        return ConvertTo-AbrVbazSizeFromUnit -Value $Value -Unit GB
    }
    ConvertTo-AbrVbazDisplayValue -InputObject $Value
}

function Format-AbrVbazTablePropertyLabel {
    [CmdletBinding()]
    param (
        [string] $PropertyName,
        $Value
    )

    $Label = Format-AbrVbazPropertyLabel -Name $PropertyName
    if ($PropertyName -ieq 'lastBackup') {
        $Label = 'Last Backup Time'
    } elseif ($PropertyName -ieq 'pointInTime') {
        $Label = 'Point In Time'
    } elseif ($PropertyName -ieq 'sizeInBytes') {
        $Label = 'Size'
    } elseif ($PropertyName -ieq 'backupSizeBytes') {
        $Label = 'Backup Size'
    } elseif ($PropertyName -ieq 'sizeInMb' -or $PropertyName -ieq 'sizeInGB') {
        $Label = 'Size'
    } elseif ($PropertyName -ieq 'totalSizeInGB') {
        $Label = 'Total Size'
    }

    $Label = $Label -replace '\s+Utc$', ''
    if (Test-AbrVbazDateTimeProperty -Name $PropertyName) {
        $Label = "$Label ($(Get-AbrVbazDateTimeZoneLabel -Name $PropertyName -Value $Value))"
    } elseif ($PropertyName -match '(?i)(bytes|sizeInBytes|backupSizeBytes)$') {
        $Label = ($Label -replace '\s*Bytes$', '')
    }
    $Label
}

function Test-AbrVbazDisplayValue {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        $Value
    )

    if ($null -eq $Value) {
        return $false
    }

    $DisplayValue = [string](ConvertTo-AbrVbazDisplayValue -InputObject $Value)
    if ([string]::IsNullOrWhiteSpace($DisplayValue)) {
        return $false
    }

    $DisplayValue -notin @('--', '[]', '{}', 'null')
}

function Format-AbrVbazPropertyLabel {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Name
    )

    if (-not $script:TextInfo) {
        $script:TextInfo = (Get-Culture).TextInfo
    }

    $Label = ($Name -creplace '([A-Z]+)([A-Z][a-z])', '$1 $2') -creplace '([a-z0-9])([A-Z])', '$1 $2'
    $Label = $Label -replace '_', ' '
    $Label = $script:TextInfo.ToTitleCase($Label.ToLowerInvariant())

    # Re-case acronyms and initialisms that ToTitleCase down-cases (e.g. "Vbr" -> "VBR").
    $Acronyms = [ordered]@{
        Ids = 'IDs'; Id = 'ID'; Vms = 'VMs'; Vm = 'VM'; Vnets = 'VNets'; Vnet = 'VNet'
        Sql = 'SQL'; Flr = 'FLR'; Vbr = 'VBR'; Os = 'OS'; Ip = 'IP'; Dbs = 'DBs'; Db = 'DB'
        Mb = 'MB'; Gb = 'GB'; Kb = 'KB'; Tb = 'TB'; Pb = 'PB'; Utc = 'UTC'; Mfa = 'MFA'
        Cpu = 'CPU'; Sla = 'SLA'; Nsgs = 'NSGs'; Nsg = 'NSG'; Saml = 'SAML'; Idp = 'IdP'
        Rpo = 'RPO'; Url = 'URL'; Api = 'API'; Gfs = 'GFS'; Dns = 'DNS'
    }
    foreach ($Key in $Acronyms.Keys) {
        $Label = $Label -replace "\b$Key\b", $Acronyms[$Key]
    }
    $Label
}

function ConvertTo-AbrVbazTableObject {
    [CmdletBinding()]
    param (
        $InputObject,
        [string[]] $PreferredProperties
    )

    $Output = [ordered]@{}
    foreach ($PropertyName in $PreferredProperties) {
        $Value = Get-AbrVbazPropertyValue -InputObject $InputObject -Name $PropertyName
        if (Test-AbrVbazDisplayValue -Value $Value) {
            $Output[(Format-AbrVbazTablePropertyLabel -PropertyName $PropertyName -Value $Value)] = ConvertTo-AbrVbazTableValue -PropertyName $PropertyName -Value $Value
        }
    }

    if ($Output.Count -lt 3 -and $InputObject) {
        $SkippedFallbackProperties = @('links', '_links', 'embedded', '_embedded', 'href', 'rel')
        foreach ($Property in $InputObject.PSObject.Properties | Where-Object { $_.Name -notin $SkippedFallbackProperties } | Select-Object -First 16) {
            $Label = Format-AbrVbazPropertyLabel -Name $Property.Name
            if (-not $Output.Contains($Label) -and (Test-AbrVbazDisplayValue -Value $Property.Value)) {
                $Output[(Format-AbrVbazTablePropertyLabel -PropertyName $Property.Name -Value $Property.Value)] = ConvertTo-AbrVbazTableValue -PropertyName $Property.Name -Value $Property.Value
            }
        }
    }

    [pscustomobject]$Output
}

function ConvertTo-AbrVbazVmPolicyTableObject {
    [CmdletBinding()]
    param (
        $InputObject
    )

    $Output = [ordered]@{}
    foreach ($PropertyName in @('name', 'priority', 'isEnabled', 'backupType', 'snapshotStatus', 'backupStatus')) {
        $Value = Get-AbrVbazPropertyValue -InputObject $InputObject -Name $PropertyName
        if (Test-AbrVbazDisplayValue -Value $Value) {
            $Output[(Format-AbrVbazPropertyLabel -Name $PropertyName)] = ConvertTo-AbrVbazDisplayValue -InputObject $Value
        }
    }

    $ArchiveConfigured = Get-AbrVbazPropertyValue -InputObject $InputObject -Name 'isArchiveBackupConfigured'
    if ($ArchiveConfigured -eq $true) {
        $ArchiveStatus = Get-AbrVbazPropertyValue -InputObject $InputObject -Name 'archiveStatus'
        if (Test-AbrVbazDisplayValue -Value $ArchiveStatus) {
            $Output['Archive Status'] = ConvertTo-AbrVbazDisplayValue -InputObject $ArchiveStatus
        }
    }

    foreach ($PropertyName in @('healthCheckStatus', 'indexingStatus', 'nextExecutionTime')) {
        $Value = Get-AbrVbazPropertyValue -InputObject $InputObject -Name $PropertyName
        if (Test-AbrVbazDisplayValue -Value $Value) {
            $Output[(Format-AbrVbazPropertyLabel -Name $PropertyName)] = ConvertTo-AbrVbazDisplayValue -InputObject $Value
        }
    }

    $BackupType = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $InputObject -Name 'backupType') -Default ''
    if ($BackupType -notmatch 'selected\s*items?') {
        $ExcludedItemsCount = Get-AbrVbazPropertyValue -InputObject $InputObject -Name 'excludedItemsCount'
        if (Test-AbrVbazDisplayValue -Value $ExcludedItemsCount) {
            $Output['Excluded Items Count'] = ConvertTo-AbrVbazDisplayValue -InputObject $ExcludedItemsCount
        }
    }

    [pscustomobject]$Output
}

function Add-AbrVbazRestorePointValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary] $Output,
        [Parameter(Mandatory)]
        [string] $Label,
        $InputObject,
        [Parameter(Mandatory)]
        [string[]] $Names,
        [ValidateSet('Default', 'DateTime', 'Size')]
        [string] $Type = 'Default'
    )

    $Value = Get-AbrVbazPropertyValue -InputObject $InputObject -Name $Names
    if (-not (Test-AbrVbazDisplayValue -Value $Value)) {
        return
    }

    if ($Type -eq 'DateTime') {
        $Output["$Label ($(Get-AbrVbazDateTimeZoneLabel -Name $Names[0] -Value $Value))"] = ConvertTo-AbrVbazDateTimeDisplayValue -InputObject $Value
    } elseif ($Type -eq 'Size') {
        $Output[$Label] = ConvertTo-AbrVbazByteSize -Value $Value
    } else {
        $Output[$Label] = ConvertTo-AbrVbazDisplayValue -InputObject $Value
    }
}

function ConvertTo-AbrVbazRestorePointTableObject {
    [CmdletBinding()]
    param (
        $InputObject,
        [Parameter(Mandatory)]
        [ValidateSet('VirtualMachine', 'SQL', 'FileShare', 'CosmosDb', 'VNet')]
        [string] $WorkloadType
    )

    $Output = [ordered]@{}
    switch ($WorkloadType) {
        'VirtualMachine' {
            Add-AbrVbazRestorePointValue -Output $Output -Label 'Virtual Machine' -InputObject $InputObject -Names @('vmName', 'name')
        }
        'SQL' {
            Add-AbrVbazRestorePointValue -Output $Output -Label 'Database' -InputObject $InputObject -Names @('databaseName', 'name')
            Add-AbrVbazRestorePointValue -Output $Output -Label 'SQL Server' -InputObject $InputObject -Names @('sqlServerName', 'serverName', 'sqlServer')
        }
        'FileShare' {
            Add-AbrVbazRestorePointValue -Output $Output -Label 'File Share' -InputObject $InputObject -Names @('fileShareName', 'name')
        }
        'CosmosDb' {
            Add-AbrVbazRestorePointValue -Output $Output -Label 'Cosmos DB Account' -InputObject $InputObject -Names @('accountName', 'cosmosDbAccountName', 'name')
        }
        'VNet' {
            Add-AbrVbazRestorePointValue -Output $Output -Label 'Virtual Network' -InputObject $InputObject -Names @('virtualNetworkName', 'vnetName', 'name')
        }
    }

    Add-AbrVbazRestorePointValue -Output $Output -Label 'Policy' -InputObject $InputObject -Names @('policyName', 'jobName')
    Add-AbrVbazRestorePointValue -Output $Output -Label 'Point In Time' -InputObject $InputObject -Names @('pointInTime', 'creationTime', 'creationDate') -Type DateTime
    Add-AbrVbazRestorePointValue -Output $Output -Label 'Repository' -InputObject $InputObject -Names @('repositoryName', 'backupRepositoryName')
    Add-AbrVbazRestorePointValue -Output $Output -Label 'Backup Destination' -InputObject $InputObject -Names @('backupDestination')
    Add-AbrVbazRestorePointValue -Output $Output -Label 'Region' -InputObject $InputObject -Names @('regionName', 'region')
    Add-AbrVbazRestorePointValue -Output $Output -Label 'State' -InputObject $InputObject -Names @('state', 'status')
    Add-AbrVbazRestorePointValue -Output $Output -Label 'Type' -InputObject $InputObject -Names @('type')
    Add-AbrVbazRestorePointValue -Output $Output -Label 'GFS Flags' -InputObject $InputObject -Names @('gfsFlags')
    Add-AbrVbazRestorePointValue -Output $Output -Label 'Size' -InputObject $InputObject -Names @('backupSizeBytes', 'sizeInBytes', 'size') -Type Size

    [pscustomobject]$Output
}

function Get-AbrVbazId {
    [CmdletBinding()]
    param ($InputObject)

    Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('id', 'Id', 'uid', 'instanceId', 'policyId', 'repositoryId', 'accountId')
}

function Get-AbrVbazApplianceName {
    [CmdletBinding()]
    [OutputType([string])]
    param ([string] $Default)

    $About = $script:AbrVbazInventory.SystemAbout | Select-Object -First 1
    $ServerInfo = $script:AbrVbazInventory.SystemServerInfo | Select-Object -First 1
    foreach ($Source in @($ServerInfo, $About)) {
        $Name = Get-AbrVbazPropertyValue -InputObject $Source -Name @('serverName', 'hostName', 'hostname', 'name', 'displayName')
        if ($Name) {
            return $Name
        }
    }
    $Default
}

function Initialize-AbrVbazInventory {
    [CmdletBinding()]
    param ()

    $script:AbrVbazInventory = [ordered]@{}
    $EndpointMap = [ordered]@{
        SystemAbout = '/system/about'
        SystemStatus = '/system/status'
        SystemServerInfo = '/system/serverInfo'
        SystemTime = '/system/time'
        SystemSupportInfo = '/system/supportInfo'
        PrivateDeploymentState = '/system/privateDeployment/state'
        License = '/license'
        LicenseResources = '/license/resources'
        LicenseAgreement = '/licenseAgreement'
        ConfigurationBackupStats = '/configurationBackup/stats'
        ConfigurationBackupSettings = '/configurationBackup/settings'
        ConfigurationBackupRestorePoints = '/configurationBackup/restorePoints'
        RetentionSettings = '/settings/retention'
        Certificates = '/settings/certificates'
        SamlIdentityProvider = '/settings/saml2/idp'
        SamlServiceProvider = '/settings/saml2/sp'
        Users = '/users'
        AzureServiceAccounts = '/accounts/azure/service'
        StandardAccounts = '/accounts/standard'
        Tenants = '/cloudInfrastructure/tenants'
        Subscriptions = '/cloudInfrastructure/subscriptions'
        Regions = '/cloudInfrastructure/regions'
        ResourceGroups = '/cloudInfrastructure/resourceGroups'
        Repositories = '/repositories'
        VeeamVaults = '/veeamVaults'
        Workers = '/workers'
        WorkerStatistics = '/workers/statistics'
        WorkerNetworkConfiguration = '/workers/networkConfiguration'
        WorkerProfiles = '/workers/profiles'
        WorkerCustomTags = '/workers/customTags'
        VmPolicies = '/policies/virtualMachines'
        SlaVmPolicies = '/policy/slaBased/virtualMachines'
        FileSharePolicies = '/policies/fileShares'
        SqlPolicies = '/policies/sql'
        CosmosDbPolicies = '/policies/cosmosDb'
        VnetPolicy = '/policy/vnet'
        SlaTemplates = '/policyTemplates/slaTemplate'
        StorageTemplates = '/policyTemplates/storageTemplate'
        ProtectedVirtualMachines = '/protectedItem/virtualMachines'
        ProtectedDatabases = '/protectedItem/sql'
        ProtectedFileShares = '/protectedItem/fileShares'
        ProtectedCosmosDbAccounts = '/protectedItem/cosmosDb'
        ProtectedVnet = '/protectedItem/vnet'
        JobSessions = '/jobSessions'
        VmRestorePoints = '/restorePoints/virtualMachines'
        SqlRestorePoints = '/restorePoints/sql'
        FileShareRestorePoints = '/restorePoints/fileShares'
        CosmosRepositoryRestorePoints = '/restorePoints/cosmosDb/repository'
        CosmosContinuousRestorePoints = '/restorePoints/cosmosDb/continuous'
        VnetRestorePoints = '/restorePoints/vnets'
        OverviewSessionsSummary = '/overview/sessionsSummary'
        OverviewStatistics = '/overview/statistics'
        OverviewProtectedWorkloads = '/overview/protectedWorkloads'
        OverviewStorageUsage = '/overview/storageUsage'
        OverviewTopPoliciesDuration = '/overview/topPoliciesDuration'
        OverviewBottlenecks = '/overview/bottlenecksOverview'
    }

    if (-not [string]::IsNullOrWhiteSpace($Options.CapturePath)) {
        Import-AbrVbazCaptureInventory -EndpointMap $EndpointMap
        return
    }

    foreach ($Name in $EndpointMap.Keys) {
        Write-PScriboMessage -Message "Collecting VBAZ endpoint $($EndpointMap[$Name])."
        $script:AbrVbazInventory[$Name] = @(Get-AbrVbazCollection -Path $EndpointMap[$Name])
    }

    if ($InfoLevel.Infrastructure.Discovery -ge 3) {
        foreach ($Pair in @{
                AvailabilitySets = '/cloudInfrastructure/availabilitySets'
                AvailabilityZones = '/cloudInfrastructure/availabilityZones'
                KeyVaults = '/cloudInfrastructure/keyVaults'
                NetworkSecurityGroups = '/cloudInfrastructure/networkSecurityGroups'
                StorageAccounts = '/cloudInfrastructure/storageAccounts'
                SqlServers = '/cloudInfrastructure/sqlServers'
                SqlElasticPools = '/cloudInfrastructure/sqlElasticPools'
                VirtualMachines = '/virtualMachines'
                VirtualNetworks = '/cloudInfrastructure/virtualNetworks'
                VmSizes = '/cloudInfrastructure/virtualMachineSizes'
                FileShares = '/fileShares'
                Databases = '/databases'
                CosmosDbAccounts = '/cosmosDb'
                Tags = '/cloudInfrastructure/tags'
            }.GetEnumerator()) {
            Write-PScriboMessage -Message "Collecting VBAZ discovery endpoint $($Pair.Value)."
            $script:AbrVbazInventory[$Pair.Key] = @(Get-AbrVbazCollection -Path $Pair.Value)
        }
    }

    if ($InfoLevel.Protection.Policies -ge 3) {
        Add-AbrVbazPolicyChildren -CollectionName VmPolicies -BasePath '/policies/virtualMachines'
        Add-AbrVbazPolicyChildren -CollectionName SlaVmPolicies -BasePath '/policy/slaBased/virtualMachines'
        Add-AbrVbazPolicyChildren -CollectionName FileSharePolicies -BasePath '/policies/fileShares'
        Add-AbrVbazPolicyChildren -CollectionName SqlPolicies -BasePath '/policies/sql'
        Add-AbrVbazPolicyChildren -CollectionName CosmosDbPolicies -BasePath '/policies/cosmosDb'
    }
}

function Import-AbrVbazCaptureInventory {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable] $EndpointMap
    )

    $CapturePath = [string]$Options.CapturePath
    $WorkingPath = $CapturePath
    if (-not (Test-Path -LiteralPath $WorkingPath)) {
        throw "CapturePath '$WorkingPath' does not exist."
    }

    if ((Get-Item -LiteralPath $WorkingPath).PSIsContainer -eq $false) {
        if ([IO.Path]::GetExtension($WorkingPath) -ne '.zip') {
            throw "CapturePath '$WorkingPath' must be a folder or ZIP file."
        }
        $ExtractPath = Join-Path $env:TEMP ('AbrVbazCapture_{0}' -f ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
        Expand-Archive -LiteralPath $WorkingPath -DestinationPath $ExtractPath -Force
        $WorkingPath = $ExtractPath
    }

    $ManifestPath = Get-ChildItem -LiteralPath $WorkingPath -Recurse -Filter manifest.json | Select-Object -First 1 -ExpandProperty FullName
    if ($ManifestPath) {
        $script:AbrVbazCaptureManifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
        if ($script:AbrVbazCaptureManifest.server) {
            $script:AbrVbazTarget = $script:AbrVbazCaptureManifest.server
        }
        $script:AbrVbazPort = $script:AbrVbazCaptureManifest.port
        $script:AbrVbazApiVersion = $script:AbrVbazCaptureManifest.apiVersion
    }

    $EnvelopeFiles = @(Get-ChildItem -LiteralPath $WorkingPath -Recurse -Filter *.json | Where-Object { $_.Name -ne 'manifest.json' -and $_.FullName -notlike '*\metadata\*' })
    $Envelopes = foreach ($File in $EnvelopeFiles) {
        try {
            Get-Content -LiteralPath $File.FullName -Raw | ConvertFrom-Json
        } catch {
            Write-PScriboMessage -IsWarning -Message "Unable to read VBAZ capture envelope '$($File.FullName)': $($_.Exception.Message)"
        }
    }

    foreach ($Name in $EndpointMap.Keys) {
        $Endpoint = $EndpointMap[$Name]
        $FullEndpoint = "/api/$($Options.ApiVersion)$Endpoint"
        # $Matches is a automatic variable in PWSH
        $Match = @($Envelopes | Where-Object { $_.success -and ($_.path -eq $Endpoint -or $_.path -eq $FullEndpoint -or $_.path -like "*/$($Endpoint.TrimStart('/'))") })
        $Items = @()
        foreach ($Envelope in $Match) {
            $Items += @(Get-AbrVbazObjectCollection -InputObject $Envelope)
        }
        $script:AbrVbazInventory[$Name] = $Items
    }

    if ($InfoLevel.Protection.Policies -ge 3) {
        foreach ($PolicyType in @(
                @{ CollectionName = 'VmPolicies'; BasePath = '/policies/virtualMachines' },
                @{ CollectionName = 'SlaVmPolicies'; BasePath = '/policy/slaBased/virtualMachines' },
                @{ CollectionName = 'FileSharePolicies'; BasePath = '/policies/fileShares' },
                @{ CollectionName = 'SqlPolicies'; BasePath = '/policies/sql' },
                @{ CollectionName = 'CosmosDbPolicies'; BasePath = '/policies/cosmosDb' }
            )) {
            foreach ($Policy in @($script:AbrVbazInventory[$PolicyType.CollectionName])) {
                $PolicyId = Get-AbrVbazId -InputObject $Policy
                if (-not $PolicyId) {
                    continue
                }
                $SafeName = $PolicyType.CollectionName + '_' + ($PolicyId -replace '[^A-Za-z0-9]', '_')
                foreach ($Child in @('selectedItems', 'excludedItems', 'regions', 'protectedItems')) {
                    $ChildPath = "/api/$($Options.ApiVersion)$($PolicyType.BasePath)/$PolicyId/$Child"
                    $ChildMatches = @($Envelopes | Where-Object { $_.success -and $_.path -eq $ChildPath })
                    $ChildItems = @()
                    foreach ($Envelope in $ChildMatches) {
                        $ChildItems += @(Get-AbrVbazObjectCollection -InputObject $Envelope)
                    }
                    $ChildKey = "$($SafeName)_$($Child.Substring(0,1).ToUpper())$($Child.Substring(1))"
                    $script:AbrVbazInventory[$ChildKey] = $ChildItems
                }
            }
        }
    }
}

function Add-AbrVbazPolicyChildren {
    [CmdletBinding()]
    param (
        [string] $CollectionName,
        [string] $BasePath
    )

    foreach ($Policy in @($script:AbrVbazInventory[$CollectionName])) {
        $PolicyId = Get-AbrVbazId -InputObject $Policy
        if (-not $PolicyId) {
            continue
        }
        $SafeName = $CollectionName + '_' + ($PolicyId -replace '[^A-Za-z0-9]', '_')
        $script:AbrVbazInventory["$($SafeName)_SelectedItems"] = @(Get-AbrVbazCollection -Path "$BasePath/$PolicyId/selectedItems")
        $script:AbrVbazInventory["$($SafeName)_ExcludedItems"] = @(Get-AbrVbazCollection -Path "$BasePath/$PolicyId/excludedItems")
        $script:AbrVbazInventory["$($SafeName)_Regions"] = @(Get-AbrVbazCollection -Path "$BasePath/$PolicyId/regions")
        $script:AbrVbazInventory["$($SafeName)_ProtectedItems"] = @(Get-AbrVbazCollection -Path "$BasePath/$PolicyId/protectedItems")
    }
}

function Resolve-AbrVbazPolicyChildItem {
    [CmdletBinding()]
    param (
        $InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    # Selected/excluded items are wrapped in a per-workload property, e.g. { "virtualMachine": { ... } }.
    foreach ($Wrapper in @('virtualMachine', 'database', 'sqlDatabase', 'fileShare', 'cosmosDbAccount', 'cosmosDb', 'account', 'item', 'resource')) {
        $Property = $InputObject.PSObject.Properties | Where-Object { $_.Name -ieq $Wrapper } | Select-Object -First 1
        if ($Property -and ($Property.Value -is [pscustomobject] -or $Property.Value -is [hashtable])) {
            return $Property.Value
        }
    }

    $InputObject
}

function Get-AbrVbazPolicyChildItems {
    [CmdletBinding()]
    [OutputType([object[]], [array])]
    param (
        [string] $CollectionName,
        $Policy,
        [ValidateSet('SelectedItems', 'ExcludedItems', 'Regions', 'ProtectedItems')]
        [string] $Child
    )

    $PolicyId = Get-AbrVbazId -InputObject $Policy
    if (-not $PolicyId) {
        return @()
    }

    $SafeName = $CollectionName + '_' + ($PolicyId -replace '[^A-Za-z0-9]', '_')
    $Items = @($script:AbrVbazInventory["$($SafeName)_$Child"])

    @($Items | ForEach-Object { Resolve-AbrVbazPolicyChildItem -InputObject $_ } | Where-Object {
            $_ -and @($_.PSObject.Properties | Where-Object { $_.Name -notlike '_*' -and (Test-AbrVbazDisplayValue -Value $_.Value) }).Count -gt 0
        })
}

function ConvertTo-AbrVbazPolicyChildRow {
    [CmdletBinding()]
    param (
        $InputObject
    )

    # Normalizes a selected/excluded policy item into consistent columns across workload types.
    $Output = [ordered]@{}

    $Name = Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('name', 'displayName', 'virtualNetworkName')
    if (Test-AbrVbazDisplayValue -Value $Name) { $Output['Name'] = ConvertTo-AbrVbazDisplayValue -InputObject $Name }

    $Type = Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('osType', 'databaseType', 'type')
    if (Test-AbrVbazDisplayValue -Value $Type) { $Output['Type'] = ConvertTo-AbrVbazDisplayValue -InputObject $Type }

    $Server = Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('serverName')
    if (Test-AbrVbazDisplayValue -Value $Server) { $Output['Server'] = ConvertTo-AbrVbazDisplayValue -InputObject $Server }

    $StorageAccount = Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('storageAccountName', 'storageAccount')
    if (Test-AbrVbazDisplayValue -Value $StorageAccount) { $Output['Storage Account'] = ConvertTo-AbrVbazDisplayValue -InputObject $StorageAccount }

    $Region = Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('regionDisplayName', 'regionName', 'region')
    if (Test-AbrVbazDisplayValue -Value $Region) { $Output['Region'] = ConvertTo-AbrVbazDisplayValue -InputObject $Region }

    $Subscription = Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('subscriptionName')
    if (-not (Test-AbrVbazDisplayValue -Value $Subscription)) {
        $Subscription = Resolve-AbrVbazSubscriptionName -SubscriptionId ([string](Get-AbrVbazPropertyValue -InputObject $InputObject -Name 'subscriptionId'))
    }
    if (Test-AbrVbazDisplayValue -Value $Subscription) { $Output['Subscription'] = ConvertTo-AbrVbazDisplayValue -InputObject $Subscription }

    $ResourceGroup = Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('resourceGroupName', 'resourceGroup')
    if (Test-AbrVbazDisplayValue -Value $ResourceGroup) { $Output['Resource Group'] = ConvertTo-AbrVbazDisplayValue -InputObject $ResourceGroup }

    $VmSize = Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('vmSize')
    if (Test-AbrVbazDisplayValue -Value $VmSize) { $Output['VM Size'] = ConvertTo-AbrVbazDisplayValue -InputObject $VmSize }

    $SizeGb = Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('totalSizeInGB')
    $SizeMb = Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('sizeInMb')
    if ((Test-AbrVbazDisplayValue -Value $SizeGb) -and ([double]$SizeGb -gt 0)) {
        $Output['Size'] = ConvertTo-AbrVbazSizeFromUnit -Value $SizeGb -Unit GB
    } elseif ((Test-AbrVbazDisplayValue -Value $SizeMb) -and ([double]$SizeMb -gt 0)) {
        $Output['Size'] = ConvertTo-AbrVbazSizeFromUnit -Value $SizeMb -Unit MB
    }

    $Status = Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('status')
    if (Test-AbrVbazDisplayValue -Value $Status) { $Output['Status'] = ConvertTo-AbrVbazDisplayValue -InputObject $Status }

    [pscustomobject]$Output
}

function New-AbrVbazCountObject {
    [CmdletBinding()]
    param (
        [string] $Name,
        [object[]] $Items
    )

    [pscustomobject]@{
        Name = $Name
        Total = @($Items).Count
    }
}

function New-AbrVbazGroupSummary {
    [CmdletBinding()]
    [OutputType([array])]
    param (
        [object[]] $Items,
        [string[]] $GroupBy,
        [string] $GroupLabel = 'Group'
    )

    $Rows = foreach ($Item in @($Items)) {
        $GroupValue = $null
        foreach ($PropertyName in $GroupBy) {
            $GroupValue = Get-AbrVbazPropertyValue -InputObject $Item -Name $PropertyName
            if ($GroupValue) {
                break
            }
        }
        if (-not $GroupValue) {
            $GroupValue = Resolve-AbrVbazOperationalGroup -InputObject $Item
        }
        if (-not $GroupValue) {
            $GroupValue = 'Not exposed by API'
        }
        [pscustomobject]@{
            Group = ConvertTo-AbrVbazDisplayValue -InputObject $GroupValue
        }
    }

    @($Rows | Group-Object -Property Group | Sort-Object -Property Name | ForEach-Object {
            $Output = [ordered]@{}
            $Output[$GroupLabel] = $_.Name
            $Output['Total'] = $_.Count
            [pscustomobject]$Output
        })
}

function New-AbrVbazResourceGroupRegionSummary {
    [CmdletBinding()]
    [OutputType([array])]
    param (
        [object[]] $Items
    )

    $Rows = foreach ($Item in @($Items)) {
        $Region = Get-AbrVbazPropertyValue -InputObject $Item -Name @('regionName', 'location')
        if (-not (Test-AbrVbazDisplayValue -Value $Region)) {
            $Region = 'Not exposed by API'
        }
        $Subscription = Get-AbrVbazPropertyValue -InputObject $Item -Name @('subscriptionName', 'subscriptionId')
        if (-not (Test-AbrVbazDisplayValue -Value $Subscription)) {
            $Subscription = 'Not exposed by API'
        }
        [pscustomobject]@{
            Region = ConvertTo-AbrVbazDisplayValue -InputObject $Region
            Subscription = ConvertTo-AbrVbazDisplayValue -InputObject $Subscription
        }
    }

    @($Rows | Group-Object -Property Region | Sort-Object -Property Name | ForEach-Object {
            $Subscriptions = @($_.Group.Subscription | Sort-Object -Unique)
            [pscustomobject]@{
                Region = $_.Name
                'Resource Groups' = $_.Count
                Subscriptions = ($Subscriptions -join ', ')
            }
        })
}

function Resolve-AbrVbazSubscriptionName {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [string] $SubscriptionId
    )

    if (-not (Test-AbrVbazDisplayValue -Value $SubscriptionId)) {
        return $SubscriptionId
    }

    foreach ($Subscription in @($script:AbrVbazInventory.Subscriptions)) {
        $Id = Get-AbrVbazPropertyValue -InputObject $Subscription -Name @('id', 'subscriptionId')
        if ([string]$Id -ieq [string]$SubscriptionId) {
            $Name = Get-AbrVbazPropertyValue -InputObject $Subscription -Name @('name', 'displayName', 'subscriptionName')
            if (Test-AbrVbazDisplayValue -Value $Name) {
                return [string]$Name
            }
        }
    }

    $SubscriptionId
}

function New-AbrVbazResourceGroupSubscriptionSummary {
    [CmdletBinding()]
    [OutputType([array])]
    param (
        [object[]] $Items
    )

    # The VBAZ resourceGroups payload does not reliably expose a region, so this
    # summary groups resource groups by subscription and resolves the friendly name.
    $Rows = foreach ($Item in @($Items)) {
        $Subscription = Resolve-AbrVbazSubscriptionName -SubscriptionId ([string](Get-AbrVbazPropertyValue -InputObject $Item -Name @('subscriptionName', 'subscriptionId')))
        if (-not (Test-AbrVbazDisplayValue -Value $Subscription)) {
            $Subscription = 'Not exposed by API'
        }
        [pscustomobject]@{
            Subscription = ConvertTo-AbrVbazDisplayValue -InputObject $Subscription
        }
    }

    @($Rows | Group-Object -Property Subscription | Sort-Object -Property Name | ForEach-Object {
            [pscustomobject]@{
                Subscription = $_.Name
                'Resource Groups' = $_.Count
            }
        })
}

function Resolve-AbrVbazOperationalGroup {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        $InputObject
    )

    foreach ($PropertyName in @('policyName', 'jobName', 'name', 'displayName', 'vmName', 'databaseName', 'serverName', 'fileShareName', 'accountName', 'virtualNetworkName', 'resourceName')) {
        $Value = Get-AbrVbazPropertyValue -InputObject $InputObject -Name $PropertyName
        if ($Value) {
            return $Value
        }
    }

    $PolicyId = Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('policyId', 'jobId')
    if ($PolicyId) {
        foreach ($PolicySetName in @('VmPolicies', 'SlaVmPolicies', 'FileSharePolicies', 'SqlPolicies', 'CosmosDbPolicies', 'VnetPolicy')) {
            foreach ($Policy in @($script:AbrVbazInventory[$PolicySetName])) {
                if ((Get-AbrVbazId -InputObject $Policy) -eq $PolicyId) {
                    $PolicyName = Get-AbrVbazPropertyValue -InputObject $Policy -Name @('name', 'displayName')
                    if ($PolicyName) {
                        return $PolicyName
                    }
                }
            }
        }
        return "Policy ID $PolicyId"
    }

    foreach ($IdProperty in @('vmId', 'databaseId', 'fileShareId', 'cosmosDbAccountId', 'vnetId', 'resourceId')) {
        $ResourceId = Get-AbrVbazPropertyValue -InputObject $InputObject -Name $IdProperty
        if ($ResourceId) {
            return "Resource ID $ResourceId"
        }
    }

    $null
}

function Get-AbrVbazJobSessionType {
    [CmdletBinding()]
    [OutputType([string])]
    param ($InputObject)

    $Type = Get-AbrVbazPropertyValue -InputObject $InputObject -Name @('type', 'sessionType', 'jobType')
    if (Test-AbrVbazDisplayValue -Value $Type) {
        return (ConvertTo-AbrVbazDisplayValue -InputObject $Type)
    }

    'Not exposed by API'
}

function Test-AbrVbazMeaningfulSessionType {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [string] $Type
    )

    if ([string]::IsNullOrWhiteSpace($Type)) {
        return $true
    }

    # System/housekeeping sessions (retention, rescan, configuration sync, snapshot deletion,
    # repository creation) are scheduler run-history rather than as built configuration. They are
    # counted in the summary-by-type table but excluded from the per-session detail tables.
    -not ($Type -match '(?i)(Retention|Rescan|Sync|Deletion|RepositoryCreation)')
}

function Get-AbrVbazSessionTypeSortKey {
    [CmdletBinding()]
    param (
        [string] $Type
    )

    # Explicit ordering for the per-session detail subsections. Snapshot sessions are listed before
    # their corresponding backup sessions to follow the protection workflow (snapshot, then backup).
    $Order = @(
        'PolicySnapshot', 'PolicyBackup', 'FileSharePolicySnapshot',
        'SqlPolicyBackup', 'SqlPolicyArchive',
        'VnetPolicyBackup', 'VnetPolicyBackupToRepository',
        'ManualSnapshot', 'SqlManualBackup', 'ConfigurationBackupManual',
        'RestoreVms', 'SqlRestore', 'FileLevelRestore'
    )
    $Index = [array]::IndexOf($Order, [string]$Type)
    if ($Index -lt 0) {
        $Index = 900
    }
    '{0:D3}_{1}' -f $Index, $Type
}

function Set-AbrVbazSessionRowStyle {
    [CmdletBinding()]
    param (
        [object[]] $Rows
    )

    if (-not $HealthCheck.Operations.Sessions) {
        return
    }

    @($Rows) | Where-Object { $_.Status -match 'Failed|Error' -or $_.Result -match 'Failed|Error' -or $_.State -match 'Failed|Error' } | Set-Style -Style Critical -Property Status, Result, State
    @($Rows) | Where-Object { $_.Status -match 'Warning' -or $_.Result -match 'Warning' -or $_.State -match 'Warning' } | Set-Style -Style Warning -Property Status, Result, State
}

function Get-AbrVbazJobSessionInfoValue {
    [CmdletBinding()]
    param (
        $InputObject,
        [Parameter(Mandatory)]
        [string[]] $Name
    )

    $Value = Get-AbrVbazPropertyValue -InputObject $InputObject -Name $Name
    if (Test-AbrVbazDisplayValue -Value $Value) {
        return $Value
    }

    foreach ($InfoProperty in @('backupJobInfo', 'retentionJobInfo', 'repositoryJobInfo', 'restoreJobInfo', 'fileLevelRestoreJobInfo')) {
        $Info = Get-AbrVbazPropertyValue -InputObject $InputObject -Name $InfoProperty
        if ($Info) {
            $Value = Get-AbrVbazPropertyValue -InputObject $Info -Name $Name
            if (Test-AbrVbazDisplayValue -Value $Value) {
                return $Value
            }
        }
    }

    $null
}

function Get-AbrVbazJobSessionPolicyName {
    [CmdletBinding()]
    [OutputType([string])]
    param ($InputObject)

    $PolicyName = Get-AbrVbazJobSessionInfoValue -InputObject $InputObject -Name @('policyName', 'jobName')
    if (Test-AbrVbazDisplayValue -Value $PolicyName) {
        return (ConvertTo-AbrVbazDisplayValue -InputObject $PolicyName)
    }

    $PolicyId = Get-AbrVbazJobSessionInfoValue -InputObject $InputObject -Name @('policyId', 'jobId')
    if (Test-AbrVbazDisplayValue -Value $PolicyId) {
        return "Policy ID $PolicyId"
    }

    'Not exposed by API'
}

function ConvertTo-AbrVbazJobSessionTableObject {
    [CmdletBinding()]
    param ($InputObject)

    $Output = [ordered]@{}
    foreach ($Definition in @(
            @{ Label = 'Type'; Names = @('localizedType') },
            @{ Label = 'Status'; Names = @('status', 'state', 'result') },
            @{ Label = 'Execution Start Time'; Names = @('executionStartTime', 'startTime', 'creationTime'); IsTime = $true },
            @{ Label = 'Execution Duration'; Names = @('executionDuration', 'duration') }
        )) {
        $Value = Get-AbrVbazPropertyValue -InputObject $InputObject -Name $Definition.Names
        if (Test-AbrVbazDisplayValue -Value $Value) {
            $Label = $Definition.Label
            if ($Definition.IsTime) {
                $Label = "$Label ($(Get-AbrVbazDateTimeZoneLabel -Name $Definition.Names[0] -Value $Value))"
                $Output[$Label] = ConvertTo-AbrVbazDateTimeDisplayValue -InputObject $Value
            } else {
                $Output[$Label] = ConvertTo-AbrVbazDisplayValue -InputObject $Value
            }
        }
    }

    foreach ($Definition in @(
            @{ Label = 'Policy Name'; Names = @('policyName', 'jobName') },
            @{ Label = 'Policy Type'; Names = @('policyType') },
            @{ Label = 'Policy Removed'; Names = @('policyRemoved') },
            @{ Label = 'Protected Instances'; Names = @('protectedInstancesCount') },
            @{ Label = 'Deleted Restore Points'; Names = @('deletedRestorePointsCount') },
            @{ Label = 'Repository Name'; Names = @('repositoryName') },
            @{ Label = 'Restore Point Name'; Names = @('restorePointName') }
        )) {
        $Value = Get-AbrVbazJobSessionInfoValue -InputObject $InputObject -Name $Definition.Names
        if (Test-AbrVbazDisplayValue -Value $Value) {
            $Output[$Definition.Label] = ConvertTo-AbrVbazDisplayValue -InputObject $Value
        }
    }

    [pscustomobject]$Output
}

function Get-AbrVbazOperationsDetailMode {
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    if ($Options.PSObject.Properties['OperationsDetailMode'] -and $Options.OperationsDetailMode) {
        return [string]$Options.OperationsDetailMode
    }
    'Grouped'
}

function Get-AbrVbazStatusOrder {
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [string] $Status
    )

    # Standard status ordering for charts: Success, then Warning, then Error/Failed, then the rest.
    switch -Regex ([string]$Status) {
        '(?i)(success|succeeded|^ok$|healthy|completed|protected|enabled|valid|running)' { return 0 }
        '(?i)(warning|warn)' { return 1 }
        '(?i)(error|failed|failure|critical|unavailable)' { return 2 }
        '(?i)(disabled|never|skipped|idle|stopped|none)' { return 3 }
        default { return 4 }
    }
}

function Get-AbrVbazStatusColor {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [string] $Status
    )

    # Standard status colours, using the report's original chart palette:
    # Success = green, Warning = yellow, Error/Failed = red, inactive = grey, other = blue.
    switch -Regex ([string]$Status) {
        '(?i)(success|succeeded|^ok$|healthy|completed|protected|enabled|valid|running)' { return '#DFF0D0' }
        '(?i)(warning|warn)' { return '#FFF3C4' }
        '(?i)(error|failed|failure|critical|unavailable)' { return '#FECDD1' }
        '(?i)(disabled|never|skipped|idle|stopped|none)' { return '#ADACAF' }
        default { return '#D9EDF7' }
    }
}

function New-AbrVbazStatusChart {
    [CmdletBinding()]
    param (
        [string] $Title,
        [object[]] $Items
    )

    if ($Options.EnableCharts -eq $false -or -not $Items) {
        return $null
    }

    try {
        $Statuses = foreach ($Item in $Items) {
            ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $Item -Name @('lastStatus', 'status', 'state', 'result', 'lastResult') -Default 'Unknown')
        }
        $Grouped = @($Statuses | Group-Object | Sort-Object @{ Expression = { Get-AbrVbazStatusOrder -Status $_.Name } }, Name)
        if (-not $Grouped) {
            return $null
        }
        $Labels = @($Grouped | ForEach-Object { [string]$_.Name })
        $Values = @($Grouped | ForEach-Object { [double]$_.Count })
        if (@($Labels).Count -ne @($Values).Count) {
            Write-PScriboMessage -IsWarning -Message "Unable to create chart '$Title': label count '$(@($Labels).Count)' does not match value count '$(@($Values).Count)'."
            return $null
        }
        $Palette = @($Grouped | ForEach-Object { Get-AbrVbazStatusColor -Status $_.Name })
        New-BarChart -Title $Title -Values ([double[]]$Values) -Labels ([string[]]$Labels) -LabelXAxis 'Status' -LabelYAxis 'Count' -EnableCustomColorPalette -CustomColorPalette $Palette -Width 600 -Height 400 -Format base64 -EnableLegend -LegendOrientation Horizontal -LegendAlignment UpperCenter -AxesMarginsTop 0.5 -TitleFontBold -TitleFontSize 16
    } catch {
        Write-PScriboMessage -IsWarning -Message "Unable to create chart '$Title': $($_.Exception.Message)"
        $null
    }
}

function New-AbrVbazPolicyStatusChart {
    [CmdletBinding()]
    param (
        [string] $Title,
        [object[]] $Items
    )

    if ($Options.EnableCharts -eq $false -or -not $Items) {
        return $null
    }

    try {
        $Statuses = foreach ($Item in $Items) {
            $Status = Get-AbrVbazPropertyValue -InputObject $Item -Name @('backupStatus', 'snapshotStatus', 'archiveStatus', 'healthCheckStatus', 'indexingStatus', 'lastStatus', 'status', 'state', 'result', 'lastResult')
            if (-not $Status) {
                $Enabled = Get-AbrVbazPropertyValue -InputObject $Item -Name @('isEnabled', 'enabled')
                if ($null -ne $Enabled) {
                    if ($Enabled -is [bool]) {
                        if ($Enabled) { $Status = 'Enabled' } else { $Status = 'Disabled' }
                    } elseif ([string]$Enabled -match '^(true|yes|enabled)$') {
                        $Status = 'Enabled'
                    } elseif ([string]$Enabled -match '^(false|no|disabled)$') {
                        $Status = 'Disabled'
                    }
                }
            }
            if ($Status) {
                ConvertTo-AbrVbazDisplayValue -InputObject $Status
            }
        }
        $Grouped = @($Statuses | Where-Object { Test-AbrVbazDisplayValue -Value $_ } | Group-Object | Sort-Object @{ Expression = { Get-AbrVbazStatusOrder -Status $_.Name } }, Name)
        if (-not $Grouped) {
            return $null
        }
        $Labels = @($Grouped | ForEach-Object { [string]$_.Name })
        $Values = @($Grouped | ForEach-Object { [double]$_.Count })
        $Palette = @($Grouped | ForEach-Object { Get-AbrVbazStatusColor -Status $_.Name })
        New-BarChart -Title $Title -Values ([double[]]$Values) -Labels ([string[]]$Labels) -LabelXAxis 'Status' -LabelYAxis 'Count' -EnableCustomColorPalette -CustomColorPalette $Palette -Width 600 -Height 400 -Format base64 -EnableLegend -LegendOrientation Horizontal -LegendAlignment UpperCenter -AxesMarginsTop 0.5 -TitleFontBold -TitleFontSize 16
    } catch {
        Write-PScriboMessage -IsWarning -Message "Unable to create chart '$Title': $($_.Exception.Message)"
        $null
    }
}

function New-AbrVbazCountChart {
    [CmdletBinding()]
    param (
        [string] $Title,
        [object[]] $CountObjects
    )

    if ($Options.EnableCharts -eq $false -or -not $CountObjects) {
        return $null
    }

    try {
        $Filtered = @($CountObjects | Where-Object { [int](Get-AbrVbazPropertyValue -InputObject $_ -Name @('Total', 'Count') -Default 0) -gt 0 })
        if (-not $Filtered) {
            return $null
        }
        $Labels = @($Filtered | ForEach-Object { [string](Get-AbrVbazPropertyValue -InputObject $_ -Name 'Name' -Default 'Unknown') })
        $Values = @($Filtered | ForEach-Object { [double](Get-AbrVbazPropertyValue -InputObject $_ -Name @('Total', 'Count') -Default 0) })
        if (@($Labels).Count -ne @($Values).Count) {
            Write-PScriboMessage -IsWarning -Message "Unable to create chart '$Title': label count '$(@($Labels).Count)' does not match value count '$(@($Values).Count)'."
            return $null
        }
        New-PieChart -Title $Title -Values ([double[]]$Values) -Labels ([string[]]$Labels) -EnableCustomColorPalette -CustomColorPalette @('#00B336', '#86C232', '#4099DA', '#71797E', '#E6B325', '#B7D7F0') -Width 600 -Height 400 -Format base64 -EnableLegend -LegendOrientation Horizontal -LegendAlignment UpperCenter -TitleFontBold -TitleFontSize 16
    } catch {
        Write-PScriboMessage -IsWarning -Message "Unable to create chart '$Title': $($_.Exception.Message)"
        $null
    }
}

function ConvertTo-AbrVbazOverviewStatisticsRows {
    [CmdletBinding()]
    [OutputType([object[]], [array])]
    param (
        [object[]] $Items
    )

    $Statistics = @($Items) | Select-Object -First 1
    if (-not $Statistics) {
        return @()
    }

    $Output = [ordered]@{}
    $Metrics = [ordered]@{
        'Snapshot Restore Points' = @{ Current = 'snapshotsCount'; Total = 'snapshotsTotalCount' }
        'Backup Restore Points' = @{ Current = 'backupsCount'; Total = 'backupsTotalCount' }
        'Archive Restore Points' = @{ Current = 'archivesCount'; Total = 'archivesTotalCount' }
    }

    foreach ($Label in $Metrics.Keys) {
        $Current = Get-AbrVbazPropertyValue -InputObject $Statistics -Name @($Metrics[$Label].Current)
        if (Test-AbrVbazDisplayValue -Value $Current) {
            $Output[$Label] = ConvertTo-AbrVbazDisplayValue -InputObject $Current
            # Only surface the "Total" variant when it differs from the current count.
            $Total = Get-AbrVbazPropertyValue -InputObject $Statistics -Name @($Metrics[$Label].Total)
            if ((Test-AbrVbazDisplayValue -Value $Total) -and ([string]$Total -ne [string]$Current)) {
                $Output["$Label (Total)"] = ConvertTo-AbrVbazDisplayValue -InputObject $Total
            }
        }
    }

    # Carry any additional, non-duplicate fields the dashboard may expose.
    foreach ($Property in $Statistics.PSObject.Properties) {
        if ($Property.Name -match '(?i)(count|usage|space|items|policies|sessions|repositories)' -and $Property.Name -notmatch '(?i)(snapshots|backups|archives)') {
            $Label = Format-AbrVbazPropertyLabel -Name $Property.Name
            if (-not $Output.Contains($Label) -and (Test-AbrVbazDisplayValue -Value $Property.Value)) {
                $Output[$Label] = ConvertTo-AbrVbazTableValue -PropertyName $Property.Name -Value $Property.Value
            }
        }
    }

    @([pscustomobject]$Output)
}

function ConvertTo-AbrVbazStorageUsageRows {
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [object[]] $Items
    )

    $Rows = @()
    foreach ($Item in @($Items)) {
        $MetricMap = [ordered]@{
            'Restore Point Count' = @{ Names = @('snapshotsCount', 'snapshotCount', 'restorePointsCount'); Type = 'Count'; Notes = 'Number of restore point records reported by the dashboard.' }
            'Total Usage' = @{ Names = @('totalUsage', 'totalUsedSpace', 'usedSpace'); Type = 'Capacity'; Notes = 'Total protected data stored across reported storage tiers.' }
            'Cool Tier Usage' = @{ Names = @('coolUsage', 'backupCount', 'backupUsage'); Type = 'Capacity'; Notes = 'Bytes stored in cool/backup tier storage.' }
            'Archive Tier Usage' = @{ Names = @('archiveUsage', 'archivesCount', 'archiveCount'); Type = 'Capacity'; Notes = 'Bytes stored in archive tier storage.' }
        }

        foreach ($MetricName in $MetricMap.Keys) {
            $Definition = $MetricMap[$MetricName]
            $Value = Get-AbrVbazPropertyValue -InputObject $Item -Name $Definition.Names
            if (-not (Test-AbrVbazDisplayValue -Value $Value)) {
                continue
            }
            $DisplayValue = if ($Definition.Type -eq 'Capacity') {
                ConvertTo-AbrVbazByteSize -Value $Value
            } else {
                ConvertTo-AbrVbazDisplayValue -InputObject $Value
            }
            $Rows += [pscustomobject]@{
                Metric = $MetricName
                Value = $DisplayValue
                'Raw Value' = ConvertTo-AbrVbazDisplayValue -InputObject $Value
                Type = $Definition.Type
                Notes = $Definition.Notes
            }
        }
    }

    $Rows
}

function Test-AbrVbazAnyHealthCheckEnabled {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if (-not $HealthCheck) {
        return $false
    }

    foreach ($Group in $HealthCheck.PSObject.Properties.Value) {
        if ($Group -is [bool]) {
            if ($Group) { return $true }
            continue
        }
        if ($Group -and $Group.PSObject) {
            foreach ($Leaf in $Group.PSObject.Properties.Value) {
                if ($Leaf -eq $true) {
                    return $true
                }
            }
        }
    }

    $false
}

function New-AbrVbazHealthFinding {
    [CmdletBinding()]
    param (
        [string] $Category,
        [string] $Item,
        [ValidateSet('Critical', 'Warning')]
        [string] $Severity,
        [string] $Detail
    )

    [pscustomobject][ordered]@{
        Severity = $Severity
        Category = $Category
        Item = $Item
        Detail = $Detail
    }
}

function Get-AbrVbazHealthFindings {
    [CmdletBinding()]
    [OutputType([object[]], [array])]
    param ()

    $Findings = [System.Collections.Generic.List[object]]::new()

    # Configuration backup disabled.
    $ConfigBackup = @($script:AbrVbazInventory.ConfigurationBackupSettings) | Select-Object -First 1
    if ($ConfigBackup) {
        $Enabled = Get-AbrVbazPropertyValue -InputObject $ConfigBackup -Name @('isEnabled', 'enabled')
        if ($Enabled -eq $false -or [string]$Enabled -ieq 'false') {
            $Findings.Add((New-AbrVbazHealthFinding -Category 'Configuration Backup' -Item 'Scheduled configuration backup' -Severity 'Warning' -Detail 'The built-in scheduled configuration backup is disabled (it may be managed externally by a Veeam Backup & Replication server).'))
        }
    }

    # Repositories: status and immutability.
    foreach ($Repository in @($script:AbrVbazInventory.Repositories)) {
        $RepositoryName = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $Repository -Name 'name' -Default 'Repository')
        $Status = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $Repository -Name @('status', 'state'))
        if ([string]$Status -match 'Failed|Unavailable|Error') {
            $Findings.Add((New-AbrVbazHealthFinding -Category 'Repository' -Item $RepositoryName -Severity 'Critical' -Detail "Repository status is '$Status'."))
        }
        $Immutability = Get-AbrVbazPropertyValue -InputObject $Repository -Name 'immutabilityEnabled'
        if ($Immutability -eq $false -or [string]$Immutability -ieq 'false') {
            $Findings.Add((New-AbrVbazHealthFinding -Category 'Repository' -Item $RepositoryName -Severity 'Warning' -Detail 'Immutability is not enabled on this backup repository.'))
        }
    }

    # Azure service accounts: permission and cloud state.
    foreach ($Account in @($script:AbrVbazInventory.AzureServiceAccounts)) {
        $AccountName = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $Account -Name 'name' -Default 'Azure account')
        $Permissions = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $Account -Name 'azurePermissionsState')
        if ((Test-AbrVbazDisplayValue -Value $Permissions) -and $Permissions -notmatch '(?i)^(valid|ok|healthy|good|present)$') {
            $Findings.Add((New-AbrVbazHealthFinding -Category 'Azure Account' -Item $AccountName -Severity 'Warning' -Detail "Azure permissions state is '$Permissions'."))
        }
        $CloudState = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $Account -Name 'cloudState')
        if ((Test-AbrVbazDisplayValue -Value $CloudState) -and $CloudState -match '(?i)(invalid|error|failed)') {
            $Findings.Add((New-AbrVbazHealthFinding -Category 'Azure Account' -Item $AccountName -Severity 'Critical' -Detail "Cloud state is '$CloudState'."))
        }
    }

    # Stale protected-workload backups.
    $ThresholdDays = 7
    if ($Options.PSObject.Properties['StaleBackupThresholdDays'] -and $Options.StaleBackupThresholdDays) {
        $ThresholdDays = [int]$Options.StaleBackupThresholdDays
    }
    $Cutoff = (Get-Date).ToUniversalTime().AddDays(-$ThresholdDays)
    $WorkloadSets = [ordered]@{
        'Protected VM' = $script:AbrVbazInventory.ProtectedVirtualMachines
        'Protected SQL Database' = $script:AbrVbazInventory.ProtectedDatabases
        'Protected File Share' = $script:AbrVbazInventory.ProtectedFileShares
    }
    foreach ($WorkloadLabel in $WorkloadSets.Keys) {
        foreach ($Workload in @($WorkloadSets[$WorkloadLabel])) {
            $LastBackup = Get-AbrVbazPropertyValue -InputObject $Workload -Name @('lastBackup', 'lastBackupTime')
            if (-not (Test-AbrVbazDisplayValue -Value $LastBackup)) {
                continue
            }
            try {
                $LastBackupTime = [datetimeoffset]::Parse([string]$LastBackup, [System.Globalization.CultureInfo]::InvariantCulture).UtcDateTime
            } catch {
                continue
            }
            if ($LastBackupTime -lt $Cutoff) {
                $WorkloadName = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $Workload -Name @('name', 'displayName') -Default 'Workload')
                $Findings.Add((New-AbrVbazHealthFinding -Category $WorkloadLabel -Item $WorkloadName -Severity 'Warning' -Detail "Last backup ($($LastBackupTime.ToString('yyyy-MM-dd HH:mm')) UTC) is older than $ThresholdDays day(s)."))
            }
        }
    }

    # Job sessions with a failed or warning result.
    $Sessions = @($script:AbrVbazInventory.JobSessions)
    if ($Sessions.Count -gt 0) {
        $FailedSessions = @($Sessions | Where-Object {
                $Status = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name @('lastStatus', 'status', 'state', 'result', 'lastResult'))
                $Status -match '(?i)(failed|error)'
            }).Count
        $WarningSessions = @($Sessions | Where-Object {
                $Status = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $_ -Name @('lastStatus', 'status', 'state', 'result', 'lastResult'))
                $Status -match '(?i)warning'
            }).Count
        if ($FailedSessions -gt 0) {
            $Findings.Add((New-AbrVbazHealthFinding -Category 'Job Sessions' -Item 'Failed sessions' -Severity 'Critical' -Detail "$FailedSessions job session(s) completed with a Failed or Error result."))
        }
        if ($WarningSessions -gt 0) {
            $Findings.Add((New-AbrVbazHealthFinding -Category 'Job Sessions' -Item 'Warning sessions' -Severity 'Warning' -Detail "$WarningSessions job session(s) completed with a Warning result."))
        }
    }

    # Certificates expiring within 30 days.
    foreach ($Certificate in @($script:AbrVbazInventory.Certificates)) {
        $Expiration = Get-AbrVbazPropertyValue -InputObject $Certificate -Name @('expirationDate', 'notAfter')
        if (-not (Test-AbrVbazDisplayValue -Value $Expiration)) {
            continue
        }
        try {
            $ExpirationTime = [datetimeoffset]::Parse([string]$Expiration, [System.Globalization.CultureInfo]::InvariantCulture).UtcDateTime
        } catch {
            continue
        }
        if ($ExpirationTime -lt (Get-Date).ToUniversalTime().AddDays(30)) {
            $CertificateName = ConvertTo-AbrVbazDisplayValue -InputObject (Get-AbrVbazPropertyValue -InputObject $Certificate -Name @('subject', 'name', 'type') -Default 'Certificate')
            $Findings.Add((New-AbrVbazHealthFinding -Category 'Certificate' -Item $CertificateName -Severity 'Warning' -Detail "Certificate expires $($ExpirationTime.ToString('yyyy-MM-dd')) UTC."))
        }
    }

    $SeverityOrder = @{ 'Critical' = 0; 'Warning' = 1 }
    @($Findings | Sort-Object @{ Expression = { $SeverityOrder[$_.Severity] } }, Category, Item)
}

function Add-AbrVbazTable {
    [CmdletBinding()]
    param (
        [string] $Name,
        [object[]] $InputObject,
        [string[]] $Columns,
        [switch] $List
    )

    $Rows = @($InputObject)
    $Rows = @($Rows | Where-Object {
            $MeaningfulValues = @($_.PSObject.Properties | Where-Object {
                    $_.Name -notlike '*__Style' -and (Test-AbrVbazDisplayValue -Value $_.Value)
                })
            $MeaningfulValues.Count -gt 0
        })
    if (-not $Rows) {
        Paragraph "No $Name data was returned by the appliance."
        return
    }

    if ($List -and $Rows.Count -gt 1) {
        $MergedRow = [ordered]@{}
        foreach ($Row in $Rows) {
            foreach ($Property in $Row.PSObject.Properties | Where-Object { $_.Name -notlike '*__Style' }) {
                if ((Test-AbrVbazDisplayValue -Value $Property.Value) -and -not $MergedRow.Contains($Property.Name)) {
                    $MergedRow[$Property.Name] = $Property.Value
                    # Carry any health-check styling marker so highlights survive the list merge.
                    $StyleProperty = $Row.PSObject.Properties["$($Property.Name)__Style"]
                    if ($StyleProperty) {
                        $MergedRow["$($Property.Name)__Style"] = $StyleProperty.Value
                    }
                }
            }
        }
        $Rows = @([pscustomobject]$MergedRow)
    }

    $MaxTableRows = 0
    if ($Options.PSObject.Properties['MaxTableRows'] -and $Options.MaxTableRows) {
        $MaxTableRows = [int]$Options.MaxTableRows
    }
    if ($MaxTableRows -gt 0 -and $Rows.Count -gt $MaxTableRows) {
        Paragraph "$Name contains $($Rows.Count) records. Showing the first $MaxTableRows records returned by the appliance. Increase Options.MaxTableRows or set it to 0 for the full table."
        $Rows = @($Rows | Select-Object -First $MaxTableRows)
    }

    $TableChunkSize = 0
    if ($Options.PSObject.Properties['TableChunkSize'] -and $Options.TableChunkSize) {
        $TableChunkSize = [int]$Options.TableChunkSize
    }

    $TableParams = @{
        Name = $Name
        List = [bool]$List
    }
    if (-not $Columns) {
        $ColumnNames = [ordered]@{}
        foreach ($Row in $Rows) {
            foreach ($Property in $Row.PSObject.Properties | Where-Object { $_.Name -notlike '*__Style' }) {
                if (-not $ColumnNames.Contains($Property.Name)) {
                    $ColumnNames[$Property.Name] = $true
                }
            }
        }
        $Columns = @($ColumnNames.Keys)
    } else {
        $Columns = @($Columns)
    }

    $Columns = @($Columns | Where-Object {
            $ColumnName = $_
            @($Rows | Where-Object { Test-AbrVbazDisplayValue -Value $_.$ColumnName }).Count -gt 0
        })

    if ($Columns.Count -lt 2) {
        foreach ($Row in $Rows) {
            if (-not $Row.PSObject.Properties['Value']) {
                $Row | Add-Member -NotePropertyName 'Value' -NotePropertyValue '--' -Force
            }
        }
        $Columns = @($Columns + 'Value')
    }
    $TableParams['Columns'] = [string[]]$Columns
    # Always specify ColumnWidths (AsBuiltReport table standard): 40/60 for key/value List tables,
    # evenly distributed and summing to 100 for multi-column tables.
    if ($List) {
        $TableParams['ColumnWidths'] = 40, 60
    } else {
        $ColumnCount = @($Columns).Count
        if ($ColumnCount -ge 1) {
            $Base = [math]::Floor(100 / $ColumnCount)
            $Widths = @(for ($i = 0; $i -lt $ColumnCount; $i++) { $Base })
            $Remainder = 100 - ($Base * $ColumnCount)
            for ($i = 0; $i -lt $Remainder; $i++) { $Widths[$i] += 1 }
            $TableParams['ColumnWidths'] = [int[]]$Widths
        }
    }
    if ($Report.ShowTableCaptions -and -not $List) {
        $TableParams['Caption'] = "- $Name"
    }

    if (-not $List -and $TableChunkSize -gt 0 -and $Rows.Count -gt $TableChunkSize) {
        Paragraph "$Name contains $($Rows.Count) records. Rendering the table in chunks of $TableChunkSize rows."
        for ($Start = 0; $Start -lt $Rows.Count; $Start += $TableChunkSize) {
            $End = [Math]::Min($Start + $TableChunkSize - 1, $Rows.Count - 1)
            $ChunkRows = @($Rows[$Start..$End])
            $ChunkParams = $TableParams.Clone()
            $ChunkName = "$Name (Rows $($Start + 1)-$($End + 1) of $($Rows.Count))"
            $ChunkParams['Name'] = $ChunkName
            if ($Report.ShowTableCaptions) {
                $ChunkParams['Caption'] = "- $ChunkName"
            }
            $ChunkRows | Table @ChunkParams
        }
        return
    }

    $Rows | Table @TableParams
}

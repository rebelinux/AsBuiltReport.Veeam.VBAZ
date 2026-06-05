# Veeam Backup for Microsoft Azure As Built Report

`AsBuiltReport.Veeam.VBAZ` generates an as built report for Veeam Backup for Microsoft Azure appliances using the VBAZ REST API.

## Requirements

- PowerShell 5.1 or PowerShell 7
- `AsBuiltReport.Core`
- `AsBuiltReport.Chart`
- `AsBuiltReport.Diagram`
- Network access to the VBAZ REST API, normally `https://<appliance>:11005`
- A VBAZ account with read access to configuration, inventory, policy, session and restore point data

## Installation

Install the module from the PowerShell Gallery; its prerequisite modules (`AsBuiltReport.Core`, `AsBuiltReport.Chart` and `AsBuiltReport.Diagram`) are installed automatically:

```powershell
Install-Module -Name AsBuiltReport.Veeam.VBAZ -Repository PSGallery -Scope CurrentUser
```

To update an existing installation:

```powershell
Update-Module -Name AsBuiltReport.Veeam.VBAZ
```

## Example

```powershell
New-AsBuiltReport -Report Veeam.VBAZ -Target vbaz01.example.com -Credential (Get-Credential) -Format Html,Word -OutputFolderPath C:\Reports -ReportConfigFilePath .\AsBuiltReport.Veeam.VBAZ.json
```

For lab appliances using self-signed certificates, set `Options.SkipCertificateCheck` to `true` in the report JSON.

If the appliance API is published on a different port, such as `443`, set `Options.ApiPort` accordingly.

For offline development or report testing from a collector capture, set `Options.CapturePath` to either the extracted capture folder or the collector ZIP file. When `CapturePath` is set, the module reads saved envelopes instead of connecting to the appliance.

Sample configs are included under `Samples`:

- `AsBuiltReport.Veeam.VBAZ.Level1.json`
- `AsBuiltReport.Veeam.VBAZ.Level2.json`
- `AsBuiltReport.Veeam.VBAZ.Level3.json`

## Configuration

The report is generated from a JSON configuration file supplied with `-ReportConfigFilePath`. A default template, `AsBuiltReport.Veeam.VBAZ.json`, ships inside the module, and three ready-to-use samples are provided under `Samples/`. The file is divided into four sections — `Report`, `Options`, `InfoLevel` and `HealthCheck`. Change the values only; do not rename the properties.

### Report

The `Report` section configures the report metadata and document-level features.

| Name | Description |
| --- | --- |
| Name | The name of the As Built Report |
| Version | The report version |
| Status | The report release status |
| Language | The report language (`en-US`) |
| ShowCoverPageImage | Toggle to enable/disable the cover page image |
| ShowTableOfContents | Toggle to enable/disable the table of contents |
| ShowHeaderFooter | Toggle to enable/disable the page header and footer |
| ShowTableCaptions | Toggle to enable/disable table captions/numbering |

### Options

The `Options` section controls how the module connects to the appliance, what optional content is rendered, and how large tables are handled.

| Option | Description | Default |
| --- | --- | --- |
| ReportStyle | Document style applied to the report (`Veeam` or `Default`) | `Veeam` |
| ApiPort | TCP port of the VBAZ REST API | `11005` |
| ApiVersion | VBAZ REST API version | `v8.1` |
| SkipCertificateCheck | Ignore TLS certificate validation errors (lab/self-signed appliances) | `false` |
| CapturePath | Generate the report offline from a collector capture (folder or ZIP) instead of connecting | `""` |
| PageSize | REST API paging size used when collecting large collections | `500` |
| MaxTableRows | Hard cap on rows rendered per table (`0` = unlimited) | `0` |
| TableChunkSize | Split large non-list tables into chunks of this many rows | `500` |
| OperationsDetailMode | Per-session/per-restore-point detail: `Summary`, `Grouped` or `Full` | `Grouped` |
| StaleBackupThresholdDays | Flag protected workloads whose last backup is older than this many days | `7` |
| EnableCharts | Render summary charts (requires `AsBuiltReport.Chart`) | `true` |
| EnableDiagrams | Render the topology diagram (requires `AsBuiltReport.Diagram`) | `true` |
| EnableDiagramLogo | Show the Veeam logo header on the diagram | `true` |
| EnableDiagramDebug | Render the diagram with debug borders | `false` |
| DiagramTheme | Diagram colour theme | `White` |
| DiagramWaterMark | Optional watermark text on the diagram | `""` |
| ExportDiagrams | Export the diagram to a separate file | `false` |
| ExportDiagramsFormat | Diagram export format(s), e.g. `png` | `png` |
| EnableDiagramSignature | Add a signature block to the diagram | `false` |
| SignatureAuthorName | Author name used in the diagram signature | `""` |
| SignatureCompanyName | Company name used in the diagram signature | `""` |
| RoundUnits | Decimal places used when rounding capacity values | `1` |
| UpdateCheck | Check the PowerShell Gallery for a newer module version at runtime | `true` |

### InfoLevel

The `InfoLevel` section sets the amount of detail in each section. The report uses a deliberately small model, consistent with the VBR and VB365 reports:

- `0`: disabled
- `1`: summary
- `2`: detailed
- `3`: deep diagnostic, used only for broad discovery inventory and child endpoint fan-out

InfoLevel keys are grouped as `System`, `Infrastructure`, `Protection` and `Operations`. The per-section behaviour at each level is documented in the [Section Matrix](#section-matrix) below.

### HealthCheck

The `HealthCheck` section toggles the environment health checks. When any flag is enabled, the report opens with a consolidated **Health Check Summary** and highlights exceptions inline (see [Health Checks](#health-checks)).

| Health Check | Description |
| --- | --- |
| System.License | Flag expired or invalid licensing |
| System.ConfigurationBackup | Flag a disabled scheduled configuration backup |
| System.Security | Surface security-related exceptions (e.g. certificates expiring within 30 days) |
| Infrastructure.Repositories | Flag unhealthy or non-immutable repositories |
| Infrastructure.Workers | Flag worker exceptions |
| Protection.Policies | Flag policy exceptions |
| Operations.Sessions | Flag failed or warning job sessions |

## Section Matrix

| Section | Level 1 Summary | Level 2 Detailed | Level 3 Deep Diagnostic |
| --- | --- | --- | --- |
| System.Appliance | server name, version, region, status and time | support/private deployment state and additional server fields | reserved for raw payload review only when needed |
| System.License | license type and instance usage | licensed resources and licensing server detail | reserved for raw payload review only when needed |
| System.ConfigurationBackup | configuration backup state and schedule | stats, retention and restore point detail | configuration check/session endpoints where available |
| System.Security | users and certificate summary | SAML, retention, certificate and service account metadata | user/account detail fan-out where available |
| Infrastructure.Accounts | Azure service account, standard account and tenant counts | account state, permissions, worker-management selection and subscription associations | account detail fan-out where available |
| Infrastructure.Subscriptions | tenant/subscription/region counts | subscription, region and resource group summaries | broad Azure discovery inventory |
| Infrastructure.Repositories | repository count, status and region | storage account/container/folder, storage tier, encryption, immutability and ownership | repository detail fan-out where available |
| Infrastructure.Workers | worker count and status | worker profile, statistics and network configuration | custom tags and per-region worker detail where available |
| Protection.Policies | policy counts by workload and enabled state | policy status, schedule, repository target, retention and charts | selected, excluded, region and protected child paths |
| Protection.ProtectedItems | protected workload counts | protected VM, SQL, file share, Cosmos DB and VNet details | protected item detail fan-out where available |
| Protection.Templates | SLA/storage template counts | template definitions and assignments | template detail fan-out where available |
| Operations.Overview | overview statistics and charts | storage usage, protected workloads, top policy duration and bottlenecks | drilldown endpoints where available |
| Operations.Sessions | job session status summary | session status/result charts plus summaries by status and type | same as Level 2 (per-session detail is opt-in via `OperationsDetailMode = Full`, not the level) |
| Operations.RestorePoints | restore point counts by workload | grouped restore point summaries by policy/workload | same as Level 2 (per-restore-point detail is opt-in via `OperationsDetailMode = Full`, not the level) |

## High Volume Operations

Following the VBR report convention, operational run history is summarized, not enumerated. In the VBR report operational detail (`Jobs.Restores`) is a deliberate, off-by-default opt-in rather than a function of the detail level, and there is no per-session run-history table at all. This report mirrors that: per-session and per-restore-point detail is controlled only by `Options.OperationsDetailMode`, never as a side effect of raising `InfoLevel` to 3.

- `Options.OperationsDetailMode`: `Summary`, `Grouped` or `Full`. **All sample configs (including Level 3) default to `Grouped`** so the report documents configuration and grouped operational summaries. Set it to `Full` only when a per-session/per-restore-point operational appendix is genuinely wanted.
- When `Full` is set, the per-session detail tables still exclude system/housekeeping session types (retention, infrastructure rescan, configuration sync, snapshot deletion, repository creation); those remain counted in the *Job Session Summary by Type* table. A note records how many were omitted.
- `Options.TableChunkSize`: splits large non-list tables into multiple tables. The sample configs use `500`.
- `Options.MaxTableRows`: optional hard cap, applied as the safety valve when `Full` detail is enabled. Set to `0` to render all rows.

## Health Checks

When any `HealthCheck` flag is enabled, the report opens with a **Health Check Summary** section that consolidates configuration and operational exceptions into a single, severity-sorted table so they are visible without scrolling the full report. In addition to the inline cell highlighting, the summary surfaces:

- disabled scheduled configuration backup
- repositories that are not immutable, or not in a healthy status
- Azure service accounts with missing permissions or an invalid cloud state
- protected workloads whose last backup is older than the stale threshold
- job sessions with a failed or warning result
- certificates expiring within 30 days

`Options.StaleBackupThresholdDays` controls the stale-backup threshold (default `7`).

## Policy Configuration Detail (Level 3)

At Level 3, each backup policy is followed by a **Configuration** sub-section that documents the policy's actual scope from the selected, excluded, region and protected child endpoints: a summary line (backup type, selected/excluded/protected item counts, regions in scope) plus a table of the specific virtual machines, databases or file shares the policy selects and excludes.

## Charts and Diagrams

When enabled, the module renders:

- protected workload and storage usage charts from `/overview/*` endpoints
- policy state/result charts from policy collections
- job session result charts from `/jobSessions`
- license/resource charts where numeric license resource data is available
- a VBAZ topology diagram showing appliance, accounts, subscriptions, repositories, workers, policies and protected workload groups

The topology diagram leads with the Veeam logo and report title at the top by default. Set `Options.EnableDiagramLogo` to `false` to render the diagram without the header logo.

## API Endpoint Groups

The module currently collects these read-only endpoint groups:

| Group | Endpoints |
| --- | --- |
| Appliance | `/system/about`, `/system/status`, `/system/serverInfo`, `/system/time`, `/system/supportInfo`, `/system/privateDeployment/state` |
| License | `/license`, `/license/resources`, `/licenseAgreement` |
| Configuration backup | `/configurationBackup/stats`, `/configurationBackup/settings`, `/configurationBackup/restorePoints` |
| Security | `/users`, `/settings/certificates`, `/settings/retention`, `/settings/saml2/idp`, `/settings/saml2/sp` |
| Accounts | `/accounts/azure/service`, `/accounts/standard`, `/cloudInfrastructure/tenants` |
| Cloud inventory | `/cloudInfrastructure/subscriptions`, `/cloudInfrastructure/regions`, `/cloudInfrastructure/resourceGroups` |
| Repositories | `/repositories`, `/veeamVaults` |
| Workers | `/workers`, `/workers/statistics`, `/workers/networkConfiguration`, `/workers/profiles`, `/workers/customTags` |
| Policies | `/policies/virtualMachines`, `/policy/slaBased/virtualMachines`, `/policies/fileShares`, `/policies/sql`, `/policies/cosmosDb`, `/policy/vnet` |
| Policy children at level 3 | `/{policyPath}/{policyId}/selectedItems`, `/{policyPath}/{policyId}/excludedItems`, `/{policyPath}/{policyId}/regions`, `/{policyPath}/{policyId}/protectedItems` |
| Protected items | `/protectedItem/virtualMachines`, `/protectedItem/sql`, `/protectedItem/fileShares`, `/protectedItem/cosmosDb`, `/protectedItem/vnet` |
| Templates | `/policyTemplates/slaTemplate`, `/policyTemplates/storageTemplate` |
| Sessions | `/jobSessions` |
| Restore points | `/restorePoints/virtualMachines`, `/restorePoints/sql`, `/restorePoints/fileShares`, `/restorePoints/cosmosDb/repository`, `/restorePoints/cosmosDb/continuous`, `/restorePoints/vnets` |
| Overview | `/overview/sessionsSummary`, `/overview/statistics`, `/overview/protectedWorkloads`, `/overview/storageUsage`, `/overview/topPoliciesDuration`, `/overview/bottlenecksOverview` |
| Discovery at level 3 | `/cloudInfrastructure/availabilitySets`, `/cloudInfrastructure/availabilityZones`, `/cloudInfrastructure/keyVaults`, `/cloudInfrastructure/networkSecurityGroups`, `/cloudInfrastructure/storageAccounts`, `/cloudInfrastructure/sqlServers`, `/cloudInfrastructure/sqlElasticPools`, `/virtualMachines`, `/cloudInfrastructure/virtualNetworks`, `/cloudInfrastructure/virtualMachineSizes`, `/fileShares`, `/databases`, `/cosmosDb`, `/cloudInfrastructure/tags` |

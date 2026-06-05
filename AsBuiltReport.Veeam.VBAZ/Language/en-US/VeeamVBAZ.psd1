# culture = 'en-US'
@{
    InvokeAsBuiltReportVeeamVBAZ = ConvertFrom-StringData @'
        ReportIntro = The following section provides an overview of the Veeam Backup for Microsoft Azure appliance, cloud infrastructure, protection policies, protected workloads and operational restore data collected through the VBAZ REST API.
        IseErrorMessage = You cannot run this script inside the PowerShell ISE. Please execute it from the PowerShell Command Window.
        Connecting = Connecting to Veeam Backup for Microsoft Azure appliance '{0}'.
        LoadingCapture = Loading Veeam Backup for Microsoft Azure capture '{0}'.
        CredentialRequired = A credential is required to connect to a Veeam Backup for Microsoft Azure appliance. Provide -Credential, or set Options.CapturePath to generate the report from a collector capture.
        UnableToComplete = Unable to complete Veeam Backup for Microsoft Azure report for '{0}': {1}
'@

    ExportAbrVbazDiagram = ConvertFrom-StringData @'
        Heading = Infrastructure Diagram
        DiagramError = Unable to generate the VBAZ infrastructure diagram: {0}
'@

    GetAbrVbazHealthCheckSection = ConvertFrom-StringData @'
        Heading = Health Check Summary
        Paragraph = The following section consolidates the configuration and operational exceptions identified by the enabled health checks. Review each item against the expected design for this environment. Items highlighted in red are critical; items highlighted in amber are warnings.
        NoFindings = No health check exceptions were identified.
'@

    GetAbrVbazSystemSection = ConvertFrom-StringData @'
        Heading = System
        Paragraph = The following section summarizes the VBAZ appliance, licensing, configuration backup and security settings.
'@

    GetAbrVbazAppliance = ConvertFrom-StringData @'
        Heading = Appliance
'@

    GetAbrVbazLicense = ConvertFrom-StringData @'
        Heading = License
'@

    GetAbrVbazConfigurationBackup = ConvertFrom-StringData @'
        Heading = Configuration Backup
'@

    GetAbrVbazSecurity = ConvertFrom-StringData @'
        Heading = Security
'@

    GetAbrVbazInfrastructureSection = ConvertFrom-StringData @'
        Heading = Cloud Infrastructure
        Paragraph = The following section summarizes the connected Azure accounts, subscriptions, repositories, workers and discovery inventory used by the VBAZ appliance.
'@

    GetAbrVbazTenant = ConvertFrom-StringData @'
        Heading = Azure Tenants
        Paragraph = Azure tenants identify the Microsoft Entra tenants known to the VBAZ appliance through connected accounts. They provide tenant context for subscriptions and protected Azure resources.
'@

    GetAbrVbazSubscription = ConvertFrom-StringData @'
        Heading = Subscriptions
'@

    GetAbrVbazAzureAccount = ConvertFrom-StringData @'
        Heading = Azure Service Accounts
'@

    GetAbrVbazStandardAccount = ConvertFrom-StringData @'
        Heading = Standard Accounts
'@

    GetAbrVbazResourceGroup = ConvertFrom-StringData @'
        Heading = Resource Groups
        Paragraph = Resource groups discovered by the VBAZ appliance, grouped by subscription. The VBAZ resource group endpoint does not reliably expose a region, so resource groups are summarized by subscription rather than by region.
'@

    GetAbrVbazRepository = ConvertFrom-StringData @'
        Heading = Repositories
        RepositoryDetails = Repository Details
'@

    GetAbrVbazWorker = ConvertFrom-StringData @'
        Heading = Workers
        WorkerNetworkConfiguration = Worker Network Configuration
        WorkerProfiles = Worker Profiles
        WorkerStatistics = Worker Statistics
        WorkerDetails = Worker Details
'@

    GetAbrVbazDiscovery = ConvertFrom-StringData @'
        Heading = Azure Discovery Inventory
'@

    GetAbrVbazProtectionSection = ConvertFrom-StringData @'
        Heading = Protection
        Paragraph = The following section summarizes backup policies, SLA policies, templates and protected workloads.
'@

    GetAbrVbazPolicy = ConvertFrom-StringData @'
        Heading = Policies
        Configuration = {0} Configuration
        ConfigurationSummary = Backup type: {0}. Selected items: {1}. Excluded items: {2}. Protected items: {3}. Regions in scope: {4}.
'@

    GetAbrVbazProtectedItem = ConvertFrom-StringData @'
        Heading = Protected Items
'@

    GetAbrVbazTemplate = ConvertFrom-StringData @'
        Heading = Templates
'@

    GetAbrVbazOperationsSection = ConvertFrom-StringData @'
        Heading = Operations
        Paragraph = The following section summarizes operational dashboards, job sessions and restore point inventory exposed by the VBAZ REST API.
'@

    GetAbrVbazOverview = ConvertFrom-StringData @'
        Heading = Overview
        StorageUsageParagraph = Storage usage values are converted from raw byte counts where the dashboard reports capacity metrics. The raw value is retained for auditability.
'@

    GetAbrVbazJobSession = ConvertFrom-StringData @'
        Heading = Job Sessions
        PolicySnapshotHeading = Policy Snapshot Sessions
        OmittedSessions = {0} system and maintenance session(s) across {1} housekeeping type(s) ({2}) are included in the summary by type above and omitted from the per-session detail tables below to keep the report focused on policy, backup and restore activity.
'@

    GetAbrVbazRestorePoint = ConvertFrom-StringData @'
        Heading = Restore Points
        RestorePointDetails = Restore Point Details
'@
}

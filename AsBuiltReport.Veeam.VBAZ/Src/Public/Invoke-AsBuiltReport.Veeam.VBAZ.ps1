function Invoke-AsBuiltReport.Veeam.VBAZ {
    <#
    .SYNOPSIS
        Documents Veeam Backup for Microsoft Azure appliances.
    .DESCRIPTION
        Generates a Word/HTML/Text as built report using the Veeam Backup for Microsoft Azure REST API and PScribo.
    .PARAMETER Target
        The IP address or FQDN of the Veeam Backup for Microsoft Azure appliance(s) to document.
        Multiple appliances may be supplied.
    .PARAMETER Credential
        The credential used to authenticate to the Veeam Backup for Microsoft Azure REST API.
        Not required when generating a report from an offline collector capture (Options.CapturePath).
    .EXAMPLE
        New-AsBuiltReport -Report Veeam.VBAZ -Target vbaz01.example.com -Credential (Get-Credential) -Format Html,Word -OutputFolderPath C:\Reports

        Generates HTML and Word As Built Reports for the appliance 'vbaz01.example.com' in C:\Reports.
    .NOTES
        Version:        0.1.0
        Author:         AsBuiltReport Community
        Github:         AsBuiltReport
        Credits:        Iain Brighton (@iainbrighton) - PScribo module
    .LINK
        https://github.com/acgdickie/AsBuiltReport.Veeam.VBAZ
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Scope = 'Function')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Target,

        [ValidateNotNullOrEmpty()]
        [PSCredential] $Credential
    )

    # Localized structural strings (populated by AsBuiltReport.Core from Language\<culture>\VeeamVBAZ.psd1).
    $LocalizedData = $reportTranslate.InvokeAsBuiltReportVeeamVBAZ

    if ($psISE) {
        Write-Error -Message $LocalizedData.IseErrorMessage
        break
    }

    $script:Report = $ReportConfig.Report
    $script:InfoLevel = $ReportConfig.InfoLevel
    $script:Options = $ReportConfig.Options
    $script:HealthCheck = $ReportConfig.HealthCheck

    # A live connection requires a credential; offline capture mode (Options.CapturePath) does not.
    if ([string]::IsNullOrWhiteSpace($Options.CapturePath) -and -not $Credential) {
        throw $LocalizedData.CredentialRequired
    }

    if ($Options.UpdateCheck) {
        # Core's Write-ReportModuleInfo prepends 'AsBuiltReport.', so pass the short Vendor.Technology name.
        Write-ReportModuleInfo -ModuleName 'Veeam.VBAZ'
    }

    # Verify the report-specific prerequisite modules are installed at the required versions.
    Get-RequiredModule -Name 'AsBuiltReport.Chart' -Version '0.3.2'
    Get-RequiredModule -Name 'AsBuiltReport.Diagram' -Version '1.0.7'

    if ($Options.ReportStyle -eq 'Veeam') {
        & "$PSScriptRoot\..\..\AsBuiltReport.Veeam.VBAZ.Style.ps1"
    } else {
        Style -Name 'ON' -Size 8 -BackgroundColor '4c7995' -Color '4c7995'
        Style -Name 'OFF' -Size 8 -BackgroundColor 'ADDBDB' -Color 'ADDBDB'
    }

    $script:TextInfo = (Get-Culture).TextInfo

    foreach ($System in $Target) {
        try {
            if ([string]::IsNullOrWhiteSpace($Options.CapturePath)) {
                Write-PScriboMessage -Message ($LocalizedData.Connecting -f $System)
                Connect-AbrVbazApi -Target $System -Credential $Credential
            } else {
                Write-PScriboMessage -Message ($LocalizedData.LoadingCapture -f $Options.CapturePath)
                $script:AbrVbazTarget = $System
            }
            Initialize-AbrVbazInventory

            $DisplayName = Get-AbrVbazApplianceName -Default $System

            Section -Style Heading1 $DisplayName {
                Paragraph $LocalizedData.ReportIntro
                BlankLine

                if ($Options.EnableDiagrams) {
                    Export-AbrVbazDiagram
                }

                Get-AbrVbazHealthCheckSection
                Get-AbrVbazSystemSection
                Get-AbrVbazInfrastructureSection
                Get-AbrVbazProtectionSection
                Get-AbrVbazOperationsSection
            }
        } catch {
            Write-PScriboMessage -IsWarning -Message ($LocalizedData.UnableToComplete -f $System, $_.Exception.Message)
        } finally {
            if ([string]::IsNullOrWhiteSpace($Options.CapturePath)) {
                Disconnect-AbrVbazApi
            }
        }
    }
}

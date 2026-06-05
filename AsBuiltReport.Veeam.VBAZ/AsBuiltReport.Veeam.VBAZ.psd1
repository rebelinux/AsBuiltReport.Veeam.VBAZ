@{
    RootModule = 'AsBuiltReport.Veeam.VBAZ.psm1'
    ModuleVersion = '0.1.0'
    GUID = '0b7b1b2a-1641-4f57-bf76-0c389f910b30'
    Author = 'AsBuiltReport Community'
    CompanyName = 'AsBuiltReport'
    Copyright = '(c) AsBuiltReport Community. All rights reserved.'
    Description = 'A PowerShell module to generate an as built report on the configuration of Veeam Backup for Microsoft Azure using the VBAZ REST API.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    RequiredModules = @(
        @{ ModuleName = 'AsBuiltReport.Core'; ModuleVersion = '1.6.4' },
        @{ ModuleName = 'AsBuiltReport.Chart'; ModuleVersion = '0.3.2' },
        @{ ModuleName = 'AsBuiltReport.Diagram'; ModuleVersion = '1.0.7' }
    )
    FunctionsToExport = @('Invoke-AsBuiltReport.Veeam.VBAZ')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('AsBuiltReport', 'Report', 'Veeam', 'VBAZ', 'Azure', 'Documentation', 'REST', 'PScribo', 'Windows', 'Linux', 'MacOS', 'PSEdition_Desktop', 'PSEdition_Core')
            LicenseUri = 'https://github.com/acgdickie/AsBuiltReport.Veeam.VBAZ/blob/master/LICENSE'
            ProjectUri = 'https://github.com/acgdickie/AsBuiltReport.Veeam.VBAZ'
            IconUri = 'https://github.com/acgdickie.png'
            ReleaseNotes = 'https://raw.githubusercontent.com/acgdickie/AsBuiltReport.Veeam.VBAZ/master/CHANGELOG.md'
        }
    }
}

#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    .SYNOPSIS
        Pester tests for the AsBuiltReport.Veeam.VBAZ module.
    .DESCRIPTION
        Validates the module manifest, source-file integrity, per-resource function
        layout, JSON configuration samples, en-US localization data and (when the
        analyzer is available) PSScriptAnalyzer compliance.
    .NOTES
        Run from the module root:  Invoke-Pester -Path .\Tests
#>

BeforeDiscovery {
    # Tests/ lives at the repo root; the publishable module is in a same-named nested folder.
    $RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    $ModuleName = 'AsBuiltReport.Veeam.VBAZ'
    $ModuleRoot = Join-Path $RepoRoot $ModuleName

    # All source scripts (used for parse + localization-reference checks).
    $SourceFiles = @(Get-ChildItem -Path (Join-Path $ModuleRoot 'Src') -Filter '*.ps1' -Recurse -File |
            ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } })

    # Files that must contain exactly one function matching the file name.
    $FunctionFiles = @(
        Get-ChildItem -Path (Join-Path $ModuleRoot 'Src\Public') -Filter '*.ps1' -Recurse -File
        Get-ChildItem -Path (Join-Path $ModuleRoot 'Src\Private\Report') -Filter '*.ps1' -Recurse -File
    ) | ForEach-Object { @{ Name = $_.Name; Path = $_.FullName; BaseName = $_.BaseName } }

    # Default config (ships in the module) + every sample config (lives at the repo root).
    $ConfigFiles = @(
        @{ Name = "$ModuleName.json"; Path = (Join-Path $ModuleRoot "$ModuleName.json") }
        Get-ChildItem -Path (Join-Path $RepoRoot 'Samples') -Filter '*.json' -File |
            ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } }
    )
}

BeforeAll {
    $script:RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    $script:ModuleName = 'AsBuiltReport.Veeam.VBAZ'
    $script:ModuleRoot = Join-Path $script:RepoRoot $script:ModuleName
    $script:ManifestPath = Join-Path $script:ModuleRoot "$script:ModuleName.psd1"
    $script:LanguagePath = Join-Path $script:ModuleRoot 'Language\en-US\VeeamVBAZ.psd1'

    # Load the localization data by executing the psd1 (it uses ConvertFrom-StringData,
    # so Import-PowerShellDataFile cannot parse it). The file is trusted repo content.
    $script:Localized = & ([scriptblock]::Create((Get-Content -Path $script:LanguagePath -Raw)))
}

Describe 'Module manifest' {
    It 'exists' {
        $script:ManifestPath | Should -Exist
    }
    It 'is a valid module manifest' {
        { Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop } | Should -Not -Throw
    }
    It 'declares the root module, version and GUID' {
        $manifest = Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop
        $manifest.RootModule | Should -Be "$script:ModuleName.psm1"
        $manifest.Version | Should -BeOfType ([version])
        $manifest.Guid | Should -Not -Be ([guid]::Empty)
    }
    It 'requires AsBuiltReport.Core, Chart and Diagram' {
        $manifest = Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop
        $required = $manifest.RequiredModules.Name
        $required | Should -Contain 'AsBuiltReport.Core'
        $required | Should -Contain 'AsBuiltReport.Chart'
        $required | Should -Contain 'AsBuiltReport.Diagram'
    }
    It 'exports only the Invoke-AsBuiltReport.Veeam.VBAZ function' {
        $manifest = Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop
        $manifest.ExportedFunctions.Keys | Should -Be 'Invoke-AsBuiltReport.Veeam.VBAZ'
    }
}

Describe 'Module import' {
    It 'imports without error' {
        { Import-Module -Name $script:ManifestPath -Force -ErrorAction Stop } | Should -Not -Throw
    }
    It 'exposes the public entry-point command' {
        Import-Module -Name $script:ManifestPath -Force -ErrorAction Stop
        Get-Command -Name 'Invoke-AsBuiltReport.Veeam.VBAZ' -Module $script:ModuleName | Should -Not -BeNullOrEmpty
    }
    It 'defines the refactored per-resource section functions inside the module' {
        Import-Module -Name $script:ManifestPath -Force -ErrorAction Stop
        $mod = Get-Module -Name $script:ModuleName
        $internal = & $mod { Get-Command -CommandType Function -Name 'Get-AbrVbaz*' | Select-Object -ExpandProperty Name }
        foreach ($fn in 'Get-AbrVbazSystemSection', 'Get-AbrVbazInfrastructureSection', 'Get-AbrVbazProtectionSection',
            'Get-AbrVbazOperationsSection', 'Get-AbrVbazHealthCheckSection', 'Get-AbrVbazAppliance', 'Get-AbrVbazPolicy',
            'Get-AbrVbazRepository', 'Get-AbrVbazWorker', 'Get-AbrVbazRestorePoint') {
            $internal | Should -Contain $fn
        }
    }
}

Describe 'Source file integrity' {
    It '<Name> has no parse errors' -ForEach $SourceFiles {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
        $errors | Should -BeNullOrEmpty
    }
}

Describe 'Per-resource function layout' {
    It '<Name> defines exactly one function named after the file' -ForEach $FunctionFiles {
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
        $functions = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
        $functions.Count | Should -Be 1
        $functions[0].Name | Should -Be $BaseName
    }
}

Describe 'Configuration samples' {
    It '<Name> is valid JSON with the required top-level sections' -ForEach $ConfigFiles {
        $Path | Should -Exist
        $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
        foreach ($section in 'Report', 'Options', 'InfoLevel', 'HealthCheck') {
            $json.PSObject.Properties.Name | Should -Contain $section
        }
    }
    It '<Name> uses InfoLevel values within the supported 0-3 range' -ForEach $ConfigFiles {
        $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
        foreach ($group in $json.InfoLevel.PSObject.Properties) {
            if ($group.Name -eq '_comment_') { continue }
            foreach ($level in $group.Value.PSObject.Properties) {
                if ($level.Name -eq '_comment_') { continue }
                $level.Value | Should -BeGreaterOrEqual 0
                $level.Value | Should -BeLessOrEqual 3
            }
        }
    }
}

Describe 'Localization (en-US)' {
    It 'loads the VeeamVBAZ.psd1 data file' {
        $script:Localized | Should -BeOfType ([hashtable])
        $script:Localized.Keys.Count | Should -BeGreaterThan 0
    }
    It 'has a non-empty value for every localized string' {
        foreach ($group in $script:Localized.Keys) {
            $script:Localized[$group] | Should -BeOfType ([hashtable]) -Because "group '$group' should be a ConvertFrom-StringData hashtable"
            foreach ($key in $script:Localized[$group].Keys) {
                [string]::IsNullOrWhiteSpace($script:Localized[$group][$key]) | Should -BeFalse -Because "$group.$key must not be empty"
            }
        }
    }
    It 'defines every $reportTranslate group referenced in source' {
        $referenced = [System.Collections.Generic.HashSet[string]]::new()
        Get-ChildItem -Path (Join-Path $script:ModuleRoot 'Src') -Filter '*.ps1' -Recurse -File | ForEach-Object {
            foreach ($m in [regex]::Matches((Get-Content -Path $_.FullName -Raw), '\$reportTranslate\.(\w+)')) {
                [void]$referenced.Add($m.Groups[1].Value)
            }
        }
        $referenced.Count | Should -BeGreaterThan 0
        foreach ($group in $referenced) {
            $script:Localized.Keys | Should -Contain $group -Because "source references `$reportTranslate.$group"
        }
    }
}

Describe 'PSScriptAnalyzer' {
    BeforeAll {
        $script:Analyzer = Get-Module -ListAvailable -Name PSScriptAnalyzer | Select-Object -First 1
        $script:SettingsPath = Join-Path $script:RepoRoot '.github\workflows\PSScriptAnalyzerSettings.psd1'
    }
    It 'reports no error-severity findings (matches CI failOnErrors)' {
        if (-not $script:Analyzer) { Set-ItResult -Skipped -Because 'PSScriptAnalyzer is not installed' }
        $params = @{ Path = (Join-Path $script:ModuleRoot 'Src'); Recurse = $true; Severity = 'Error' }
        if (Test-Path $script:SettingsPath) { $params['Settings'] = $script:SettingsPath }
        $findings = Invoke-ScriptAnalyzer @params
        $findings | Should -BeNullOrEmpty
    }
}

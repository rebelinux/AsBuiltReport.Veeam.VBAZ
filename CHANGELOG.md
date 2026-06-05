# :arrows_clockwise: Veeam Backup for Microsoft Azure As Built Report Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

##### This project is community maintained and has no sponsorship from Veeam, its employees or any of its affiliates.

## [0.1.0] - 2026-06-04

### Added

- Initial release of the Veeam Backup for Microsoft Azure (VBAZ) As Built Report module.
- Configuration reporting via the VBAZ REST API (`/api/<version>`) with token (password grant) authentication.
- Offline reporting from collector captures via `Options.CapturePath` (folder or ZIP of API envelopes).
- Report sections: System (appliance, license, configuration backup, security), Cloud Infrastructure (accounts, subscriptions, resource groups, repositories, workers, discovery inventory), Protection (policies, per-policy selected/excluded items at Level 3, protected items, templates) and Operations (overview, job sessions, restore points).
- Health Check Summary section consolidating exceptions (disabled configuration backup, non-immutable repositories, account permission issues, stale backups, failed/warning sessions, expiring certificates), with `Options.StaleBackupThresholdDays`.
- Small InfoLevel model (`0` disabled, `1` summary, `2` detailed, `3` deep diagnostic) consistent with the VBR and VB365 modules.
- `Options.OperationsDetailMode` (`Summary`/`Grouped`/`Full`) to control per-session and per-restore-point detail independently of InfoLevel; system/housekeeping session types are excluded from the per-session detail.
- Charts (`AsBuiltReport.Chart`) for protected workloads, storage usage, policy and job session status, with standard Success/Warning/Error colour mapping.
- Veeam topology diagram (`AsBuiltReport.Diagram`) using official Veeam icons, with a configurable header logo via `Options.EnableDiagramLogo`.
- Sample report configurations: `AsBuiltReport.Veeam.VBAZ.Level1.json`, `AsBuiltReport.Veeam.VBAZ.Level2.json` and `AsBuiltReport.Veeam.VBAZ.Level3.json`.
- `en-US` localization data (`Language/en-US/VeeamVBAZ.psd1`) for section headings, introductory paragraphs and runtime messages, resolved through the `$reportTranslate` table populated by `AsBuiltReport.Core`.
- Report sections organized as one public entry point plus per-resource private functions (`Src/Private/Report/Get-AbrVbaz*.ps1`), following the AsBuiltReport module conventions.
- Pester test suite (`Tests/`) covering the module manifest, source-file parsing, per-resource function layout, configuration samples, localization data and PSScriptAnalyzer compliance.

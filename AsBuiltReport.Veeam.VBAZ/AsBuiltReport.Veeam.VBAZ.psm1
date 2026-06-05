# Dot-source all Public and Private function definition files using dynamic discovery.
foreach ($Folder in @('Public', 'Private')) {
    $FolderPath = Join-Path -Path $PSScriptRoot -ChildPath "Src\$Folder"
    if (Test-Path -Path $FolderPath) {
        Get-ChildItem -Path $FolderPath -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                . $_.FullName
            } catch {
                Write-Error -Message "Failed to import function $($_.FullName): $_"
            }
        }
    }
}

# Export only the public functions; the manifest's FunctionsToExport controls what is published.
$Public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Src\Public') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)
Export-ModuleMember -Function $Public.BaseName

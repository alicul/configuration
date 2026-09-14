$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
foreach ($file in @('install.ps1', 'wezterm\session.ps1')) {
    $tokens = $null; $errors = $null
    [Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file), [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count) { throw ($errors | Out-String) }
}
. (Join-Path $root 'wezterm\session.ps1')
function Invoke-Mux {
    param([string[]]$Arguments)
    $script:Captured = $Arguments
}
$env:WEZTERM_PANE = '17'
Open-SelectedFiles -Paths @('C:\Users\licul\space name.txt', 'C:\Users\licul\$literal.txt', 'C:\Users\licul\-option')
if ($Captured[0] -ne 'spawn' -or $Captured[2] -ne '17') { throw 'Incorrect target' }
$manifestPath = $Captured[-1]
try {
    $paths = ConvertFrom-Json ([IO.File]::ReadAllText($manifestPath))
    if ($paths.Count -ne 3 -or $paths[1] -ne 'C:\Users\licul\$literal.txt') {
        throw "Path corrupted: count=$($paths.Count), content=$([IO.File]::ReadAllText($manifestPath))"
    }
} finally { Remove-Item -LiteralPath $manifestPath }
Write-Output 'PASS: Windows manifest preserves paths and targets a new tab'

$temp = Join-Path ([IO.Path]::GetTempPath()) ('wezterm-install-test-' + [guid]::NewGuid())
try {
    & (Join-Path $root 'install.ps1') -DestinationProfile $temp -RoamingDirectory (Join-Path $temp 'Roaming') | Out-Null
    $destination = Join-Path $temp 'Roaming\helix\config.toml'
    [IO.File]::WriteAllText($destination, 'old configuration')
    & (Join-Path $root 'install.ps1') -DestinationProfile $temp -RoamingDirectory (Join-Path $temp 'Roaming') | Out-Null
    & (Join-Path $root 'install.ps1') -DestinationProfile $temp -RoamingDirectory (Join-Path $temp 'Roaming') | Out-Null
    $backups = @(Get-ChildItem -LiteralPath (Split-Path -Parent $destination) -Filter 'config.toml.backup-*')
    if ($backups.Count -ne 1 -or [IO.File]::ReadAllText($backups[0].FullName) -ne 'old configuration') { throw 'Backup failed' }
    if ((Get-FileHash $destination).Hash -ne (Get-FileHash (Join-Path $root 'helix\config.toml')).Hash) { throw 'Copy failed' }
} finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
Write-Output 'PASS: PowerShell installer backs up changed files and is idempotent'

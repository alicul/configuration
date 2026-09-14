# Add a terminal only to the old two-pane Yazi + Helix layout. Safe to rerun.
$ErrorActionPreference = 'Stop'
$wezterm = 'C:\Program Files\WezTerm\wezterm.exe'
$helper = Join-Path $env:USERPROFILE '.config\wezterm\session.ps1'
$shell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$json = & $wezterm cli --no-auto-start --prefer-mux list --format json
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the existing mux server' }
$panes = $json | ConvertFrom-Json
foreach ($tab in ($panes | Group-Object window_id,tab_id)) {
    if ($tab.Count -ne 2) { continue }
    $browser = @($tab.Group | Where-Object { $_.left_col -eq 0 -and $_.title -like 'Yazi:*' })
    $editor = @($tab.Group | Where-Object { $_.left_col -gt 0 -and $_.title -match '^hx(\.exe)?$' })
    if ($browser.Count -ne 1 -or $editor.Count -ne 1) { continue }
    $cwd = if ($editor[0].cwd) { ([uri]$editor[0].cwd).LocalPath } else { $env:USERPROFILE }
    $created = & $wezterm cli --no-auto-start --prefer-mux split-pane --pane-id $editor[0].pane_id `
        --bottom --percent 30 --cwd $cwd -- $shell -NoLogo -NoProfile -ExecutionPolicy Bypass `
        -File $helper -Mode terminal
    if ($LASTEXITCODE -ne 0) { throw "Could not split editor pane $($editor[0].pane_id)" }
    Write-Output "Added terminal $created beneath Helix $($editor[0].pane_id) in tab $($editor[0].tab_id)"
}

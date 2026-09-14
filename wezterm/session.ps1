param(
    [ValidateSet('workspace', 'browser', 'terminal')][string]$Mode = 'workspace',
    [string]$Manifest = ''
)
$ErrorActionPreference = 'Stop'
$SessionScript = $PSCommandPath
$SessionDirectory = $PSScriptRoot
$PowerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Invoke-Mux {
    param([string[]]$Arguments)
    & $script:WezTermExe cli --prefer-mux @Arguments
    if ($LASTEXITCODE -ne 0) { throw "WezTerm command failed ($LASTEXITCODE): $($Arguments[0])" }
}

function Get-SessionCommand {
    param([string]$SessionMode, [string]$FileManifest = '')
    $command = @($script:PowerShellExe, '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $script:SessionScript, '-Mode', $SessionMode)
    if ($FileManifest) { $command += @('-Manifest', $FileManifest) }
    return $command
}

function Open-SelectedFiles {
    param([string[]]$Paths)
    # A JSON manifest avoids Windows PowerShell's native argument quoting of
    # arbitrary filenames. The new workspace owns/deletes its manifest.
    $fileManifest = Join-Path ([IO.Path]::GetTempPath()) ("wezterm-open-" + [guid]::NewGuid() + '.json')
    $absolute = @($Paths | ForEach-Object {
        if ([IO.Path]::IsPathRooted($_)) { [IO.Path]::GetFullPath($_) }
        else { [IO.Path]::GetFullPath((Join-Path (Get-Location).ProviderPath $_)) }
    })
    [IO.File]::WriteAllText($fileManifest, (ConvertTo-Json -InputObject $absolute -Compress),
        (New-Object Text.UTF8Encoding($false)))
    try {
        $arguments = @('spawn', '--pane-id', $env:WEZTERM_PANE, '--cwd', (Get-Location).ProviderPath,
            '--') + @(Get-SessionCommand 'workspace' $fileManifest)
        Invoke-Mux -Arguments $arguments | Out-Null
    } catch {
        Remove-Item -LiteralPath $fileManifest -ErrorAction SilentlyContinue
        throw
    }
}

function Start-Browser {
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ("wezterm-yazi-" + [guid]::NewGuid())
    [IO.Directory]::CreateDirectory($temporary) | Out-Null
    $chosen = Join-Path $temporary 'chosen'
    $cwdFile = Join-Path $temporary 'cwd'
    $env:YAZI_CONFIG_HOME = Join-Path $script:SessionDirectory 'yazi'
    try {
        while ($true) {
            Remove-Item -LiteralPath $chosen, $cwdFile -ErrorAction SilentlyContinue
            & $script:YaziExe --chooser-file $chosen --cwd-file $cwdFile
            if (Test-Path -LiteralPath $cwdFile) {
                $directory = [IO.File]::ReadAllText($cwdFile).TrimEnd([char[]]"`r`n")
                if (Test-Path -LiteralPath $directory -PathType Container) {
                    Set-Location -LiteralPath $directory
                }
            }
            if (Test-Path -LiteralPath $chosen) {
                $paths = @([IO.File]::ReadAllLines($chosen) | Where-Object { $_ -ne '' })
                if ($paths.Count) {
                    try { Open-SelectedFiles -Paths $paths }
                    catch { Write-Warning $_; Start-Sleep -Seconds 3 }
                }
            }
            Start-Sleep -Milliseconds 300
        }
    } finally {
        Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Start-Workspace {
    $files = @()
    if ($script:Manifest) {
        $files = ConvertFrom-Json ([IO.File]::ReadAllText($script:Manifest))
        Remove-Item -LiteralPath $script:Manifest
    }
    $arguments = @('split-pane', '--pane-id', $env:WEZTERM_PANE, '--left', '--percent', '25',
        '--cwd', (Get-Location).ProviderPath, '--') + @(Get-SessionCommand 'browser')
    Invoke-Mux -Arguments $arguments | Out-Null
    $arguments = @('split-pane', '--pane-id', $env:WEZTERM_PANE, '--bottom', '--percent', '30',
        '--cwd', (Get-Location).ProviderPath, '--') + @(Get-SessionCommand 'terminal')
    Invoke-Mux -Arguments $arguments | Out-Null
    Invoke-Mux -Arguments @('activate-pane', '--pane-id', $env:WEZTERM_PANE) | Out-Null
    # Keep this an editor pane; the independent terminal is always below it.
    while ($true) {
        & $script:HelixExe @files
        $files = @()
        Start-Sleep -Milliseconds 300
    }
}

function Start-Terminal {
    $shell = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    $shellExe = if ($shell) { $shell.Source } else { $script:PowerShellExe }
    while ($true) {
        & $shellExe -NoLogo
        Start-Sleep -Milliseconds 300
    }
}

function Start-Session {
    # Also find apps installed since Explorer/the parent terminal started.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + $env:Path
    $script:WezTermExe = (Get-Command wezterm.exe -ErrorAction Stop).Source
    $script:HelixExe = (Get-Command hx.exe -ErrorAction Stop).Source
    $script:YaziExe = (Get-Command yazi.exe -ErrorAction Stop).Source
    if ($env:WEZTERM_PANE -notmatch '^\d+$') { throw 'Start this workspace inside a WezTerm mux pane.' }
    switch ($script:Mode) {
        'browser' { Start-Browser }
        'terminal' { Start-Terminal }
        'workspace' { Start-Workspace }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Start-Session }
    catch { Write-Error $_; exit 1 }
}

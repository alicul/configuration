param([string]$DestinationProfile = $env:USERPROFILE, [string]$RoamingDirectory = $env:APPDATA)
$ErrorActionPreference = 'Stop'
function Install-ConfigFile {
    param([string]$Source, [string]$Destination)
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Destination)) | Out-Null
    if (Test-Path -LiteralPath $Destination) {
        if ((Get-FileHash -LiteralPath $Source).Hash -eq (Get-FileHash -LiteralPath $Destination).Hash) {
            Write-Output "Unchanged: $Destination"
            return
        }
        $backup = $Destination + '.backup-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [guid]::NewGuid().ToString('N')
        Move-Item -LiteralPath $Destination -Destination $backup
        Write-Output "Backup: $backup"
    }
    Copy-Item -LiteralPath $Source -Destination $Destination
    Write-Output "Installed: $Destination"
}
$weztermDirectory = Join-Path $DestinationProfile '.config\wezterm'
foreach ($file in @('wezterm.lua', 'session.ps1', 'session.sh', 'yazi\yazi.toml', 'yazi\keymap.toml')) {
    Install-ConfigFile (Join-Path $PSScriptRoot "wezterm\$file") (Join-Path $weztermDirectory $file)
}
Install-ConfigFile (Join-Path $PSScriptRoot 'helix\config.toml') (Join-Path $RoamingDirectory 'helix\config.toml')
Write-Output 'Installed. Existing mux servers and panes were not restarted.'

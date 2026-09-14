param([string]$ConfigFile = "$env:USERPROFILE\.config\wezterm\wezterm.lua")
$ErrorActionPreference = 'Stop'
$wezterm = 'C:\Program Files\WezTerm\wezterm.exe'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('wezterm-config-test-' + [guid]::NewGuid())
[IO.Directory]::CreateDirectory($temp) | Out-Null
try {
    $result = (Join-Path $temp 'result.txt').Replace('\', '/')
    $configPath = $ConfigFile.Replace('\', '/')
    $wrapper = Join-Path $temp 'check.lua'
    $lua = @"
local ok, value = pcall(function() return dofile([=[$configPath]=]) end)
local f = assert(io.open([=[$result]=], 'w'))
f:write(tostring(ok), '\n', tostring(value))
f:close()
if ok then return value else return {} end
"@
    [IO.File]::WriteAllText($wrapper, $lua, (New-Object Text.UTF8Encoding($false)))
    & $wezterm --config-file $wrapper show-keys | Out-Null
    $diagnostic = [IO.File]::ReadAllText($result)
    if (-not $diagnostic.StartsWith('true')) { throw $diagnostic }
    $keys = & $wezterm --config-file $ConfigFile show-keys
    if (-not ($keys -match 'DetachDomain')) { throw 'Lua evaluated but bindings were not applied' }
    $keys | Select-String 'DetachDomain|InputSelector'
    Write-Output 'PASS: actual WezTerm loads the installed configuration and detach bindings'
} finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }

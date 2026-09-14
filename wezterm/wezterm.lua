local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Set the VDI's lowercase short hostname; the IP is already configured.
local vdi = {
  hostname = 'your-vdi-hostname',
  address = '10.52.20.64',
  username = 'alicul',
  wezterm_path = '/home/alicul/.local/bin/wezterm',
}
local host_overrides = {
  -- ['my-laptop'] = { font_size = 20.0 },
}
local is_windows = wezterm.target_triple:find('windows', 1, true) ~= nil
local is_linux = wezterm.target_triple:find('linux', 1, true) ~= nil
local is_wsl = is_linux and wezterm.running_under_wsl()
local hostname = wezterm.hostname():lower():match('^[^.]+')
local is_vdi = is_linux and not is_wsl and hostname == vdi.hostname

-- All panes are owned by an independent server, including native Windows.
-- Keep this FIRST: the helper and WSL proxy use cli --prefer-mux.
config.unix_domains = { { name = 'persistent' } }
config.default_gui_startup_args = { 'connect', 'persistent' }
config.default_domain = 'persistent'
config.default_mux_server_domain = 'local'

-- Use the helper installed alongside this file, on the machine running panes.
if is_windows then
  config.default_prog = {
    'powershell.exe', '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', wezterm.config_dir .. '/session.ps1', '-Mode', 'workspace',
  }
else
  config.default_prog = { 'bash', wezterm.config_dir .. '/session.sh', 'workspace' }
end

-- Ordinary WSL domains are GUI-owned. Replace them with connections to each
-- distro's independent Linux mux server. This also works with WSL 2.
config.wsl_domains = {}
if is_windows then
  for _, domain in ipairs(wezterm.default_wsl_domains()) do
    local distro = domain.distribution
    if distro:match('^Ubuntu') or distro == 'Debian' then
      table.insert(config.unix_domains, {
        name = 'persistent-wsl:' .. distro,
        proxy_command = {
          'wsl.exe', '--distribution', distro, '--exec',
          'sh', '-c',
          'export PATH="$HOME/.local/bin:$PATH"; '
            .. 'unset WEZTERM_UNIX_SOCKET WEZTERM_PANE; '
            .. 'exec wezterm cli --prefer-mux proxy',
        },
      })
    end
  end
  -- Start native Windows; the Linux apps need installation inside WSL before
  -- selecting its persistent domain. Change this to persistent-wsl:Debian etc.
  local startup = 'persistent'
  config.default_gui_startup_args = { 'connect', startup }
  config.default_domain = startup
end

local function read_file(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local contents = f:read '*a'
  f:close()
  return contents
end

local function valid_socket(path)
  if not path or path == '' then return false end
  local ok = wezterm.run_child_process { 'test', '-S', path }
  return ok
end

local function find_ssh_socket()
  if not is_linux then return nil end
  -- Preserve the original oh-my-zsh agent preference over GNOME's agent.
  for _, path in ipairs(wezterm.glob(wezterm.home_dir .. '/.ssh/environment-*')) do
    local contents = read_file(path)
    local sock = contents and contents:match 'SSH_AUTH_SOCK=([^;\r\n]+)'
    if sock then
      sock = sock:match '^%s*(.-)%s*$'
      sock = sock:gsub('^["\']', ''):gsub('["\']$', '')
      if valid_socket(sock) then return sock end
    end
  end
  local inherited = os.getenv 'SSH_AUTH_SOCK'
  if valid_socket(inherited) then return inherited end
  local runtime = os.getenv 'XDG_RUNTIME_DIR'
  if runtime and valid_socket(runtime .. '/gcr/ssh') then
    return runtime .. '/gcr/ssh'
  end
end

local sock = find_ssh_socket()
if sock then config.set_environment_variables = { SSH_AUTH_SOCK = sock } end

config.ssh_domains = {}
if not is_vdi then
  config.ssh_domains = { {
    name = 'VDI',
    remote_address = vdi.address,
    username = vdi.username,
    multiplexing = 'WezTerm',
    remote_wezterm_path = vdi.wezterm_path,
    ssh_option = sock and { identityagent = sock } or nil,
  } }
end

config.font = wezterm.font 'JetBrains Mono'
config.font_size = 20.0
config.window_background_opacity = 0.95
config.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }
-- Keep window controls in the tab bar, including in fullscreen mode.
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.integrated_title_buttons = { 'Hide', 'Maximize', 'Close' }
config.integrated_title_button_alignment = 'Right'
config.window_close_confirmation = 'AlwaysPrompt'
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.initial_cols = 140
config.initial_rows = 36
config.default_cursor_style = 'BlinkingBlock'
config.enable_kitty_keyboard = true
config.exit_behavior = 'Hold'

local fullscreen_initialized = {}
local function initialize_fullscreen(window)
  local id = window:window_id()
  if fullscreen_initialized[id] then return end
  fullscreen_initialized[id] = true
  if not window:get_dimensions().is_full_screen then window:toggle_fullscreen() end
end
wezterm.on('window-config-reloaded', initialize_fullscreen)
wezterm.on('gui-attached', function()
  local workspace = wezterm.mux.get_active_workspace()
  for _, window in ipairs(wezterm.mux.all_windows()) do
    if window:get_workspace() == workspace then
      local gui = window:gui_window()
      if gui then initialize_fullscreen(gui) end
    end
  end
end)

local clipboard = is_windows and 'Clipboard' or 'ClipboardAndPrimarySelection'
config.mouse_bindings = {}
for _, mods in ipairs { 'NONE', 'SHIFT' } do
  for streak = 1, 3 do
    table.insert(config.mouse_bindings, {
      event = { Up = { streak = streak, button = 'Left' } },
      mods = mods,
      action = act.CompleteSelection(clipboard),
    })
  end
end

-- Closing is explicit and confirmed; Ctrl+Shift+E still detaches safely.
-- Ctrl+C/V and Alt+arrows reach Helix unchanged.
config.disable_default_key_bindings = true
local detach = act.DetachDomain 'CurrentPaneDomain'
-- A curated selector excludes the GUI-owned "local" domain.
local choices = {}
for _, domain in ipairs(config.unix_domains) do
  table.insert(choices, { id = domain.name, label = domain.name })
end
if not is_vdi then table.insert(choices, { id = 'VDI', label = 'VDI: ' .. vdi.address }) end
local select_domain = act.InputSelector {
  title = 'Attach a persistent session',
  choices = choices,
  action = wezterm.action_callback(function(window, pane, id)
    if id then window:perform_action(act.AttachDomain(id), pane) end
  end),
}
wezterm.on('new-tab-button-click', function(window, pane)
  window:perform_action(act.SpawnTab 'CurrentPaneDomain', pane)
  return false
end)
config.keys = {
  { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = true } },
  { key = 'e', mods = 'CTRL|SHIFT', action = detach },
  { key = 'F11', mods = 'NONE', action = act.ToggleFullScreen },
  { key = 'l', mods = 'CTRL|SHIFT', action = select_domain },
  { key = 'LeftArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Down' },
  { key = 'PageUp', mods = 'CTRL', action = act.ActivateTabRelative(-1) },
  { key = 'PageDown', mods = 'CTRL', action = act.ActivateTabRelative(1) },
  { key = '+', mods = 'CTRL', action = act.IncreaseFontSize },
  { key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
  { key = '0', mods = 'CTRL', action = act.ResetFontSize },
  { key = 'r', mods = 'CTRL|SHIFT', action = act.ReloadConfiguration },
}
if not is_vdi then
  table.insert(config.keys, {
    key = 'd', mods = 'CTRL|SHIFT', action = act.AttachDomain 'VDI',
  })
end
for key, value in pairs(host_overrides[hostname] or {}) do config[key] = value end
return config

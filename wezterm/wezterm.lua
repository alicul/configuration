local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- WezTerm may be started by the desktop rather than a login shell, so make
-- user-installed programs such as Helix and Yazi available to every pane.
local is_windows = wezterm.target_triple:find('windows', 1, true) ~= nil
local path_separator = is_windows and ';' or ':'
local tool_paths = {
  wezterm.home_dir .. '/bin',
  wezterm.home_dir .. '/.local/bin',
  wezterm.home_dir .. '/.hermit/go/bin',
}
local inherited_path = os.getenv 'PATH'

config.set_environment_variables = {
  PATH = table.concat(tool_paths, path_separator)
    .. (inherited_path and path_separator .. inherited_path or ''),
}

-- Appearance: Clean, modern IDE styling (Cursor / VS Code / Antigravity aesthetic)
config.color_scheme = 'Dark+'
config.font = wezterm.font 'JetBrains Mono'
config.font_size = 18.0
config.window_background_opacity = 0.98
config.window_padding = { left = 2, right = 2, top = 2, bottom = 2 }
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.integrated_title_buttons = { 'Hide', 'Maximize', 'Close' }
config.integrated_title_button_alignment = 'Right'
config.use_fancy_tab_bar = false
-- Integrated window controls live in the tab bar, so keep it visible even
-- though this workspace normally has only one tab.
config.hide_tab_bar_if_only_one_tab = false
config.default_cursor_style = 'BlinkingBlock'
config.enable_kitty_keyboard = true

-- Launch single fullscreen IDE workspace
wezterm.on('gui-startup', function(cmd)
  -- 1. Spawn primary window with Helix
  local tab, editor_pane, window = wezterm.mux.spawn_window {
    args = { 'hx' },
    cwd = (cmd and cmd.cwd) or wezterm.home_dir,
  }

  -- Fullscreen mode
  local gui = window:gui_window()
  if gui then
    gui:toggle_fullscreen()
  end

  -- 2. Left pane: YAZI file tree sidebar (20% width)
  local helix_pane_id = tostring(editor_pane:pane_id())
  local yazi_pane = editor_pane:split {
    direction = 'Left',
    size = 0.20,
    args = { 'yazi' },
    set_environment_variables = {
      HELIX_PANE_ID = helix_pane_id,
      YAZI_CONFIG_HOME = wezterm.config_dir .. '/yazi',
    },
  }

  -- 3. Bottom pane: Terminal shell under Helix (30% height of right column)
  local term_pane = editor_pane:split {
    direction = 'Bottom',
    size = 0.30,
  }

  -- Focus Helix editor pane
  editor_pane:activate()
end)

-- Fullscreen maintenance on reload
wezterm.on('window-config-reloaded', function(window)
  if not window:get_dimensions().is_full_screen then
    window:toggle_fullscreen()
  end
end)

-- Standard IDE Shortcuts
config.keys = {
  { key = 'F11', mods = 'NONE', action = act.ToggleFullScreen },
  { key = 'LeftArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Down' },
  { key = 'c', mods = 'CTRL', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
  { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = '+', mods = 'CTRL', action = act.IncreaseFontSize },
  { key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
  { key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
  { key = '0', mods = 'CTRL', action = act.ResetFontSize },
  { key = 'r', mods = 'CTRL|SHIFT', action = act.ReloadConfiguration },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = true } },
}

return config

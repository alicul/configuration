#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

# 1. Syntax check bash scripts
bash -n "$root/wezterm/open-in-helix.sh" "$root/install.sh"
printf 'PASS: Bash scripts have valid syntax\n'

# The file opener must recover after the original Helix pane exits.
grep -Fq 'wezterm cli split-pane' "$root/wezterm/open-in-helix.sh"
grep -Fq 'state_file=' "$root/wezterm/open-in-helix.sh"
printf 'PASS: Helix pane recovery is configured\n'

# WezTerm must expose user-local and Hermit commands/tools outside a login shell.
grep -Fq "wezterm.home_dir .. '/bin'" "$root/wezterm/wezterm.lua"
grep -Fq "wezterm.home_dir .. '/.local/bin'" "$root/wezterm/wezterm.lua"
grep -Fq "wezterm.home_dir .. '/.hermit/go/bin'" "$root/wezterm/wezterm.lua"
grep -Fq 'config.set_environment_variables' "$root/wezterm/wezterm.lua"
printf 'PASS: WezTerm prepends user-local and Hermit command/tool directories to PATH\n'

# Integrated minimize/maximize/close controls are drawn in the tab bar.
grep -Fq 'config.hide_tab_bar_if_only_one_tab = false' "$root/wezterm/wezterm.lua"
printf 'PASS: WezTerm keeps the integrated window controls visible\n'

# Ctrl+C copies and Ctrl+V pastes; the shell interrupt is configured separately.
grep -Fq "key = 'c', mods = 'CTRL', action = act.CopyTo 'Clipboard'" "$root/wezterm/wezterm.lua"
grep -Fq "key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard'" "$root/wezterm/wezterm.lua"
printf 'PASS: WezTerm provides Ctrl+C copy and Ctrl+V paste\n'

# Helix explicitly enables the Go and Python language servers.
grep -Fq 'language-servers = ["gopls"]' "$root/helix/languages.toml"
grep -Fq 'language-servers = ["basedpyright", "ruff"]' "$root/helix/languages.toml"
grep -Fq 'args = ["server"]' "$root/helix/languages.toml"
grep -Fq 'display-inlay-hints = false' "$root/helix/config.toml"
grep -Fq 'end-of-line-diagnostics = "hint"' "$root/helix/config.toml"
grep -Fq 'cursor-line = "hint"' "$root/helix/config.toml"
grep -Fq 'other-lines = "error"' "$root/helix/config.toml"
grep -Fq 'for language_tool in go gopls dlv basedpyright-langserver ruff' "$root/install.sh"
printf 'PASS: Helix configures Go and Python LSP support\n'

# Enter and mouse clicks enter directories or open the hovered file in Helix.
grep -Fq 'on = "<Enter>", run = "plugin smart-enter"' "$root/wezterm/yazi/keymap.toml"
grep -Fq 'hovered.cha.is_dir and "enter" or "open"' "$root/wezterm/yazi/plugins/smart-enter.yazi/main.lua"
grep -Fq 'ya.emit("open", { hovered = true })' "$root/wezterm/yazi/init.lua"
grep -Fq 'on = "<Esc>", run = "close"' "$root/wezterm/yazi/keymap.toml"
printf 'PASS: Yazi opens files and navigates directories from Enter or click\n'

# Keep Yazi single-column and use the current URL-based opener rule schema.
grep -Fq 'ratio = [0, 1, 0]' "$root/wezterm/yazi/yazi.toml"
grep -Fq 'url = "*", use = "edit"' "$root/wezterm/yazi/yazi.toml"
grep -Fq "open-in-helix.sh\" %s" "$root/wezterm/yazi/yazi.toml"
if grep -Fq 'name = "*"' "$root/wezterm/yazi/yazi.toml"; then
  printf 'FAIL: Yazi opener rules require url or mime, not name\n' >&2
  exit 1
fi
printf 'PASS: Yazi uses a single-column layout and valid opener rules\n'

# 2. Verify installer idempotence and backups in private directory
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT

# A stale recovery ID may be reused by the terminal in a new WezTerm session;
# the live startup-provided editor ID must win.
wezterm() {
  case "${1:-} ${2:-}" in
    'cli list')
      printf 'WINID TABID PANEID WORKSPACE SIZE TITLE CWD\n'
      printf '0 0 0 default 80x28 hx file:///tmp\n'
      printf '0 0 1 default 20x40 yazi file:///tmp\n'
      printf '0 0 2 default 80x12 bash file:///tmp\n'
      ;;
    'cli send-text'|'cli activate-pane')
      [[ " $* " == *' --pane-id 0 '* ]]
      ;;
    *) return 1 ;;
  esac
}
export -f wezterm
mkdir -p "$test_dir/runtime/wezterm-helix-$UID"
printf '2\n' > "$test_dir/runtime/wezterm-helix-$UID/1.pane"
WEZTERM_PANE=1 HELIX_PANE_ID=0 XDG_RUNTIME_DIR="$test_dir/runtime" \
  bash "$root/wezterm/open-in-helix.sh" /tmp/main.go
unset -f wezterm
[[ $(cat -- "$test_dir/runtime/wezterm-helix-$UID/1.pane") == 0 ]]
printf 'PASS: Current Helix pane overrides stale recovery state\n'

XDG_CONFIG_HOME="$test_dir" bash "$root/install.sh" >/dev/null 2>&1
cmp -s "$root/helix/config.toml" "$test_dir/helix/config.toml"
cmp -s "$root/helix/languages.toml" "$test_dir/helix/languages.toml"
cmp -s "$root/wezterm/wezterm.lua" "$test_dir/wezterm/wezterm.lua"
cmp -s "$root/wezterm/yazi/yazi.toml" "$test_dir/wezterm/yazi/yazi.toml"
cmp -s "$root/wezterm/yazi/init.lua" "$test_dir/wezterm/yazi/init.lua"
cmp -s "$root/wezterm/yazi/plugins/smart-enter.yazi/main.lua" "$test_dir/wezterm/yazi/plugins/smart-enter.yazi/main.lua"

# Simulate modified existing config and re-install
printf 'modified helix config\n' > "$test_dir/helix/config.toml"
XDG_CONFIG_HOME="$test_dir" bash "$root/install.sh" >/dev/null 2>&1
backups=("$test_dir"/helix/config.toml.backup-*)
[[ ${#backups[@]} == 1 ]]
[[ $(cat -- "${backups[0]}") == 'modified helix config' ]]
cmp -s "$root/helix/config.toml" "$test_dir/helix/config.toml"
cmp -s "$root/helix/languages.toml" "$test_dir/helix/languages.toml"
printf 'PASS: Installer creates backups of modified files and is idempotent\n'

# 3. WezTerm Lua configuration check (if wezterm binary is available)
if command -v wezterm >/dev/null 2>&1; then
  wezterm --config-file "$root/wezterm/wezterm.lua" show-keys >/dev/null
  printf 'PASS: WezTerm configuration validated by wezterm\n'
fi

printf 'ALL CHECKS PASSED!\n'

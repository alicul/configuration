#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_base=${XDG_CONFIG_HOME:-"$HOME/.config"}
backup_stamp="$(date -u +%Y%m%dT%H%M%SZ)-$$"

install_file() {
  local source=$1 destination=$2
  mkdir -p -- "$(dirname -- "$destination")"
  if [[ -e $destination || -L $destination ]]; then
    if cmp -s -- "$source" "$destination"; then
      printf 'Unchanged: %s\n' "$destination"
      return
    fi
    mv -- "$destination" "$destination.backup-$backup_stamp"
    printf 'Backup: %s\n' "$destination.backup-$backup_stamp"
  fi
  cp -- "$source" "$destination"
  printf 'Installed: %s\n' "$destination"
}

for file in wezterm.lua open-in-helix.sh yazi/yazi.toml yazi/init.lua \
  yazi/keymap.toml yazi/plugins/smart-enter.yazi/main.lua; do
  install_file "$source_dir/wezterm/$file" "$config_base/wezterm/$file"
done

chmod +x "$config_base/wezterm/open-in-helix.sh" 2>/dev/null || true
install_file "$source_dir/helix/config.toml" "$config_base/helix/config.toml"
install_file "$source_dir/helix/languages.toml" "$config_base/helix/languages.toml"

tool_path="$HOME/bin:$HOME/.local/bin:$HOME/.hermit/go/bin:$PATH"
for language_tool in go gopls dlv basedpyright-langserver ruff; do
  if ! PATH="$tool_path" command -v "$language_tool" >/dev/null 2>&1; then
    printf 'Warning: language tool not found: %s\n' "$language_tool" >&2
  fi
done

printf 'Installed minimal IDE configuration.\n'

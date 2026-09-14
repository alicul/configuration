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
for file in wezterm.lua session.sh session.ps1 yazi/yazi.toml yazi/keymap.toml; do
  install_file "$source_dir/wezterm/$file" "$config_base/wezterm/$file"
done
install_file "$source_dir/helix/config.toml" "$config_base/helix/config.toml"
printf 'Installed. Existing mux servers and panes were not restarted.\n'

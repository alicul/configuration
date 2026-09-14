#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
bash -n "$root/wezterm/session.sh" "$root/install.sh"
source "$root/wezterm/session.sh"
export WEZTERM_PANE=17
declare -a captured
mux() { captured=("$@"); }
files=('space name.txt' '-option' 'a"quote' "a'quote" '$(touch nope)' '`nope`')
open_files "${files[@]}"
[[ ${captured[0]} == spawn && ${captured[2]} == 17 ]]
[[ ${captured[8]} == workspace ]]
for i in "${!files[@]}"; do [[ ${captured[i+9]} == "$PWD/${files[i]}" ]]; done
printf 'PASS: filenames remain literal arguments; new editor tabs preserve existing panes\n'

# Exercise installation and backup in a private directory, without changing HOME.
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
XDG_CONFIG_HOME="$test_dir" bash "$root/install.sh" >/dev/null
printf 'old configuration\n' > "$test_dir/helix/config.toml"
XDG_CONFIG_HOME="$test_dir" bash "$root/install.sh" >/dev/null
XDG_CONFIG_HOME="$test_dir" bash "$root/install.sh" >/dev/null
backups=("$test_dir"/helix/config.toml.backup-*)
[[ ${#backups[@]} == 1 ]]
[[ $(cat -- "${backups[0]}") == 'old configuration' ]]
cmp -s "$root/helix/config.toml" "$test_dir/helix/config.toml"
printf 'PASS: Bash installer backs up changed files and is idempotent\n'

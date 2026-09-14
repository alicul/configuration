#!/usr/bin/env bash
# open-in-helix.sh: Open file(s) in the Helix editor pane in WezTerm
set -euo pipefail

files=("$@")
[[ ${#files[@]} -eq 0 ]] && exit 0

for index in "${!files[@]}"; do
  file=${files[$index]}
  [[ -z $file ]] && continue
  [[ $file = /* ]] || file="$PWD/$file"
  files[$index]=$file
done

runtime_base=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}
state_dir="$runtime_base/wezterm-helix-$UID"
mkdir -p -- "$state_dir"
chmod 700 -- "$state_dir"
state_file="$state_dir/${WEZTERM_PANE:-sidebar}.pane"

pane_list=$(wezterm cli list 2>/dev/null)
current_tab=$(awk -v pane="${WEZTERM_PANE:-}" 'NR > 1 && $3 == pane { print $2; exit }' <<<"$pane_list")

pane_is_live() {
  local pane=$1
  [[ -n $pane && -n $current_tab ]] || return 1
  awk -v pane="$pane" -v tab="$current_tab" \
    'NR > 1 && $2 == tab && $3 == pane { found = 1 } END { exit !found }' <<<"$pane_list"
}

# The ID supplied by this Yazi process belongs to the current WezTerm session
# and is authoritative. Only use recovery state after that original pane exits;
# numeric pane IDs can be reused by a later WezTerm session.
helix_pane=${HELIX_PANE_ID:-}
if ! pane_is_live "$helix_pane"; then
  helix_pane=
  if [[ -r $state_file ]]; then
    IFS= read -r recovered_pane < "$state_file" || true
    if pane_is_live "${recovered_pane:-}"; then
      helix_pane=$recovered_pane
    fi
  fi
fi

if [[ -z $helix_pane ]]; then
  # Once the original editor closes, the terminal is the other pane in this
  # tab. Splitting above it restores the original editor/terminal column.
  anchor_pane=$(awk -v pane="${WEZTERM_PANE:-}" -v tab="$current_tab" \
    'NR > 1 && $2 == tab && $3 != pane { candidate = $3 } END { print candidate }' <<<"$pane_list")
  editor_cwd=$(dirname -- "${files[0]}")

  if [[ -n $anchor_pane ]]; then
    helix_pane=$(wezterm cli split-pane --pane-id "$anchor_pane" --top --percent 70 \
      --cwd "$editor_cwd" -- hx "${files[@]}")
  else
    helix_pane=$(wezterm cli split-pane --pane-id "${WEZTERM_PANE:?}" --right --percent 80 \
      --cwd "$editor_cwd" -- hx "${files[@]}")
  fi

  helix_pane=${helix_pane//$'\r'/}
  printf '%s\n' "$helix_pane" > "$state_file"
  wezterm cli activate-pane --pane-id "$helix_pane" || true
  exit 0
fi

printf '%s\n' "$helix_pane" > "$state_file"
for file in "${files[@]}"; do
  # Send Escape to ensure normal mode, pause slightly to avoid Alt-key sequence, then issue :open
  wezterm cli send-text --pane-id "$helix_pane" --no-paste $'\x1b'
  sleep 0.05
  wezterm cli send-text --pane-id "$helix_pane" --no-paste ":open \"$file\""$'\r'
done

# Focus the Helix editor pane
wezterm cli activate-pane --pane-id "$helix_pane" || true

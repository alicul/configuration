#!/usr/bin/env bash
# Bash and the three terminal apps only; no additional language runtime.
session_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
session_script="$session_dir/session.sh"

mux() { command wezterm cli --prefer-mux "$@"; }

require_apps() {
  local app
  for app in wezterm hx yazi; do
    command -v "$app" >/dev/null || { printf 'Install %s and put it on PATH.\n' "$app" >&2; return 1; }
  done
  [[ ${WEZTERM_PANE:-} =~ ^[0-9]+$ ]] || {
    printf 'Start this workspace inside a WezTerm mux pane.\n' >&2
    return 1
  }
}

open_files() {
  local file
  local -a paths=()
  for file in "$@"; do
    [[ $file = /* ]] || file="$PWD/$file"
    paths+=("$file")
  done
  mux spawn --pane-id "$WEZTERM_PANE" --cwd "$PWD" \
    -- bash "$session_script" workspace "${paths[@]}" >/dev/null
}

browser() {
  local chosen cwd_file directory
  local -a files
  session_tmp=$(mktemp -d "${TMPDIR:-/tmp}/wezterm-yazi.XXXXXXXX") || return 1
  # Only remove the private temporary directory created by this invocation.
  trap 'rm -rf -- "$session_tmp"' EXIT
  chosen="$session_tmp/chosen"
  cwd_file="$session_tmp/cwd"
  export YAZI_CONFIG_HOME="$session_dir/yazi"
  while :; do
    rm -f -- "$chosen" "$cwd_file"
    command yazi --chooser-file "$chosen" --cwd-file "$cwd_file"
    if [[ -f $cwd_file ]]; then
      directory=$(cat -- "$cwd_file")
      [[ ! -d $directory ]] || cd -- "$directory" || return 1
    fi
    if [[ -s $chosen ]]; then
      mapfile -t files < "$chosen"
      if ! open_files "${files[@]}"; then
        printf 'Could not open editor; the file browser will restart.\n' >&2
        sleep 3
      fi
    fi
    sleep 0.3
  done
}

workspace() {
  mux split-pane --pane-id "$WEZTERM_PANE" --left --percent 25 --cwd "$PWD" \
    -- bash "$session_script" browser >/dev/null || return 1
  mux split-pane --pane-id "$WEZTERM_PANE" --bottom --percent 30 --cwd "$PWD" \
    -- bash "$session_script" terminal >/dev/null || return 1
  mux activate-pane --pane-id "$WEZTERM_PANE" || return 1
  while :; do
    command hx "$@"
    set --
    sleep 0.3
  done
}

terminal() {
  local login_shell=${SHELL:-}
  if [[ -z $login_shell ]]; then
    login_shell=$(getent passwd "$(id -u)" | cut -d: -f7)
  fi
  while :; do
    "${login_shell:-/bin/bash}" -l
    sleep 0.3
  done
}

main() {
  export PATH="$HOME/.local/bin:$PATH"
  require_apps || return 1
  # Do not let an interrupt reaching the wrapper remove the persistent pane.
  trap ':' INT
  local mode=${1:-workspace}
  [[ $# -eq 0 ]] || shift
  case $mode in
    workspace) workspace "$@" ;;
    browser) browser ;;
    terminal) terminal ;;
    *) printf 'Unknown mode: %s\n' "$mode" >&2; return 1 ;;
  esac
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi

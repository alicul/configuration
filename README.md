# WezTerm + Helix + Yazi

Portable configuration for Ubuntu 24.04/26.04, Debian/Ubuntu WSL, and Windows 11.
Yazi stays on the left; Helix opens on the right. There is no Python dependency:
Linux uses Bash, and Windows uses its built-in Windows PowerShell 5.1.

## Install

Install `wezterm`, `wezterm-mux-server`, `hx`, and `yazi` on each machine where
panes run. Install Yazi's companion `ya` and its platform dependencies as described
in the [Yazi installation guide](https://yazi-rs.github.io/docs/installation/).
Windows applications and Linux/WSL applications are separate installations.

From this directory:

```bash
# Debian, Ubuntu, or the VDI
bash install.sh
```

```powershell
# Windows; no administrator privileges required
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

The execution-policy override applies to this invocation only. The installer
backs up changed destination files with `.backup-*` suffixes and leaves running
servers and panes alone. Yazi's sidebar settings are private to this bundle;
standalone Yazi retains any existing configuration.

| Platform | WezTerm and helpers | Helix |
| --- | --- | --- |
| Linux/WSL | `$XDG_CONFIG_HOME/wezterm` or `~/.config/wezterm` | `$XDG_CONFIG_HOME/helix/config.toml` or `~/.config/helix/config.toml` |
| Windows | `%USERPROFILE%\.config\wezterm` | `%APPDATA%\helix\config.toml` |

Keep `session.sh`, `session.ps1`, and `yazi/` beside `wezterm.lua`. If
`WEZTERM_CONFIG_FILE` is set or a portable Windows config lives beside the
WezTerm executable, ensure it selects this configuration.

The installers no longer copy any Python files. If an earlier Python-based
version was installed, `session.py` is unused and may be removed manually.

## Machines and persistence

Each environment uses an independent WezTerm mux server. Linux starts its local
`persistent` domain. **Windows starts its native `persistent` domain**; installed
Debian/Ubuntu WSL distributions are selectable using Ctrl+Shift+L. This avoids
starting an unconfigured WSL distribution just because it exists. After installing
this bundle and the Linux applications in WSL, you can change the Windows
`startup` variable to `persistent-wsl:Debian` or `persistent-wsl:Ubuntu-26.04`.

The VDI is `10.52.20.64`, user `alicul`, with WezTerm at
`/home/alicul/.local/bin/wezterm`. Replace `your-vdi-hostname` in `wezterm.lua`
with its lowercase short hostname to suppress its connection to itself.
Other hostnames only need entries if you want appearance overrides.

Install compatible WezTerm versions on clients and servers. WSL uses a proxy
through `wsl.exe` into each distro's Linux mux, without sharing an AF_UNIX socket
between Windows and WSL 2. WSL needs its own installed Linux binaries and config.
Windows-originated SSH connections use Windows credentials, even from a WSL tab.
The original Linux oh-my-zsh SSH-agent discovery is retained.

**Ctrl+Shift+E detaches the entire current environment.** Its tabs, panes,
programs, and unsaved editor buffers remain in the running server. Reopening
WezTerm reconnects to the startup domain; use the domain selector for other
sessions. Detaching or losing a GUI/network connection does not terminate the
server's programs.

Live sessions do not survive a reboot, power loss, `wsl --shutdown`, server
termination, or deliberate pane termination. OS logout may also end user
processes. Save files before shutting down. The configuration cannot make a
process literally unkillable or checkpoint unsaved buffers across reboot.

Tab and integrated window close buttons are available, with close confirmation.
The selector excludes GUI-owned disposable domains. Use the detach shortcut
to preserve work; confirming closure ends the affected programs.
Existing mux servers may need a
restart to pick up a changed default program; save and end their jobs first.
This installer never restarts them for you.

## Daily use

| Shortcut/action | Result |
| --- | --- |
| Ctrl+Shift+T or tab bar + | New workspace in the current environment |
| Ctrl+Shift+L | Select a persistent environment |
| Ctrl+Shift+D | Attach/reattach VDI |
| Ctrl+Shift+E | Detach the current environment, preserving its tabs |
| Ctrl+Shift+W | Close the current tab after confirmation |
| F11 | Toggle fullscreen |
| Ctrl+Shift+Left/Right | Focus browser/editor pane |
| Ctrl+Shift+Up/Down | Focus editor/terminal pane |
| Ctrl+PageUp/PageDown | Switch tabs |
| Ctrl+Shift+C/V | Copy/paste through WezTerm |
| Shift+drag | Select terminal text when an application handles the mouse |
| Helix Space then y | Copy using the terminal clipboard (OSC 52) |

Each workspace has a 25% Yazi sidebar and a 75% right column containing Helix
above an independent terminal (30% of the column's height). In Yazi, use arrows
to navigate, Enter to enter a directory or open a file, and Space to select
multiple files. Opening files creates **a new tab with its own browser on the
left and Helix on the right**. Existing editors and unsaved buffers remain intact.
The browser restarts in its browsed directory after selection. Its q/Q/Ctrl+C
bindings cancel instead of quitting; its supervisor restarts Yazi if it exits.

Quitting Helix with `:q` restarts the editor. The independent bottom terminal
stays available throughout; exiting its shell restarts it.

Linux passes file paths as Bash array elements; Windows uses a temporary JSON
manifest between supervisors. Neither injects editor commands into a live pane
nor evaluates filenames as shell code. Yazi's newline-separated chooser cannot
represent filenames containing newline characters; use Helix's own picker for
those. Current Yazi `[mgr]` configuration is used (verified with Yazi 26.9.1).

## Checks

```bash
bash tests/check.sh
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\check.ps1
wezterm show-keys
```

The shell tests cover literal filename handling and installer backup/idempotence.
PowerShell tests run with the Windows built-in runtime. Configuration validation
uses the actual installed WezTerm, rather than a mocked Lua API.

For a persistence smoke check, create an unsaved Helix note, detach, reconnect,
and verify that the same note and sidebar remain. Repeat separately on native
Windows, each configured WSL distribution, and the VDI. No scripts restart or
kill existing servers to perform validation.

References: [WezTerm multiplexing](https://wezterm.org/multiplexing.html),
[DetachDomain](https://wezterm.org/config/lua/keyassignment/DetachDomain.html),
[Yazi configuration](https://yazi-rs.github.io/docs/configuration/yazi/),
[Helix configuration](https://docs.helix-editor.com/configuration.html).

## IDE layout update

Font size is 20. Windows enter fullscreen on startup/attach (and when this
configuration is reloaded); F11 toggles fullscreen. Window minimize, maximize,
and close controls are integrated at the upper right of the always-visible
fancy tab bar. Each tab also has its close button.

New workspaces have Yazi on the left, Helix in the upper right, and a separate
terminal in the lower right (30% of the right column). Ctrl+Shift+Up/Down moves
between editor and terminal. The left side can be extended with an AI pane later.
Quitting Helix restarts the editor; exiting the bottom shell restarts the shell.

**Updated close behavior:** Ctrl+Shift+W and tab close buttons close the tab;
confirming closure ends that tab's programs. Ctrl+Shift+E remains the shortcut
for detaching and preserving the entire environment. The window close control
also asks for confirmation. Use detach when you want to resume your work later.

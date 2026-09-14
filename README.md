# Minimal Terminal IDE: WezTerm + Helix + Yazi

A minimal, modern terminal IDE configuration styled like **Cursor, VS Code, and Antigravity**.

```
+-------------------------------------------------------------+
|                          WEZTERM                            |
+--------------+----------------------------------------------+
|              |                                              |
|              |                   HELIX                      |
|              |                 (editor)                     |
|    YAZI      |                                              |
| (file tree)  +----------------------------------------------+
|              |                                              |
|              |                  TERMINAL                    |
|              |                   (shell)                    |
+--------------+----------------------------------------------+
```

## Highlights

- **IDE Layout**: Single fullscreen window with Yazi on the left (20% width), Helix on the top-right, and an interactive shell on the bottom-right.
- **Click to Open**: Left-clicking or pressing `Enter` on a file in Yazi opens it directly in the running Helix editor buffer—no new tabs or windows spawned.
- **Editor Recovery**: If Helix exits, opening a file from Yazi recreates the editor pane above the terminal automatically.
- **No Session Persistence**: No background multiplexing daemons or complex socket proxies. Starts fast, exits cleanly.
- **Modern Aesthetics**: Unified Dark+ / VS Code color scheme, JetBrains Mono font, and sleek integrated decorations.
- **Standard Shortcuts**: Standard navigation, clipboard, zoom, and fullscreen shortcuts.
- **User-local Tools**: WezTerm prepends `~/bin`, `~/.local/bin`, and Hermit's `~/.hermit/go/bin` to `PATH`, including when it is launched from the desktop. This exposes both Hermit command shims (including `go`) and the Go tools (`gopls` and `dlv`) to Helix.
- **Visible Window Controls**: The tab bar stays visible so minimize, maximize, and close remain available in the single-tab workspace.

---

## Installation

```bash
bash install.sh
```

Config files installed:
- WezTerm: `~/.config/wezterm/`
- Helix: `~/.config/helix/config.toml` and `~/.config/helix/languages.toml`

The installer automatically creates timestamped backups of any modified configuration files.

### Language servers

Helix uses `gopls` for Go, plus `basedpyright-langserver` and Ruff for Python. The Hermit-managed Go tools (`gopls` and `dlv`) are loaded from `~/.hermit/go/bin`; Python tools are loaded from `~/.local/bin` or any existing `PATH` entry.

```bash
uv tool install basedpyright
uv tool install ruff
```

Verify the setup with:

```bash
hx --health go
hx --health python
```

Go files are formatted through `gopls` when saved. Automatic inlay hints are disabled because `gopls` can reject hint requests while package metadata is loading; completion, diagnostics, navigation, code actions, and formatting remain enabled. For Python, Basedpyright provides type-aware language intelligence while Ruff provides lint diagnostics, code actions, import organization, and format-on-save. Detailed diagnostics wrap inline across the editor on the cursor line, while other lines show only errors to keep the view readable.

---

## Shortcuts

| Shortcut | Action |
| --- | --- |
| `F11` | Toggle fullscreen |
| `Ctrl+Shift+Left` | Focus left pane (Yazi sidebar) |
| `Ctrl+Shift+Right` | Focus right pane (Helix editor) |
| `Ctrl+Shift+Up` | Focus upper pane (Helix editor) |
| `Ctrl+Shift+Down` | Focus lower pane (Terminal) |
| `Ctrl+C` | Copy selected text to the clipboard |
| `Ctrl+V` | Paste from clipboard |
| `Ctrl+Shift+C` | Copy to clipboard |
| `Ctrl+Shift+V` | Paste from clipboard |
| `Ctrl++` / `Ctrl+=` | Increase font size |
| `Ctrl+-` | Decrease font size |
| `Ctrl+0` | Reset font size |
| `Ctrl+Shift+R` | Reload configuration |
| `Ctrl+Shift+W` | Close active pane (prompted) |

---

## Yazi Sidebar Navigation

- Yazi remains a single-column file tree; file contents are displayed in Helix, not in a Yazi preview column.
- **Click a file**, press `Enter`, or press `O`: Opens the file in the Helix editor pane and focuses the editor.
- **Click a directory** or press `Enter`: Enters the directory.
- `Esc` or `Ctrl+C`: Closes an active input prompt.
- `q`, `Q`, `Ctrl+C`: Clear selection / keep sidebar open (prevents accidental exit).

---

## Testing & Validation

```bash
bash tests/check.sh
```

# parket

> [!WARNING]
> **parket is no longer actively maintained.**
>
> **I have switched back to dwm on a Linux machine.** I will no longer have a Mac available to develop or test parket.
>
> Existing releases remain available, but bug fixes, new features, and compatibility with future macOS versions are not guaranteed.
>
> The repository remains open for a [new maintainer or a maintained fork](https://github.com/basuev/parket/issues/3). Responses and PR merges are not guaranteed.

A small native tiling window manager for macOS.

It tiles normal document windows with a dwm-style master-stack layout and emulates workspaces by moving inactive workspace windows offscreen. It uses Swift, public macOS APIs, and zero runtime dependencies. It does not require SIP changes.

![parket preview](assets/parket-preview.png)

Inspired by [dwm](https://dwm.suckless.org/) and [AeroSpace](https://github.com/nikitabobko/AeroSpace).

## Install

```fish
brew install --cask basuev/parket/parket
```

Open parket from Applications. On first launch, parket opens the Accessibility prompt. Grant access, then choose Recheck in the permission window or Recheck Accessibility from the menubar.

Homebrew is the normal install path. Release zips use ad-hoc signing.

## Requirements

- macOS 13+
- Accessibility permission

## Keys

| Key | Action |
|-----|--------|
| `Option + 1-9, 0` | Switch workspace |
| `Option + Shift + 1-9, 0` | Move focused window to workspace |
| `Option + J/K` | Focus next or previous window |
| `Option + Return` | Swap focused window with master |
| `Option + Tab` | Switch to last active workspace |
| `Option + M` | Toggle monocle layout |
| `Option + F` | Toggle floating on the focused window |
| `Option + H` / `Option + L` | Shrink or grow the master column |
| `Option + B` | Show or hide the top bar |
| `Option + Shift + C` | Reload config |
| `Option + N` | Rename the current workspace |
| `Option + Shift + Return` | Spawn a new window of the configured terminal |
| `Option + ,` / `Option + .` | Focus previous or next monitor |
| `Option + Shift + ,` / `Option + Shift + .` | Move window to previous or next monitor |

Right-click the bar or menu extra and choose Settings for appearance, tiling, modifier, and terminal. Config is for keymaps, workspace rules, and custom binds. Small windows and Picture in Picture float automatically.

Control+Option+Command is an alias for Option on every bind; add Shift for the move/spawn binds. Set `hyper = false` to turn that off.

Command+Tab remains the macOS app switcher. If it selects a window on another parket workspace, parket opens that workspace and focuses the selected window.

Menubar commands: Pause Tiling, Retile Now, Pause and Restore Windows, Settings, Open Config, Copy Diagnostic Report, Reload Config.

## Model

- 10 workspaces per display.
- Master-stack and monocle layouts.
- The top bar overlays the macOS menu bar; windows still tile below the system menu bar.
- One native tab group counts as one tileable window.
- Panels, dialogs, minimized windows, fullscreen windows, and dead AX elements stay out of workspace state.
- Small windows and Picture in Picture float automatically.
- Recovery actions bring tracked windows back onscreen.

## Configuration

Edit `~/.config/parket/config.toml`. All fields are optional.

Appearance, tiling, modifier, and terminal live in Settings. `config.toml` is for keymaps, workspace rules, and custom binds. UI keys in the file apply until you change them in Settings.

```toml
workspace_count = 10
master_ratio = 0.45
modifier = "option"
hyper = true                   # also bind control+option+command (and +shift) to the same actions
workspace_letter_keys = true   # also binds q-p to workspaces 1-10
focus_follows_mouse = true     # focuses the window the pointer moves onto
bar = true                     # false hides the overlay bar; Settings stays in the bar or menu extra
menu_bar_icon = false          # true shows the menu bar extra
bar_font = "mono"              # "menubar" or "mono" (Yakshaven)
bar_highlight = "text"         # "text", "fill", or "outline" for the selected window title
bar_tag_highlight = "text"     # same options for workspace numbers; omit to follow bar_highlight
outer_gap = 0                  # padding under the bar and on left, right, bottom
window_gap = 8                 # space between tiled windows
border_width = 2
border_radius = 6
terminal = "Ghostty"           # app name or bundle id; empty uses the macOS default terminal

[bindings]
focus_next = "j"
focus_prev = "k"
swap_master = "return"
toggle_layout = "m"
toggle_floating = "f"
toggle_bar = "b"
spawn_terminal = "shift+return"
decrease_master = "h"
increase_master = "l"
focus_monitor_prev = "comma"
focus_monitor_next = "period"
move_monitor_prev = "shift+comma"
move_monitor_next = "shift+period"
last_workspace = "tab"
reload_config = "shift+c"
rename_workspace = "n"

[[rules]]
app = "Finder"
float = true

[[rules]]
app = "Safari"
workspace = 2
```

Bindings use the configured modifier key. Prefix a key with `shift+` to add Shift. See [config.example.toml](config.example.toml) for supported key names and defaults.

Use Reload Config from the menubar after editing.

## Build from Source

```fish
make install
open /Applications/parket.app
```

Run the required local gate:

```fish
make check
```

`make check` runs formatting, policy checks, tests, and a release build. See [Tests/Smoke/README.md](Tests/Smoke/README.md) for AX smoke checks and [docs/benchmarks.md](docs/benchmarks.md) for latency runs.

## Update

```fish
brew update
brew upgrade --cask basuev/parket/parket
```

Source install:

```fish
git pull
make install
```

Source installs replace only `Contents/MacOS/parket`, so Accessibility permission survives the update.

## Uninstall

```fish
brew uninstall --cask basuev/parket/parket
rm -rf /Applications/parket.app
```

Source checkout:

```fish
make uninstall
```

## Benchmarks

The latency harness measures hotkey dispatch to the expected visible, focused fixture window.

Latest local two-display matrix, 2026-06-14:

| Scenario | parket | AeroSpace |
|----------|--------|-----------|
| Default focus p95 | 9.5 ms | 29.7 ms |
| Multi-monitor focus p95 | 15.2 ms | 38.9 ms |
| Native-tabs scenario | Passed | Failed correctness |

See [docs/benchmarks.md](docs/benchmarks.md) for the full matrix, run notes, and claim wording.

## Contributing

Active development has stopped because the author has switched back to dwm on Linux and will no longer have a Mac available for testing.

Documentation fixes may still be reviewed. Changes to window behavior need verification by a contributor with a Mac. Passing `make check` alone does not replace [AX smoke checks](Tests/Smoke/README.md) in a real macOS session.

Responses, reviews, and PR merges are not guaranteed.

If you want to maintain parket or a fork, comment on the [maintainer search issue](https://github.com/basuev/parket/issues/3). Forks are welcome under the MIT license.

## License

MIT

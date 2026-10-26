# Box Dots

My Hyprland configs: a Quickshell bar, menus and desktop widgets, all themed from the
current wallpaper with matugen.

### Packages these configs need (maybe not complete)

hyprland \
quickshell \
kitty \
fish \
starship \
zoxide \
matugen \
awww \
python-pyvips \
cliphist \
wl-clipboard \
wtype \
grimblast \
hyprpicker \
hyprlock \
fcitx5 fcitx5-mozc fcitx5-chinese-addons \
rofimoji (only for its emoji data) \
playerctl \
pavucontrol \
ddcutil \
power-profiles-daemon \
iwd iwgtk \
blueman \
tailscale \
dankcalendar (dcal)

```
hyprpm add https://github.com/sandwichfarm/hyprexpo
hyprpm enable hyprexpo
hyprpm reload
```

### Layout

- `hypr/`: Hyprland config in Lua (`hyprland.lua` entry point, `exec.lua` autostart,
  `keybinds.lua`, `look.lua`, `windowrules.lua`, `env.lua`)
- `quickshell/`: everything on screen besides windows, run as `qs` (hot-reloads on save)
  - `Bar.qml` + `modules/`: the powerline bar
  - `SidePanel.qml`: the drawer on the right (push the pointer against the right screen edge, or
    click the bell, media block or clock to pin it): calendar, media, connections, sound and the
    notification history; `qs ipc call sidebar toggle`
  - `menus/`: launcher, clipboard, emoji, nerd font, keybinds, power and wallpaper menus
  - `WeekCalendar.qml`, `TodoList.qml`, `HabitTracker.qml`: desktop widgets backed by dcal
  - `Notifs.qml`, `NotificationPopups.qml`: the notification daemon and its toasts (they expand on
    hover; right click on the bell toggles do not disturb)
- `matugen/`: templates for every generated color file
- `zsh/`: zsh set up to feel like the fish config (autosuggestions, highlighting in fish's colors,
  history search, the kitty cat's hooks), next to fish rather than instead of it: run `zsh` to try it
- `hypr/scripts/`: screenshot script and the Python helpers the menus call

### NixOS

`nixos/` is the system config for my NixOS machines, tied together by `flake.nix` (`flake.lock`
pins nixpkgs and home-manager):

- `common.nix`: what every machine gets (SDDM, Hyprland under uwsm, fonts, services)
- `home.nix`: home-manager, also shared: links these configs out of `~/nix-dots` (so the repo must
  be cloned there), user packages and the session services (dcal, cliphist, hyprpolkitagent)
- `hosts/<hostname>/`: one folder per machine with its `hardware-configuration.nix`, hostname and
  stateVersions. `nixos-rebuild --flake` picks the folder named after the machine's hostname.

New files must be `git add`ed before the flake sees them.

```
sudo nixos-rebuild switch --flake ~/nix-dots/nixos   # also: boot, test, build (no sudo)
nix flake update --flake ~/nix-dots/nixos            # update nixpkgs and home-manager, then rebuild
```

Adding a machine: in the installer, run `nixos-generate-config --root /mnt` and clone this repo
to `/mnt/home/tom/nix-dots`. Create `hosts/<name>/` with that `hardware-configuration.nix` and a
`default.nix` like `hosts/nixbox/default.nix` (its own hostname, and the installer's release as
both stateVersions), add `<name>` to the list in `flake.nix`, `git add` it, then
`nixos-install --flake /mnt/home/tom/nix-dots/nixos#<name>`.

The configs check for `/etc/NIXOS` where NixOS differs from Arch (hyprexpo, package aliases).
Kitty Cam is not set up there. On small screens Quickshell shrinks the bar, menus and widgets on
its own.

### Wallpapers and theming

Wallpapers in `~/Pictures/Wallpapers` are resized and thumbnailed into `~/.cache/box-dots`
and shown in the wallpaper picker (SUPER + P). Picking one sets it with awww and runs
`matugen`, which regenerates the colors for Hyprland, Quickshell, kitty, fish, starship,
btop, hyprlock, fastfetch and the fcitx5 theme. Quickshell picks up the new
palette by itself.

### Menus

| Key | Menu |
|---|---|
| SUPER + SPACE | Start menu: app launcher, recent files, media, quick toggles, volume and brightness |
| SUPER + V | Clipboard history, with image previews |
| SUPER + . | Emoji picker (copies to the clipboard) |
| SUPER + , | Nerd Font glyph picker |
| SUPER + P | Wallpaper picker |
| SUPER + K | Keybind reference |
| SUPER + ESCAPE | Power menu |

### Other keys

| Key | Action |
|---|---|
| SUPER + D | Show / hide the desktop widgets |
| SUPER + TAB | Workspace overview (hyprexpo) |
| CTRL + SPACE | Cycle input method (English, Japanese, Chinese) |
| SHIFT + SUPER + S | Screenshot of an area |
| SHIFT + SUPER + C | Pick a color to the clipboard |
| SUPER + L | Lock screen |

The bar has workspaces, the window title, CPU/memory, media, audio, network, bluetooth,
tailscale and input method blocks, the tray and an animated gif (any gif dropped into
`~/Pictures/waybar-gifs`; click to switch). The Arch logo opens the power menu.

### Cute pets in the terminal

- random pet when opening kitty, or with the command "c"

![terminal pet](resources/random-terminal-pet.png)

# box (desktop PC) vs nixbox (laptop)

Branch `pc-nix`. Differences that come from the hardware, not from taste. The Arch dotfiles
(`box-dots`) are the PC; this repo started as the laptop's port of them.

| Area | Laptop (`nixbox`) | PC (`box`) |
|---|---|---|
| Display | `eDP-1` 1920x1080, scale 1 pinned (auto picks 1.5) | one 3440x1440 monitor on HDMI, `@99.98` pinned, scale auto (`hypr/hyprland.lua`) |
| Input | touchpad, natural scroll | mouse (Logitech Bolt) only, no touchpad block |
| SDDM greeter size | 1920x1080 | 3440x1440 (`common.nix`) |
| GPU | nothing set (mesa defaults) | RTX 2060 12GB, `hardware.nvidia.open` + modesetting (`hosts/box`) |
| CPU / chipset | nvme, sdhci, kvm-intel | i5-10400F: SATA AHCI, xHCI, kvm-intel (`hardware-configuration.nix`) |
| Disk | ext4 root on NVMe | btrfs on SATA SSD (@, @home, @nix, @log, @snapshots, zstd:3) + monthly scrub |
| Swap | none | zram 4 GB zstd |
| Containers | Docker daemon, socket-activated, `docker` group | rootless Podman + docker shim, `DOCKER_HOST` = user podman.socket |
| Network hardware | built-in Wi-Fi/BT | USB Wi-Fi dongle (rtw88_8822bu) + UB500 Bluetooth dongle (needs redistributable firmware); keep both away from the Bolt receiver |
| Webcam / Kitty Cam | none, not linked | linked to `~/.config/kitty-cam`, gstreamer + pipewire plugins on `GST_PLUGIN_SYSTEM_PATH_1_0` |
| Brightness | `brightnessctl` on `/sys/class/backlight` | DDC/CI through `ddcutil` (`hardware.i2c`, already in `common.nix`); `Monitor.qml` picks by itself |
| Battery | bar block + btop battery | none; `modules/Battery.qml` hides itself, nothing to change |

Not machine differences (left alone): the Nix vs Arch logo, workspaces linking (works on one screen),
hyprexpo from `/etc/hypr/plugins`, NetworkManager with the iwd backend (the Arch PC uses bare
iwd + networkd; the bar's iwctl/iwgtk work with either).

## Installing on the PC

1. In the installer: `nixos-generate-config --root /mnt`, then copy its `hardware-configuration.nix`
   over `hosts/box/hardware-configuration.nix` (the committed one is a draft with the Arch UUIDs) and
   set `system.stateVersion` in `hosts/box/default.nix` to what it wrote in `configuration.nix`.
2. Clone this repo, branch `pc-nix`, to `/mnt/home/tom/nix-dots`; `git add` changed files.
3. `nixos-install --flake /mnt/home/tom/nix-dots/nixos#box`

To check the config without building: `nix build "./nixos#nixosConfigurations.box.config.system.build.toplevel" --dry-run`
(quote it in zsh).

Not carried over (data, not config): Kitty Cam's `sounds/*.mp3`, `~/.config/chromium-flags.conf`
(NixOS's chromium ignores it; kitty-cam's own window adds `WebRtcPipeWireCamera` itself, other
Chromium windows would need it as `commandLineArgs`), the NVIDIA env tweaks if any are needed later.

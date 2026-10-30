# The desktop PC: i5-10400F, RTX 2060 12GB, one 3440x1440 monitor (HDMI), a wired webcam, no battery.
# Everything shared is in ../../common.nix and ../../home.nix; see README.md here for what differs
# from the laptop and why.
{ config, lib, pkgs, ... }:

let
  # Kitty Cam publishes the cat as a PipeWire camera through gst-launch's pipewiresink, and its
  # soundboard runs pw-loopback; both come from these.
  gstPlugins = with pkgs.gst_all_1; [ gstreamer gst-plugins-base pkgs.pipewire ];
in
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixbox";

  system.stateVersion = "25.11";

  # NVIDIA RTX 2060 (Turing): the open kernel module is supported and what the Arch box runs
  # (nvidia-open). Modesetting is what Wayland needs.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    open = true;
    # Early KMS (below) puts the driver's firmware into the initrd. Ship only the Turing GSP
    # blob: the Ampere one is 73 MB the 2060 never loads, and the firmware reading the initrd
    # before the kernel starts is a black screen of that length.
    package = let p = config.boot.kernelPackages.nvidiaPackages.stable; in p // {
      firmware = pkgs.runCommand "nvidia-firmware-turing-${p.version}" { } ''
        mkdir -p $out/lib/firmware/nvidia/${p.version}
        cp ${p.firmware}/lib/firmware/nvidia/${p.version}/gsp_tu10x.bin $out/lib/firmware/nvidia/${p.version}/
      '';
    };
    modesetting.enable = true;
    powerManagement.enable = true; # preserves VRAM across hibernate
    nvidiaSettings = false;
  };

  # NVIDIA module is built against the kernel set in common.nix (linuxPackages_latest)

  # Boot splash: Plymouth with the NixOS snowflake and a progress bar (pkgs/plymouth-nixos-theme.nix).
  # `quiet`/`splash` and the zero log levels keep kernel and initrd text from painting over it.
  # Early KMS: without the nvidia modules in the initrd, Plymouth starts on the EFI framebuffer
  # (simpledrm) and nvidia-drm replaces it ~4 s later, which blanked the splash (2026-10-29).
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_drm" "nvidia_uvm" ];
  boot.plymouth = {
    enable = true;
    theme = "nixos-bar";
    themePackages = [ (pkgs.callPackage ../../pkgs/plymouth-nixos-theme.nix { }) ];
  };
  boot.consoleLogLevel = 0;

  # Hibernate resume: swapfile on /swap (@swap btrfs subvolume, hardware-configuration.nix)
  boot.resumeDevice = "/dev/disk/by-label/root";
  boot.kernelParams = [ "resume_offset=7677184" "quiet" "splash" ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.page-cluster" = 3;
  };

  # btrfs on the system disk (hardware-configuration.nix): monthly scrub, as the Arch box
  services.btrfs.autoScrub.enable = true;

  # Weekly read-only snapshot of /home (@home) in /.snapshots (@snapshots), keeping the newest 10.
  # Same disk, so it guards against deleted or overwritten files, not a failing drive. Persistent:
  # a week missed while the PC was off is caught up at the next boot.
  systemd.services.home-snapshot = {
    description = "Snapshot /home and keep the newest 10";
    serviceConfig.Type = "oneshot";
    path = [ pkgs.btrfs-progs ];
    script = ''
      btrfs subvolume snapshot -r /home "/.snapshots/home-$(date +%Y-%m-%d_%H-%M)"
      ls -1d /.snapshots/home-* | head -n -10 | xargs -r btrfs subvolume delete
    '';
    startAt = "weekly";
  };
  systemd.timers.home-snapshot.timerConfig.Persistent = true;

  # Chromium: force-installed extensions (ExtensionInstallForcelist). No full uBlock Origin: it is MV2 and gone
  # from the Web Store, so uBlock Origin Lite is the Chromium one.
  programs.chromium = {
    enable = true;
    extensions = [
      "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
      "ghmbeldphafepmbegfdlkpapadhbakde" # Proton Pass
      "likgccmbimhjbgkjambclfkhldnlhbnn" # Yomitan
      "khncfooichmfjbepaaaebmommgaepoid" # Unhook - Remove YouTube Recommended & Shorts
    ];
    # Proton Pass is the password manager: switch off the built-in one
    extraOpts = {
      PasswordManagerEnabled = false;
      DefaultSearchProviderEnabled = true;
      DefaultSearchProviderName = "DuckDuckGo";
      DefaultSearchProviderKeyword = "ddg";
      DefaultSearchProviderSearchURL = "https://duckduckgo.com/?q={searchTerms}";
      DefaultSearchProviderSuggestURL = "https://duckduckgo.com/ac/?q={searchTerms}&type=list";
    };
  };

  # Wi-Fi is a USB Realtek dongle (rtw88_8822bu, 5 GHz) and Bluetooth a UB500 dongle (RTL8761BU):
  # both need the firmware in redistributable-firmware, which hardware-configuration.nix pulls in
  # for the CPU microcode. Keep the two dongles away from the Logitech Bolt receiver (mouse lag).
  hardware.enableRedistributableFirmware = true;

  # The one monitor: its 99.98 Hz mode pinned (the preferred mode is 60 Hz), unscaled. Replaces the
  # generic monitor rule in hypr/hyprland.lua.
  environment.etc."hypr/host.lua".text = ''
    hl.monitor({
      output   = "",
      mode     = "3440x1440@99.98",
      position = "auto",
      scale    = "1",
    })
  '';

  # Kitty Cam: the cat as a webcam (the laptop has none). Linked like the other configs, so the
  # keybinds' soundboard (hypr/keybinds.lua) finds ~/.config/kitty-cam/kitty-cam.
  environment.sessionVariables.GST_PLUGIN_SYSTEM_PATH_1_0 =
    lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gstPlugins;
  home-manager.users.tom = { config, ... }: {
    home.stateVersion = "25.11";
    xdg.configFile."kitty-cam".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-dots/kitty-cam";
    home.packages = gstPlugins;
  };
}

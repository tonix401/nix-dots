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

  networking.hostName = "box";

  system.stateVersion = "25.11";

  # NVIDIA RTX 2060 (Turing): the open kernel module is supported and what the Arch box runs
  # (nvidia-open). Modesetting is what Wayland needs.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true; # preserves VRAM across hibernate
    nvidiaSettings = false;
  };

  # The newest stable kernel instead of the LTS default; the nvidia module is built against it, so
  # if a kernel release breaks the driver, boot the previous generation and drop this line.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Hibernate resume: swapfile on /swap (@swap btrfs subvolume, hardware-configuration.nix)
  boot.resumeDevice = "/dev/disk/by-label/root";
  boot.kernelParams = [ "resume_offset=7677184" ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.page-cluster" = 3;
  };

  # btrfs on the system disk (hardware-configuration.nix): monthly scrub, as the Arch box
  services.btrfs.autoScrub.enable = true;

  # Rootless Podman with a docker CLI shim instead of the Docker daemon (as on Arch); the user's
  # podman.socket (below, DOCKER_HOST) answers docker-API clients.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };
  environment.systemPackages = [ pkgs.podman-compose ];
  systemd.user.sockets.podman.wantedBy = [ "sockets.target" ];

  # Wi-Fi is a USB Realtek dongle (rtw88_8822bu, 5 GHz) and Bluetooth a UB500 dongle (RTL8761BU):
  # both need the firmware in redistributable-firmware, which hardware-configuration.nix pulls in
  # for the CPU microcode. Keep the two dongles away from the Logitech Bolt receiver (mouse lag).
  hardware.enableRedistributableFirmware = true;

  # Kitty Cam: the cat as a webcam (the laptop has none). Linked like the other configs, so the
  # keybinds' soundboard (hypr/keybinds.lua) finds ~/.config/kitty-cam/kitty-cam.
  environment.sessionVariables.GST_PLUGIN_SYSTEM_PATH_1_0 =
    lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gstPlugins;
  home-manager.users.tom = { config, ... }: {
    home.stateVersion = "25.11";
    home.sessionVariables.DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";
    xdg.configFile."kitty-cam".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-dots/kitty-cam";
    home.packages = gstPlugins;
  };
}

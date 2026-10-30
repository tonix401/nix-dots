# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

let
  # `nix-apply`: rebuilds and switches to this flake (scripts/nix-apply.sh)
  nix-apply = pkgs.writeShellApplication {
    name = "nix-apply";
    runtimeInputs = with pkgs; [ git hostname ];
    text = builtins.readFile ./scripts/nix-apply.sh;
  };

  hyprexpo = pkgs.callPackage (pkgs.fetchFromGitHub {
    owner = "sandwichfarm";
    repo = "hyprexpo";
    rev = "a54d20e433831eb9a5770e052c48736421ba7db5";
    hash = "sha256-L3QG1HvO2tdaAgYrOxaiqn/NXs9kECHEP78h2+8pZ6A=";
  }) { };

  # Same look as the Arch box: the post-apocalyptic_hacker preset with its colors fixed (not
  # matugen) and the background following the current wallpaper.
  sddmTheme = pkgs.sddm-astronaut.override {
    embeddedTheme = "post-apocalyptic_hacker";
    themeConfig = {
      ScreenWidth = "3440";
      ScreenHeight = "1440";
      Font = "JetBrainsMono Nerd Font";
      FontSize = "15";
      KeyboardSize = "0.4";
      RoundCorners = "10";
      HourFormat = "HH:mm";
      DateFormat = "dddd d";
      Background = "/home/tom/.cache/box-dots/current/wallpaper.png";
      DimBackground = "0.0";
      CropBackground = "true";
      BackgroundHorizontalAlignment = "center";
      BackgroundVerticalAlignment = "center";
      HeaderTextColor = "#ffffff";
      DateTextColor = "#ffffff";
      TimeTextColor = "#ffffff";
      FormBackgroundColor = "#000000";
      BackgroundColor = "#000000";
      DimBackgroundColor = "#000000";
      LoginFieldBackgroundColor = "#000000";
      PasswordFieldBackgroundColor = "#000000";
      LoginFieldTextColor = "#ffffff";
      PasswordFieldTextColor = "#ffffff";
      UserIconColor = "#ffffff";
      PasswordIconColor = "#ffffff";
      PlaceholderTextColor = "#cccccc";
      WarningColor = "#fc2e64";
      LoginButtonTextColor = "#ffffff";
      LoginButtonBackgroundColor = "#000000";
      SystemButtonsIconsColor = "#ffffff";
      SessionButtonTextColor = "#ffffff";
      VirtualKeyboardButtonTextColor = "#ffffff";
      DropdownTextColor = "#ffffff";
      DropdownSelectedBackgroundColor = "#4d1927";
      DropdownBackgroundColor = "#32141f";
      HighlightTextColor = "#ffffff";
      HighlightBackgroundColor = "#4d1927";
      HighlightBorderColor = "#4d1927";
      HoverUserIconColor = "#fc2e64";
      HoverPasswordIconColor = "#fc2e64";
      HoverSystemButtonsIconsColor = "#fc2e64";
      HoverSessionButtonTextColor = "#fc2e64";
      HoverVirtualKeyboardButtonTextColor = "#fc2e64";
      HaveFormBackground = "false";
      FormPosition = "center";
      VirtualKeyboardPosition = "right";
      HideVirtualKeyboard = "true";
      HideSystemButtons = "false";
      HideLoginButton = "false";
      ForceLastUser = "true";
      PasswordFocus = "true";
      HideCompletePassword = "true";
      AllowEmptyPassword = "false";
      AllowUppercaseLettersInUsernames = "false";
      BypassSystemButtonsChecks = "false";
      RightToLeftLayout = "false";
    };
  };
in
{
  # Shared by every machine; the per-machine part (hardware scan, hostname, stateVersion) is in
  # hosts/<hostname>/, and home-manager's module comes in from flake.nix.
  # Built with: sudo nixos-rebuild switch --flake ~/nix-dots/nixos
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # No channels: <nixpkgs> in NIX_PATH and the flake registry both point at the flake's pinned nixpkgs
  nix.channel.enable = false;

  # At most 10 system generations: every switch deletes all but the newest 10, the boot menu lists
  # only those, and the weekly garbage collection frees what the deleted ones used.
  system.activationScripts.keepTenGenerations = ''
    ${config.nix.package}/bin/nix-env --profile /nix/var/nix/profiles/system --delete-generations +10
  '';
  boot.loader.systemd-boot.configurationLimit = 10;
  nix.gc = {
    automatic = true;
    dates = "weekly";
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Wi-Fi: bare iwd, which does its own DHCP, so iwgtk and the bar's iwctl talk to the only network
  # manager. NetworkManager with the iwd backend kept a throwaway in-memory copy of each network and
  # told iwd to Forget it (deleting the saved .psk) when that copy went away; saved passwords were
  # lost after every session with a live nixos-rebuild switch (2026-10-29/30).
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General.EnableNetworkConfiguration = true;
      Network = {
        EnableIPv6 = true;
        # openresolv, the same resolv.conf manager tailscale writes through
        NameResolvingService = "resolvconf";
      };
    };
  };
  # Wired ports only (iwd owns wlan*); "background" so an unplugged eno1 doesn't stall the boot
  networking.dhcpcd = {
    allowInterfaces = [ "en*" "eth*" ];
    wait = "background";
  };

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "intl";
  };

  # Configure console keymap
  console.keyMap = "us-acentos";

  users.users.tom = {
    isNormalUser = true;
    description = "tom";
    extraGroups = [ "wheel" "i2c" ];
    # Lets the sddm user reach the wallpaper in ~/.cache (traverse only, no listing)
    homeMode = "711";
    shell = pkgs.zsh;
  };

  # Dotfiles and user packages live in home.nix
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    users.tom = import ./home.nix;
  };

  nixpkgs.config.allowUnfree = true;

  # Desktop
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;
    theme = "sddm-astronaut-theme";
    extraPackages = [ sddmTheme ];
    settings.General.InputMethod = "qtvirtualkeyboard";
    # Always start the default session (hyprland-uwsm): a remembered session would win over it, and
    # one plain-Hyprland login keeps the session services (dcal, cliphist, polkit agent) down for good.
    settings.Users.RememberLastSession = false;
  };
  # The greeter's background is the wallpaper picked with SUPER+P (copied there by
  # hypr/scripts/helpers/update-current-wallpaper.py), so the sddm user must be able to get to it.
  systemd.tmpfiles.rules = [
    "d /home/tom/.cache 0711 tom users -"
    "d /home/tom/.cache/box-dots 0755 tom users -"
    "d /home/tom/.cache/box-dots/current 0755 tom users -"
  ];
  # Hyprland under uwsm (see hypr/exec.lua): the session is a systemd unit, so graphical-session.target
  # and XDG autostart (fcitx5) come up with it, and apps launched with `uwsm app --` get their own scope.
  services.displayManager.defaultSession = "hyprland-uwsm";

  # hyprlock needs its own PAM service to check the password (no service file otherwise)
  security.pam.services.hyprlock = { };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  # dconf backs the gsettings the gtk portal reads the dark-mode preference from (home.nix dconf.settings)
  programs.dconf.enable = true;

  # Loaded from ~/.config/hypr/hyprland.lua; replaces hyprpm on NixOS
  environment.etc."hypr/plugins/hyprexpo.so".source = "${hyprexpo}/lib/libhyprexpo.so";

  # The login shell. box-dots/zsh runs compinit and the prompt itself, so /etc/zshrc doesn't.
  programs.zsh = {
    enable = true;
    enableGlobalCompInit = false;
    promptInit = "";
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-chinese-addons
      fcitx5-mozc
      fcitx5-gtk
    ];
  };

  # Audio (wpctl in keybinds and quickshell)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Bluetooth (quickshell: rfkill / blueman-manager)
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  services.power-profiles-daemon.enable = true;
  services.tailscale.enable = true;

  # Monitor brightness over DDC/CI (ddcutil in quickshell)
  hardware.i2c.enable = true;

  # Installs LocalSend and opens its port (53317) in the firewall
  programs.localsend.enable = true;

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

  environment.systemPackages = with pkgs; [
    sddmTheme
    git
    chromium
    claude-code
    nix-apply
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    adwaita-fonts # Adwaita Sans / Mono: the ui font in gtk and quickshell
  ];
}

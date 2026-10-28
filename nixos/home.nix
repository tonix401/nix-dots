{ config, lib, pkgs, goose, ... }:

let
  dots = "${config.home.homeDirectory}/nix-dots";
  # Out-of-store links keep the files writable, so matugen can regenerate colors
  link = name: { source = config.lib.file.mkOutOfStoreSymlink "${dots}/${name}"; };
in
{
  home.username = "tom";
  home.homeDirectory = "/home/tom";
  # home.stateVersion is per machine, in hosts/<hostname>/default.nix

  xdg.configFile = lib.genAttrs [
    "btop"
    "cat" # the kitty cat's rig, read by quickshell (components/Cat.qml, CatTester.qml)
    "fastfetch"
    "fcitx5"
    "gtk-3.0"
    "gtk-4.0"
    "hypr"
    "kitty"
    "matugen"
    "nano/qml.nanorc"
    "nano/tsx.nanorc"
    "quickshell"
    "starship.toml"
    "xdg-terminals.list" # kitty for Terminal=true apps, which uwsm opens through xdg-terminal-exec
    "zsh"
  ] link // {
    # iwgtk's tray indicator (its package autostarts `iwgtk -i`) repeats the bar's network block and
    # floods the quickshell log with tray-property warnings; right-clicking that block still opens iwgtk.
    "autostart/iwgtk-indicator.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=iwgtk
      Hidden=true
    '';

    # nano/nanorc includes syntax files from /usr/share (Arch); here they're in the store, so this copy
    # has the paths swapped (edits to it need a rebuild). nixpkgs' nanorc is from 2020 and has no jsx,
    # so the definitions come from nano-syntax-highlighting, the project Arch packages.
    "nano/nanorc".text =
      let
        syntax = pkgs.fetchFromGitHub {
          owner = "galenguyer";
          repo = "nano-syntax-highlighting";
          rev = "ce0e7100dc9af181c258c5eb244b9d39e84e9936";
          hash = "sha256-fJ4fleEXTz0MtVB9iqBbjFylhxh/K/pQ/YEPkAlx7GA=";
        };
      in
      builtins.replaceStrings
        [ "/usr/share/nano/" "/usr/share/nano-syntax-highlighting/" ]
        [ "${pkgs.nano}/share/nano/" "${syntax}/" ]
        (builtins.readFile ../nano/nanorc);
  };

  # zsh reads the rest of its config from ~/.config/zsh
  home.file.".zshenv".text = ''
    export ZDOTDIR="$HOME/.config/zsh"
    source "$ZDOTDIR/.zshenv"
  '';

  # The zsh plugins box-dots/zsh/.zshrc loads, at ~/.local/share/zsh/plugins/<name>/<name>.zsh (Arch
  # has them at /usr/share/zsh/plugins)
  xdg.dataFile = lib.mapAttrs' (name: dir: lib.nameValuePair "zsh/plugins/${name}" { source = dir; }) {
    zsh-autosuggestions = "${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions";
    zsh-syntax-highlighting = "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting";
    zsh-history-substring-search = "${pkgs.zsh-history-substring-search}/share/zsh/plugins/zsh-history-substring-search";
    zsh-abbr = "${pkgs.zsh-abbr}/share/zsh/zsh-abbr";
    fzf-tab = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
  };

  # Launcher entries for the quickshell menus (quickshell/menus); the launcher itself and the share
  # menu (opened by the portal) are left out.
  xdg.desktopEntries = lib.mapAttrs' (menu: e: lib.nameValuePair "quickshell-${menu}" {
    inherit (e) name icon comment;
    exec = "qs ipc call menu open ${menu}";
    terminal = false;
    categories = [ "Utility" ];
  }) {
    display = { name = "Display Arrangement"; icon = "video-display"; comment = "Arrange, mirror or turn off monitors"; };
    wallpaper = { name = "Wallpaper Picker"; icon = "preferences-desktop-wallpaper"; comment = "Pick a wallpaper and regenerate the colors"; };
    emoji = { name = "Emoji Picker"; icon = "face-smile"; comment = "Search and copy an emoji"; };
    nerdfont = { name = "Nerd Font Picker"; icon = "preferences-desktop-font"; comment = "Search and copy a Nerd Font glyph"; };
    keybinds = { name = "Keybind Reference"; icon = "preferences-desktop-keyboard-shortcuts"; comment = "List the Hyprland keybinds"; };
    clipboard = { name = "Clipboard History"; icon = "edit-paste"; comment = "Paste from the clipboard history"; };
    power = { name = "Power Menu"; icon = "system-shutdown"; comment = "Shut down, reboot, lock or log out"; };
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "tom";
      email = "tom.weise.2004@gmail.com";
    };
  };

  programs.firefox.enable = true;

  # Session services, started with graphical-session.target (which uwsm brings up with Hyprland)
  services.cliphist.enable = true; # clipboard history for the quickshell clipboard menu
  services.hyprpolkitagent.enable = true;

  # Dank Calendar, hidden in the background: the backend the quickshell widgets (WeekCalendar,
  # TodoList, HabitTracker) talk to over $XDG_RUNTIME_DIR/dankcal-<pid>.sock, and the window
  #  opens to add accounts. Same as the package's own unit, which can't be enabled here.
  systemd.user.services.dcal = {
    Unit = {
      Description = "Dank Calendar";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.dankcalendar}/bin/dcal run --session --hidden";
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "app.slice";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Anki without the app: anki-connect-server serves the collection on AnkiConnect's API and syncs
  # it with AnkiWeb (pkgs/anki-connect-server.nix). Its settings and the AnkiWeb login are in
  # ~/.config/anki-connect-server/env (chmod 600, ANKICONNECT_COLLECTION_PATH, _PORT, _BIND,
  # _ANKIWEB_USER, _ANKIWEB_PASS), kept out of the repo and the store; it doesn't start until that exists.
  systemd.user.services.anki-connect-server = {
    Unit = {
      Description = "Headless AnkiConnect-compatible API server (no Qt/GUI)";
      ConditionPathExists = "%h/.config/anki-connect-server/env";
    };
    Service = {
      Type = "simple";
      EnvironmentFile = "%h/.config/anki-connect-server/env";
      ExecStart = "${pkgs.callPackage ./pkgs/anki-connect-server.nix { }}/bin/anki-connect-server api";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.services.anki-connect-sync = {
    Unit = {
      Description = "Trigger an anki-connect-server sync to AnkiWeb";
      After = [ "anki-connect-server.service" ];
      Requires = [ "anki-connect-server.service" ];
    };
    Service = {
      Type = "oneshot";
      # Without the JSON content type the server answers 422 (curl -d sends it as a form)
      ExecStart = ''${pkgs.curl}/bin/curl -sf -H "Content-Type: application/json" -X POST http://127.0.0.1:8765/api -d '{"action":"sync","version":6}' '';
    };
  };
  systemd.user.timers.anki-connect-sync = {
    Unit.Description = "Periodically trigger an anki-connect-server sync";
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "30min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Dark mode for everything that asks the portal (libadwaita, Qt 6.5+, Electron, browsers): the gtk
  # portal answers org.freedesktop.appearance color-scheme from this key.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "adw-gtk3-dark";
  };

  home.pointerCursor = {
    enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  home.packages = with pkgs; [
    # hyprland ecosystem
    hyprlock
    hyprshutdown
    awww
    quickshell
    hyprpicker
    xsettingsd
    xdg-terminal-exec
    matugen
    adw-gtk3
    adwaita-icon-theme # the icon theme quickshell and gtk use

    # menus, clipboard, screenshots
    grimblast
    cliphist
    wtype
    wl-clipboard
    libnotify
    imagemagick
    librsvg
    # rofimoji's module provides the emoji data for quickshell/scripts/emoji.py; numpy is for
    # cat/voice.py (the kitty cats singing along)
    (python3.withPackages (ps: [ ps.pyvips ps.numpy (ps.toPythonModule rofimoji) ]))

    # quickshell bar and menus
    jq
    ddcutil
    nemo
    dankcalendar
    pavucontrol
    iwgtk
    playerctl
    pulseaudio # pactl: cat/voice.py watches playback with it (the sound server is pipewire-pulse)
    brightnessctl
    goose # goosectl, the sidebar's goose toggle (flake.nix)

    # terminal
    kitty
    starship
    fastfetch
    btop
    eza
    zoxide
    fzf
    fortune
    cowsay
    lolcat

    # apps
    anki
    mousepad
    vscode
    signal-desktop
    transmission_4-gtk
    obsidian
    vlc
    mpv
  ];
}

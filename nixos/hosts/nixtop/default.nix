# The laptop. Everything shared is in ../../common.nix and ../../home.nix.
{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixtop";

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

  # The NixOS release this machine was first installed with, which its stateful data (file
  # locations, database versions) follows. Leave it at that release; it is not the version running.
  system.stateVersion = "25.11";
  home-manager.users.tom.home.stateVersion = "25.11";
}

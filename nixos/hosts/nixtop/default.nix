# The laptop. Everything shared is in ../../common.nix and ../../home.nix.
{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixtop";

  # The NixOS release this machine was first installed with, which its stateful data (file
  # locations, database versions) follows. Leave it at that release; it is not the version running.
  system.stateVersion = "25.11";
  home-manager.users.tom.home.stateVersion = "25.11";
}

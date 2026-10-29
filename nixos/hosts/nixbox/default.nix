# The laptop. Everything shared is in ../../common.nix and ../../home.nix.
{ pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixbox";

  # Docker daemon; being in the docker group lets tom use it without sudo. Started by its socket on
  # the first `docker` call instead of at boot (~130 MB for dockerd + containerd otherwise), so
  # containers with a restart policy only come back once docker is used.
  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = false;
  users.users.tom.extraGroups = [ "docker" ];
  environment.systemPackages = [ pkgs.docker-compose ];

  # The NixOS release this machine was first installed with, which its stateful data (file
  # locations, database versions) follows. Leave it at that release; it is not the version running.
  system.stateVersion = "25.11";
  home-manager.users.tom.home.stateVersion = "25.11";
}

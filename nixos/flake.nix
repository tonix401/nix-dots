{
  description = "NixOS and home-manager config for my machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      # One nixpkgs for the system and home.nix (useGlobalPkgs already shares the package set)
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      # A machine: the shared config plus hosts/<name>. nixos-rebuild --flake picks the one named
      # after the hostname.
      mkHost = name: nixpkgs.lib.nixosSystem {
        modules = [
          ./common.nix
          ./hosts/${name}
          home-manager.nixosModules.home-manager
        ];
      };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs [ "nixbox" ] mkHost;
    };
}

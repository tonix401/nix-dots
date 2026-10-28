{
  description = "NixOS and home-manager config for my machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      # One nixpkgs for the system and home.nix (useGlobalPkgs already shares the package set)
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # The desktop goose (goosectl, the sidebar's goose toggle): the fork with the Arch box's changes
    desktop-goose = {
      url = "github:tonix401/desktop-goose/94a8042f33c862d4039a429fb26ed273393e7843";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, desktop-goose, ... }:
    let
      # A machine: the shared config plus hosts/<name>. nixos-rebuild --flake picks the one named
      # after the hostname.
      mkHost = name: nixpkgs.lib.nixosSystem {
        modules = [
          ./common.nix
          ./hosts/${name}
          home-manager.nixosModules.home-manager
          ({ pkgs, ... }: {
            home-manager.extraSpecialArgs.goose = desktop-goose.packages.${pkgs.stdenv.hostPlatform.system}.default;
          })
        ];
      };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs [ "nixbox" ] mkHost;
    };
}

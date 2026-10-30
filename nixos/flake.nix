{
  description = "NixOS and home-manager config for my machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # The registry's `nixpkgs` (what `nix profile add nixpkgs#x` resolves): the same nixpkgs with allowUnfree
    nixpkgs-unfree = {
      url = "path:./nixpkgs-unfree";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    # Hermes Agent and Claude Code are installed with `nix profile`, not declared here.
  };

  outputs = { nixpkgs, nixpkgs-unfree, home-manager, desktop-goose, ... }:
    let
      # A machine: the shared config plus hosts/<name>. nixos-rebuild --flake picks the one named
      # after the hostname.
      mkHost = name: nixpkgs.lib.nixosSystem {
        modules = [
          ./common.nix
          ./hosts/${name}
          home-manager.nixosModules.home-manager
          ({ pkgs, ... }: {
            # Flake evaluation ignores nixpkgs.config, so `nix profile add nixpkgs#vscode` needs a registry
            # entry whose package set allows unfree. <nixpkgs> stays the plain source for nix-shell -p.
            nixpkgs.flake.setFlakeRegistry = false;
            nixpkgs.flake.setNixPath = false;
            nix.registry.nixpkgs.flake = nixpkgs-unfree;
            nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
            home-manager.extraSpecialArgs.goose = desktop-goose.packages.${pkgs.stdenv.hostPlatform.system}.default;
          })
        ];
      };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs [ "nixtop" "nixbox" ] mkHost;
    };
}

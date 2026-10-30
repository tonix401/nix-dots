{
  description = "nixpkgs with allowUnfree, for `nix profile add nixpkgs#...` (flake evaluation ignores nixpkgs.config)";

  # flake.nix makes this follow the system's nixpkgs
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }: nixpkgs // {
    legacyPackages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
      import nixpkgs { inherit system; config.allowUnfree = true; });
  };
}

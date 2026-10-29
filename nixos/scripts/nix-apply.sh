# Applies the flake in ~/nix-dots/nixos to this machine (the config named after the hostname).
#   nix-apply           build and switch to it now
#   nix-apply boot      switch on the next boot instead (also test, build, dry-build)
#   nix-apply update    update the flake inputs first, then switch
flake="$HOME/nix-dots/nixos"

action="${1:-switch}"
if [[ "$action" == update ]]; then
  nix flake update --flake "$flake"
  action=switch
fi

# The flake only sees files git knows about, so a new, unstaged file would be missing from the build
if [[ -n "$(git -C "$flake" ls-files --others --exclude-standard)" ]]; then
  echo "nix-apply: untracked files in $flake are left out of the build:" >&2
  git -C "$flake" ls-files --others --exclude-standard >&2
fi

if [[ "$action" == build ]]; then
  # No sudo needed; nix build instead of nixos-rebuild so no result link lands in the current folder
  nix build "$flake#nixosConfigurations.$(hostname).config.system.build.toplevel" --no-link --print-out-paths
elif [[ "$action" == dry-build ]]; then
  nixos-rebuild dry-build --flake "$flake#$(hostname)"
else
  sudo nixos-rebuild "$action" --flake "$flake#$(hostname)"
fi

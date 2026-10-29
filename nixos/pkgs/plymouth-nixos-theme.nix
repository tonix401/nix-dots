# Boot splash: the NixOS snowflake on a dark background with a thin progress bar under it.
# A Plymouth "script" theme: the bar is a 1x1 pixel image scaled to the current progress, since the
# script language has no rectangle primitive.
{ stdenvNoCC, imagemagick, nixos-icons }:

stdenvNoCC.mkDerivation {
  pname = "plymouth-nixos-theme";
  version = "1";
  src = ./plymouth-nixos;
  nativeBuildInputs = [ imagemagick ];

  installPhase = ''
    dir=$out/share/plymouth/themes/nixos-bar
    mkdir -p $dir
    cp nixos-bar.script $dir/
    cp ${nixos-icons}/share/icons/hicolor/1024x1024/apps/nix-snowflake.png $dir/logo.png
    magick -size 1x1 xc:white $dir/track.png
    magick -size 1x1 'xc:#7ebae4' $dir/fill.png
    sed "s|@@OUT@@|$dir|g" nixos-bar.plymouth > $dir/nixos-bar.plymouth
  '';
}

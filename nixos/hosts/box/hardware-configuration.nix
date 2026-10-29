# DRAFT, written on the Arch install this machine runs now (2026-10-29): the kernel modules come from
# its lsmod/lspci and the filesystems copy its btrfs layout. A reinstall formats new partitions with
# new UUIDs, so in the installer replace this file with the output of
#   nixos-generate-config --root /mnt
# (and keep the extra mount options below if you keep the subvolume layout).
{ config, lib, pkgs, modulesPath, ... }:

let
  # Same flags as the Arch fstab
  btrfs = subvol: {
    device = "/dev/disk/by-uuid/0371cd78-d77d-4e64-ae05-22f0e0700693";
    fsType = "btrfs";
    options = [ "subvol=${subvol}" "compress=zstd:3" "noatime" "discard=async" ];
  };
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # i5-10400F, 500-series chipset (SATA AHCI, xHCI); the system disk is a SATA SSD (sda)
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = btrfs "@";
  fileSystems."/home" = btrfs "@home";
  fileSystems."/nix" = btrfs "@nix"; # its own subvolume, so snapshots of @ skip the store
  fileSystems."/var/log" = btrfs "@log";
  fileSystems."/.snapshots" = btrfs "@snapshots";

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/4236-92C7";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

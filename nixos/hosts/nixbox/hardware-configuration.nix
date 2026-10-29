{ config, lib, pkgs, modulesPath, ... }:

let
  btrfs = subvol: {
    device = "/dev/disk/by-label/root";
    fsType = "btrfs";
    options = [ "subvol=${subvol}" "compress=zstd:3" "noatime" "discard=async" ];
  };
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = btrfs "@";
  fileSystems."/home" = btrfs "@home";
  fileSystems."/nix" = btrfs "@nix";
  fileSystems."/var/log" = btrfs "@log";
  fileSystems."/.snapshots" = btrfs "@snapshots";

  fileSystems."/swap" = {
    device = "/dev/disk/by-label/root";
    fsType = "btrfs";
    options = [ "subvol=@swap" "noatime" "discard=async" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/EFI";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [{ device = "/swap/swapfile"; }];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

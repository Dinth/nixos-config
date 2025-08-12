{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];
  services.qemuGuest.enable = true;

  boot.loader.grub.enable = true; # Use the boot drive for GRUB
  boot.loader.grub.devices = [ "nodev" ];
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = false;
  boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  filesystems."/" = {
    device = "/dev/disk/by-uuid/3376fb2d-989f-47ae-96c2-e310f394418f";
    fsType = "ext4";
  };

  swapDevices = [ ];

  networking.wireless.enable = false;
  networking.networkmanager.enable = false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

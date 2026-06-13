{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];
  services.qemuGuest.enable = true;

  boot.loader.grub.enable = true; # Use the boot drive for GRUB
  # BIOS Proxmox guest: install GRUB to the boot disk's MBR. Previously this
  # set both `devices = ["nodev"]` (EFI-style, "don't install to a disk") and
  # `device = "/dev/sda"`, which contradict each other — `nodev` belongs to
  # EFI installs. The list form pointed at /dev/sda is the correct BIOS setup.
  boot.loader.grub.devices = ["/dev/sda"];
  boot.loader.grub.useOSProber = false;
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = ["uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/3376fb2d-989f-47ae-96c2-e310f394418f";
    fsType = "ext4";
  };

  swapDevices = [];

  networking.wireless.enable = false;
  networking.networkmanager.enable = false;
  networking.modemmanager.enable = false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

{ config, lib, pkgs, modulesPath, ... }:
{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel "];
  boot.extraModulePackages = [ ];

  filesystems."/" = {
    device = "/dev/disk/by-uuid/f458e530-c7f3-450e-b4fe-859fd65a94f3";
    fsType = "ext4";
  };
  boot.initrd.luks.devices."luks-8159708a-cba7-4234-b4a5-9e643f481a00".device = "/dev/disk/by-uuid/8159708a-cba7-4234-b4a5-9e643f481a00";
  filesystems."/boot" = {
    device = "/dev/disk/by-uuid/D2E3-5273";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };
  swapDevices = [
    {
      device = "/dev/disk/by-uuid/3334d6a1-ef4d-4f22-b3d9-4bf7165df56d";
    }
  ];
  systemd.tpm2.enable = true;
  services.fwupd.enable = true;
  services.fstrim.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}

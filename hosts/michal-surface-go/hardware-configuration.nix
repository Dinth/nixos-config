{ config, lib, pkgs, modulesPath, ... }:
{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel "];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [
    "mem_sleep_default=deep"  # Proper suspend
    "i915.enable_fbc=1"       # Frame buffer compression
  ];
  boot.kernel.sysctl = {
    "vm.dirty_writeback_centisecs" = 1500;
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
  };
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/f458e530-c7f3-450e-b4fe-859fd65a94f3";
    fsType = "ext4";
  };
  boot.initrd.luks.devices."luks-8159708a-cba7-4234-b4a5-9e643f481a00".device = "/dev/disk/by-uuid/8159708a-cba7-4234-b4a5-9e643f481a00";
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/D2E3-5273";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };
  swapDevices = [
    {
      device = "/dev/disk/by-uuid/14a6a5bc-5971-4f26-8346-adc9fa6d5006";
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
  hardware.graphics = {
    enable = true;         # replaces hardware.opengl.enable
    enable32Bit = true;    # replaces hardware.opengl.driSupport32Bit (if present)
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
    ];
    # Use enableHybridCodec, extraPackages32Bit, or other new options as needed
  };
  hardware.sensor.iio.enable = true;
  services.power-profiles-daemon.enable = false;  # Disable conflicting service
  services.tlp = {
    enable = true;
    settings = {
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";
    };
  };
  services.thermald.enable = true;
  environment.systemPackages = with pkgs; [
    libcamera
  ];
}

{ config, lib, pkgs, modulesPath, ... }:
{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];
#  hardware.microsoft-surface.kernelVersion = "stable";
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ "xhci_pci" "nvme" "usbhid" "i915" ];

  boot.kernelModules = [ "kvm-intel" ];
#  boot.extraModprobeConfig = ''
#    options ipu3-imgu load_firmware=1
#  '';
  boot.resumeDevice = "/dev/nvme0n1p3";
  boot.extraModulePackages = [ ];
  boot.kernelParams = [
#    "mem_sleep_default=deep"  # Proper suspend
#    "i915.fastboot=1"
#    "i915.enable_fbc=1"       # Frame buffer compression
#    "i915.enable_psr=1"
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
      device = "/dev/nvme0n1p3";
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
#    wireplumber = {
#      enable = false;
#      extraConfig = ''
#        context.modules = [
#          { name = libwireplumberModule "libpipewire-module-spa-device-factory" }
#          { name = libwireplumberModule "libpipewire-module-spa-node-factory" }
#          { name = libwireplumberModule "libspa-libcamera" }
#        ];
#      '';
#    };
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
  services.iptsd = {
    enable = true;
    config = {
      Config = {
        BlockOnPalm = true;
        BlockOnPen = true;
        TouchThreshold = 20;
        StabilityThreshold = 0.1;
      };
    };
  };
  services.touchegg.enable = true;
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.sensor.iio.enable = true;
#   services.power-profiles-daemon.enable = false;  # Disable conflicting service
#   services.tlp = {
#     enable = true;
#     settings = {
#       CPU_BOOST_ON_AC = 1;
#       CPU_BOOST_ON_BAT = 0;
#       CPU_SCALING_GOVERNOR_ON_AC = "performance";
#       CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
#       START_CHARGE_THRESH_BAT0 = 40;
#       STOP_CHARGE_THRESH_BAT0 = 80;
#       RUNTIME_PM_ON_AC = "on";
#       RUNTIME_PM_ON_BAT = "auto";
#     };
#   };
#  services.thermald.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  environment.systemPackages = with pkgs; [
    iptsd
    surface-control
  ];
  powerManagement.powertop.enable = true;
  # Hibernation after 30m of sleep
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30m
    SuspendState=mem
  '';

  # Configure automatic behavior
  services.logind.extraConfig = ''
    IdleAction=suspend-then-hibernate
    IdleActionSec=5min
    HandleLidSwitch=suspend-then-hibernate
  '';
}
}

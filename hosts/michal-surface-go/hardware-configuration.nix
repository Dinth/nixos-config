{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];
  #  hardware.microsoft-surface.kernelVersion = "stable";
  boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"];
  boot.initrd.kernelModules = ["xhci_pci" "nvme" "usbhid" "i915"];

  boot.kernelModules = ["kvm-intel" "ipu3-cio2"];
  # ipu3-imgu: Intel IPU3 image processing unit — required for built-in cameras
  boot.resumeDevice = "/dev/nvme0n1p3";
  boot.extraModulePackages = [];
  boot.kernelParams = [
    # nixos-hardware microsoft-surface-go sets mem_sleep_default=deep via its surface/common
    # module, but S3 deep sleep causes dw9719 camera VCM I2C failure on resume (error -121),
    # leaving the system with a blank screen. Override to s2idle here — last occurrence wins
    # on the kernel cmdline.
    "mem_sleep_default=s2idle"
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
    options = ["fmask=0077" "dmask=0077"];
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
    enable = true; # replaces hardware.opengl.enable
    enable32Bit = true; # replaces hardware.opengl.driSupport32Bit (if present)
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libva-vdpau-driver
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
  # touchegg removed: KDE Plasma 6 Wayland handles multi-touch natively via KWin/libinput
  # Running both caused double-handling of touch events
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
    libcamera # IPU3 camera stack; test with: cam -l
    v4l-utils # v4l2-ctl --list-devices to verify camera nodes appear
    xournalpp # Stylus note-taking; works via iptsd without libwacom
    # libwacom  # Uncomment to test: Surface Pen uses IPTS not Wacom, likely no benefit
  ];
  powerManagement.powertop.enable = true;
  # powertop --auto-tune sets all USB devices to autosuspend, which causes
  # the Type Cover (touchpad) to disconnect with hid-multitouch ENODEV (-19).
  # Pin the Surface Type Cover to always-on to override powertop's setting.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="09b5", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
  '';
  # The hid-multitouch driver for the Type Cover touchpad (USB interface 1-7:1.3)
  # submits a control URB during system suspend, which fails with -EPERM and aborts
  # the entire suspend. Unbind the interface before sleep and rebind on resume.
  # The || true handles the case where the Type Cover is detached.
  powerManagement.powerDownCommands = ''
    echo 1-7:1.3 > /sys/bus/usb/drivers/usbhid/unbind || true
  '';
  powerManagement.resumeCommands = ''
    echo 1-7:1.3 > /sys/bus/usb/drivers/usbhid/bind || true
  '';
  # Hibernation after 30m of sleep
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30m
    SuspendState=mem
    HibernateOnACPower=no
  '';

  # Configure automatic behavior
  services.logind.settings.Login = {
    IdleAction = "suspend-then-hibernate";
    IdleActionSec = "5min";
    HandleLidSwitch = "suspend-then-hibernate";
  };
  amd_gpu.enable = false;
}

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

  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = ["xhci_pci" "nvme" "usbhid" "i915"];
      luks.devices."luks-8159708a-cba7-4234-b4a5-9e643f481a00" = {
        device = "/dev/disk/by-uuid/8159708a-cba7-4234-b4a5-9e643f481a00";
        # dm-crypt blocks discard passthrough by default, which made fstrim
        # a silent no-op on / — extra important on this tablet's small,
        # wear-sensitive flash. See the desktop's hardware config for the
        # allowDiscards trade-off note.
        allowDiscards = true;
        # Skip dm-crypt's read/write workqueues — lower latency on flash.
        bypassWorkqueues = true;
      };
    };
    # ipu3-imgu: Intel IPU3 image processing unit — required for built-in cameras
    kernelModules = ["kvm-intel" "ipu3-cio2"];
    resumeDevice = "/dev/nvme0n1p3";
    extraModulePackages = [];
    kernelParams = [
      # nixos-hardware microsoft-surface-go sets mem_sleep_default=deep via its surface/common
      # module, but S3 deep sleep causes dw9719 camera VCM I2C failure on resume (error -121),
      # leaving the system with a blank screen. Override to s2idle here — last occurrence wins
      # on the kernel cmdline.
      "mem_sleep_default=s2idle"
    ];
    kernel.sysctl = {
      "vm.dirty_writeback_centisecs" = 1500;
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/f458e530-c7f3-450e-b4fe-859fd65a94f3";
    fsType = "ext4";
    # noatime: skip access-time writes — matches the desktop and reduces
    # flash wear on the Surface's eMMC/SSD.
    options = ["noatime"];
  };

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

  # zram: compressed RAM swap for this low-memory tablet. Gets a higher
  # priority than the nvme swap partition above, so the kernel spills to
  # compressed RAM first and only touches the eMMC/SSD swap under real
  # pressure — cutting flash wear and swap-in latency. zstd gives the best
  # ratio/speed trade-off. vm.swappiness=10 above still applies.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  hardware = {
    graphics = {
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
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    sensor.iio.enable = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  services = {
    # services.fwupd is enabled in hosts/common.nix.
    fstrim.enable = true;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
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
    iptsd = {
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
    udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="09b5", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
    '';
    # Configure automatic behavior
    logind.settings.Login = {
      IdleAction = "suspend-then-hibernate";
      IdleActionSec = "5min";
      HandleLidSwitch = "suspend-then-hibernate";
    };
    # Intel thermal daemon — proactively caps power before the SoC hits its
    # trip points. On this fanless Pentium Gold it delays hard throttling
    # under sustained load (the passive chassis is the only heatsink).
    # AMD desktop correctly leaves this off (thermald is Intel-only).
    thermald.enable = true;
    #   power-profiles-daemon.enable = false;  # Disable conflicting service
    #   tlp = {
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
  };

  systemd = {
    tpm2.enable = true;
    # Hibernation after 30m of sleep
    sleep.settings.Sleep = {
      HibernateDelaySec = "30m";
      SuspendState = "mem";
      HibernateOnACPower = "no";
    };
  };

  powerManagement = {
    powertop.enable = true;
    # powertop --auto-tune sets all USB devices to autosuspend, which causes
    # the Type Cover (touchpad) to disconnect with hid-multitouch ENODEV (-19).
    # Pin the Surface Type Cover to always-on to override powertop's setting.
    # The hid-multitouch driver for the Type Cover touchpad (USB interface 1-7:1.3)
    # submits a control URB during system suspend, which fails with -EPERM and aborts
    # the entire suspend. Unbind the interface before sleep and rebind on resume.
    # The || true handles the case where the Type Cover is detached.
    powerDownCommands = ''
      echo 1-7:1.3 > /sys/bus/usb/drivers/usbhid/unbind || true
    '';
    resumeCommands = ''
      echo 1-7:1.3 > /sys/bus/usb/drivers/usbhid/bind || true
    '';
  };

  environment.systemPackages = with pkgs; [
    iptsd
    surface-control
    libcamera # IPU3 camera stack; test with: cam -l
    v4l-utils # v4l2-ctl --list-devices to verify camera nodes appear
    xournalpp # Stylus note-taking; works via iptsd without libwacom
    # libwacom  # Uncomment to test: Surface Pen uses IPTS not Wacom, likely no benefit
  ];

  amd_gpu.enable = false;
}

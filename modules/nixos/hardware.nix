{ config, pkgs, lib, ... }:
{
# Set optimisations for compilations
#  nixpkgs.hostPlatform = {
#    gcc.arch = "znver3";
#    gcc.tune = "znver3";
#    system = "x86_64-linux";
#  };

  fileSystems."/" =
  { device = "/dev/disk/by-uuid/789d3481-8d64-4a39-b219-95b98db2a3a7";
      fsType = "ext4";
      options = [ "noatime" "nodiratime" ];
  };

  networking.networkmanager.enable = true; # Enable networking

  hardware.block.defaultScheduler = "none";

  boot.kernelParams = lib.mkAfter [
    "preempt=full" #
    "amd_iommu=on" #
    "amd_pstate=active" # AMD Active Pstates instead of cpufreq
    "tsc=reliable" # Trust AMD builtin clock for better latency
    "clocksource=tsc" # Trust AMD builtin cock for etter latency
    "rcu_nocbs=2,4,6,8,10,12,14" # Offload RCU calls from every second core for latency
  ];

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.hardware.bolt.enable = true;
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.keyboard.qmk.enable = true;
  hardware.logitech = {
    wireless.enable = true;
    wireless.enableGraphical = true;
  };
  hardware.flipperzero.enable = true;

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      canon-cups-ufr2
  ];
  };
   hardware.printers = {
     ensurePrinters = [
       {
         name = "Canon_MF270_Series";
         location = "Wickhay";
         deviceUri = "socket://10.10.10.40:9100";
         model = "CNRCUPSMF270ZJ.ppd";
         ppdOptions = {
           PageSize = "A4";
         };
       }
     ];
     ensureDefaultPrinter = "Canon_MF270_Series";
   };
  hardware.steam-hardware.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      amdvlk
      rocmPackages.clr.icd
      vulkan-tools
      clinfo
      radeontop
      amdgpu_top # AMD graphic card resource monitor
    ];
  };
  hardware.sane.enable = true;
  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  services.fwupd.enable = true;
  services.pcscd.enable = true;
  services.fstrim.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };
  systemd.services.logiops = {
    description = "An unofficial userspace driver for HID++ Logitech devices";
    wantedBy = [ "graphical.target" ];
    after = [ "bluetooth.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.logiops}/bin/logid";
    };
    restartTriggers = [ config.environment.etc."logid.cfg".source ];
  };
  environment.etc."logid.cfg".source = ./files/logid.cfg;
}

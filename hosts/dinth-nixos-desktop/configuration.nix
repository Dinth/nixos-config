{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../secrets/deployment.nix

      ../../modules/nixos/core.nix
      ../../modules/nixos/packages.nix
    ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/789d3481-8d64-4a39-b219-95b98db2a3a7";
    fsType = "ext4";
    options = [ "noatime" "nodiratime" ];
  };
  swapDevices = [
    {
      device = "/swapfile";
      size = 32 * 1024;
    }
  ];
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
  hardware.flipperzero.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  services.fwupd.enable = true;
  services.fstrim.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  primaryUser = {
    name = "michal";
    fullName = "Michal Gawronski-Kot";
    email = "michal@gawronskikot.com";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}

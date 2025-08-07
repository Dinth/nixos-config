{ config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../common.nix
      ../../secrets/deployment.nix
    ];


  networking.networkmanager.enable = true; # Enable networking via NM

  hardware.block.defaultScheduler = "none";

  boot.kernelParams = [
    "systemd.show_status=auto"
    "rd.udev.log_level=3"
    "preempt=full" #
    "amd_pstate=active" # AMD Active Pstates instead of cpufreq
    "tsc=reliable" # Trust AMD builtin clock for better latency
    "clocksource=tsc" # Trust AMD builtin cock for etter latency
    "rcu_nocbs=2,4,6,8,10,12,14" # Offload RCU calls from every second core for latency
  ];
  boot = {
    kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.max_map_count" = 524288; # 64GB ram,
      "vm.vfs_cache_pressure" = 50; # more memory for filesystem data
      "vm.dirty_ratio" = 30;
      "vm.dirty_background_ratio" = 15;
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };
  };
  services.thermald.enable = true;
  networking.modemmanager.enable = false;
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

  cli.enable = true;
  graphical.enable = true;
  kde.enable = true;
  _1password.enable = true;
  _1password.gui = true;
  gaming.enable = true;
  virtualisation.enable = true;
  logitech.enable = true;
  amd_gpu.enable = true;
  printers.enable = true;
  weechat.enable = true;

  primaryUser = {
    name = "michal";
    fullName = "Michal Gawronski-Kot";
    email = "michal@gawronskikot.com";
  };
  networking.hostName = "dinth-nixos-desktop"; # Define your hostname.
  services.fstrim.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.michal = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = "Michal";
    extraGroups = [ "networkmanager" "wheel" "scanner" "network" "disk" "audio" "video" "vboxusers" "dialout" "gamemode" ];
  };
  home-manager.users.${config.primaryUser.name} = {
    home = {
      stateVersion = "25.05";
      username = "michal";
      homeDirectory = "/home/michal";
      packages = with pkgs; [
        mqtt-explorer
        discord
        signal-desktop
      ];
    };
    catppuccin.flavor = "mocha";
  };
  environment.systemPackages = with pkgs; [
    cifs-utils
    pciutils
    usbutils
    ffmpeg # multimedia framework
    hdparm
    lm_sensors
    detach
    nixos-anywhere
  ];


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}

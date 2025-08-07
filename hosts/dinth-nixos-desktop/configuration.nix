{ config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../common.nix
      ../../secrets/deployment.nix
    ];


  networking.hostName = "dinth-nixos-desktop"; # Define your hostname.
  networking.networkmanager.enable = true; # Enable networking via NM

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
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
  ssh.enable = true;

  primaryUser = {
    name = "michal";
    fullName = "Michal Gawronski-Kot";
    email = "michal@gawronskikot.com";
  };
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

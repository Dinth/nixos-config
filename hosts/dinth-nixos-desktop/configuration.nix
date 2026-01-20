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

  boot.plymouth = {
    enable = true;
  };
  catppuccin.plymouth.enable = true;
  catppuccin.plymouth.flavor = "mocha";

  cli.enable = true;
  graphical.enable = true;
  kde.enable = true;
  _1password.enable = true;
  gaming.enable = true;
  virtualisation.enable = true;
  logitech.enable = true;
  printers.enable = true;
  weechat.enable = true;
  docker.enable = false;
  yubikey.enable = true;
  opencode.enable = true;
  cloudflarewarp = true;
  primaryUser = {
    name = "michal";
    fullName = "Michal Gawronski-Kot";
    email = "michal@gawronskikot.com";
    publicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnJL7HYauYQWLSdKDZwGJBj/OWu+rBZEcaxS/Dn/Wtq"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHw58iDAXminEmYKnzUjRzMhpR7rvULZZUZ0izMdiuhSAAAABHNzaDo="
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIK+KGs2KSEQaHkzK+awc4QXMKu6kMn10F7cZ4raPcQJKAAAABHNzaDo="
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMOPDiAQbAD53X2neUh/vbIv7pRx2+qkZ7Ti9PH+CJ1yAAAABHNzaDo="
    ];
  };
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${config.primaryUser.name} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = config.primaryUser.fullName;
    extraGroups = [ "networkmanager" "wheel" "scanner" "network" "disk" "audio" "video" "vboxusers" "dialout" "gamemode" "scanner" "lp" ];
    openssh.authorizedKeys.keys = config.primaryUser.publicKeys;
  };
  home-manager.users.${config.primaryUser.name} = {
    home = {
      stateVersion = "25.05";
      username = config.primaryUser.name;
      homeDirectory = "/home/${config.primaryUser.name}";
      packages = with pkgs; [
        mqtt-explorer
        discord
        signal-desktop
        caido
        milkytracker
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

  fileSystems."/mnt/VM" = {
    device = "//10.10.1.19/VM";
    fsType = "cifs";
    options = [
      "credentials=/run/agenix/nas-vm-creds"
      "rw"
      "noserverino"
      "actimeo=1"
      "noperm"
      "cache=none"
      "echo_interval=10"
      "uid=${toString config.users.users.${config.primaryUser.name}.uid}"
      "gid=${toString config.users.groups.users.gid}"
      "_netdev"  # marks as network filesystem
      "nofail"   # don't block boot if mount fails
      "vers=3.0"
      "x-systemd.automount"
      "x-systemd.requires=network-online.target"
      "x-systemd.after=network-online.target"
      "x-systemd.idle-timeout=60"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
    ];
  };
  services.dbus = {
    enable = true;
    implementation = "broker";
  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}

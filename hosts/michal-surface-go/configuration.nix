{ config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../common.nix
      ../../secrets/deployment.nix
    ];

  networking.hostName = "michal-surface-go"; # Define your hostname.
  networking.networkmanager.enable = true; # Enable networking via NM
  networking.modemmanager.enable = true; # Enable modemmanager
  networking.networkmanager.ensureProfiles = {
    profiles = {
      "CracoviaPany" = {
        connection = {
          id = "CracoviaPany";
          type = "wifi";
          autoconnect = true;
          interface-name = "wlp1s0";
        };
        wifi = {
          mode = "infrastructure";
          ssid = "CracoviaPany";
        };
        wifi-security = {
          auth-alg = "open";
          key-mgmt = "wpa-psk";
        };
        ipv4 = {
          method = "auto";
        };
        ipv6 = {
          method = "ignore";
        };
      };
    };
    secrets.entries = [
      {
        matchId = "CracoviaPany";
        key = "psk";
        file = config.age.secrets.wifi-password.path;
      }
    ];
  };
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;
  boot.initrd.systemd.enable = true;
  boot.plymouth = {
    enable = true;
  };
  catppuccin.plymouth.enable = true;
  catppuccin.plymouth.flavor = "mocha";

  cli.enable = true;
  graphical.enable = true;
  kde.enable = true;
  _1password.enable = true;
  _1password.gui = true;
  gaming.enable = false;
  virtualisation.enable = false;
  logitech.enable = true;
  amd_gpu.enable = false;
  printers.enable = true;
  weechat.enable = true;
  docker.enable = false;

  services.touchegg.enable = true;
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
      ];
    };
  };
  system.stateVersion = "25.05";
}

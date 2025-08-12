{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../secrets/deployment.nix
  ];
  networking.hostName = "r230-nixos";
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
  system.stateVersion = "25.05";
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
    catppuccin.flavor = "mocha";
  };
  cli.enable = true;
  graphical.enable = false;
  kde.enable = false;
  _1password.enable = false;
  _1password.gui = false;
  gaming.enable = false;
  virtualisation.enable = false;
  logitech.enable = false;
  amd_gpu.enable = false;
  printers.enable = false;
  weechat.enable = false;
}

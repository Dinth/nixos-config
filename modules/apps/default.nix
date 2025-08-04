{ config, pkgs, ... }:
{
  imports = [
    ./1Password
    ./bat
    ./btop
    ./eza
    ./git
    ./google-chrome
    ./htop
    ./kate
    ./konsole
    ./mc
    ./neovim
    ./OrcaSlicer
    ./sddm
    ./ssh
    ./steam
    ./weechat
    ./zoxide
    ./zsh
  ];
}

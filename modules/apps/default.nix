{ config, pkgs, ... }:
{
  imports = [
    ./1Password
    ./bat
    ./btop
    ./eza
    ./git
    ./google-chrome
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

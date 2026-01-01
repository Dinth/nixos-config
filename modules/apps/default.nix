{ config, pkgs, ... }:
{
  imports = [
    ./1Password
    ./bat
    ./btop
    ./clamav
    ./eza
    ./git
    ./google-chrome
    ./htop
    ./kate
    ./konsole
    ./mc
    ./neovim
    ./nextcloud-client
    ./OrcaSlicer
    ./sddm
    ./ssh
    ./starship
    ./steam
    ./weechat
    ./zoxide
    ./zsh
  ];
}

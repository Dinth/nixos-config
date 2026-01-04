{ config, pkgs, ... }:
{
  imports = [
    ./1Password
    ./bat
    ./btop
    ./clamav
    ./eza
    ./fzf
    ./git
    ./google-chrome
    ./htop
    ./kate
    ./konsole
    ./mc
    ./neovim
    ./nextcloud-client
    ./opencode
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

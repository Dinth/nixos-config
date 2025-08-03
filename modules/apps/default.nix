{ config, pkgs, ... }:
{
  imports = [
    ./bat
    ./btop
    ./eza
    ./git
    ./kate
    ./konsole
    ./mc
    ./sddm
    ./ssh
    ./steam
    ./weechat
    ./zoxide
    ./zsh
  ];
}

{ config, pkgs, ... }:
{
  imports = [
    ./bat
    ./btop
    ./eza
    ./git
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

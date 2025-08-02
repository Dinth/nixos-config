{ config, lib, pkgs, ... }:
{
  imports = [
    ../apps/bat
    ../apps/btop
    ../apps/eza
    ../apps/git
    ../apps/ssh
    ../apps/weechat
    ../apps/zoxide
    ../apps/zsh
  ];
}

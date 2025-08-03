{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.cli;
in
{
  options = {
    cli = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable full CLI features.";
      };
      catppuccin = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable catppuccin theme for CLI tools.";
      };
    };
  };
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

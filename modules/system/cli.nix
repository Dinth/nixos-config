{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
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
}

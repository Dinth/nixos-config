{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.graphical;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    graphical = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable graphical environment.";
      };
    };
  };
}

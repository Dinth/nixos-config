{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.ssh;
in
{
  options = {
    ssh = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable SSH server";
      };
    };
  };
  config = mkIf cfg.enable {

  };
}

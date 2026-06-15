{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.nomachine-client;
in {
  options = {
    nomachine-client = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Install the NoMachine remote desktop client (nxplayer)";
      };
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [pkgs.nomachine-client];
  };
}

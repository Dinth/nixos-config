{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.docker;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    docker = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable docker deamon.";
      };
    };
  };
  config = mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
    users.users.${primaryUsername}.extraGroups = [ "docker" ];
  };
}

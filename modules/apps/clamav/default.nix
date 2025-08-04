{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption mkMerge;
  cfg = config.antivirus;
in
{
  options = {
    antivirus = {
      enable = mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable ClamAV antivirus services";
      };
      accessScanning = {
        enable = mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable on-access file scanning";
        };
        homeDirectories = mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "Downloads"
          ];
          description = "Directories to scan on access, relative to the home directory of each user";
        };
        directories = mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional directories to scan on access. Must be absolute paths.";
        };
      };
    };
  };
  config =
  let
    allNormalUsers = lib.attrsets.filterAttrs (username: config: config.isNormalUser) config.users.users;
    allACScanHomeDirs = builtins.concatMap (
      dir: lib.attrsets.mapAttrsToList (username: config: config.home + "/" + dir) allNormalUsers
    )
    cfg.accessScanning.homeDirectories;
  in
  {

  };
}

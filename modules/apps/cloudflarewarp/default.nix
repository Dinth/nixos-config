{ config, lib, pkgs, ...}:
let
  inherit (lib) mkIf mkOption;
  cfg = config.cloudflarewarp;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    cloudflarewarp = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Install and setup Cloudflare WARP client";
      };
    };
  };
  config = mkIf cfg.enable {
    services.cloudflare-warp.enable = true;
  };
};

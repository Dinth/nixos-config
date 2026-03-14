{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.komodo-periphery;
in
{
  options.komodo-periphery = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Komodo Periphery agent";
    };

    passkeys = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Passkeys for authentication with Komodo Core";
    };

    openFirewall = mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open port 8120 in firewall";
    };
  };

  config = mkIf cfg.enable {
    services.komodo-periphery = {
      enable = true;
      openFirewall = cfg.openFirewall;
      passkeys = cfg.passkeys;
    };
  };
}

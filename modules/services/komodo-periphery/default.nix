{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.komodo-periphery;
in
{
  options.komodo-periphery = {
    enable = mkOption {
      type = lib.types.bool;
      default = config.docker.enable;
      description = "Enable Komodo Periphery agent (auto-enabled when Docker is enabled)";
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
      passkeys = cfg.passkeys;
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ 8120 ];
  };
}

{ config, lib, pkgs, machineType ? "desktop", ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.komodo-periphery;
  isDockerServer = machineType == "server" && config.docker.enable;
in
{
  options.komodo-periphery = {
    enable = mkOption {
      type = lib.types.bool;
      default = isDockerServer;
      description = "Enable Komodo Periphery agent (auto-enabled on servers with Docker)";
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

{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.tailscale;
in {
  options.tailscale = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Tailscale VPN";
    };
    exitNode = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow this machine to act as a Tailscale exit node";
    };
    authKeyFile = mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the Tailscale auth key (e.g. from ragenix)";
    };
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = if cfg.exitNode then "both" else "client";
      authKeyFile = lib.mkIf (cfg.authKeyFile != null) cfg.authKeyFile;
    };

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };

    environment.systemPackages = [ pkgs.tailscale ];
  };
}

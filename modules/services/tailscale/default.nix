{
  config,
  lib,
  ...
}: let
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
      useRoutingFeatures =
        if cfg.exitNode
        then "both"
        else "client";
      authKeyFile = lib.mkIf (cfg.authKeyFile != null) cfg.authKeyFile;
      # useRoutingFeatures only flips the kernel IP-forwarding sysctls; the
      # node still has to *advertise* itself as an exit node via `up`, or it
      # never appears as an exit option in the tailnet.
      extraUpFlags = lib.optionals cfg.exitNode ["--advertise-exit-node"];
    };

    # Ensure the autoconnect service waits for an active network connection.
    # Without this it starts before WiFi is up, loops in NoState for 90s, and times out.
    systemd.services.tailscaled-autoconnect = lib.mkIf (cfg.authKeyFile != null) {
      after = ["network-online.target"];
      wants = ["network-online.target"];
    };

    networking.firewall = {
      trustedInterfaces = ["tailscale0"];
      allowedUDPPorts = [config.services.tailscale.port];
    };
    # The upstream services.tailscale module already adds the CLI to
    # environment.systemPackages, so no need to duplicate it here.
  };
}

{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption mkForce;
  cfg = config.docker;
  primaryUsername = config.primaryUser.name;
  tcpEnabled = cfg.tcpClients != [];
in {
  options = {
    docker = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Docker daemon.";
      };
      tcpClients = mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          IP addresses allowed to reach Docker's TCP socket on port 2375.

          SECURITY: port 2375 is the UNENCRYPTED, UNAUTHENTICATED Docker API —
          anyone who can reach it (or spoof one of these source IPs on the LAN)
          gets root-equivalent control of the host. The firewall allowlist below
          is the only guard. Prefer a TLS socket (2376) or a socket-proxy that
          exposes a read-only subset before enabling this anywhere sensitive.
        '';
        example = ["10.10.1.11"];
      };
    };
  };
  config = mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      daemon.settings = {
        # Keep fd:// for socket activation (docker.service requires docker.socket),
        # then append TCP if tcpClients are set. mkForce overrides the module default.
        hosts = mkForce (["fd://"] ++ lib.optionals tcpEnabled ["tcp://0.0.0.0:2375"]);
        log-driver = "json-file";
        log-opts = {
          max-size = "10m";
          max-file = "5";
        };
        storage-driver = "overlay2";
      };
    };

    # Allow only the specified IPs to reach port 2375; all others are
    # dropped by default. Uses iptables (active backend) + nftables (for
    # the eventual migration) — same dual-backend pattern as in
    # modules/services/prometheus-exporters/default.nix.
    networking.firewall = lib.mkIf tcpEnabled {
      extraCommands =
        lib.concatMapStrings
        (ip: "iptables -A nixos-fw -s ${ip} -p tcp --dport 2375 -j nixos-fw-accept\n")
        cfg.tcpClients;
      extraStopCommands =
        lib.concatMapStrings
        (ip: "iptables -D nixos-fw -s ${ip} -p tcp --dport 2375 -j nixos-fw-accept || true\n")
        cfg.tcpClients;
      extraInputRules =
        lib.concatMapStrings
        (ip: "ip saddr ${ip} tcp dport 2375 accept\n")
        cfg.tcpClients;
    };

    users.users.${primaryUsername}.extraGroups = ["docker"];
  };
}

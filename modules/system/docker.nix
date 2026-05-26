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
        description = "IP addresses allowed to reach Docker's TCP socket on port 2375.";
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

    # Dedicated unprivileged service account for container processes and
    # docker-adjacent services (e.g. Komodo Periphery). Fixed UID so that
    # bind-mounted data under /opt/docker survives rebuilds. The docker group
    # GID is left at the NixOS default (131) set by virtualisation.docker.
    users.users.docker = {
      isSystemUser = true;
      group = "docker";
      uid = 911;
      description = "Docker service account";
      home = "/var/lib/docker-user";
      createHome = false;
    };
  };
}

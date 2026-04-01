{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption mkForce;
  cfg = config.docker;
  primaryUsername = config.primaryUser.name;
  tcpEnabled = cfg.tcpClients != [];
in
{
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
        example = [ "10.10.1.11" ];
      };
    };
  };
  config = mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      daemon.settings = {
        # Keep fd:// for socket activation (docker.service requires docker.socket),
        # then append TCP if tcpClients are set. mkForce overrides the module default.
        hosts = mkForce ([ "fd://" ] ++ lib.optionals tcpEnabled [ "tcp://0.0.0.0:2375" ]);
        log-driver = "json-file";
        log-opts = {
          max-size = "10m";
          max-file = "5";
        };
        storage-driver = "overlay2";
      };
    };

    # Allow only the specified IPs to reach port 2375; all others are dropped by default
    networking.firewall.extraInputRules = lib.mkIf tcpEnabled (
      lib.concatMapStrings
        (ip: "ip saddr ${ip} tcp dport 2375 accept\n")
        cfg.tcpClients
    );

    users.users.${primaryUsername}.extraGroups = [ "docker" ];
  };
}

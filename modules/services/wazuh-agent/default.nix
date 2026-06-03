{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.wazuh;
in {
  options.wazuh = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the Wazuh agent and enrol it against the homelab manager.

        The agent itself is not in nixpkgs — the package and the underlying
        `services.wazuh-agent.*` options come from the `wazuh-agent` flake
        input (community fork), wired in at the flake level. This module is a
        thin homelab toggle that pins the manager and keeps host configs to a
        single `wazuh.enable = true;`. The agent compiles from source on the
        first rebuild.
      '';
    };

    managerIP = mkOption {
      type = lib.types.str;
      default = "10.10.1.18";
      description = "IP/hostname of the Wazuh manager (registration on 1515, reporting on 1514).";
    };
  };

  config = mkIf cfg.enable {
    services.wazuh-agent = {
      enable = true;
      # Reporting on 1514, enrolment (agent-auth) on 1515. registration.host
      # must be set explicitly: when left null the upstream module falls back
      # to manager.host *and* manager.port (1514), which would send enrolment
      # to the wrong port. Same server, default registration port (1515).
      manager.host = cfg.managerIP;
      registration.host = cfg.managerIP;
    };
  };
}

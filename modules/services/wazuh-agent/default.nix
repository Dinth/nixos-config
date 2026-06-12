{
  config,
  lib,
  pkgs,
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

    managerHost = mkOption {
      type = lib.types.str;
      default = "edr.wickhay.uk";
      description = "IP/hostname of the Wazuh manager (reporting on managerPort, enrolment on registrationPort).";
    };

    managerPort = mkOption {
      type = lib.types.port;
      default = 9514;
      description = "Port the manager listens on for agent reporting traffic.";
    };

    registrationPort = mkOption {
      type = lib.types.port;
      default = 9515;
      description = "Port the manager listens on for agent enrolment (agent-auth).";
    };
  };

  config = mkIf cfg.enable {
    # Enrolment password for agent-auth. The upstream `agentAuthPassword`
    # option bakes the password into a world-readable /nix/store script, so we
    # keep it out of the store: decrypt via ragenix and drop it into
    # authd.pass at runtime (see the ExecStartPre below). Owned by the wazuh
    # user the upstream module creates so agent-auth can read it.
    age.secrets.wazuh-enrolment = {
      file = ../../../secrets/wazuh-enrolment.age;
      owner = "wazuh";
      group = "wazuh";
      mode = "0400";
    };

    services.wazuh-agent = {
      enable = true;
      # Reporting on managerPort, enrolment (agent-auth) on registrationPort.
      # registration.host must be set explicitly: when left null the upstream
      # module falls back to manager.host *and* manager.port, which would send
      # enrolment to the reporting port. Same server, separate ports.
      manager.host = cfg.managerHost;
      manager.port = cfg.managerPort;
      registration.host = cfg.managerHost;
      registration.port = cfg.registrationPort;
    };

    # Install the enrolment password into authd.pass before agent-auth runs.
    # agent-auth reads /var/ossec/etc/authd.pass automatically; runs as the
    # wazuh user, which owns both the secret and the ossec etc dir.
    systemd.services.wazuh-agent-auth.serviceConfig.ExecStartPre = [
      "${lib.getExe' pkgs.coreutils "install"} -m 0640 ${config.age.secrets.wazuh-enrolment.path} /var/ossec/etc/authd.pass"
    ];
  };
}

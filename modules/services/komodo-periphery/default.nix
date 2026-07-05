{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.komodo-periphery;

  # Docker config dir with compose plugin wired in so `docker compose` works
  dockerConfig = pkgs.runCommand "docker-config-with-compose" {} ''
    mkdir -p $out/cli-plugins
    ln -s ${pkgs.docker-compose}/bin/docker-compose $out/cli-plugins/docker-compose
  '';

  komodo-periphery-pkg = pkgs.stdenv.mkDerivation rec {
    pname = "komodo-periphery";
    version = "2.2.0";

    src = pkgs.fetchurl {
      url = "https://github.com/moghtech/komodo/releases/download/v${version}/periphery-x86_64";
      hash = "sha256-rOkAeAXb/nWtc8dcNrsmhS+pCdglV38x9dE+7NPFJmA=";
    };

    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [pkgs.makeWrapper];

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/.periphery-unwrapped
      chmod +x $out/bin/.periphery-unwrapped

      makeWrapper ${pkgs.nix-ld}/libexec/nix-ld $out/bin/periphery \
        --set NIX_LD_LIBRARY_PATH "${lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib pkgs.openssl]}" \
        --set NIX_LD "${pkgs.stdenv.cc.libc}/lib/ld-linux-x86-64.so.2" \
        --prefix PATH : "${lib.makeBinPath [pkgs.bash pkgs.openssl pkgs.docker pkgs.git]}" \
        --add-flags "$out/bin/.periphery-unwrapped"
    '';
  };

  configFile = pkgs.writeText "periphery.toml" ''
    port = ${toString cfg.port}
    ssl_enabled = false
    root_directory = "/var/lib/komodo"
    core_public_keys = [${lib.concatMapStringsSep ", " (k: ''"${k}"'') cfg.corePublicKeys}]

    [logging]
    level = "info"
  '';
in {
  options.komodo-periphery = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Komodo Periphery agent.";
    };

    corePublicKeys = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Public keys of Komodo Core instances allowed to connect.";
    };

    port = mkOption {
      type = lib.types.port;
      default = 8120;
      description = "Port the Periphery agent listens on.";
    };

    openFirewall = mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the Periphery port in the firewall (LAN-wide unless allowFrom is set).";
    };

    allowFrom = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["10.10.1.13"];
      description = ''
        Source IPs allowed to reach the Periphery port. When non-empty, the
        port is opened only for these addresses instead of LAN-wide —
        Periphery deploys arbitrary compose stacks with docker-socket access,
        so core_public_keys auth shouldn't be the only guard. Uses the same
        dual-backend (iptables active, nftables for the eventual migration)
        pattern as modules/services/prometheus-exporters.
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.nix-ld.enable = true;

    systemd.services.komodo-periphery = {
      description = "Komodo Periphery agent";
      after = ["network.target" "docker.service"];
      requires = ["docker.service"];
      wantedBy = ["multi-user.target"];

      # Cap crash-loop hammering of the docker daemon.
      startLimitIntervalSec = 300;
      startLimitBurst = 5;

      environment = {
        DOCKER_HOST = "unix:///run/docker.sock";
        DOCKER_CONFIG = "${dockerConfig}";
      };

      serviceConfig = {
        Type = "exec";
        ExecStart = "${komodo-periphery-pkg}/bin/periphery --config-path ${configFile}";
        Restart = "on-failure";
        RestartSec = "10s";
        StateDirectory = "komodo komodo/stacks komodo/repos komodo/builds";
        WorkingDirectory = "/var/lib/komodo";

        # Modest hardening. Kept compatible with docker-socket access and
        # arbitrary compose-stack management under /var/lib/komodo, so no
        # ProtectSystem=strict / ProtectHome here.
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
      };
    };

    networking.firewall = mkIf cfg.openFirewall (
      if cfg.allowFrom == []
      then {allowedTCPPorts = [cfg.port];}
      else {
        extraCommands =
          lib.concatMapStrings (ip: ''
            iptables -A nixos-fw -s ${ip} -p tcp --dport ${toString cfg.port} -j nixos-fw-accept
          '')
          cfg.allowFrom;
        extraStopCommands =
          lib.concatMapStrings (ip: ''
            iptables -D nixos-fw -s ${ip} -p tcp --dport ${toString cfg.port} -j nixos-fw-accept || true
          '')
          cfg.allowFrom;
        extraInputRules =
          lib.concatMapStrings (ip: ''
            ip saddr ${ip} tcp dport ${toString cfg.port} accept
          '')
          cfg.allowFrom;
      }
    );
  };
}

{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.languagetool;
  primaryUsername = config.primaryUser.name;

  # Three loopback ports, one hop each:
  #   8081  nginx — what every client talks to; tries omv, then 8082
  #   8082  systemd socket — accepting a connection starts the local server
  #   8083  the local LanguageTool JVM itself
  # 8081 is also the LanguageTool browser extension's built-in "local server".
  proxyPort = 8081;
  socketPort = 8082;
  localPort = 8083;

  # ExecStartPost: hold the unit in "activating" until the JVM answers, so
  # systemd-socket-proxyd (ordered after it) doesn't forward the waiting
  # request into a port nothing is listening on yet. Cold start is ~10s.
  waitForServer = pkgs.writeShellScript "languagetool-wait" ''
    set -euo pipefail
    for _ in $(seq 120); do
      ${lib.getExe pkgs.curl} -sf -o /dev/null http://127.0.0.1:${toString localPort}/v2/languages && exit 0
      sleep 0.5
    done
    exit 1
  '';
in {
  options.languagetool = {
    enable = mkOption {
      type = lib.types.bool;
      # Grammar checking only matters where there's something to type into.
      default = config.graphical.enable;
      description = "Route LanguageTool clients through a local proxy: the omv server first, an on-demand local server as fallback.";
    };

    remote = mkOption {
      type = lib.types.str;
      default = "10.10.1.13:8010";
      description = "host:port of the shared LanguageTool server (omv).";
    };

    url = mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "http://localhost:${toString proxyPort}";
      description = "Base URL clients should use (append /v2 for the API).";
    };
  };

  config = mkIf cfg.enable {
    # Failover proxy. omv is primary; after one failed connect it's skipped
    # for 30s and requests go straight to the local backup. Away from home
    # (Surface), the connect timeout is the only cost before falling back.
    services.nginx = {
      enable = true;
      upstreams.languagetool.servers = {
        ${cfg.remote} = {
          max_fails = 1;
          fail_timeout = "30s";
        };
        "127.0.0.1:${toString socketPort}".backup = true;
      };
      virtualHosts.languagetool = {
        listen = [
          {
            addr = "127.0.0.1";
            port = proxyPort;
          }
        ];
        locations."/" = {
          proxyPass = "http://languagetool";
          extraConfig = ''
            proxy_connect_timeout 2s;
            # Covers the local server's cold start behind the backup socket.
            proxy_read_timeout 90s;
            proxy_next_upstream error timeout http_502 http_503 http_504;
            client_max_body_size 10m;
          '';
        };
      };
    };

    # The local server costs ~0.5 GB of JVM heap, so it never runs unless the
    # backup socket gets a connection: socket -> proxyd -> languagetool. proxyd
    # exits after 15 idle minutes and StopWhenUnneeded takes the JVM with it.
    services.languagetool = {
      enable = true;
      port = localPort;
      jvmOptions = ["-Xmx512m"];
    };

    systemd.services.languagetool = {
      wantedBy = lib.mkForce [];
      unitConfig.StopWhenUnneeded = true;
      serviceConfig.ExecStartPost = waitForServer;
    };

    systemd.sockets.languagetool-proxy = {
      wantedBy = ["sockets.target"];
      listenStreams = ["127.0.0.1:${toString socketPort}"];
    };

    systemd.services.languagetool-proxy = {
      description = "On-demand proxy to the local LanguageTool server";
      requires = ["languagetool.service"];
      after = ["languagetool.service"];
      serviceConfig = {
        ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd --exit-idle-time=15min 127.0.0.1:${toString localPort}";
        DynamicUser = true;
        PrivateTmp = true;
      };
    };

    # LibreOffice: built-in remote LanguageTool checker, made the grammar
    # checker for the languages we write in (replacing Lightproof for English).
    # libreoffice-qt comes from kde.nix, so follow that toggle.
    home-manager.users.${primaryUsername} = hm:
      mkIf config.kde.enable {
        home.activation.libreofficeLanguagetool = hm.lib.hm.dag.entryAfter ["writeBoundary"] ''
          run ${pkgs.python3.interpreter} ${./libreoffice-xcu.py} \
            "${hm.config.xdg.configHome}/libreoffice/4/user/registrymodifications.xcu" \
            "${cfg.url}/v2" en-GB en-US pl-PL
        '';
      };
  };
}

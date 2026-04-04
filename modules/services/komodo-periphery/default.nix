{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.komodo-periphery;

  # Docker config dir with compose plugin wired in so `docker compose` works
  dockerConfig = pkgs.runCommand "docker-config-with-compose" {} ''
    mkdir -p $out/cli-plugins
    ln -s ${pkgs.docker-compose}/bin/docker-compose $out/cli-plugins/docker-compose
  '';

  komodo-periphery-pkg = pkgs.stdenv.mkDerivation rec {
    pname = "komodo-periphery";
    version = "2.0.0";

    src = pkgs.fetchurl {
      url = "https://github.com/moghtech/komodo/releases/download/v${version}/periphery-x86_64";
      hash = "sha256-FfaDSy26wDFIB3I6MCku+UKEGzELqB8TP9gLLKXpb6c=";
    };

    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/.periphery-unwrapped
      chmod +x $out/bin/.periphery-unwrapped

      makeWrapper ${pkgs.nix-ld}/libexec/nix-ld $out/bin/periphery \
        --set NIX_LD_LIBRARY_PATH "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib pkgs.openssl ]}" \
        --set NIX_LD "${pkgs.stdenv.cc.libc}/lib/ld-linux-x86-64.so.2" \
        --prefix PATH : "${lib.makeBinPath [ pkgs.openssl pkgs.docker pkgs.git ]}" \
        --add-flags "$out/bin/.periphery-unwrapped"
    '';
  };

  configFile = pkgs.writeText "periphery.toml" ''
    port = ${toString cfg.port}
    ssl_enabled = false
    root_directory = "/var/lib/komodo-periphery"
    core_public_keys = [${lib.concatMapStringsSep ", " (k: ''"${k}"'') cfg.corePublicKeys}]

    [logging]
    level = "trace"
  '';
in
{
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
      description = "Open the Periphery port in the firewall.";
    };
  };

  config = mkIf cfg.enable {
    programs.nix-ld.enable = true;

    systemd.services.komodo-periphery = {
      description = "Komodo Periphery agent";
      after = [ "network.target" "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        DOCKER_HOST = "unix:///run/docker.sock";
        DOCKER_CONFIG = "${dockerConfig}";
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${komodo-periphery-pkg}/bin/periphery --config-path ${configFile}";
        Restart = "on-failure";
        RestartSec = "10s";
        StateDirectory = "komodo-periphery komodo-periphery/stacks komodo-periphery/repos komodo-periphery/builds";
        WorkingDirectory = "/var/lib/komodo-periphery";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}

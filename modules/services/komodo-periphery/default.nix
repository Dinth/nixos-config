{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.komodo-periphery;

  komodo-periphery-pkg = pkgs.stdenv.mkDerivation rec {
    pname = "komodo-periphery";
    version = "1.19.5";

    src = pkgs.fetchurl {
      url = "https://github.com/moghtech/komodo/releases/download/v${version}/periphery-x86_64";
      hash = "sha256-1uics2Avffe2TEPTWJLGQVeBGcJFGWuu0oV9fQeFlHA=";
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
        --add-flags "$out/bin/.periphery-unwrapped"
    '';
  };

  configFile = pkgs.writeText "periphery.toml" ''
    port = ${toString cfg.port}
    ssl_enabled = true
    passkeys = [${lib.concatMapStringsSep ", " (k: ''"${k}"'') cfg.passkeys}]
  '';
in
{
  options.komodo-periphery = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Komodo Periphery agent.";
    };

    passkeys = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Passkeys for authentication with Komodo Core.";
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

    users.users.komodo-periphery = {
      isSystemUser = true;
      group = "komodo-periphery";
      extraGroups = [ "docker" ];
    };
    users.groups.komodo-periphery = {};

    systemd.services.komodo-periphery = {
      description = "Komodo Periphery agent";
      after = [ "network.target" "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${komodo-periphery-pkg}/bin/periphery --config-path ${configFile}";
        Restart = "on-failure";
        RestartSec = "10s";
        User = "komodo-periphery";
        Group = "komodo-periphery";
        StateDirectory = "komodo-periphery";
        WorkingDirectory = "/var/lib/komodo-periphery";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}

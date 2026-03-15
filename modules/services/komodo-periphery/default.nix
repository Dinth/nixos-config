{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.komodo-periphery;

  # Build periphery from source (only periphery binary, not core)
  komodo-periphery-pkg = pkgs.rustPlatform.buildRustPackage rec {
    pname = "komodo-periphery";
    version = "1.16.3";

    src = pkgs.fetchFromGitHub {
      owner = "moghtech";
      repo = "komodo";
      rev = "v${version}";
      hash = "sha256-TaQXUUWHBYo+/mGbygak0Clw8QqAkgPOgBqWzBSjkSM=";
    };

    cargoHash = lib.fakeHash;

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.openssl ];

    cargoBuildFlags = [ "-p" "komodo_periphery" ];

    postInstall = ''
      mv $out/bin/periphery $out/bin/periphery || true
    '';

    meta = {
      description = "Komodo Periphery - Multi-server Docker and Git deployment agent";
      homepage = "https://github.com/moghtech/komodo";
      license = lib.licenses.gpl3;
    };
  };

  configFile = pkgs.writeText "komodo-periphery.toml" ''
    port = 8120
    ssl_enabled = true
    passkeys = [${lib.concatMapStringsSep ", " (k: ''"${k}"'') cfg.passkeys}]
  '';
in
{
  options.komodo-periphery = {
    enable = mkOption {
      type = lib.types.bool;
      default = config.docker.enable;
      description = "Enable Komodo Periphery agent (auto-enabled when Docker is enabled)";
    };

    passkeys = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Passkeys for authentication with Komodo Core";
    };

    openFirewall = mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open port 8120 in firewall";
    };
  };

  config = mkIf cfg.enable {
    users.users.komodo-periphery = {
      isSystemUser = true;
      group = "komodo-periphery";
      extraGroups = [ "docker" ];
    };
    users.groups.komodo-periphery = {};

    systemd.services.komodo-periphery = {
      description = "Komodo Periphery - Multi-server Docker and Git deployment agent";
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
        SupplementaryGroups = [ "docker" ];
        StateDirectory = "komodo-periphery";
        WorkingDirectory = "/var/lib/komodo-periphery";
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ 8120 ];
  };
}

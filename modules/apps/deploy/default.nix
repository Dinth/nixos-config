{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.deploy;

  deployScript = pkgs.writeShellScriptBin "deploy-nixos" ''
    set -euo pipefail

    HOST="''${1:-}"
    ACTION="''${2:-switch}"

    case "$HOST" in
      r230-nixos|r230)
        TARGET="michal@10.10.1.12"
        CONFIG="r230-nixos"
        ;;
      *)
        echo "Usage: deploy-nixos <host> [switch|boot|test]"
        echo "Hosts: r230-nixos (r230)"
        exit 1
        ;;
    esac

    echo "Deploying $CONFIG to $TARGET ($ACTION)..."
    nixos-rebuild "$ACTION" \
      --flake "/home/michal/Documents/nixos-config#$CONFIG" \
      --target-host "$TARGET" \
      --use-remote-sudo
  '';
in
{
  options.deploy = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ deployScript ];
  };
}

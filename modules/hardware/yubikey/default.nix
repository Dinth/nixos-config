{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf mkOption mkMerge;
  cfg = config.yubikey;
  primaryUsername = config.primaryUser.name;
  # Enforcing yubikey-manager 5.7.1 - required for yubioath-flutter <=7.2.3
  oldNixpkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/a343533bccc62400e8a9560423486a3b6c11a23b.tar.gz";
    sha256 = "0103a1a1g5sp4bjhm6fl0nfw69jgdiwrwz96nnqi0f3bg6vcg1sf";  # Leave empty first to get hash from error
  }) {};
in
{
  options = {
    yubikey = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable support for Yubikeys";
      };
    };
  };
  config = mkMerge [
    (mkIf cfg.enable {
      services.pcscd.enable = true;
      # Enforcing yubikey-manager 5.7.1 - required for yubioath-flutter <=7.2.3
      environment.systemPackages = [
        pkgs.libfido2
        oldNixpkgs.yubikey-manager
      ];
#      environment.systemPackages = with pkgs; [
#        libfido2 # FIDO2 library (for Yubikeys)
#        yubikey-manager # Yubikey manager
#      ];
    })
    (mkIf (cfg.enable && config.graphical.enable) {
      environment.systemPackages = with pkgs; [
        yubioath-flutter
      ];
    })
  ];
}

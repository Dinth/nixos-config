{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption mkMerge;
  cfg = config.yubikey;
in {
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
      # udev rules for the OTP/FIDO HID interface so ykman/fido2 tools work
      # without root. pcscd already covers the CCID/PIV/OATH-over-CCID side.
      services.udev.packages = [pkgs.yubikey-personalization];
      environment.systemPackages = with pkgs; [
        libfido2 # FIDO2 library (for Yubikeys)
        yubikey-manager # Yubikey manager
      ];

      # Touch-to-sudo via U2F. control = "sufficient" means a successful key
      # touch authenticates, but a missing/unenrolled key falls through to the
      # normal password prompt — so this never locks sudo out.
      #
      # ENROLL FIRST (per user, per key), otherwise only the password path works:
      #   mkdir -p ~/.config/Yubico
      #   pamu2fcfg > ~/.config/Yubico/u2f_keys           # touch the key
      #   pamu2fcfg -n >> ~/.config/Yubico/u2f_keys       # optional 2nd/backup key
      security.pam.u2f = {
        enable = true;
        control = "sufficient";
        settings.cue = true; # prompt "touch your security key"
      };
      security.pam.services.sudo.u2fAuth = true;
    })
    (mkIf (cfg.enable && config.graphical.enable) {
      environment.systemPackages = with pkgs; [
        yubioath-flutter
      ];
    })
  ];
}

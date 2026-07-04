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
      # NOTE: security.pam.u2f.enable is the GLOBAL switch — setting it true
      # attaches pam_u2f to *every* PAM service (login, sddm, the KDE screen
      # locker, polkit, sshd, …), which forces a key touch to unlock the
      # screen and interacts badly with KDE's unlock UI. We only want a key
      # touch for privilege escalation, so leave the global switch off and
      # opt in per-service on doas alone. control/settings still apply to the
      # services that do enable u2f.
      security.pam.u2f = {
        enable = false;
        control = "sufficient";
        settings.cue = true; # prompt "touch your security key"
      };
      # doas is the escalation path on these hosts (sudo is disabled in
      # modules/system/security.nix), so pam_u2f must attach to the doas
      # service — targeting sudo would be inert. control = "sufficient" means
      # a missing/failed key falls through to the password prompt. The cue
      # prompt comes from the global security.pam.u2f.settings above (the
      # per-service submodule only exposes enable/control, not settings).
      security.pam.services.doas.u2f = {
        enable = true;
        control = "sufficient";
      };
    })
    (mkIf (cfg.enable && config.graphical.enable) {
      environment.systemPackages = with pkgs; [
        yubioath-flutter
      ];
    })
  ];
}

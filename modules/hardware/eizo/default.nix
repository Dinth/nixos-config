{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.eizo;
  primaryUsername = config.primaryUser.name;
in {
  options = {
    eizo = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable support for Eizo screen (DDC)";
      };
      iccProfile = mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to ICC profile file for the Eizo monitor";
      };
    };
  };
  config = mkIf cfg.enable {
    boot.kernelModules = ["i2c-dev"];
    environment.systemPackages = with pkgs; [
      ddcutil
      ddccontrol
    ];
    hardware.i2c.enable = true;

    # Add primary user to i2c group for DDC control
    users.users.${primaryUsername}.extraGroups = ["i2c"];

    home-manager.users.${primaryUsername} = {
      # Install the ICC profile where colord (enabled in graphical.nix) actually
      # scans for it — ~/.local/share/icc. The previous /etc/color/icc path is
      # not a colord search location, so the profile was never picked up.
      xdg.dataFile = mkIf (cfg.iccProfile != null) {
        "icc/${baseNameOf (toString cfg.iccProfile)}".source = cfg.iccProfile;
      };

      # Disable PowerDevil DDC brightness control (glitchy i2c on this monitor)
      xdg.configFile."systemd/user/plasma-powerdevil.service.d/override.conf".text = ''
        [Service]
        Environment=POWERDEVIL_NO_DDCUTIL=1
      '';
    };
  };
}

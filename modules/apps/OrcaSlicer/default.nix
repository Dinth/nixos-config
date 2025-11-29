{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf mkOption;
  cfg = config.orcaslicer;
  primaryUsername = config.primaryUser.name;
in {
  options = {
    orcaslicer = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Orca slicer.";
      };
    };
  };
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername} = {
      home.packages = with pkgs; [
        orca-slicer # Slicer for 3d projects
      ];
      xdg.configFile."OrcaSlicer/user/default/filament" = {
        source = ./filament-profiles;
        recursive = true;
      };
      xdg.mimeApps.defaultApplications = {
        "x-scheme-handler/orcaslicer" = "OrcaSlicer.desktop";
        "x-scheme-handler/bambustudio" = "OrcaSlicer.desktop"; # makerworld
        "x-scheme-handler/prusaslicer" = "OrcaSlicer.desktop"; # printables
      };
    };
  };
}

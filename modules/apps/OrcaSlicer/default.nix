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
      networking.firewall = {
        allowedUDPPorts = [
          2021 # Bambu Printer Discovery
          1900 # SSDP
          5353 # mDNS / Avahi
        ];
      };
    home-manager.users.${primaryUsername} = {
      home.packages = with pkgs; [
        orca-slicer # Slicer for 3d projects
      ];
      xdg.configFile."OrcaSlicer/user/3210423684/filament" = {
        source = ./filament-profiles;
        recursive = true;
      };
      xdg.mimeApps = {
        defaultApplications = {
          # 1. 3D Model Formats
          "model/stl" = "OrcaSlicer.desktop";
          "model/3mf" = "OrcaSlicer.desktop";
          "application/vnd.ms-package.3dmanufacturing-3dmodel+xml" = "OrcaSlicer.desktop"; # Official 3MF mime
          "model/step" = "OrcaSlicer.desktop";
          "application/step" = "OrcaSlicer.desktop";
          "model/obj" = "OrcaSlicer.desktop";

          # 2. Machine Code
          "text/x-gcode" = "OrcaSlicer.desktop";

          # 3. URL Schemes
          "x-scheme-handler/orcaslicer" = "OrcaSlicer.desktop";
          "x-scheme-handler/bambustudio" = "OrcaSlicer.desktop"; # MakerWorld
          "x-scheme-handler/prusaslicer" = "OrcaSlicer.desktop"; # Printables
        };
      };
    };
  };
}

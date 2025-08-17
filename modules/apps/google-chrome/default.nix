{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.graphical;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    environment.etc."/opt/chrome/policies/enrollment/CloudManagementEnrollmentToken".source = config.age.secrets.chrome-enrolment.path;
    environment.etc."/opt/chrome/policies/enrollment/CloudManagementEnrollmentOptions".text = "Mandatory";
    environment.systemPackages = with pkgs; [
      google-chrome
    ];
    environment.sessionVariables.NO_AT_BRIDGE = "1";
    environment.etc."xdg/applications/google-chrome.desktop".source = ./google-chrome.desktop;
  };
}

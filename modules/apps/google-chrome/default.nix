{ config, lib, pkgs, machineType ? "", ... }:
let
  inherit (lib) mkIf;
  cfg = config.graphical;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      vdhcoapp
      google-chrome
    ] ++ lib.optionals (machineType == "tablet") [
      (google-chrome.override {
        commandLineArgs = "--enable-features=TouchpadOverscrollHistoryNavigation --enable-features=VaapiVideoDecoder --ozone-platform=wayland --enable-wayland-ime --touch-events=enabled --force-device-scale-factor=1.25 --enable-smooth-scrolling --enable-gpu-rasterization --enable-hardware-overlays --enable-zero-copy";
      })
    ];
    environment.etc."/opt/chrome/policies/enrollment/CloudManagementEnrollmentToken".source = config.age.secrets.chrome-enrolment.path;
    environment.etc."/opt/chrome/policies/enrollment/CloudManagementEnrollmentOptions".text = "Mandatory";
    environment.sessionVariables.NO_AT_BRIDGE = "1";
    environment.etc."xdg/applications/google-chrome.desktop".source = ./google-chrome.desktop;
  };
}

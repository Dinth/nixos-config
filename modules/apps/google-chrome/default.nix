{ config, lib, pkgs, machineType ? "", ... }:
let
  inherit (lib) mkIf;
  cfg = config.graphical;
  primaryUsername = config.primaryUser.name;

  chromePackage =
  if machineType == "tablet" then
    pkgs.google-chrome.override {
      commandLineArgs = "--enable-features=TouchpadOverscrollHistoryNavigation --enable-features=VaapiVideoDecoder --ozone-platform=wayland --enable-wayland-ime --enable-features=ScollableTabStrip --enable-features=ParallelDownloading --enable-gpu-rasterization --enable-zero-copy --touch-events=enabled --force-device-scale-factor=1.25 --enable-smooth-scrolling --enable-gpu-rasterization --enable-hardware-overlays --enable-zero-copy";
    }
  else
    pkgs.google-chrome;
in
{
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      vdhcoapp
      chromePackage
    ];
    environment.etc."/opt/chrome/policies/enrollment/CloudManagementEnrollmentToken".source = config.age.secrets.chrome-enrolment.path;
    environment.etc."/opt/chrome/policies/enrollment/CloudManagementEnrollmentOptions".text = "Mandatory";
    environment.sessionVariables.NO_AT_BRIDGE = "1";
    environment.etc."xdg/applications/google-chrome.desktop".source = ./google-chrome.desktop;
  };
}

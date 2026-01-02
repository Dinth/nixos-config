{ config, lib, pkgs, machineType ? "", ... }:
let
  inherit (lib) mkIf;
  cfg = config.graphical;
  primaryUsername = config.primaryUser.name;

  chromeFlags = if machineType == "tablet" then
    "--enable-features=TouchpadOverscrollHistoryNavigation,VaapiVideoDecoder,ScollableTabStrip,ParallelDownloading,GpuRasterization,ZeroCopy,SmoothScrolling,HardwareOverlays --ozone-platform=wayland --enable-wayland-ime --touch-events=enabled --force-device-scale-factor=1.25"
  else
    "";
  chromePackage = (pkgs.google-chrome.override {
      commandLineArgs = chromeFlags;
    }).overrideAttrs (old: {
      # Run this after the standard install to fix the desktop file
      postInstall = (old.postInstall or "") + ''
        if ! grep -q "StartupWMClass=" $out/share/applications/google-chrome.desktop; then
          echo "StartupWMClass=google-chrome" >> $out/share/applications/google-chrome.desktop
        fi
      '';
    });
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
  };
}

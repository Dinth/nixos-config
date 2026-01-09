{ config, lib, pkgs, machineType ? "", ... }:
let
  inherit (lib) mkIf;
  cfg = config.graphical;
  primaryUsername = config.primaryUser.name;
  baseFlags = [
    "--ozone-platform=wayland"
    "--enable-wayland-ime"
  ];
  tabletFlags = baseFlags ++ [
    "--enable-features=TouchpadOverscrollHistoryNavigation,SmoothScrolling"
    "--touch-events=enabled"
    "--force-device-scale-factor=1.25"
  ];
  desktopFlags = baseFlags ++ [
    "--enable-gpu-rasterization"
#   "--enable-zero-copy"
    "--ignore-gpu-blocklist"
    "--enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE,AcceleratedVideoEncoder"
  ];
  chromeFlags =
    if machineType == "tablet" then builtins.concatStringsSep " " tabletFlags
    else if machineType == "desktop" then builtins.concatStringsSep " " desktopFlags
    else "";

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
    environment.systemPackages = [
      pkgs.vdhcoapp
      chromePackage
    ];
    environment.etc."opt/chrome/native-messaging-hosts/net.downloadhelper.coapp.json".source =
      "${pkgs.vdhcoapp}/lib/mozilla/native-messaging-hosts/net.downloadhelper.coapp.json";
    environment.etc."/opt/chrome/policies/enrollment/CloudManagementEnrollmentToken".source = config.age.secrets.chrome-enrolment.path;
    environment.etc."/opt/chrome/policies/enrollment/CloudManagementEnrollmentOptions".text = "Mandatory";
    environment.sessionVariables.NO_AT_BRIDGE = "1";
  };
}

{
  config,
  lib,
  pkgs,
  machineType ? "",
  ...
}:
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
    "--enable-zero-copy"
    "--ignore-gpu-blocklist"
    "--enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE,VaapiVideoEncoder,CanvasOopRasterization,WebRTCPipeWireCapturer"
    "--force-color-profile=srgb"
  ];
  chromeFlags =
    if machineType == "tablet" then
      builtins.concatStringsSep " " tabletFlags
    else if machineType == "desktop" then
      builtins.concatStringsSep " " desktopFlags
    else
      "";
  extensionsPolicy = builtins.toJSON {
    PolicyListMultipleSourceMergeList = [ "ExtensionInstallForcelist" ];
    ExtensionInstallForcelist = [
      "lkbebcjgcmobigpeffafkodonchffocl;https://gitlab.com/magnolia1234/bypass-paywalls-chrome-clean/-/raw/master/updates.xml"
    ]
    ++ lib.optionals (config.kde.enable or false) [
      "cimiefiiaegbelhefglklhhakcgmhkai;https://clients2.google.com/service/update2/crx"
    ];
  };

  chromePackage =
    (pkgs.google-chrome.override {
      commandLineArgs = chromeFlags;
    }).overrideAttrs
      (old: {
        # Run this after the standard install to fix the desktop file
        # postInstall = (old.postInstall or "") + ''
        #   if ! grep -q "StartupWMClass=" $out/share/applications/google-chrome.desktop; then
        #     echo "StartupWMClass=google-chrome" >> $out/share/applications/google-chrome.desktop
        #   fi
        # '';
      });
in
{
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.vdhcoapp
      chromePackage
    ];
    environment.sessionVariables.NO_AT_BRIDGE = "1";
    environment.etc = {
      "opt/chrome/native-messaging-hosts/net.downloadhelper.coapp.json".source =
        "${pkgs.vdhcoapp}/lib/mozilla/native-messaging-hosts/net.downloadhelper.coapp.json";
      "/opt/chrome/policies/enrollment/CloudManagementEnrollmentToken".source =
        config.age.secrets.chrome-enrolment.path;
      "/opt/chrome/policies/enrollment/CloudManagementEnrollmentOptions".text = "Mandatory";
      "opt/chrome/policies/managed/extensions.json".text = extensionsPolicy;
    }
    // lib.optionalAttrs (config.kde.enable or false) {
      "opt/chrome/native-messaging-hosts/org.kde.plasma.browser_integration.json".source =
        "${pkgs.kdePackages.plasma-browser-integration}/etc/chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json";
    };
  };
}

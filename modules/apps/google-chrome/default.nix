{
  config,
  lib,
  pkgs,
  machineType ? "",
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.graphical;
  baseFlags = [
    "--ozone-platform=wayland"
    "--enable-wayland-ime"
  ];
  tabletFlags =
    baseFlags
    ++ [
      # VA-API decode via intel-media-driver — offloading video to the iGPU
      # is a battery win on the fanless tablet. Kept inside the single
      # --enable-features flag: Chrome doesn't merge repeated
      # --enable-features, the last one silently wins. The desktop's
      # Vulkan/ANGLE experiments are deliberately not carried over
      # (dGPU-oriented, unproven on Gen9 graphics).
      "--enable-features=TouchpadOverscrollHistoryNavigation,SmoothScrolling,VaapiVideoDecoder,VaapiIgnoreDriverChecks"
      "--touch-events=enabled"
      "--force-device-scale-factor=1.25"
    ];
  desktopFlags =
    baseFlags
    ++ [
      "--enable-gpu-rasterization"
      "--enable-zero-copy"
      "--ignore-gpu-blocklist"
      "--enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE,VaapiVideoEncoder,CanvasOopRasterization,WebRTCPipeWireCapturer"
      "--force-color-profile=srgb"
    ];
  chromeFlags =
    if machineType == "tablet"
    then builtins.concatStringsSep " " tabletFlags
    else if machineType == "desktop"
    then builtins.concatStringsSep " " desktopFlags
    else "";
  extensionsPolicy = builtins.toJSON {
    PolicyListMultipleSourceMergeList = ["ExtensionInstallForcelist"];
    ExtensionInstallForcelist =
      [
        "lkbebcjgcmobigpeffafkodonchffocl;https://gitlab.com/magnolia1234/bypass-paywalls-chrome-clean/-/raw/master/updates.xml"
      ]
      ++ lib.optionals (config.kde.enable or false) [
        "cimiefiiaegbelhefglklhhakcgmhkai;https://clients2.google.com/service/update2/crx"
      ];
  };

  # Chrome never touches the system hunspell dictionaries — it ships its own
  # .bdic files and downloads one per language enabled for spell check. Enabling
  # a language under Settings > Languages only adds it to accept_languages; the
  # spellcheck list is separate, which is why Polish text went unchecked.
  # SpellcheckLanguage force-enables both and triggers the pl bdic download.
  spellcheckPolicy = builtins.toJSON {
    SpellcheckEnabled = true;
    SpellcheckLanguage = ["en-GB" "pl"];
  };

  chromePackage = pkgs.google-chrome.override {
    commandLineArgs = chromeFlags;
  };
in {
  config = mkIf cfg.enable {
    environment.systemPackages = [
      chromePackage
    ];
    environment.sessionVariables.NO_AT_BRIDGE = "1";
    environment.etc =
      {
        "/opt/chrome/policies/enrollment/CloudManagementEnrollmentToken".source =
          config.age.secrets.chrome-enrolment.path;
        "/opt/chrome/policies/enrollment/CloudManagementEnrollmentOptions".text = "Mandatory";
        "opt/chrome/policies/managed/extensions.json".text = extensionsPolicy;
        "opt/chrome/policies/managed/spellcheck.json".text = spellcheckPolicy;
      }
      // lib.optionalAttrs (config.kde.enable or false) {
        "opt/chrome/native-messaging-hosts/org.kde.plasma.browser_integration.json".source = "${pkgs.kdePackages.plasma-browser-integration}/etc/chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json";
      };
  };
}

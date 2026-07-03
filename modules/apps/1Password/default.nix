{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption mkMerge;
  cfg = config._1password;
  primaryUsername = config.primaryUser.name;

  # Native-messaging host manifest for the browser ↔ desktop-app bridge.
  # 1Password writes this into each browser's *user-profile* dir, but only when
  # the desktop app launches (~/.config/google-chrome/NativeMessagingHosts/).
  # That user-level file is fragile: a Chrome first-run-after-upgrade migration
  # racing the login-time write can wipe it once, and 1Password won't recreate
  # it until its next launch — leaving Chrome with no host to start. Installing
  # it system-wide under /etc (root-owned, in the Nix store) is the canonical
  # packaged location Chrome reads and never touches, so the channel survives
  # regardless of user-profile races. `path` is the setgid wrapper created by
  # programs._1password-gui's security.wrappers entry.
  nmhManifest = builtins.toJSON {
    name = "com.1password.1password";
    description = "1Password BrowserSupport";
    path = "/run/wrappers/bin/1Password-BrowserSupport";
    type = "stdio";
    allowed_origins = [
      "chrome-extension://hjlinigoblmkhjejkmbegnoaljkphmgo/"
      "chrome-extension://bkpbhnjcbehoklfkljkkbbmipaphipgl/"
      "chrome-extension://gejiddohjgogedgjnonbofjigllpkmbf/"
      "chrome-extension://khgocmkkpikpnmmkgmdnfckapcdkgfaf/"
      "chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/"
      "chrome-extension://dppgmdbiimibapkepcbdbmkaabgiofem/"
    ];
  };
in {
  options = {
    _1password = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable 1Password CLI and GUI (GUI requires graphical.enable)";
      };
    };
  };
  config = mkMerge [
    (mkIf cfg.enable {
      programs._1password.enable = true;
    })
    (mkIf (cfg.enable && config.graphical.enable) {
      programs._1password-gui.enable = true;
      programs._1password-gui.polkitPolicyOwners = [primaryUsername];

      # System-wide native-messaging manifests (Chrome + Chromium read these
      # in addition to the per-profile dir; these are immune to the race above).
      environment.etc."opt/chrome/native-messaging-hosts/com.1password.1password.json".text = nmhManifest;
      environment.etc."chromium/native-messaging-hosts/com.1password.1password.json".text = nmhManifest;

      home-manager.users.${primaryUsername} = {
        home.file.".config/autostart/1password.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=1Password
          Exec=${pkgs._1password-gui}/bin/1password --silent
          Icon=1password
          Terminal=false
          StartupNotify=false
        '';
      };
    })
  ];
}

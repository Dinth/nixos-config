{config, ...}: let
  primaryUsername = config.primaryUser.name;
in {
  # Only imported on macOS (see modules/system/default.nix).

  # nix-darwin applies user-scoped settings (system.defaults, homebrew, ...)
  # as this user now that darwin-rebuild itself runs as root.
  system.primaryUser = primaryUsername;

  # The account is created by Mosyle during enrolment, not by nix-darwin:
  # leave it out of users.knownUsers so nix-darwin never touches its UID,
  # shell or groups, and only tell Home Manager where the home directory is.
  users.users.${primaryUsername} = {
    home = "/Users/${primaryUsername}";
    # Rendered by nix-darwin into /etc/ssh/nix_authorized_keys.d/, which its
    # sshd drop-in adds as an AuthorizedKeysFile (see modules/services/ssh).
    openssh.authorizedKeys.keys = config.primaryUser.publicKeys;
  };

  # agenix decrypts with the shared Mac fleet key (recipient `mac-fleet` in
  # secrets/secrets.nix), not the SSH host key: host keys are per machine, so
  # every new or re-imaged Mac would need a rekey. Mosyle writes this file
  # (root:wheel 0400) before the nix-darwin bootstrap runs.
  age.identityPaths = ["/etc/agenix/mac-fleet.key"];

  # Nix GUI apps are copied (not symlinked) into ~/Applications/Home Manager
  # Apps so Spotlight indexes them and the Dock can pin them. This is HM's
  # default from stateVersion 25.11; spelled out so nobody adds mac-app-util.
  # nix-darwin does the same for system packages in /Applications/Nix Apps.
  home-manager.users.${primaryUsername} = {
    targets.darwin.copyApps.enable = true;
    # system.defaults.screencapture.location below must exist, or macOS
    # silently falls back to the Desktop.
    home.file."Pictures/Screenshots/.keep".text = "";
  };

  # macOS preferences. These replace six Mosyle "custom profiles" that were
  # bare .plist files and failed to install (DSDontWriteNetworkStores,
  # NSAutomaticQuoteSubstitutionEnabled, RichText, Finder, ScrollbackLines,
  # CBBlueLightReductionCCT); the first four are covered below. Settings
  # pushed by Mosyle profiles still win over anything written here.
  system.defaults = {
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      # Hold a key to repeat it rather than to pick an accented variant.
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      # The top row sends F1–F12 (Fn for brightness/volume), since mc and the
      # mcedit-style neovim are driven by F2 Save ... F10 Quit. Takes effect
      # after logging out and back in.
      "com.apple.keyboard.fnState" = true;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      # Matches the Catppuccin Mocha theme used everywhere else.
      AppleInterfaceStyle = "Dark";
      # Open Save and Print dialogs fully expanded.
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
    };
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "Nlsv"; # list view
      FXEnableExtensionChangeWarning = false;
      _FXSortFoldersFirst = true;
      FXDefaultSearchScope = "SCcf"; # search the current folder
      AppleShowAllFiles = true; # dotfiles visible, like Dolphin here
      _FXShowPosixPathInTitle = true;
    };
    loginwindow.GuestEnabled = false;
    menuExtraClock = {
      Show24Hour = true;
      ShowDate = 1; # always
    };
    controlcenter.BatteryShowPercentage = true;
    trackpad.Clicking = true; # tap to click
    dock = {
      autohide = true;
      show-recents = false;
      # Keep Spaces in a fixed order instead of by most recent use.
      mru-spaces = false;
    };
    screencapture = {
      location = "~/Pictures/Screenshots";
      type = "png";
    };
    CustomUserPreferences = {
      # No .DS_Store litter on SMB/NFS shares (the NAS) or USB drives.
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      # TextEdit opens new documents as plain text.
      "com.apple.TextEdit".RichText = false;
    };
  };

  # The desktop runs a firewall; the Mac's was off (per Mosyle). Apple-signed
  # services (sshd, AirDrop...) and properly signed apps may still accept
  # connections; stealth mode ignores pings and probes to closed ports. The
  # Nix-built tailscaled is only ad-hoc signed, so modules/services/tailscale
  # allow-lists it explicitly.
  networking.applicationFirewall = {
    enable = true;
    enableStealthMode = true;
    allowSigned = true;
    allowSignedApp = true;
  };

  # macOS counterpart of the desktop's YubiKey touch for doas: Touch ID for
  # sudo, falling back to the password. Written to
  # /etc/pam.d/sudo_local, which survives macOS updates. reattach lets it work
  # inside tmux/screen.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  # Settings pushed as Mosyle configuration profiles live in
  # /Library/Managed Preferences and override anything system.defaults writes;
  # leave security/compliance (FileVault, firewall, screen lock, updates) to
  # the MDM and keep system.defaults to personal preferences.
}

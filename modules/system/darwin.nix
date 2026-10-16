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

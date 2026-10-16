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
  users.users.${primaryUsername}.home = "/Users/${primaryUsername}";

  # Settings pushed as Mosyle configuration profiles live in
  # /Library/Managed Preferences and override anything system.defaults writes;
  # leave security/compliance (FileVault, firewall, screen lock, updates) to
  # the MDM and keep system.defaults to personal preferences.
}

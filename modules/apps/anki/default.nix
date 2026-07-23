{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.kde;
  primaryUsername = config.primaryUser.name;
in {
  # Anki rides the kde.enable toggle, so it lands on the desktop and tablet but
  # not the headless server -- the same gate dictionaries.nix and the input
  # method use, and a flashcard app is only useful where there's a screen.
  #
  # anki-bin, not anki: the source build is a large Rust + Python + web-bundle
  # compile with no cache hit, and the rolling `nh os switch -u` workflow would
  # pay that on every rebuild. anki-bin is the upstream prebuilt and is in the
  # binary cache, so it's a download rather than a build.
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername}.home.packages = [pkgs.anki-bin];
  };
}

{
  lib,
  isDarwin,
  ...
}: {
  # nix-darwin doesn't declare NixOS-only options (systemd, boot, udev, ...),
  # and `mkIf false` doesn't hide a definition of an undeclared option, so
  # Linux-only modules must not be imported on macOS at all. isDarwin is a
  # specialArg, so it's safe to branch on here (pkgs/config would recurse).
  imports =
    [
      ./apps
      ./system
    ]
    ++ lib.optionals (!isDarwin) [
      ./hardware
      ./services
    ];
}

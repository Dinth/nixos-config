{
  lib,
  isDarwin,
  ...
}: {
  imports =
    [
      ./cli.nix
      ./gaming
      ./graphical.nix
      ./locale.nix
      ./nix.nix
      ./theme.nix
    ]
    ++ lib.optionals isDarwin [
      ./darwin.nix
    ]
    ++ lib.optionals (!isDarwin) [
      ./dictionaries.nix
      ./docker.nix
      ./input-method.nix
      ./kde.nix
      ./networking.nix
      ./security.nix
      ./virtualisation
    ];
}

{
  lib,
  isDarwin,
  ...
}: {
  imports =
    [
      ./cli.nix
      ./nix.nix
      ./theme.nix
    ]
    ++ lib.optionals isDarwin [
      ./darwin.nix
    ]
    ++ lib.optionals (!isDarwin) [
      ./dictionaries.nix
      ./docker.nix
      ./gaming
      ./graphical.nix
      ./input-method.nix
      ./locale.nix
      ./kde.nix
      ./networking.nix
      ./security.nix
      ./virtualisation
    ];
}

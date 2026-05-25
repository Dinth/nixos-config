{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./agent-permissions.nix
    ./users.nix
  ];
}

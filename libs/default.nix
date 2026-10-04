{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./agent-permissions.nix
    ./network.nix
    ./users.nix
  ];
}

{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./komodo-periphery
    ./network-mounts
    ./ssh
    ./tailscale
  ];
}

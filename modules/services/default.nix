{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./komodo-periphery
    ./network-mounts
    ./prometheus-exporters
    ./ssh
    ./tailscale
  ];
}

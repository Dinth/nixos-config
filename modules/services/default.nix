{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./alloy
    ./komodo-periphery
    ./network-mounts
    ./prometheus-exporters
    ./ssh
    ./tailscale
    ./wazuh-agent
  ];
}

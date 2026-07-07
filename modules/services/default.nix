{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./alloy
    ./komodo-periphery
    ./krdp
    ./network-mounts
    ./prometheus-exporters
    ./ssh
    ./tailscale
    ./wazuh-agent
  ];
}

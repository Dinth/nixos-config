{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./alloy
    ./komodo-periphery
    ./krdp
    ./llama-cpp
    ./network-mounts
    ./prometheus-exporters
    ./ssh
    ./tailscale
    ./wazuh-agent
  ];
}

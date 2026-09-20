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
    ./sillybunny
    ./ssh
    ./stable-diffusion
    ./tailscale
    ./wazuh-agent
  ];
}

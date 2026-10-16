{
  lib,
  isDarwin,
  ...
}: {
  imports =
    [
      ./ssh
    ]
    # Linux-only: systemd units, journald, NixOS-only service modules.
    ++ lib.optionals (!isDarwin) [
      ./alloy
      ./komodo-periphery
      ./krdp
      ./llama-cpp
      ./network-mounts
      ./prometheus-exporters
      ./sillybunny
      ./stable-diffusion
      ./tailscale
      ./wazuh-agent
    ];
}

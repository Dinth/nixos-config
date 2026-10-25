{
  lib,
  isDarwin,
  ...
}: {
  imports =
    [
      ./ssh
      ./tailscale
    ]
    # Linux-only: systemd units, journald, NixOS-only service modules.
    ++ lib.optionals (!isDarwin) [
      ./alloy
      ./komodo-periphery
      ./krdp
      ./languagetool
      ./llama-cpp
      ./network-mounts
      ./prometheus-exporters
      ./sillybunny
      ./stable-diffusion
      ./wazuh-agent
    ];
}

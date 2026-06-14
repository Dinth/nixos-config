{
  config,
  lib,
  pkgs,
  ...
}: {
  networking.firewall = {
    enable = true;
    allowPing = true;
    logRefusedPackets = true;
  };

  # mDNS only where there's a desktop to benefit from discovery / .local
  # resolution. The feature ports that used to be opened globally here are
  # owned by the modules that need them, each gated by its own enable:
  #   - KDE Connect 1714-1764 → programs.kdeconnect (modules/system/kde.nix)
  #   - SSDP 1900 / Bambu 2021 / mDNS 5353 → orcaslicer (modules/apps/OrcaSlicer)
  # 8883 (MQTT-TLS) was dropped: no host runs a broker — lnxlink/HA are
  # outbound clients, so nothing ever listened on it.
  services.avahi = lib.mkIf config.graphical.enable {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}

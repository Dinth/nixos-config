{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.krdp;

  # KRDP is KDE's native Wayland RDP server (kcm_krdpserver + krdpserver,
  # shipped with Plasma 6). It shares the *live* Plasma session, so a
  # remote RDP client drives the same desktop shown on the physical
  # monitor — the "take over my logged-in session" behaviour.
  #
  # Only the firewall is declarative here. The enable flag, RDP
  # username/password (KWallet) and the auto-generated TLS certificate
  # are per-user runtime state configured once in
  # System Settings → Remote Desktop.
  #
  # Firewall scoping mirrors prometheus-exporters: `extraCommands`
  # (iptables) is the active backend today (networking.nftables.enable =
  # false); `extraInputRules` is the nftables equivalent, a silent no-op
  # on iptables hosts, kept for the eventual migration.
  iptablesStart =
    lib.concatMapStrings (ip: ''
      iptables -A nixos-fw -s ${ip} -p tcp --dport ${toString cfg.port} -j nixos-fw-accept
    '')
    cfg.allowFrom;
  iptablesStop =
    lib.concatMapStrings (ip: ''
      iptables -D nixos-fw -s ${ip} -p tcp --dport ${toString cfg.port} -j nixos-fw-accept || true
    '')
    cfg.allowFrom;
  nftablesRule =
    lib.concatMapStrings (ip: ''
      ip saddr ${ip} tcp dport ${toString cfg.port} accept
    '')
    cfg.allowFrom;
in {
  options.krdp = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the KDE RDP server (KRDP) and open its port to allowFrom.";
    };

    port = mkOption {
      type = lib.types.port;
      default = 3389;
      description = "TCP port KRDP listens on. Must match the port set in System Settings → Remote Desktop.";
    };

    allowFrom = mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["10.10.0.0/16"];
      example = ["10.10.10.0/24"];
      description = "Source CIDRs/IPs allowed to reach the KRDP port. Defaults to the LAN.";
    };
  };

  config = mkIf cfg.enable {
    # krdpserver + kcm_krdpserver ship with Plasma 6, but pull the package
    # in explicitly so the module is self-contained.
    environment.systemPackages = [pkgs.kdePackages.krdp];

    networking.firewall = {
      extraCommands = iptablesStart;
      extraStopCommands = iptablesStop;
      extraInputRules = nftablesRule;
    };
  };
}

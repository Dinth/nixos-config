{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.krdp;
  primaryUsername = config.primaryUser.name;
  homeDir = "/home/${primaryUsername}";
  certDir = "${homeDir}/.local/share/krdpserver";
  certFile = "${certDir}/krdp.crt";
  certKeyFile = "${certDir}/krdp.key";

  # KRDP is KDE's native Wayland RDP server (kcm_krdpserver + krdpserver,
  # shipped with Plasma 6). It shares the *live* Plasma session, so a
  # remote RDP client drives the same desktop shown on the physical
  # monitor — the "take over my logged-in session" behaviour.
  #
  # This module makes the whole thing declarative. KRDP normally keeps its
  # state in three imperative places, all reproduced here:
  #   1. ~/.config/krdpserverrc  — plain INI, written via plasma-manager.
  #   2. the TLS certificate     — generated once by krdp-provision (openssl).
  #   3. the RDP login password  — lives in KWallet, NOT in any file. It is
  #      seeded into KWallet by krdp-provision from a ragenix secret.
  #
  # KWallet layout that krdpserver reads (via qtkeychain): wallet "kdewallet",
  # folder = the qtkeychain service = "KRDP", entry = the RDP username, stored
  # as a Password-type entry. We reproduce that exact layout over the
  # org.kde.KWallet DBus API (kwallet-query writes the wrong entry type, so
  # writePassword must be used).
  #
  # Firewall scoping mirrors prometheus-exporters: `extraCommands` (iptables)
  # is the active backend today (networking.nftables.enable = false);
  # `extraInputRules` is the nftables equivalent, a silent no-op on iptables
  # hosts, kept for the eventual migration.
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

  # Generates the self-signed TLS cert once, then mirrors the ragenix RDP
  # password into KWallet where krdpserver looks for it. Idempotent: the cert
  # is only (re)made when missing, and the wallet write overwrites in place.
  provision = pkgs.writeShellApplication {
    name = "krdp-provision";
    runtimeInputs = [pkgs.kdePackages.qttools pkgs.openssl pkgs.coreutils];
    text = ''
      dir=${lib.escapeShellArg certDir}

      # 1. TLS certificate — self-signed, per-host, 10 years.
      mkdir -p "$dir"
      if [ ! -s ${lib.escapeShellArg certFile} ] || [ ! -s ${lib.escapeShellArg certKeyFile} ]; then
        openssl req -newkey rsa:2048 -nodes \
          -keyout ${lib.escapeShellArg certKeyFile} \
          -x509 -days 3650 -out ${lib.escapeShellArg certFile} \
          -subj "/CN=${config.networking.hostName}"
        chmod 600 ${lib.escapeShellArg certKeyFile}
      fi

      # 2. RDP password → KWallet (wallet "kdewallet", folder "KRDP",
      #    entry = username, Password type). Needs the wallet unlocked, which
      #    it is once the Plasma session is up (pam_kwallet).
      if [ ! -r ${lib.escapeShellArg cfg.passwordFile} ]; then
        echo "krdp-provision: password file ${cfg.passwordFile} not readable; is the ragenix secret deployed?" >&2
        exit 1
      fi
      pass=$(cat ${lib.escapeShellArg cfg.passwordFile})

      svc=org.kde.kwalletd6
      obj=/modules/kwalletd6
      iface=org.kde.KWallet
      handle=$(qdbus "$svc" "$obj" "$iface".open kdewallet 0 KRDP)
      if [ -z "$handle" ] || [ "$handle" -le 0 ] 2>/dev/null; then
        echo "krdp-provision: could not open kdewallet (locked?); got handle '$handle'" >&2
        exit 1
      fi
      qdbus "$svc" "$obj" "$iface".createFolder "$handle" KRDP KRDP >/dev/null
      qdbus "$svc" "$obj" "$iface".writePassword \
        "$handle" KRDP ${lib.escapeShellArg cfg.username} "$pass" KRDP >/dev/null
      echo "krdp-provision: seeded RDP password for user ${cfg.username}"
    '';
  };
in {
  options.krdp = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the KDE RDP server (KRDP), fully declarative including cert and KWallet password.";
    };

    port = mkOption {
      type = lib.types.port;
      default = 3389;
      description = "TCP port KRDP listens on.";
    };

    allowFrom = mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["10.10.0.0/16"];
      example = ["10.10.10.0/24"];
      description = "Source CIDRs/IPs allowed to reach the KRDP port. Defaults to the LAN.";
    };

    username = mkOption {
      type = lib.types.str;
      default = config.primaryUser.name;
      description = "RDP login username. Independent of the Linux user; must match the KWallet entry seeded from passwordFile.";
    };

    passwordFile = mkOption {
      type = lib.types.str;
      default = config.age.secrets.krdp-password.path;
      description = "Path to a file holding the RDP password in plaintext (a ragenix secret), seeded into KWallet at login.";
    };
  };

  config = mkIf cfg.enable {
    # krdpserver + kcm_krdpserver ship with Plasma 6, but pull the package
    # in explicitly so the module is self-contained.
    environment.systemPackages = [pkgs.kdePackages.krdp];

    # ragenix secret holding the RDP password. Declared here (not in
    # secrets/deployment.nix) so the whole feature is co-located and only
    # deployed where krdp is enabled. Recipient list lives in secrets.nix.
    age.secrets.krdp-password = {
      file = ../../../secrets/krdp-password.age;
      owner = primaryUsername;
      group = "users";
      mode = "0400";
    };

    networking.firewall = {
      extraCommands = iptablesStart;
      extraStopCommands = iptablesStop;
      extraInputRules = nftablesRule;
    };

    home-manager.users.${primaryUsername} = {
      # Declarative krdpserverrc. plasma-manager runs with overrideConfig, so
      # every key krdpserver needs is asserted here.
      programs.plasma.configFile."krdpserverrc"."General" = {
        Autostart = true;
        ListenPort = cfg.port;
        Quality = 75;
        Users = cfg.username;
        AutogenerateCertificates = false;
        Certificate = certFile;
        CertificateKey = certKeyFile;
        SystemUserEnabled = false;
      };

      # Generate the cert and seed the KWallet password before the server
      # starts. RemainAfterExit so a booted session shows its success/failure.
      systemd.user.services.krdp-provision = {
        Unit = {
          Description = "Provision KRDP TLS cert and seed RDP password into KWallet";
          After = ["graphical-session.target"];
          PartOf = ["graphical-session.target"];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = lib.getExe provision;
        };
        Install.WantedBy = ["plasma-workspace.target"];
      };

      # Override the vendor unit (shipped disabled by preset) so it is enabled
      # declaratively and ordered after provisioning — the cert must exist and
      # the wallet must be seeded before krdpserver starts.
      systemd.user.services."app-org.kde.krdpserver" = {
        Unit = {
          Description = "KRDP Server";
          After = [
            "plasma-xdg-desktop-portal-kde.service"
            "plasma-core.target"
            "krdp-provision.service"
          ];
          Requires = ["krdp-provision.service"];
        };
        Service = {
          Type = "exec";
          ExecStart = lib.getExe' pkgs.kdePackages.krdp "krdpserver";
          Restart = "on-abnormal";
        };
        Install.WantedBy = ["plasma-workspace.target"];
      };
    };
  };
}

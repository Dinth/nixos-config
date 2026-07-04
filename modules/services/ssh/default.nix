{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.ssh;
in {
  options = {
    ssh = {
      enable = mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SSH server";
      };
    };
  };
  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        X11Forwarding = false;
        MaxAuthTries = 3;
        LoginGraceTime = 30;
        AllowUsers = [config.primaryUser.name];
        # Make the publickey-only posture explicit so it survives any future
        # change to upstream defaults.
        AuthenticationMethods = "publickey";
        # Reap hung/idle sessions: 2 missed 300s probes → disconnect.
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;
        # Modern crypto only — drop legacy CBC/SHA1 primitives.
        KexAlgorithms = [
          "sntrup761x25519-sha512@openssh.com"
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
        ];
        Ciphers = [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
        ];
        Macs = [
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
          "umac-128-etm@openssh.com"
        ];
      };
    };
    services.fail2ban = {
      enable = true;
      # Raised from 3 → 5: a flapping key (e.g. YubiKey replug, agent
      # restart) easily burns 3 retries from a trusted device.
      maxretry = 5;
      bantime = "10m";
      bantime-increment = {
        enable = true;
        maxtime = "48h";
      };
      # Don't lock ourselves out over the LAN / tailnet.
      ignoreIP = [
        "127.0.0.0/8"
        "10.10.0.0/16"
        "100.64.0.0/10"
      ];
    };
  };
}

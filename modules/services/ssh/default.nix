{
  config,
  lib,
  isDarwin,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.ssh;

  # Shared sshd hardening. NixOS takes it as services.openssh.settings; on
  # macOS it's rendered into Apple's sshd_config.d drop-in.
  sshdSettings = {
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

  # sshd_config syntax: booleans are yes/no, AllowUsers is space-separated,
  # algorithm lists are comma-separated.
  renderValue = name: value:
    if builtins.isBool value
    then
      (
        if value
        then "yes"
        else "no"
      )
    else if builtins.isList value
    then
      lib.concatStringsSep (
        if name == "AllowUsers"
        then " "
        else ","
      )
      value
    else toString value;
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
  config = mkIf cfg.enable (lib.mkMerge [
    (lib.optionalAttrs isDarwin {
      # Turns on Remote Login (Apple's sshd) and drops the hardening in
      # /etc/ssh/sshd_config.d/. Authorized keys: modules/system/darwin.nix.
      services.openssh = {
        enable = true;
        extraConfig = lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${n} ${renderValue n v}") sshdSettings);
      };
    })

    (lib.optionalAttrs (!isDarwin) {
      services.openssh = {
        enable = true;
        settings = sshdSettings;
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
        # Don't lock ourselves out — but only from where we actually SSH from:
        # workstations and the tailnet. SSH flows workstation → server here,
        # never the other way, so servers/network gear aren't whitelisted. The
        # old blanket 10.10.0.0/16 also covered IoT (10.10.25.0/24) and CCTV
        # (10.10.30.0/24), i.e. the devices most likely to be compromised and
        # used to brute-force SSH. Workstation subnets come from the shared
        # list: this one used to hard-code 10.10.10.0/24 only, so the desktop's
        # move to 10.40.0.0/24 left it bannable by its own key retries.
        ignoreIP =
          ["127.0.0.0/8"]
          ++ config.homeNetwork.workstationSubnets
          ++ ["100.64.0.0/10"]; # tailnet
      };
    })
  ]);
}

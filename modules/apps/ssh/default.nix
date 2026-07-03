{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in {
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername}.programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "r230-nixos r230 10.10.1.12" = {
          HostName = "10.10.1.12";
          User = "michal";
          IdentityFile = [config.age.secrets."id-ed25519".path];
          IdentitiesOnly = true;
        };
        "r230-proxmox proxmox 10.10.1.16" = {
          HostName = "10.10.1.16";
          User = "dinth";
          IdentityFile = [config.age.secrets."id-ed25519".path];
          IdentitiesOnly = true;
        };
        "wazuh wazuh-server 10.10.1.18" = {
          HostName = "10.10.1.18";
          User = "wazuh-user";
          IdentityFile = [config.age.secrets."id-ed25519".path];
          IdentitiesOnly = true;
        };
        "10.10.0.20 dell-switch" = {
          HostName = "10.10.0.20";
          User = "admin";
          KexAlgorithms = "+diffie-hellman-group-exchange-sha1,diffie-hellman-group1-sha1";
          HostKeyAlgorithms = "+ssh-rsa";
          PubkeyAcceptedAlgorithms = "+ssh-rsa";
          Ciphers = "+aes128-cbc,3des-cbc";
          MACs = "+hmac-sha1";
        };
        "*" = {
          IdentityFile = [
            config.age.secrets."id-ed25519".path
            config.age.secrets."id-ed25519-sk-rk-2".path
            config.age.secrets."id-ed25519-sk-rk-1".path
            config.age.secrets."id-ed25519-sk-rk-3".path
          ];
          IdentitiesOnly = true;

          # Connection multiplexing: the first connection to a host opens a
          # master socket; subsequent ssh/scp/rsync/git-over-ssh to the same
          # host reuse it — near-instant, and a hardware key (sk-rk-*) is
          # touched once per host instead of once per connection. %C is the
          # hashed conn tuple, keeping the socket path short (Unix sockets cap
          # at ~108 chars, which long user@host:port paths can overflow).
          ControlMaster = "auto";
          ControlPath = "~/.ssh/master-%C";
          ControlPersist = "5m";

          # Drop dead sessions cleanly on a network blip and keep NAT/firewall
          # state warm so idle tabs don't freeze.
          ServerAliveInterval = 60;
          ServerAliveCountMax = 3;

          # Add keys to the agent on first use (no repeat passphrase prompts)
          # and hash host names/IPs in known_hosts.
          AddKeysToAgent = "yes";
          HashKnownHosts = "yes";
        };
      };
    };
  };
}

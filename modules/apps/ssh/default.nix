{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
  hmConfig = config.home-manager.users.${primaryUsername};

  # macOS: loads id-ed25519 into the Home Manager ssh-agent, with the
  # passphrase read from its ragenix secret (the same SSH_ASKPASS trick as the
  # desktop's sshfs mounts), so ssh never has to ask for it. Idempotent: it
  # exits early when the agent already holds the key.
  sshAskpass = pkgs.writeShellScript "ssh-askpass-id-ed25519" ''
    exec ${pkgs.coreutils}/bin/cat ${config.age.secrets.id-ed25519-passphrase.path}
  '';
  sshAddKey = pkgs.writeShellApplication {
    name = "ssh-add-id-ed25519";
    runtimeInputs = [hmConfig.services.ssh-agent.package pkgs.coreutils pkgs.gawk pkgs.gnugrep];
    text = ''
      key=${config.age.secrets."id-ed25519".path}
      SSH_AUTH_SOCK="$(${lib.getExe pkgs.getconf} DARWIN_USER_TEMP_DIR)/${hmConfig.services.ssh-agent.socket}"
      export SSH_AUTH_SOCK

      # Right after login the agent may not be listening yet, and the secret
      # is decrypted by a launchd daemon that may still be running.
      for _ in $(seq 60); do
        [ -S "$SSH_AUTH_SOCK" ] && [ -r "$key" ] && break
        sleep 1
      done
      [ -r "$key" ] || {
        echo "$(date '+%F %T') $key isn't readable (secrets not decrypted?)"
        exit 1
      }

      # ssh-keygen -l reads the public half without the passphrase.
      fingerprint=$(ssh-keygen -l -f "$key" | awk '{print $2}')
      if ssh-add -l 2>/dev/null | grep -qF "$fingerprint"; then
        exit 0
      fi
      SSH_ASKPASS=${sshAskpass} SSH_ASKPASS_REQUIRE=force ssh-add -q "$key" </dev/null
      echo "$(date '+%F %T') added $key"
    '';
  };
in {
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername} = lib.mkMerge [
      (lib.optionalAttrs isDarwin {
        # Apple's /usr/bin/ssh and ssh-agent are built without FIDO2 support,
        # so the YubiKey (sk-rk) keys below only work with nixpkgs' OpenSSH.
        # Installing it here puts ssh, ssh-add and ssh-keygen ahead of
        # /usr/bin on PATH.
        programs.ssh.package = pkgs.openssh;
        # Its agent, as a launchd user agent; Home Manager points
        # SSH_AUTH_SOCK at it in zsh (keeping a forwarded agent over SSH).
        services.ssh-agent.enable = true;
        launchd.agents.ssh-add-id-ed25519 = {
          enable = true;
          config = {
            ProgramArguments = [(lib.getExe sshAddKey)];
            RunAtLoad = true;
            # Re-adds the key after the agent restarts (e.g. on a switch).
            StartInterval = 600;
            ProcessType = "Background";
            StandardOutPath = "${config.users.users.${primaryUsername}.home}/Library/Logs/ssh-add-id-ed25519.log";
            StandardErrorPath = "${config.users.users.${primaryUsername}.home}/Library/Logs/ssh-add-id-ed25519.log";
          };
        };
      })

      {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          settings = {
            "r230-nixos r230 10.10.1.12" = {
              HostName = "10.10.1.12";
              # r230's login user is the same repo-defined primary user as here.
              User = primaryUsername;
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
      }
    ];
  };
}

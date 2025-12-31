{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername}.programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "*" = {
          identityFile = [
            "~/.ssh/id_ed25519_sk_rk_1"
            "~/.ssh/id_ed25519_sk_rk_2"
            "~/.ssh/id_ed25519_sk_rk_3"
          ];
          identitiesOnly = true;
          # Optional: Add any other defaults you want from the old defaults
          # forwardAgent = false;
          # addKeysToAgent = "no";
          # compression = false;
          # serverAliveInterval = 0;
          # serverAliveCountMax = 3;
          # hashKnownHosts = false;
          # userKnownHostsFile = "~/.ssh/known_hosts";
          # controlMaster = "no";
          # controlPath = "~/.ssh/master-%r@%n:%p";
          # controlPersist = "no";
        };
      };
    };
  };
}

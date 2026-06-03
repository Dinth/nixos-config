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
      matchBlocks = {
        "r230-nixos r230 10.10.1.12" = {
          hostname = "10.10.1.12";
          user = "michal";
          identityFile = [config.age.secrets."id-ed25519".path];
          identitiesOnly = true;
        };
        "wazuh wazuh-server 10.10.1.18" = {
          hostname = "10.10.1.18";
          user = "wazuh-user";
          identityFile = [config.age.secrets."id-ed25519".path];
          identitiesOnly = true;
        };
        "10.10.0.20 dell-switch" = {
          hostname = "10.10.0.20";
          user = "admin";
          extraOptions = {
            KexAlgorithms = "+diffie-hellman-group-exchange-sha1,diffie-hellman-group1-sha1";
            HostKeyAlgorithms = "+ssh-rsa";
            PubkeyAcceptedAlgorithms = "+ssh-rsa";
            Ciphers = "+aes128-cbc,3des-cbc";
            MACs = "+hmac-sha1";
          };
        };
        "*" = {
          identityFile = [
            config.age.secrets."id-ed25519".path
            config.age.secrets."id-ed25519-sk-rk-2".path
            config.age.secrets."id-ed25519-sk-rk-1".path
            config.age.secrets."id-ed25519-sk-rk-3".path
          ];
          identitiesOnly = true;
        };
      };
    };
  };
}

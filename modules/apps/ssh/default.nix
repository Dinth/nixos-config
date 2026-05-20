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

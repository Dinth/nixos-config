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
      matchBlocks = {
        "*" = {
          identityFile = [
            "~/.ssh/id_ed25519_sk_rk_1"
            "~/.ssh/id_ed25519_sk_rk_2"
            "~/.ssh/id_ed25519_sk_rk_3"
          ];
          identitiesOnly = true;
        };
      };
    };

  };
}

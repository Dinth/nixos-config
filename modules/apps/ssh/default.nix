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
        "r230-nixos r230 10.10.1.12" = {
          hostname = "10.10.1.12";
          user = "michal";
          identityFile = [ "~/.ssh/id_ed25519" ];
          identitiesOnly = true;
        };
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

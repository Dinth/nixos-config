{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
in
{
  cfg = mkIf cfg.enable {
    programs.ssh = {
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

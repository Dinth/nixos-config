{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
in
{
  cfg = mkIf cfg.enable {
    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}

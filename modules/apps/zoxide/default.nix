{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername} = {
      home.sessionVariables.ZO_EXCLUDE_DIRS = ".git:node_modules:.venv:__pycache__:result:/nix/store";
      programs.zoxide = {
        enable = true;
        enableZshIntegration = true;
      };
    };
  };
}

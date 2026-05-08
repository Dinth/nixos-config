{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkAfter;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in {
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername} = {
      home.sessionVariables.ZO_EXCLUDE_DIRS = ".git:node_modules:.venv:__pycache__:result:/nix/store";
      programs.zoxide = {
        enable = true;
        enableZshIntegration = true;
      };
      # HM inits zoxide at order 851 and starship at 1000, so starship_chpwd
      # ends up appended to chpwd_functions after __zoxide_hook and zoxide
      # warns that it wasn't initialized last. Re-pin __zoxide_hook to the
      # end of chpwd_functions after both integrations have run.
      programs.zsh.initContent = mkAfter ''
        if (( ''${+chpwd_functions} )) && (( ''${chpwd_functions[(I)__zoxide_hook]} )); then
          chpwd_functions=(''${chpwd_functions:#__zoxide_hook} __zoxide_hook)
        fi
      '';
    };
  };
}

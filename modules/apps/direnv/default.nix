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
    home-manager.users.${primaryUsername}.programs.direnv = {
      enable = true;
      # nix-direnv: `use flake` in a project's .envrc caches the devshell as
      # a GC root — instant re-entry instead of re-evaluating the flake on
      # every cd, and `nix-collect-garbage` won't nuke the shell's closure.
      nix-direnv.enable = true;
      # zsh integration is on by default (enableZshIntegration = true).
      config.global = {
        # Suppress the wall of "export FOO" lines on every directory entry.
        hide_env_diff = true;
        # Devshell evals can legitimately take a while on first entry;
        # don't warn until clearly stuck.
        warn_timeout = "30s";
      };
    };
  };
}

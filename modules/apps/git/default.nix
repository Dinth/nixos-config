{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in {
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername}.programs.git = {
      enable = true;
      settings.user.name = "Michal Gawronski-Kot";
      settings.user.email = "michal@gawronskikot.com";
      settings = {
        url = {
          "ssh://git@github.com" = {
            insteadOf = "https://github.com";
          };
          "ssh://git@bitbucket.org" = {
            insteadOf = "https://bitbucket.org";
          };
          "ssh://git@gitlab.com" = {
            insteadOf = "https://gitlab.com";
          };
        };

        # New repos start on main (matches the repo convention).
        init.defaultBranch = "main";
        # `git pull` rebases instead of creating merge bubbles.
        pull.rebase = true;
        # `git push` on a fresh branch sets its upstream automatically —
        # no more `--set-upstream origin <branch>`.
        push.autoSetupRemote = true;
        # Prune local refs for branches deleted on the remote.
        fetch.prune = true;
        # Remember how conflicts were resolved and replay them on the next
        # rebase/merge that hits the same conflict.
        rerere.enabled = true;
        # Distinct colour for moved (vs added/removed) lines so refactors read
        # clearly.
        diff.colorMoved = "default";

        # difftastic as the external diff driver — `git diff`, `git show` and
        # `git log -p` render structural, syntax-aware diffs. difft
        # auto-detects git's GIT_EXTERNAL_DIFF 7-arg calling convention. Pass
        # `--no-ext-diff` to any git command that needs a raw/parseable patch.
        diff.external = "${lib.getExe pkgs.difftastic}";
      };
    };
  };
}

{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf getExe getExe';
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in {
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername} = { config, ... }: {
		catppuccin.fzf = {
        enable = true;
        flavor = "mocha";
        accent = "mauve";
      };
      programs.fzf = {
        enable = true;
        enableZshIntegration = true;
        defaultCommand = "${getExe pkgs.fd} --type f --hidden -E .git -E node_modules -E __pycache__ -E .venv -E .env -E dist -E build -E .next -E .nuxt";
        defaultOptions = [
          "--height 40%"
          "--border"
          "--multi"
          "--bind=ctrl-a:select-all,ctrl-d:deselect-all"
        ];
      };
	};
}

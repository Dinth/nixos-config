{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf getExe getExe';
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in {
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername} = { config, ... }: {
	  programs.starship = {
	  enable = true;
	  settings = lib.mkMerge [
	  	(builtins.fromTOML
	  	(builtins.readFile "${pkgs.starship}/share/starship/presets/catppuccin-powerline.toml"))
		{
		palette = lib.mkForce "catppuccin_mocha";
		}
		];
	  };
    };
  };
}

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
    home-manager.users.${primaryUsername} = {
      # color_theme was set by hand and then commented out, leaving btop on its
      # default palette while the rest of the tree is catppuccin — naming a theme
      # does nothing unless the .theme file is installed under btop/themes. The
      # catppuccin module does both, the same way catppuccin.bat/fzf/eza do.
      catppuccin.btop.enable = true;
      programs.btop = {
        enable = true;
        # Match the system-level package selection in cli.nix: the GPU-aware
        # build on hosts with an AMD GPU, plain btop elsewhere. Without this the
        # HM module installed plain btop into the user profile, which shadowed
        # the btop-rocm in environment.systemPackages on $PATH — so GPU stats
        # never appeared on the desktop.
        package =
          if config.amd_gpu.enable
          then pkgs.btop-rocm
          else pkgs.btop;
        settings = {
          truecolor = "True";
        };
      };
    };
  };
}

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
    home-manager.users.${primaryUsername}.programs.btop = {
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
        #        color_theme = "catppuccin_macchiato";
        truecolor = "True";
      };
    };
  };
}

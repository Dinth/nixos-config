{
  config,
  lib,
  isDarwin,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
  htop = {
    enable = true;
    settings = {
      detailed_cpu_time = true;
      hide_kernel_threads = false;
      show_cpu_frequency = true;
      show_cpu_usage = true;
      show_program_path = false;
      show_thread_names = true;
    };
  };
in {
  # NixOS has a system-wide programs.htop (/etc/htoprc); nix-darwin doesn't,
  # so on macOS the same settings go through Home Manager's per-user module.
  config = mkIf cfg.enable (
    if isDarwin
    then {home-manager.users.${primaryUsername}.programs.htop = htop;}
    else {programs.htop = htop;}
  );
}

{
  config,
  pkgs,
  lib,
  machineType ? "desktop",
  ...
}: let
  inherit (lib) mkDefault mkIf;
in {
  # Server remote deployment settings (no TTY available)
  security.doas.extraRules = mkIf (machineType == "server") (lib.mkForce [
    {
      users = [config.primaryUser.name];
      noPass = true;
      keepEnv = true;
    }
  ]);
  nix.settings.trusted-users = mkIf (machineType == "server") ["root" config.primaryUser.name];

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
  # Kernel: stable for servers, latest for desktops/tablets
  boot.kernelPackages = mkDefault (
    if machineType == "server"
    then pkgs.linuxPackages
    else pkgs.linuxPackages_latest
  );
  # boot.tmp is fully configured in modules/system/security.nix (with tmpfsSize).
  services.fwupd.enable = true;
  services.nohang = {
    enable = true;
    configPath = "desktop";
  };

  # Base home-manager config for root (required when modules apply HM config to root)
  home-manager.users.root.home = {
    stateVersion = "25.05";
    username = "root";
    homeDirectory = "/root";
  };
}

{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.virtualisation;
in
{
  imports = [
    # Import individual VM definitions here
    # ./my-vm.nix
  ];

  config = mkIf cfg.enable {
    virtualisation.libvirt.connections."qemu:///system" = {
      # Domains, networks, and pools are defined in individual VM files
      # and merged here via the module system
    };
  };
}

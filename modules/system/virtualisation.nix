{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.virtualisation;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    virtualisation = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable virtualisation.";
      };
    };
  };

  config = mkIf cfg.enable {
    users.groups.libvirtd.members = ["michal"];

    programs.virt-manager.enable = true;
    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.qemu = {
      swtpm.enable = true;
      ovmf.enable = true;
    };
    virtualisation.spiceUSBRedirection.enable = true;
    home-manager.users.${primaryUsername}.dconf.settings = {
      "org/virt-manager/virt-manager/connections" = {
        autoconnect = ["qemu:///system"];
        uris = ["qemu:///system"];
      };
    };
  };

}

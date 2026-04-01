{ config, lib, pkgs, options, ... }:
# NixVirt declarative VM management
#
# WARNING: When domains are defined here, NixVirt operates in fully declarative mode.
# Any libvirt domain NOT declared in Nix will be DELETED on rebuild
# (disk images are preserved, but VM definitions are removed).
let
  inherit (lib) mkIf elem optionalAttrs;
  hostname = config.networking.hostName;

  # All VMs run on desktop only
  runOnHosts = [ "dinth-nixos-desktop" ];

  # Check if NixVirt module is loaded
  hasNixVirt = options ? virtualisation && options.virtualisation ? libvirt;
in
{
  config = optionalAttrs hasNixVirt (mkIf (config.virtualisation.enable && elem hostname runOnHosts) {
    virtualisation.libvirt.connections."qemu:///system" = {
      networks = [{
        definition = ./default-network.xml;
        active = true;
      }];
      domains = [
        { definition = ./win11.xml; }
        { definition = ./win10.xml; }
        { definition = ./macos.xml; }
        { definition = ./linuxmint.xml; }
        { definition = ./kali.xml; }
      ];
    };
  });
}

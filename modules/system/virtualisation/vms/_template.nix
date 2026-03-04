{ config, lib, pkgs, ... }:
# Template for defining a libvirt VM declaratively
# Copy this file and rename it to your VM name (e.g., ubuntu-server.nix)
# Then add it to the imports list in ./default.nix
let
  inherit (lib) mkIf elem;
  hostname = config.networking.hostName;

  # VM Configuration
  vmName = "example-vm";
  vmUuid = "00000000-0000-0000-0000-000000000000"; # Generate with: uuidgen
  vmMemoryGiB = 4;
  vmCpus = 4;
  diskPath = "/var/lib/libvirt/images/${vmName}.qcow2";

  # Which host(s) should run this VM
  # Use a list to allow the same VM definition on multiple hosts
  runOnHosts = [ "dinth-nixos-desktop" ];
in
{
  config = mkIf (config.virtualisation.enable && elem hostname runOnHosts) {
    virtualisation.libvirt.connections."qemu:///system" = {
      domains = [{
        definition = {
          name = vmName;
          uuid = vmUuid;
          memory = { count = vmMemoryGiB; unit = "GiB"; };
          vcpu.count = vmCpus;

          os = {
            type = "hvm";
            arch = "x86_64";
            boot = [{ dev = "hd"; }];
          };

          features = {
            acpi = {};
            apic = {};
          };

          cpu.mode = "host-passthrough";

          clock = {
            offset = "utc";
            timer = [
              { name = "rtc"; tickpolicy = "catchup"; }
              { name = "pit"; tickpolicy = "delay"; }
              { name = "hpet"; present = false; }
            ];
          };

          devices = {
            emulator = "/run/libvirt/nix-emulators/qemu-system-x86_64";

            disk = [{
              type = "file";
              device = "disk";
              driver = {
                name = "qemu";
                type = "qcow2";
                cache = "writeback";
                discard = "unmap";
              };
              source.file = diskPath;
              target = {
                dev = "vda";
                bus = "virtio";
              };
            }];

            interface = [{
              type = "network";
              source.network = "default";
              model.type = "virtio";
            }];

            channel = [{
              type = "unix";
              target = {
                type = "virtio";
                name = "org.qemu.guest_agent.0";
              };
            }];

            graphics = [{
              type = "spice";
              autoport = true;
              listen.type = "address";
            }];

            video = [{
              model = {
                type = "virtio";
                heads = 1;
              };
            }];

            # For USB passthrough (optional)
            # hostdev = [{
            #   mode = "subsystem";
            #   type = "usb";
            #   source = {
            #     vendor.id = "0x1234";
            #     product.id = "0x5678";
            #   };
            # }];
          };
        };
        # Set to true to auto-start the VM
        active = false;
      }];
    };
  };
}

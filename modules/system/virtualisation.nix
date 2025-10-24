{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption mkMerge;
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

  config = mkMerge [
    (mkIf cfg.enable {
      virtualisation.virtualbox.host = {
        enable = true;
        enableExtensionPack = true;
        enableKvm = true;
        addNetworkInterface = false;
      };
    })
    (mkIf (pkgs.stdenv.isLinux && cfg.enable) {
      users.groups.libvirtd.members = [ primaryUsername ];
      programs.virt-manager.enable = true;
      virtualisation = {
        libvirtd = {
          enable = true;
          qemu = {
            swtpm.enable = true;
          };
        };
        spiceUSBRedirection.enable = true;
      };
      home-manager.users.${primaryUsername}.dconf.settings = {
        "org/virt-manager/virt-manager/connections" = {
          autoconnect = ["qemu:///system"];
          uris = ["qemu:///system"];
        };
      };
      environment.systemPackages = with pkgs; [
        libguestfs
      ];
      networking = {
        firewall.allowedTCPPorts = [ 8095 ];
        firewall.allowedUDPPorts = [ 8095 ];
        firewall.trustedInterfaces = [ "virbr0" ];
        firewall.extraCommands = ''
          # PREROUTING: Redirect incoming traffic to the VM
          iptables -t nat -A PREROUTING -i enp7s0 -p tcp --dport 8095 -j DNAT --to-destination 192.168.122.132:8095
          iptables -t nat -A PREROUTING -i enp7s0 -p udp --dport 8095 -j DNAT --to-destination 192.168.122.132:8095

          # POSTROUTING: Masquerade outgoing traffic from the VM network
          iptables -t nat -A POSTROUTING -s 192.168.122.0/24 -o enp7s0 -j MASQUERADE
        '';
        nat = {
          enable = true;
          internalInterfaces = [ "virbr0" ];
          externalInterface = "enp7s0";
          forwardPorts = [ {
            sourcePort = 8095;        # Port on the host
            proto = "tcp";            # Protocol (tcp/udp)
            destination = "192.168.122.132:8095"; # VM IP and port
          } {
            sourcePort = 8095;        # Port on the host
            proto = "udp";            # Protocol (tcp/udp)
            destination = "192.168.122.132:8095"; # VM IP and port
          } ];
        };
      };
      systemd.user.services.virtualbox-suspend-inhibitor = {
        description = "Suspend Inhibitor for VirtualBox";
        after = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = ''
            ${lib.getExe pkgs.bash} -c " \
              while true; do \
                # Wait until a VM is running \
                while ! ${lib.getExe' pkgs.virtualbox "VBoxManage"} list runningvms | ${lib.getExe pkgs.gnugrep} -q '.'; do \
                  sleep 30; \
                done; \
                \
                echo 'VM detected. Acquiring suspend lock.'; \
                \
                # Inhibit suspend while VMs are active. The lock is held for the duration of this command. \
                ${lib.getExe' pkgs.systemd "systemd-inhibit"} --what=sleep --who='VirtualBox' --why='A Virtual Machine is running' \
                ${lib.getExe pkgs.bash} -c 'while ${lib.getExe' pkgs.virtualbox "VBoxManage"} list runningvms | ${lib.getExe pkgs.gnugrep} -q \".\"; do sleep 30; done'; \
                \
                echo 'Last VM shut down. Releasing suspend lock.'; \
              done \
            "
          '';
          Restart = "always";
          RestartSec = "10";
        };
      };
    })
  ];
}

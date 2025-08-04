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
      virtualisation.virtualbox.host.enable = true;
      virtualisation.virtualbox.host.enableExtensionPack = true;
      virtualisation.virtualbox.host.enableKvm = true;
      virtualisation.virtualbox.host.addNetworkInterface = false;
    })
    (mkIf (pkgs.stdenv.isLinux && cfg.enable) {
      users.groups.libvirtd.members = [ primaryUsername ];
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
      systemd.user.services.virtualbox-suspend-inhibitor = {
        description = "Suspend Inhibitor for VirtualBox";
        after = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = ''
            ${lib.getExe pkgs.bash} -c " \
              while true; do \
                # Wait until a VM is running \
                while ! ${lib.getExe' pkgs.virtualbox "VBoxManager"} list runningvms | ${lib.getExe pkgs.gnugrep} -q '.'; do \
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

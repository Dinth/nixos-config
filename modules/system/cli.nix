{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    cli = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable full CLI features.";
      };
      catppuccin = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable catppuccin theme for CLI tools.";
      };
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      jq # JSON processor
      btop # system monitor and process viewer
      btop-rocm # btop addon for AMD GPUs
      iotop
      iftop #
      hwinfo
      inxi
      wget
      git
      difftastic # structural diff
      vivid # LS_COLOURS generator
      net-snmp # client and server for SNMP protocol
      zip
      unzip
      rar
      unar
      tabiew # Terminal CSV viewer
      _7zz
      python3
      psmisc #fuser, killall, pidof, pstree, peekfd
    ];
    programs.usbtop.enable = true;
    programs.ssh.startAgent = true;
  };
}

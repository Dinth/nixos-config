{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption getExe getExe';
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
      # -- Modern Core Tools --
      bat           # Modern replacement for 'cat' with syntax highlighting and git integration
      eza           # Modern replacement for 'ls' with icons, git status, and tree view
      fd            # Modern replacement for 'find' - faster and more user-friendly syntax
      ripgrep       # Modern replacement for 'grep' - extremely fast recursive search
      fzf           # Command-line fuzzy finder - essential for history search and file navigation
      jq            # Lightweight and flexible command-line JSON processor

      # -- System Monitoring --
      btop-rocm     # Resource monitor (CPU, Mem, Net) with specific support for AMD GPUs
      iotop         # Top-like interface for monitoring disk I/O usage by process
      iftop         # Display bandwidth usage on a network interface
      hwinfo        # Detailed hardware identification tool
      inxi          # Full featured CLI system information tool (great for support formatting)
      stress-ng     # Tool to stress test CPU, memory, I/O, and disk
      psmisc        # A set of small useful utilities: fuser, killall, pstree, peekfd
      acpi          # Shows battery status and other ACPI information

      # -- Network Utilities --
      wget          # Classic tool for retrieving files using HTTP, HTTPS, and FTP
      curl          # Tool for transferring data with URLs (essential for API testing)
      git           # Distributed version control system
      net-snmp      # Suite of applications for the SNMP protocol (monitoring network devices)
      wakeonlan     # Sends 'magic packets' to wake up compatible devices on the network
      netcat-openbsd# Networking utility (TCP/UDP reader/writer). OpenBSD version has better features than GNU.
      nmap          # Network discovery and security auditing tool
      dig           # DNS lookup utility (part of bind-tools)
      doggo         # A modern, user-friendly command-line DNS client (dig replacement)
      trippy        # Network diagnostic tool (combines traceroute and ping in a TUI)

      # -- General Utilities --
      difftastic    # Structural diff tool that compares code logic, not just text lines
      vivid         # Generator for LS_COLORS with support for multiple themes
      tealdeer      # Fast implementation of tldr - simplified, community-driven man pages
      tabiew        # Terminal-based CSV and TSV viewer
      xxd           # Hex dump utility (creates hex dump or restores from one)
      pciutils      # Utilities for inspecting PCI devices (provides 'lspci')
      usbutils      # Utilities for inspecting USB devices (provides 'lsusb')

      # -- Archiving --
      zip           # Packager for .zip files
      unzip         # Extractor for .zip files
      unar          # Multi-format unarchiver (handles zip, rar, 7z, tar, etc.)
      _7zz          # Command line version of 7-Zip

      # -- Development --
      python3       # Python interpreter
    ];
    environment.shellAliases = {
      ls = "${getExe pkgs.eza} -l --icons --git --group-directories-first"; # Use icons and group dirs
      tree = "${getExe pkgs.eza} --tree";                                # Tree view using eza
      cat = "${getExe pkgs.bat}";                                        # Use bat for reading files
      grep = "${getExe pkgs.ripgrep}";                                        # Use ripgrep by default
      find = "${getExe pkgs.fd}";                                        # Use fd by default
      diff = "${getExe pkgs.difftastic}";                                     # Use difftastic for diffs
      ip = "${lib.getExe' pkgs.iproute2 "ip"} --color=auto";                             # Colorize IP output
    };
    programs.usbtop.enable = true;
    programs.ssh.startAgent = true;
  };
}

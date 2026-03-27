{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption mkDefault;
  cfg = config.graphical;
  primaryUsername = config.primaryUser.name;
  primaryEmail = config.primaryUser.email;
in
{
  options = {
    graphical = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable graphical environment.";
      };
    };
  };
  config = mkIf cfg.enable {
    services.xserver.enable = true;

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    environment.systemPackages = with pkgs; [
      vlc
      libvlc
      libva
      libva-utils
      mesa
      vulkan-tools
      vulkan-loader
      vulkan-validation-layers
      mpv
      wl-clipboard
      libvdpau-va-gl
      shared-mime-info
    ];
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-lgc-plus
      corefonts
      vista-fonts
      nerd-fonts.fira-code
      ubuntu-classic
    ];
    fonts.fontconfig = {
      enable = mkDefault true;
      antialias = mkDefault true;
      subpixel.rgba = mkDefault "rgb";
      subpixel.lcdfilter = mkDefault "default";
      hinting = {
        enable = mkDefault true;
        style = mkDefault "full";
        autohint = mkDefault true;
      };
      allowBitmaps = mkDefault false;
    };
    orcaslicer.enable = mkDefault true;
    security.rtkit.enable = mkDefault true;
    services.colord.enable = mkDefault true;
    security.polkit.enable = mkDefault true;
    services.libinput.touchpad.naturalScrolling = mkDefault true;
    xdg.portal = {
      enable = true;
    };
    xdg.mime.enable = true;
    home-manager.users.${primaryUsername} = {
      xdg = {
        enable = true;
        mimeApps.enable = true;
      };
      home.file.".XCompose".text = ''
        include "%L"  # Loads default sequences first

        # --- EMOTICONS / KAOMOJI ---
        <Multi_key> <s> <h> : "¯\\_(ツ)_/¯"
        <Multi_key> <t> <f> : "(╯°□°)╯︵ ┻━┻"
        <Multi_key> <t> <p> : "┬─┬ノ( º _ ºノ)"
        <Multi_key> <v> <v> : "٩(◕‿◕)۶"
        <Multi_key> <b> <h> : "(づ｡◕‿‿◕｡)づ"
        <Multi_key> <h> <m> : "(─_─ )ゞ"

        # --- THE LENNY COLLECTION ---
        <Multi_key> <l> <n> : "( ͡° ͜ʖ ͡°)"
        <Multi_key> <l> <3> : "( ͡°( ͡° ͜ʖ( ͡° ͜ʖ ͡°)ʖ ͡°) ͡°)"
        <Multi_key> <l> <s> : "( ͡° ʖ̯ ͡°)"
        <Multi_key> <p> <p> : "(｡◕‿‿◕｡)"
        <Multi_key> <c> <r> : "(╥﹏╥)"
        <Multi_key> <d> <e> : "(⌐ ͡■ ͜ʖ ͡■)"
        <Multi_key> <e> <l> : "( ͡€ ͜ʖ ͡€)"
        <Multi_key> <f> <p> : "(－‸ლ)"

        # --- STATUS & ARROWS ---
        <Multi_key> <o> <k> : "✓"
        <Multi_key> <n> <o> : "✗"
        <Multi_key> <minus> <minus> <greater> : "→"
        <Multi_key> <less> <minus> <minus> : "←"
        <Multi_key> <equal> <equal> <greater> : "⇒"
        <Multi_key> <less> <equal> <equal> : "⇐"
        <Multi_key> <bar> <asciicircum> : "↑"
        <Multi_key> <bar> <v> : "↓"

        # --- GREEK LETTERS ---
        <Multi_key> <g> <a> : "α"
        <Multi_key> <g> <b> : "β"
        <Multi_key> <g> <d> : "Δ"
        <Multi_key> <g> <p> : "π"
        <Multi_key> <g> <o> : "Ω"
        <Multi_key> <g> <m> : "μ"

        # --- MATH & SYMBOLS ---
        <Multi_key> <p> <m> : "±"
        <Multi_key> <i> <semicolon> : "∞"
        <Multi_key> <n> <e> : "≠"
        <Multi_key> <asciitilde> <equal> : "≈"
        <Multi_key> <s> <q> : "√"
        <Multi_key> <period> <period> <period> : "…"
        <Multi_key> <o> <o> : "°"

        # --- CURRENCY ---
        <Multi_key> <l> <minus> : "£"
        <Multi_key> <e> <equal> : "€"

        # --- TEXT EXPANSION ---
        <Multi_key> <m> <a> <i> <l> : "${primaryEmail}"
      '';
    };
  };
}

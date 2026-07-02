{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption mkDefault;
  cfg = config.graphical;
  primaryUsername = config.primaryUser.name;
  primaryEmail = config.primaryUser.email;
in {
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
      # mesa / vulkan-validation-layers dropped: GPU drivers belong in
      # hardware.graphics.extraPackages (set per-host), not systemPackages,
      # and the validation layers are a heavyweight dev-only closure that no
      # app loads unless it explicitly requests Vulkan validation.
      vulkan-tools
      vulkan-loader
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
        # Let well-hinted fonts (corefonts, vista-fonts, Ubuntu) use their native
        # bytecode hinting; forcing the autohinter degraded rendering after the
        # freetype 2.13->2.14 bump in the 26.05 upgrade.
        autohint = mkDefault false;
      };
      allowBitmaps = mkDefault false;
      # Avoid pixelated embedded bitmaps in fonts like Calibri/Cambria at small sizes.
      useEmbeddedBitmaps = mkDefault false;
      # Pin generic-family resolution: otherwise `monospace` leaked to Hack (a
      # transitive dep) instead of the Fira Code we install, and emoji/CJK had no
      # fallback in the chain.
      defaultFonts = {
        sansSerif = mkDefault ["Noto Sans" "Noto Sans CJK SC" "Noto Color Emoji"];
        serif = mkDefault ["Noto Serif" "Noto Serif CJK SC" "Noto Color Emoji"];
        monospace = mkDefault ["FiraCode Nerd Font Mono" "Noto Sans Mono CJK SC" "Noto Color Emoji"];
        emoji = mkDefault ["Noto Color Emoji"];
      };
    };
    orcaslicer.enable = mkDefault true;
    security.rtkit.enable = mkDefault true;
    services.colord.enable = mkDefault true;
    security.polkit.enable = mkDefault true;
    services.libinput.touchpad = {
      naturalScrolling = mkDefault true;
      tapping = mkDefault true;
      disableWhileTyping = mkDefault true;
      additionalOptions = ''Option "PalmDetection" "true"'';
    };
    xdg.portal = {
      enable = true;
    };
    xdg.mime.enable = true;
    home-manager.users.${primaryUsername} = {
      xdg = {
        enable = true;
        mimeApps.enable = true;
        # Let Home Manager forcefully own mimeapps.list: replace it with the
        # managed (immutable, read-only) store symlink instead of trying to
        # back the existing file up. Without this, activation aborts whenever a
        # stale ~/.config/mimeapps.list.backup already exists ("backup would be
        # clobbered"), which recurs every time the file drifts from HM's copy.
        configFile."mimeapps.list".force = true;
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

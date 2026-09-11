{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.sillytavern;
in {
  options.sillytavern = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the SillyTavern LLM frontend (loopback only).";
    };

    port = mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port the SillyTavern web UI listens on.";
    };
  };

  config = mkIf cfg.enable {
    # Upstream's module runs SillyTavern as a dedicated system user with state
    # in /var/lib/SillyTavern (characters, chats, presets, extensions) and
    # ProtectHome=true, so nothing of it lands in ~. That directory is the
    # backup target -- there is no other persistent state.
    #
    # Note: /var/lib/SillyTavern/config.yaml is a tmpfiles "L+" symlink into
    # the store, i.e. read-only. Anything not covered by the CLI flags below
    # (basicAuthMode, request proxy, ...) has to be set by generating a yaml
    # and pointing services.sillytavern.configFile at it -- editing the live
    # file will fail.
    services.sillytavern = {
      enable = true;
      inherit (cfg) port;

      # The module's configFile default points at
      # lib/node_modules/sillytavern/config.yaml, which 1.18.0 no longer ships
      # -- the default moved to default/config.yaml. That leaves the tmpfiles
      # "L+" rule pointing at a dangling symlink, and SillyTavern dies on
      # startup trying to create it:
      #   EROFS: read-only file system, open '/var/lib/SillyTavern/config.yaml'
      # Pointing at the file the package actually ships fixes it, and keeps
      # config in lockstep with whatever version is installed.
      #
      # Its defaults already match what we want (listen: false,
      # whitelistMode: true); dataRoot is ignored because the package runs in
      # global mode, where data always lives under XDG_DATA_HOME.
      configFile = "${config.services.sillytavern.package}/lib/node_modules/sillytavern/default/config.yaml";
      # listen is deliberately left null rather than false: the module builds
      # flags as "--${name}=${toString x}", and toString false is the empty
      # string, so listen = false emits a bare "--listen=" for SillyTavern's
      # arg parser to interpret. Omitting the flag lets config.yaml's own
      # default (listen: false) stand, which is what we want anyway.
      #
      # The web UI is unauthenticated, so it stays on loopback; reaching it
      # from another host means an SSH tunnel, not a firewall hole:
      #   ssh -L 8000:127.0.0.1:8000 dinth-nixos-desktop
      listenAddressIPv4 = "127.0.0.1";
    };
  };
}

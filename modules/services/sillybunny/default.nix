{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.sillybunny;

  # Global-mode state lives at $XDG_DATA_HOME/<APP_NAME>, and APP_NAME is
  # hardcoded to "SillyBunny" upstream (src/runtime.js), so the StateDirectory
  # name is not ours to pick: XDG_DATA_HOME=%S makes it /var/lib/SillyBunny.
  stateDir = "SillyBunny";
  stateRoot = "/var/lib/${stateDir}";
  # State of the nixpkgs SillyTavern service this module replaced. Left in
  # place untouched as the rollback copy; see the import unit below.
  legacyRoot = "/var/lib/SillyTavern";
  importMarker = "${stateRoot}/.imported-from-sillytavern";
in {
  options.sillybunny = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the SillyBunny LLM frontend (loopback only).";
    };

    port = mkOption {
      type = types.port;
      default = 8000;
      description = ''
        Port the SillyBunny web UI listens on. Upstream's own default is 4444;
        8000 is kept from the SillyTavern service this replaced so existing
        bookmarks and SSH tunnels still land on it.
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./package.nix {};
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix {}";
      description = "SillyBunny package to run. Not in nixpkgs; built by ./package.nix.";
    };
  };

  config = mkIf cfg.enable {
    # SillyBunny is a SillyTavern fork and nixpkgs has no package or module for
    # it, so both the derivation (./package.nix) and the unit below are ours --
    # this is the nixpkgs services.sillytavern module rewritten around the
    # fork's paths, keeping its hardening set.
    #
    # Everything persistent is under /var/lib/SillyBunny (characters, chats,
    # presets, extensions, the webpack cache), and ProtectHome=true keeps the
    # service out of ~. That directory is the backup target.
    users.users.sillybunny = {
      description = "SillyBunny service user";
      isSystemUser = true;
      group = "sillybunny";
    };
    users.groups.sillybunny = {};

    systemd.services.sillybunny = {
      description = "SillyBunny LLM frontend";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      # Required by the in-app extension manager, which clones into the
      # third-party directory bind-mounted below.
      path = [pkgs.gitMinimal];

      environment = {
        # envPaths() resolves the data root from XDG_DATA_HOME; %S is the
        # StateDirectory root, so this lands on /var/lib/SillyBunny.
        XDG_DATA_HOME = "%S";
        NODE_NO_WARNINGS = "1";
      };

      serviceConfig = {
        Type = "simple";
        # The web UI is unauthenticated, so it stays on loopback; reaching it
        # from another host means an SSH tunnel, not a firewall hole:
        #   ssh -L ${toString cfg.port}:127.0.0.1:${toString cfg.port} dinth-nixos-desktop
        #
        # browserLaunchEnabled is forced off because the shipped default
        # config.yaml turns it on, and a system service has no session to open
        # a browser in.
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe cfg.package)
          "--port=${toString cfg.port}"
          "--listenAddressIPv4=127.0.0.1"
          "--browserLaunchEnabled=false"
        ];
        User = "sillybunny";
        Group = "sillybunny";
        Restart = "always";
        StateDirectory = stateDir;
        # Extensions are installed at runtime into a directory inside the
        # (read-only) store path, so writable state is mounted over it.
        BindPaths = [
          "%S/${stateDir}/extensions:${cfg.package}/lib/node_modules/sillybunny/public/scripts/extensions/third-party"
        ];

        # Security hardening, as in the nixpkgs module.
        CapabilityBoundingSet = [""];
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
      };
    };

    # One-shot carry-over of the SillyTavern state this module replaced.
    # SillyBunny keeps its parent's data layout, so the old data root drops
    # straight in. It is copied rather than moved: /var/lib/SillyTavern stays
    # behind untouched, both as the rollback copy and because SillyBunny will
    # write format migrations into its copy that SillyTavern cannot read back.
    #
    # Runs as root because the two state roots are 0700 under different system
    # users. Guarded by a marker file, so a later `rm -rf` of a chat in
    # SillyBunny is not undone on the next boot.
    systemd.services.sillybunny-import-sillytavern = {
      description = "Import SillyTavern state into SillyBunny's data root";
      requiredBy = ["sillybunny.service"];
      before = ["sillybunny.service"];

      unitConfig.ConditionPathExists = [
        legacyRoot
        "!${importMarker}"
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail

        # Copy the contents of $1 into $2 and hand it to the service user, but
        # only while $2 is still empty -- anything already there is live
        # SillyBunny state and wins. chown is -h so a symlink is never
        # followed: config.yaml points into the store, and chowning that
        # fails.
        copy_if_empty() {
          local src="$1" dst="$2"

          [ -d "$src" ] || return 0
          mkdir -p "$dst"

          if [ -n "$(ls -A "$dst")" ]; then
            echo "$dst already has contents; leaving it alone"
            return 0
          fi

          echo "Importing $src -> $dst"
          cp -a "$src/." "$dst/"
          chown -Rh sillybunny:sillybunny "$dst"
        }

        mkdir -p ${stateRoot}

        # config.yaml is deliberately not carried over: on the old side it is
        # a symlink into the SillyTavern store path, and the tmpfiles rule
        # below already points the new one at SillyBunny's own defaults.
        copy_if_empty ${legacyRoot}/data ${stateRoot}/data
        copy_if_empty ${legacyRoot}/extensions ${stateRoot}/extensions

        touch ${importMarker}
      '';
    };

    # config.yaml is an "L+" symlink into the store, i.e. read-only. Anything
    # not covered by the CLI flags above (basicAuthMode, request proxy, ...)
    # has to be set by generating a yaml and pointing this rule at it --
    # editing the live file will fail.
    #
    # Pointing it at the package's own default/config.yaml keeps config in
    # lockstep with the installed version and, because nothing is then
    # missing, stops addMissingConfigValues() from trying to write the file
    # back on startup (which would die with EROFS).
    systemd.tmpfiles.settings.sillybunny = {
      "${stateRoot}/data".d = {
        mode = "0700";
        user = "sillybunny";
        group = "sillybunny";
      };
      "${stateRoot}/extensions".d = {
        mode = "0700";
        user = "sillybunny";
        group = "sillybunny";
      };
      "${stateRoot}/config.yaml"."L+" = {
        mode = "0600";
        argument = "${cfg.package}/lib/node_modules/sillybunny/default/config.yaml";
        user = "sillybunny";
        group = "sillybunny";
      };
    };
  };
}

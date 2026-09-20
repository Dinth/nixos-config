{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.stableDiffusion;
  primaryUsername = config.primaryUser.name;
  primaryHome = config.users.users.${primaryUsername}.home;
  primaryGroup = config.users.users.${primaryUsername}.group;

  # sd-server loads exactly one checkpoint, chosen at startup, so switching
  # means repointing a symlink and restarting rather than any API call.
  activeLink = "${cfg.checkpointsDir}/active.safetensors";

  # `sd-switch <name>` relinks and restarts; with no argument it lists what is
  # declared and marks the live one. The name -> file mapping is baked in from
  # cfg.checkpoints, so only a declared checkpoint can ever be selected.
  sdSwitch = pkgs.writeShellApplication {
    name = "sd-switch";
    runtimeInputs = [pkgs.systemd pkgs.coreutils];
    text = ''
      declare -A checkpoints=(
        ${lib.concatStringsSep "\n        " (
        lib.mapAttrsToList (name: path: ''["${name}"]="${path}"'') cfg.checkpoints
      )}
      )

      # No argument: show what is declared and which one is live.
      if [ $# -eq 0 ]; then
        current="$(readlink -f ${activeLink} 2>/dev/null || echo none)"
        for name in "''${!checkpoints[@]}"; do
          marker=" "
          [ "''${checkpoints[$name]}" = "$current" ] && marker="*"
          printf '%s %s -> %s\n' "$marker" "$name" "''${checkpoints[$name]}"
        done
        exit 0
      fi

      target="''${checkpoints[$1]:-}"
      if [ -z "$target" ]; then
        echo "sd-switch: unknown checkpoint '$1'; run with no arguments to list" >&2
        exit 1
      fi
      if [ ! -e "$target" ]; then
        echo "sd-switch: '$1' is declared but $target is missing -- download it first" >&2
        exit 1
      fi

      ln -sfn "$target" ${activeLink}
      systemctl restart sd-server.service
      echo "sd-switch: now serving $1 ($target)"
    '';
  };
in {
  options.stableDiffusion = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the stable-diffusion.cpp image server (Vulkan backend, loopback only).";
    };

    port = mkOption {
      type = lib.types.port;
      default = 1234;
      description = ''
        Port sd-server listens on. 1234 is both sd-server's own default and
        the one SillyBunny's stable-diffusion.cpp source expects, so leaving
        it alone means neither side needs configuring.
      '';
    };

    checkpointsDir = mkOption {
      type = lib.types.path;
      default = "${primaryHome}/Models/sd";
      defaultText = lib.literalExpression ''"''${primaryHome}/Models/sd"'';
      description = "Directory holding the checkpoints and the active symlink.";
    };

    checkpoints = mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = {};
      example = lib.literalExpression ''{anime = "/home/michal/Models/sd/wai.safetensors";}'';
      description = ''
        Checkpoints selectable with `sd-switch`. Declaring one here does not
        download it -- the entry simply becomes a name the switch accepts.
      '';
    };

    defaultCheckpoint = mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Which of `checkpoints` the active symlink is seeded with. Seeded only
        when the symlink does not exist, so a runtime `sd-switch` survives
        rebuilds instead of being reverted by the next activation.
      '';
    };

    extraFlags = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["--offload-to-cpu"];
      description = "Extra flags for sd-server, e.g. --offload-to-cpu when the LLM already owns the VRAM.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.defaultCheckpoint == null || cfg.checkpoints ? ${cfg.defaultCheckpoint};
        message = "stableDiffusion.defaultCheckpoint '${toString cfg.defaultCheckpoint}' is not a key of stableDiffusion.checkpoints.";
      }
    ];

    environment.systemPackages = [sdSwitch];

    systemd.services.sd-server = {
      description = "stable-diffusion.cpp image server";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      # Skip cleanly rather than fail when no checkpoint is present yet.
      unitConfig.ConditionPathExists = activeLink;

      environment = {
        # Same reasoning as llama-cpp: pin RADV so enumeration cannot pick
        # lavapipe, and give Mesa a writable shader cache.
        VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";
        MESA_SHADER_CACHE_DIR = "/var/cache/sd-server/mesa";
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe' pkgs.stable-diffusion-cpp-vulkan "sd-server")
            "--listen-ip"
            "127.0.0.1"
            "--listen-port"
            (toString cfg.port)
            "-m"
            activeLink
            # Both cut VRAM, which matters because llama-server is usually
            # holding most of the card already.
            "--diffusion-fa"
            "--vae-tiling"
          ]
          ++ cfg.extraFlags
        );

        # Runs as the primary user for the same reason llama-cpp does: the
        # checkpoints live in ~/Models, which a DynamicUser cannot reach.
        User = primaryUsername;
        Group = primaryGroup;
        Restart = "on-failure";
        RestartSec = 10;
        StateDirectory = "sd-server";
        CacheDirectory = "sd-server";
        WorkingDirectory = "/var/lib/sd-server";

        # GPU access needs devices visible; everything else stays shut.
        PrivateDevices = false;
        CapabilityBoundingSet = [""];
        NoNewPrivileges = true;
        ProtectHome = "read-only";
        ProtectSystem = "strict";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RemoveIPC = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = ["@system-service" "~@privileged"];
      };
    };

    # `L` rather than `L+`: seed the symlink once, then leave runtime
    # sd-switch choices alone. L+ would silently revert the active checkpoint
    # on every rebuild.
    systemd.tmpfiles.settings.sd-models =
      {
        "${cfg.checkpointsDir}".d = {
          mode = "0755";
          user = primaryUsername;
          group = primaryGroup;
        };
      }
      // lib.optionalAttrs (cfg.defaultCheckpoint != null) {
        "${activeLink}".L = {
          user = primaryUsername;
          group = primaryGroup;
          argument = cfg.checkpoints.${cfg.defaultCheckpoint};
        };
      };

    # sd-switch restarts the unit, so let the primary user manage these two
    # units without a password prompt. Scoped to exactly the GPU services --
    # the whole point is swapping which of them holds the card.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "${primaryUsername}") {
          var unit = action.lookup("unit");
          if (unit == "sd-server.service" || unit == "llama-cpp.service") {
            return polkit.Result.YES;
          }
        }
      });
    '';
  };
}

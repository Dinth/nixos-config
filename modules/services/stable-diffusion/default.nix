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
        the one SillyTavern's stable-diffusion.cpp source expects, so leaving
        it alone means neither side needs configuring.
      '';
    };

    model = mkOption {
      type = lib.types.path;
      default = "${primaryHome}/Models/sd/model.safetensors";
      defaultText = lib.literalExpression ''"''${primaryHome}/Models/sd/model.safetensors"'';
      description = ''
        Checkpoint to serve. sd-server loads exactly one, at startup. The unit
        is gated on this file existing, so enabling the module before the
        download lands leaves it cleanly skipped rather than crash-looping.
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
    systemd.services.sd-server = {
      description = "stable-diffusion.cpp image server";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      # Skip cleanly rather than fail when no checkpoint is present yet.
      unitConfig.ConditionPathExists = cfg.model;

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
            cfg.model
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

    systemd.tmpfiles.settings.sd-models = {
      "${builtins.dirOf cfg.model}".d = {
        mode = "0755";
        user = primaryUsername;
        group = primaryGroup;
      };
    };
  };
}

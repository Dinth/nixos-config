{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.llamaCpp;
  primaryUsername = config.primaryUser.name;
  primaryHome = config.users.users.${primaryUsername}.home;
  primaryGroup = config.users.users.${primaryUsername}.group;
in {
  options.llamaCpp = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the llama.cpp inference server (Vulkan backend, loopback only).";
    };

    port = mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port llama-server listens on (OpenAI-compatible API + web UI).";
    };

    modelsDir = mkOption {
      type = lib.types.path;
      default = "${primaryHome}/Models";
      defaultText = lib.literalExpression ''"''${primaryHome}/Models"'';
      description = ''
        Directory llama-server scans for GGUF files. Lives in the primary
        user's home so models can be managed like any other file; reaching it
        is what forces the DynamicUser/ProtectHome relaxation below.
      '';
    };

    presetFile = mkOption {
      type = lib.types.path;
      default = "${primaryHome}/Models/models.ini";
      defaultText = lib.literalExpression ''"''${primaryHome}/Models/models.ini"'';
      description = ''
        Per-model settings, as an INI whose section names match the model ids
        the router reports. Deliberately a runtime file next to the weights
        rather than generated from Nix: model choices are not configuration
        this repo should carry. Created empty by tmpfiles if absent, so the
        flag is always valid.
      '';
    };

    contextSize = mkOption {
      type = lib.types.ints.unsigned;
      default = 32768;
      description = ''
        Default context window, in tokens, for models loaded without a preset.
        0 means "whatever the model was trained for", which on a modern model
        can be 128k and will not fit alongside the weights -- hence a cap.
        The KV cache is the cost: quantised to q8_0 below, it is roughly half
        what it would otherwise be.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.llama-cpp = {
      enable = true;
      # Vulkan, not ROCm: this box is a Navi 22 (RX 6700 XT) = gfx1031, which
      # ROCm has never shipped official kernels for -- a ROCm build only works
      # by faking HSA_OVERRIDE_GFX_VERSION=10.3.0 and drags a multi-GB closure
      # along. The Vulkan backend rides the RADV driver amd_gpu.nix already
      # installs and performs comparably on RDNA2.
      #
      # The Vulkan variant does come off cache.nixos.org (verified on build
      # 9190), but it is a non-default override, so any bump Hydra has not
      # built yet falls back to a local shaderc + C++ compile.
      package = pkgs.llama-cpp.override {vulkanSupport = true;};

      host = "127.0.0.1";
      inherit (cfg) port;

      # Router mode: llama-server lists every GGUF under this directory and
      # loads them on demand, so SillyBunny's model dropdown can switch
      # between them instead of the service being pinned to one file.
      modelsDir = cfg.modelsDir;

      extraFlags = [
        "-ngl"
        "999" # offload every layer that fits; llama.cpp clamps to the model
        "-c"
        (toString cfg.contextSize)
        "--jinja" # honour the model's own chat template
        # Flash attention is a prerequisite for quantising the KV cache, and
        # q8_0 K/V roughly halves it -- the difference between 8k and 32k of
        # context fitting next to the weights on a 12 GB card.
        "-fa"
        "on"
        "-ctk"
        "q8_0"
        "-ctv"
        "q8_0"
        # The card is shared with sd-server, so the router must not hoard it:
        # one model resident at a time (upstream default is 4, which on 12 GB
        # means a second model simply fails to load), and release the GPU after
        # five minutes of silence so image generation can have it.
        "--models-max"
        "1"
        "--sleep-idle-seconds"
        "300"
        # Per-model overrides (context, --n-cpu-moe, samplers) keyed by model
        # id. Passed as a path, not generated from an attrset, so which models
        # exist and how each is tuned stays runtime state in ~/Models.
        "--models-preset"
        (toString cfg.presetFile)
      ];
    };

    systemd.services.llama-cpp = {
      # The upstream unit runs under DynamicUser with ProtectHome=true, which
      # makes /home an empty tmpfs for the service -- a transient UID could not
      # traverse 0700 ~michal anyway. Serving models out of the user's home
      # therefore means running as that user, with /home merely read-only:
      # llama-server only ever reads the GGUFs, and writes stay in its
      # StateDirectory / CacheDirectory.
      #
      # The trade is real: the process can now read everything the user can.
      # It listens on loopback only, which is what keeps that acceptable.
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = primaryUsername;
        Group = primaryGroup;
        ProtectHome = lib.mkForce "read-only";
      };

      environment = {
        # Pin the ICD to RADV so device enumeration can't land on lavapipe,
        # the CPU-software Vulkan driver that also ships in the Mesa ICD dir.
        VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";
        # DynamicUser + ProtectHome leaves no writable HOME for Mesa's shader
        # cache; point it at the unit's CacheDirectory instead.
        MESA_SHADER_CACHE_DIR = "/var/cache/llama-cpp/mesa";
      };
    };

    # /dev/dri/renderD128 is mode 0666 under systemd's default udev rules, so
    # the service needs no video/render membership -- only PrivateDevices off,
    # which the upstream module already sets for GPU access.
    systemd.tmpfiles.settings.llama-models = {
      "${cfg.modelsDir}".d = {
        mode = "0755";
        user = primaryUsername;
        group = primaryGroup;
      };
      # `f` creates the preset file only when absent, leaving hand-written
      # entries alone; without it --models-preset points at nothing on a fresh
      # install and llama-server refuses to start.
      "${toString cfg.presetFile}".f = {
        mode = "0644";
        user = primaryUsername;
        group = primaryGroup;
      };
    };
  };
}

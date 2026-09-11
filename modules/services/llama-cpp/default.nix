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

    contextSize = mkOption {
      type = lib.types.ints.positive;
      default = 8192;
      description = "Default context window, in tokens, for models loaded without a preset.";
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
      # loads them on demand, so SillyTavern's model dropdown can switch
      # between them instead of the service being pinned to one file.
      modelsDir = cfg.modelsDir;

      extraFlags = [
        "-ngl"
        "999" # offload every layer that fits; llama.cpp clamps to the model
        "-c"
        (toString cfg.contextSize)
        "--jinja" # honour the model's own chat template
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
    };
  };
}

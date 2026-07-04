{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.amd_gpu;
in {
  options = {
    amd_gpu = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable AMD GPU support.";
      };
    };
  };
  config = mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      # extraPackages is the *driver closure* fed to the graphics stack — only
      # runtime ICDs / loadable layers belong here. It is NOT on $PATH, so CLI
      # tools must go in environment.systemPackages instead (see below).
      extraPackages = with pkgs; [
        rocmPackages.clr.icd # OpenCL runtime (ROCm)
        # vulkan-validation-layers dropped: a heavyweight dev-only layer that is
        # never loaded unless an app sets VK_INSTANCE_LAYERS. Keeping it here
        # only added closure weight and contradicted the same call in
        # modules/system/graphical.nix. Re-add temporarily when validating.
      ];
      # 32-bit Vulkan stack for Wine/Proton (DXVK + VKD3D-Proton are both
      # Vulkan-backed). Without the 32-bit vulkan-loader, DXVK in a 32-bit
      # Wine process fails surface creation with VK_ERROR_OUT_OF_HOST_MEMORY.
      extraPackages32 = with pkgs.pkgsi686Linux; [
        mesa
        vulkan-loader
      ];
    };

    # GPU inspection / monitoring CLIs. These were previously (incorrectly) in
    # hardware.graphics.extraPackages, where they never reached $PATH.
    environment.systemPackages = with pkgs; [
      vulkan-tools # vulkaninfo, vkcube
      clinfo # OpenCL device query
      radeontop # GPU load meter
      amdgpu_top # AMD GPU resource monitor
    ];

    # Route VA-API/VDPAU through radeonsi so browsers/mpv get hardware video
    # decode on the Navi22 iGPU/dGPU instead of falling back to CPU.
    environment.variables = {
      LIBVA_DRIVER_NAME = "radeonsi";
      VDPAU_DRIVER = "radeonsi";
    };
  };
}

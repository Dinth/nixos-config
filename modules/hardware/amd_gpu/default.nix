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
      extraPackages = with pkgs; [
        rocmPackages.clr.icd
        vulkan-tools
        vulkan-loader
        vulkan-validation-layers
        clinfo
        radeontop
        amdgpu_top # AMD graphic card resource monitor
      ];
      # 32-bit Vulkan stack for Wine/Proton (DXVK + VKD3D-Proton are both
      # Vulkan-backed). Without the 32-bit vulkan-loader, DXVK in a 32-bit
      # Wine process fails surface creation with VK_ERROR_OUT_OF_HOST_MEMORY.
      extraPackages32 = with pkgs.pkgsi686Linux; [
        mesa
        vulkan-loader
      ];
    };
  };
}

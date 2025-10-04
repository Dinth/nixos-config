{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.amd_gpu;
  primaryUsername = config.primaryUser.name;
in
{
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
        clinfo
        radeontop
        amdgpu_top # AMD graphic card resource monitor
      ];
    };
  };
}


{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.printers;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    printers = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable printers and scanners access.";
      };
    };
  };
  config = mkIf cfg.enable {
    services.printing = {
      enable = true;
      drivers = with pkgs; [
        canon-cups-ufr2
        cups-filters
        cups-browsed
      ];
      extraConf = ''
        DefaultPaperSize A4
      '';
    };
    hardware.printers = {
      ensurePrinters = [
        {
          name = "Canon_MF270_Series";
          location = "Wickhay";
          deviceUri = "ipp://10.10.10.40/ipp/print";
          model = "everywhere";
          ppdOptions = {
            PageSize = "A4";
            Duplex = "DuplexNoTumble";
          };
        }
      ];
      ensureDefaultPrinter = "Canon_MF270_Series";
    };
    hardware.sane.enable = true;
    hardware.sane.extraBackends = [ pkgs.sane-airscan ];
    services.saned.enable = true;
  };
}


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
    ];
    };
    hardware.printers = {
      ensurePrinters = [
        {
          name = "Canon_MF270_Series";
          location = "Wickhay";
          deviceUri = "socket://10.10.10.40:9100";
          model = "CNRCUPSMF270ZJ.ppd";
          ppdOptions = {
            PageSize = "A4";
          };
        }
      ];
      ensureDefaultPrinter = "Canon_MF270_Series";
    };
    hardware.sane.enable = true;
    services.saned.enable = true;
  };
}


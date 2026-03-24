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
      ];
      browsing = true;
      extraConf = ''
        DefaultPaperSize A4
      '';
    };
    services.printing.cups-pdf.enable = false;
    services.avahi.publish.enable = true;
    services.avahi.publish.userServices = true;
    hardware.printers = {
      ensurePrinters = [
        {
          name = "Canon_MF270_Series";
          location = "Wickhay";
          # Wait up to 60s for printer to wake from sleep
          # If still fails, try: "beh:/3/10/ipp://10.10.10.40/ipp" (retries 3x, 10s apart - may cause duplicates)
          deviceUri = "ipp://10.10.10.40/ipp?contimeout=60";
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

    # Make ensure-printers service fault-tolerant - don't fail boot if printer is unreachable
    systemd.services.ensure-printers = {
      serviceConfig = {
        # Don't fail if printer is asleep/offline during boot
        SuccessExitStatus = [ 0 1 ];
        Restart = "on-failure";
        RestartSec = "30s";
        # Give up after a few retries during boot
        StartLimitBurst = 3;
        StartLimitIntervalSec = 180;
      };
      # Run after network is online
      after = [ "network-online.target" "cups.service" ];
      wants = [ "network-online.target" ];
    };
  };
}


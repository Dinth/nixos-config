{ config, pkgs, ... }:
{
  # Enable networking
  networking.networkmanager.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.hardware.bolt.enable = true;
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.keyboard.qmk.enable = true;
  hardware.logitech = {
    wireless.enable = true;
    wireless.enableGraphical = true;
  };
  hardware.flipperzero.enable = true;

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
  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  services.fwupd.enable = true;
  services.pcscd.enable = true;
  services.fstrim.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };
  systemd.services.logiops = {
    description = "An unofficial userspace driver for HID++ Logitech devices";
    # wantedBy = [ "graphical.target" ];
    # after = [ "bluetooth.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.logiops}/bin/logid";
    };
    restartTriggers = [ config.environment.etc."logid.cfg".source ];
  };
  environment.etc."logid.cfg".source = ./files/logid.cfg;
}

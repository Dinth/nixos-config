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
  environment.etc."logid.cfg".text = ''
  devices: ({
    name: "MX Master 3S";
    dpi: 1000;

    smartshift: {
      on: true;
      threshold: 12;
      default_threshold: 12;
    };

    hiresscroll: {
      hires: false;
      invert: false;
      target: true;
      up: {
            mode: "Axis";
            axis: "REL_WHEEL";
            axis_multiplier: 2.0;
      },
      down: {
              mode: "Axis";
              axis: "REL_WHEEL";
              axis_multiplier: -2.0;
      }
    };

    buttons: (
      {
        cid: 0xc3;
        action = {
          type: "Gestures";
          gestures: (
            {
              direction: "Up";
              mode: "OnRelease";
              action =
              {
                  type: "Keypress";
                  keys: ["KEY_LEFTMETA", "KEY_UP"];
              };
            },
            {
              direction: "Down";
              mode: "OnRelease";
              action =
              {
                  type: "Keypress";
                  keys: ["KEY_LEFTMETA", "KEY_DOWN"];
              };
            },
            {
              direction: "Left";
              mode: "OnRelease";
              action =
              {
                  type: "Keypress";
                  keys: ["KEY_LEFTMETA", "KEY_LEFT"];
              };
            },
            {
              direction: "Right";
              mode: "OnRelease";
              action =
              {
                  type: "Keypress";
                  keys: ["KEY_LEFTMETA", "KEY_RIGHT"];
              };
            },
            {
              direction: "None";
              mode: "OnRelease";
              action = {
                type = "Keypress";
                keys: ["KEY_LEFTCTRL", "KEY_R"];
              };
            }
          );
        };
      }
    );
  });
  '';
}

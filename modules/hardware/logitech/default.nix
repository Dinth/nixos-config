{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.logitech;
in {
  options = {
    logitech = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Logitech peripherals support.";
      };
    };
  };
  config = mkIf cfg.enable {
    hardware.logitech = {
      wireless.enable = true;
      wireless.enableGraphical = true;
    };

    services.logiops = {
      enable = true;
      config = {
        devices = [
          {
            name = "MX Master 3";
            dpi = 1000;
            smartshift = {
              on = true;
              threshold = 12;
              default_threshold = 12;
            };
            hiresscroll = {
              hires = false;
              invert = false;
              target = true;
              up = {
                mode = "Axis";
                axis = "REL_WHEEL";
                axis_multiplier = 2.0;
              };
              down = {
                mode = "Axis";
                axis = "REL_WHEEL";
                axis_multiplier = -2.0;
              };
            };
            buttons = [
              {
                cid = 195; # 0xc3 — thumb button (gesture)
                action = {
                  type = "Gestures";
                  gestures = [
                    {
                      direction = "Up";
                      mode = "OnRelease";
                      action = {
                        type = "Keypress";
                        keys = ["KEY_LEFTMETA" "KEY_UP"];
                      };
                    }
                    {
                      direction = "Down";
                      mode = "OnRelease";
                      action = {
                        type = "Keypress";
                        keys = ["KEY_LEFTMETA" "KEY_DOWN"];
                      };
                    }
                    {
                      direction = "Left";
                      mode = "OnRelease";
                      action = {
                        type = "Keypress";
                        keys = ["KEY_LEFTMETA" "KEY_LEFT"];
                      };
                    }
                    {
                      direction = "Right";
                      mode = "OnRelease";
                      action = {
                        type = "Keypress";
                        keys = ["KEY_LEFTMETA" "KEY_RIGHT"];
                      };
                    }
                    {
                      direction = "None";
                      mode = "OnRelease";
                      action = {
                        type = "Keypress";
                        keys = ["KEY_LEFTCTRL" "KEY_R"];
                      };
                    }
                  ];
                };
              }
              {
                cid = 196; # 0xc4 — forward button (horizontal scroll)
                action = {
                  type = "Axis";
                  axis = "REL_HWHEEL_HI_RES";
                  axis_multiplier = 1.0;
                };
              }
            ];
          }
        ];
      };
    };

    # Restart logid when the Logitech USB receiver reconnects
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", TAG+="systemd", ENV{SYSTEMD_WANTS}="logid.service"
    '';

    services.libinput.mouse = {
      accelProfile = "flat";
      accelSpeed = "0";
    };
  };
}

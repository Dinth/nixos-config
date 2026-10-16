{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.tailscale;
  tailscale = lib.getExe config.services.tailscale.package;

  # Brings the tailnet up away from home and down on the home Wi-Fi, where
  # every tailnet destination is reachable directly and the Mac shouldn't
  # route through a subnet router/exit node it's sitting next to.
  #
  # Home detection: the Wi-Fi SSID first. macOS 14.4+ redacts SSIDs from
  # `ipconfig getsummary` unless verbose mode is on (root-only, so this daemon
  # turns it on). If the SSID still can't be read — or the Mac is on Ethernet
  # with Wi-Fi off — fall back to the default gateway being the home router.
  #
  # Manual override: `touch /tmp/tailscale-autoswitch.off` to leave Tailscale
  # however you set it (cleared on reboot).
  homeSwitch = pkgs.writeShellApplication {
    name = "tailscale-home-switch";
    runtimeInputs = [pkgs.gawk];
    text = ''
      home_ssid=${lib.escapeShellArg cfg.homeSsid}
      home_gateway=${lib.escapeShellArg cfg.homeGateway}

      log() { echo "$(date '+%F %T') $*"; }

      if [ -e /tmp/tailscale-autoswitch.off ]; then
        exit 0
      fi

      state=$(${tailscale} status --json 2>/dev/null | awk -F'"' '/"BackendState"/ {print $4; exit}' || true)
      case "$state" in
        Running | Stopped) ;;
        *) exit 0 ;; # NeedsLogin, Starting, daemon not up yet: nothing to switch
      esac

      /usr/sbin/ipconfig setverbose 1 >/dev/null 2>&1 || true
      # Each lookup may legitimately fail (Wi-Fi off, no default route);
      # `|| true` keeps errexit/pipefail from ending the script early.
      wifi_dev=$(/usr/sbin/networksetup -listallhardwareports \
        | awk '/^Hardware Port: (Wi-Fi|AirPort)/ {getline; print $2; exit}' || true)
      ssid=""
      if [ -n "$wifi_dev" ]; then
        ssid=$(/usr/sbin/ipconfig getsummary "$wifi_dev" 2>/dev/null \
          | awk -F ' SSID : ' '/ SSID : / {print $2; exit}' || true)
      fi

      at_home=no
      how="ssid=''${ssid:-none}"
      if [ "$ssid" = "$home_ssid" ]; then
        at_home=yes
      elif [ -z "$ssid" ] || [ "$ssid" = "<redacted>" ]; then
        gateway=$(/sbin/route -n get default 2>/dev/null | awk '/gateway:/ {print $2; exit}' || true)
        how="$how gateway=''${gateway:-none}"
        if [ -n "$home_gateway" ] && [ "''${gateway:-}" = "$home_gateway" ]; then
          at_home=yes
        fi
      fi

      if [ "$at_home" = yes ] && [ "$state" = Running ]; then
        log "home ($how): tailscale down"
        ${tailscale} down
      elif [ "$at_home" = no ] && [ "$state" = Stopped ]; then
        log "away ($how): tailscale up"
        ${tailscale} up
      fi
    '';
  };
in {
  options.tailscale = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Tailscale VPN";
    };
    exitNode = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow this machine to act as a Tailscale exit node (NixOS only)";
    };
    authKeyFile = mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the Tailscale auth key (e.g. from ragenix; NixOS only)";
    };
    homeSsid = mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "CracoviaPany";
      description = ''
        macOS only: disconnect from the tailnet while on this Wi-Fi network and
        reconnect everywhere else. null keeps Tailscale always connected.
      '';
    };
    homeGateway = mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "10.40.0.1";
      description = ''
        Fallback for homeSsid when the SSID can't be read (macOS redaction, or
        Ethernet with Wi-Fi off): the default gateway that means "at home".
      '';
    };
  };

  config = mkIf cfg.enable (lib.mkMerge [
    (lib.optionalAttrs isDarwin {
      # tailscaled (open-source daemon, utun interface) as a launchd daemon,
      # plus /etc/resolver/ts.net for MagicDNS. Log in once with
      # `sudo tailscale up`; the switch below never logs in by itself.
      services.tailscale.enable = true;

      # The application firewall only waves through Apple-signed or
      # Developer-ID-signed binaries; Nix's tailscaled is ad-hoc signed, so
      # without this its WireGuard socket can't take incoming packets and
      # peers fall back to DERP relays. The path is the exact store path the
      # launchd daemon runs, re-added on every switch.
      system.activationScripts.postActivation.text = mkIf config.networking.applicationFirewall.enable (lib.mkAfter ''
        echo "allowing tailscaled through the application firewall..." >&2
        # A firewall hiccup shouldn't fail the whole switch; warn instead.
        /usr/libexec/ApplicationFirewall/socketfilterfw --add ${lib.getExe' config.services.tailscale.package "tailscaled"} >/dev/null \
          && /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp ${lib.getExe' config.services.tailscale.package "tailscaled"} >/dev/null \
          || echo "warning: could not allow tailscaled through the application firewall" >&2
      '');

      launchd.daemons.tailscale-home-switch = mkIf (cfg.homeSsid != null) {
        serviceConfig = {
          ProgramArguments = [(lib.getExe homeSwitch)];
          RunAtLoad = true;
          # resolv.conf is rewritten on every network change; the interval
          # catches anything that slips past it.
          WatchPaths = ["/var/run/resolv.conf"];
          StartInterval = 60;
          StandardOutPath = "/var/log/tailscale-home-switch.log";
          StandardErrorPath = "/var/log/tailscale-home-switch.log";
        };
      };
    })

    (lib.optionalAttrs (!isDarwin) {
      services.tailscale = {
        enable = true;
        useRoutingFeatures =
          if cfg.exitNode
          then "both"
          else "client";
        authKeyFile = lib.mkIf (cfg.authKeyFile != null) cfg.authKeyFile;
        # useRoutingFeatures only flips the kernel IP-forwarding sysctls; the
        # node still has to *advertise* itself as an exit node via `up`, or it
        # never appears as an exit option in the tailnet.
        extraUpFlags = lib.optionals cfg.exitNode ["--advertise-exit-node"];
        # Let the primary user run `tailscale up/down/logout/set` without
        # root. doas wants a password on a TTY, so re-authenticating a
        # logged-out node over SSH was otherwise impossible.
        extraSetFlags = ["--operator=${config.primaryUser.name}"];
      };

      # Ensure the autoconnect service waits for an active network connection.
      # Without this it starts before WiFi is up, loops in NoState for 90s, and times out.
      systemd.services.tailscaled-autoconnect = lib.mkIf (cfg.authKeyFile != null) {
        after = ["network-online.target"];
        wants = ["network-online.target"];
      };

      networking.firewall = {
        trustedInterfaces = ["tailscale0"];
        allowedUDPPorts = [config.services.tailscale.port];
      };
      # The upstream services.tailscale module already adds the CLI to
      # environment.systemPackages, so no need to duplicate it here.
    })
  ]);
}

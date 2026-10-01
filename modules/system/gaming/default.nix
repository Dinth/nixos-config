{
  config,
  lib,
  pkgs,
  home-manager,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.gaming;
  primaryUsername = config.primaryUser.name;

  # Unpacks Diablo/Hellfire and Heroes 3 data from the GOG installers on the
  # NAS into the per-user data dirs DevilutionX and VCMI read.
  gogGameData = pkgs.writeShellApplication {
    name = "gog-game-data";
    runtimeInputs = with pkgs; [coreutils findutils innoextract];
    text =
      builtins.replaceStrings
      ["@gogLibrary@" "@heroes3Language@"]
      [cfg.gogLibrary cfg.heroes3Language]
      (builtins.readFile ./gog-game-data.sh);
  };

  # VCMI mods, pinned to a commit of each repo's vcmi-1.7 branch (the branch
  # the launcher's mod repository tracks for VCMI 1.7.x). Keyed by VCMI mod
  # id, which is also the directory name under Mods/. Linked read-only from
  # the store, so the launcher cannot update them — bump rev + hash here.
  vcmiMod = repo: rev: hash:
    pkgs.fetchFromGitHub {
      owner = "vcmi-mods";
      inherit repo rev hash;
    };
  vcmiMods = {
    vcmi-extras = vcmiMod "vcmi-extras" "2fa21f9c24f2c14d2b9be87f445e839f76105e31" "sha256-sX7rxqdY+Cb1dQnAfXa7y2iCFjkD8rnOlrn6lTtUdHA=";
    hota = vcmiMod "horn-of-the-abyss" "947f620cde9f583357d4255e23da43d8564e2920" "sha256-oYx27NJcEg1P7tCZOuVeJTxN7zhsSsrJiz7yMcZjAaE=";
    wake-of-gods = vcmiMod "wake-of-gods" "e6b930f78ea05dc609ac3727fd927327a19658d6" "sha256-r+JrP363m+ycYMZVDH+HgsMUbuGy/PzPOT5mvqXpPm0=";
    tides-of-war = vcmiMod "tides-of-war" "de3df04dcb4c8e110a1d292525dcfe852fe5af89" "sha256-mMFzmZv07QXvfdQZqpcuKGuhdAZ7r+AH1h4F/QxwB4w=";
  };

  # Patches VCMI's own (mutable) settings files: updates off, mods enabled.
  vcmiConfig = pkgs.writeShellApplication {
    name = "vcmi-config";
    runtimeInputs = with pkgs; [coreutils jq];
    text = builtins.readFile ./vcmi-config.sh;
  };
in {
  options = {
    gaming = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable gaming features.";
      };
      gogLibrary = mkOption {
        type = lib.types.str;
        default = "/mnt/omv/Data/Games/GOG";
        description = "Directory of GOG offline installers (one folder per game) to import engine data from.";
      };
      heroes3Language = mkOption {
        type = lib.types.enum ["en" "pl"];
        default = "en";
        description = "Which Heroes 3 Complete installer to feed VCMI.";
      };
    };
  };
  config = mkIf cfg.enable {
    boot.kernelModules = ["ntsync"];

    # sched-ext userspace scheduler tuned for interactive/gaming latency:
    # LAVD (Latency-criticality Aware Virtual Deadline) prioritises the
    # wake-up chains games sit on over batch work. Needs CONFIG_SCHED_CLASS_EXT
    # (kernel ≥ 6.12 — gaming hosts run linuxPackages_latest). Reversible at
    # runtime with `systemctl stop scx` (falls back to EEVDF).
    services.scx = {
      enable = true;
      scheduler = "scx_lavd";
    };

    programs.gamemode = {
      enable = true;
      settings = {
        general.renice = 10;
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };
      };
    };

    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };

    # Allow processes in the gamemode group to renice down to -10 (matches
    # general.renice above). Without this, gamemoded logs:
    #   "RLIMIT_NICE is <= 20, unable to use setpriority safely"
    security.pam.loginLimits = [
      {
        domain = "@gamemode";
        item = "nice";
        type = "-";
        value = "-10";
      }
    ];

    environment.systemPackages = with pkgs; [
      (lutris.override {
        extraPkgs = pkgs:
          with pkgs; [
            wineWow64Packages.staging
            winetricks
            dxvk
            vkd3d
            vkd3d-proton
            gamescope
            gamemode
            mangohud
            umu-launcher
            cabextract
            p7zip
            samba
            gst_all_1.gstreamer
            gst_all_1.gst-plugins-base
            gst_all_1.gst-plugins-good
            gst_all_1.gst-plugins-bad
            gst_all_1.gst-libav
          ];
      })
      heroic
      protontricks
      protonplus
      winetricks
      umu-launcher
      wineWow64Packages.staging
      openttd-jgrpp # nixpkgs bundles OpenGFX/OpenSFX/OpenMSX base sets
      # Open-source engines; game data comes from the GOG installers.
      vcmi # Heroes 3 (RoE+AB+SoD data imported by gog-game-data below)
      devilutionx # Diablo + Hellfire (data imported by gog-game-data below)
      innoextract # unpack GOG setup_*.exe for the above
      gogGameData # manual re-run: gog-game-data
      (callPackage ./opentyrian2000-engaged.nix {})
    ];

    # Import the GOG data once per user. The script skips games already
    # imported and exits cleanly when the NAS is unreachable, so it just
    # retries on the next login. No RemainAfterExit: `systemctl --user start
    # gog-game-data` re-runs it after dropping a new installer on the NAS.
    home-manager.users.${primaryUsername} = {
      systemd.user.services.gog-game-data = {
        Unit.Description = "Import GOG game data for DevilutionX and VCMI";
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe gogGameData;
          TimeoutStartSec = "30min";
        };
        Install.WantedBy = ["default.target"];
      };

      # ~/.local/share/vcmi/Mods/<id> -> store.
      xdg.dataFile =
        lib.mapAttrs' (id: src: lib.nameValuePair "vcmi/Mods/${id}" {source = src;})
        vcmiMods;

      # settings.json and modSettings.json are rewritten by VCMI, so they are
      # patched in place instead of being replaced with store symlinks.
      home.activation.vcmiConfig = home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${lib.getExe vcmiConfig} ${lib.escapeShellArgs (lib.attrNames vcmiMods)}
      '';
    };
  };
}

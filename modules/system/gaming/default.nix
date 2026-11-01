{
  config,
  lib,
  pkgs,
  home-manager,
  isDarwin,
  ...
}: let
  inherit (lib) mkIf mkMerge mkOption;
  cfg = config.gaming;
  primaryUsername = config.primaryUser.name;

  # Unpacks Diablo/Hellfire and Heroes 3 data from the GOG installers on the
  # NAS into the per-user data dirs DamnationX/DevilutionX and VCMI read, and turns a
  # Steam install of Heroes 3 HD Edition into VCMI's "hd-edition" mod.
  gogGameData = pkgs.writeShellApplication {
    name = "gog-game-data";
    runtimeInputs = with pkgs; [coreutils findutils innoextract jq];
    text =
      builtins.replaceStrings
      ["@gogLibrary@" "@heroes3Language@"]
      [cfg.gogLibrary cfg.heroes3Language]
      (builtins.readFile ./gog-game-data.sh);
  };

  # macOS: same import, but the NAS is read over SSH (no sshfs without a
  # kernel extension) and both games keep their data in Application Support
  # (DevilutionX via SDL_GetPrefPath, VCMI hardcodes ~/Library/Application
  # Support/vcmi with config/ inside it). Same key + passphrase secret as the
  # desktop's sshfs mount of omv; the passphrase is fed through SSH_ASKPASS.
  macAppSupport = "$HOME/Library/Application Support";
  macVcmiEnv = ''VCMI_DATA_DIR="${macAppSupport}/vcmi" VCMI_CONFIG_DIR="${macAppSupport}/vcmi/config"'';
  gogAskpass = pkgs.writeShellScript "gog-ssh-askpass" ''
    exec ${pkgs.coreutils}/bin/cat ${config.age.secrets.id-ed25519-passphrase.path}
  '';
  gogGameDataMac = pkgs.writeShellScriptBin "gog-game-data" ''
    export XDG_DATA_HOME="${macAppSupport}"
    export GOG_REMOTE=${lib.escapeShellArg cfg.gogRemote.host}
    export GOG_DIR=${lib.escapeShellArg cfg.gogRemote.dir}
    export SSH_ASKPASS=${gogAskpass} SSH_ASKPASS_REQUIRE=force
    export GOG_SSH="/usr/bin/ssh -i ${config.age.secrets.id-ed25519.path} -o IdentitiesOnly=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new"
    ${lib.getExe gogGameData}
    # Enable a freshly imported mod without waiting for a rebuild.
    ${macVcmiEnv} ${lib.getExe vcmiConfig} ${vcmiPresets}
  '';

  # Vanilla OpenTTD and JGRPP both ship bin/openttd and openttd.desktop, so
  # expose JGRPP as `openttd-jgrpp` with its own launcher. Its data dir is
  # compiled in as an absolute store path, so a renamed symlink is enough.
  openttdJgrpp = pkgs.runCommand "openttd-jgrpp-renamed" {} ''
    mkdir -p $out/bin $out/share/applications
    ln -s ${lib.getExe' pkgs.openttd-jgrpp "openttd"} $out/bin/openttd-jgrpp
    sed 's/^Exec=openttd$/Exec=openttd-jgrpp/' \
      ${pkgs.openttd-jgrpp}/share/applications/openttd.desktop \
      > $out/share/applications/openttd-jgrpp.desktop
  '';

  # DamnationX does not support Hellfire yet (upstream issue #4; its launcher
  # always passes --diablo), so DevilutionX stays for Hellfire saves (*.hsv),
  # exposed only through its own "DevilutionX Hellfire" launcher.
  devilutionxHellfire = pkgs.runCommand "devilutionx-hellfire" {} ''
    mkdir -p $out/bin $out/share/applications
    ln -s ${lib.getExe pkgs.devilutionx} $out/bin/devilutionx
    ln -s ${pkgs.devilutionx}/share/applications/devilutionx-hellfire.desktop $out/share/applications/
    ln -s ${pkgs.devilutionx}/share/icons $out/share/icons
  '';

  # VCMI mods (mod id -> source), from the vcmi-mod-* flake inputs via
  # gamesOverlay. Linked read-only from the store, so the launcher cannot
  # update them — `nix flake update` does.
  inherit (pkgs) vcmiMods;

  # VCMI mod presets (switchable in the launcher) and the mods each enables.
  # Two presets because the mods do not all combine:
  #  - tears-of-ashan conflicts with wake-of-gods and tides-of-war;
  #  - tears-of-ashan needs hota.heroes3datapatch, which conflicts with
  #    hd-edition (the mod gog-game-data builds from the Steam HD Edition).
  # A mod listed here but not installed is skipped by vcmi-config.
  vcmiPresets = pkgs.writeText "vcmi-presets.json" (builtins.toJSON {
    default.mods = ["vcmi-extras" "hota" "wake-of-gods" "tides-of-war" "new-pavilion" "hd-edition"];
    tears-of-ashan = {
      mods = ["vcmi-extras" "hota" "market-of-time" "new-old-spells-plus" "tears-of-ashan" "new-pavilion"];
      # tears-of-ashan hard-depends on hota, so hota stays on; but its menu
      # theme conflicts with hota's, and VCMI resolves that in hota's favour,
      # leaving the preset looking like plain HotA. Swap the menus.
      submods = {
        hota.mainmenu = false;
        tears-of-ashan.toa-ashan-menu = true;
      };
    };
  });

  # Patches VCMI's own (mutable) settings files: updates off, presets set up.
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
      engines.enable = mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        defaultText = lib.literalExpression "config.gaming.enable";
        description = ''
          Game engines (OpenTTD, VCMI, DamnationX/DevilutionX, OpenTyrian, OpenSWOS) and
          the GOG data import that feeds them. Separate from `enable` so light
          hosts (the tablet) get these without Wine/Lutris/scx/gamemode.
        '';
      };
      gogLibrary = mkOption {
        type = lib.types.str;
        default = "/mnt/omv/Data/Games/GOG";
        description = "Directory of GOG offline installers (one folder per game) to import engine data from.";
      };
      gogRemote = {
        host = mkOption {
          type = lib.types.str;
          default = "root@10.10.1.13";
          description = "macOS only: SSH destination holding the GOG library (read with `gogRemote.dir`).";
        };
        dir = mkOption {
          type = lib.types.str;
          default = "/Data/Games/GOG";
          description = "macOS only: path of the GOG library on `gogRemote.host` (the desktop sees it as gogLibrary via sshfs).";
        };
      };
      heroes3Language = mkOption {
        type = lib.types.enum ["en" "pl"];
        default = "en";
        description = "Which Heroes 3 Complete installer to feed VCMI.";
      };
    };
  };
  config = mkMerge [
    # macOS: nixpkgs builds none of these games/launchers for Darwin, so they
    # come from Homebrew casks. nix-darwin only acts on homebrew.* once
    # homebrew.enable is set, so these lie dormant until then. JGRPP has no
    # cask (vanilla OpenTTD only), and the GOG data import below is NixOS-only
    # (it reads the NAS mount and writes Linux XDG paths).
    (lib.optionalAttrs isDarwin (mkMerge [
      (mkIf cfg.enable {
        homebrew.casks = ["steam" "heroic"];
      })
      (mkIf cfg.engines.enable {
        homebrew.casks = ["openttd" "vcmi" "devilutionx"];
        environment.systemPackages = [pkgs.innoextract gogGameDataMac];

        home-manager.users.${primaryUsername} = {
          # Import at login; skips games already imported and exits quietly
          # when omv isn't reachable (away from home), so it simply retries.
          # Re-run by hand with `gog-game-data`.
          launchd.agents.gog-game-data = {
            enable = true;
            config = {
              ProgramArguments = [(lib.getExe gogGameDataMac)];
              RunAtLoad = true;
              ProcessType = "Background";
              LowPriorityIO = true;
              StandardOutPath = "${config.users.users.${primaryUsername}.home}/Library/Logs/gog-game-data.log";
              StandardErrorPath = "${config.users.users.${primaryUsername}.home}/Library/Logs/gog-game-data.log";
            };
          };

          home.file =
            lib.mapAttrs' (id: src: lib.nameValuePair "Library/Application Support/vcmi/Mods/${id}" {source = src;})
            vcmiMods;

          home.activation.vcmiConfig = home-manager.lib.hm.dag.entryAfter ["linkGeneration"] ''
            run env ${macVcmiEnv} ${lib.getExe vcmiConfig} ${vcmiPresets}
          '';
        };
      })
    ]))

    (lib.optionalAttrs (!isDarwin) (mkIf cfg.enable {
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
      ];
    }))
    (lib.optionalAttrs (!isDarwin) (mkIf cfg.engines.enable {
      environment.systemPackages = with pkgs; [
        # nixpkgs bundles OpenGFX/OpenSFX/OpenMSX base sets with both
        openttd
        openttdJgrpp
        # Open-source engines; game data comes from the GOG installers.
        vcmi # Heroes 3 (RoE+AB+SoD data imported by gog-game-data below)
        # Diablo in DamnationX, Hellfire in DevilutionX; both read the data
        # imported by gog-game-data below and share one save folder (the Mac
        # uses DevilutionX for both)
        (callPackage ./damnationx.nix {})
        devilutionxHellfire
        innoextract # unpack GOG setup_*.exe for the above
        gogGameData # manual re-run: gog-game-data
        opentyrian2000-engaged
        openswos # SWOS 96/97 engine, 25/26 season data built in
      ];

      # Import the GOG data once per user. The script skips games already
      # imported and exits cleanly when the NAS is unreachable, so it just
      # retries on the next login. No RemainAfterExit: `systemctl --user start
      # gog-game-data` re-runs it after dropping a new installer on the NAS.
      home-manager.users.${primaryUsername} = {
        systemd.user.services.gog-game-data = {
          Unit.Description = "Import GOG/Steam game data for DamnationX and VCMI";
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe gogGameData;
            # Enable a freshly imported hd-edition mod without waiting for a rebuild.
            ExecStartPost = "${lib.getExe vcmiConfig} ${vcmiPresets}";
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
        # After linkGeneration so the Mods/ links above already exist: only
        # installed mods get enabled.
        home.activation.vcmiConfig = home-manager.lib.hm.dag.entryAfter ["linkGeneration"] ''
          run ${lib.getExe vcmiConfig} ${vcmiPresets}
        '';
      };
    }))
  ];
}

{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;

  # 1. Standard config (your existing colorful one)
  normalSettings = lib.mkMerge [
    (builtins.fromTOML (builtins.readFile
      "${pkgs.starship}/share/starship/presets/catppuccin-powerline.toml"))
    {
      palette = lib.mkForce "catppuccin_mocha";
    }
  ];

  # 2. MC Config: Structured, Informative, Monochrome
  mcSettings = {
    add_newline = false;
    # Layout: [user@host:dir] (git) duration char
    format = "$username$hostname$directory$git_branch$git_status$cmd_duration$character";
    right_format = "";

    # Ensure monochrome
    palette = "plain";
    palettes.plain = {};

    # [user@
    username = {
      show_always = true;
      style_user = "";
      style_root = "";
      # FIX: Escape the first [ with \\ so Starship sees it as literal
      format = "\\[[$user]($style)@";
    };

    # host:
    hostname = {
      ssh_only = false;
      style = "";
      format = "[$hostname]($style):";
    };

    # dir]
    directory = {
      truncation_length = 3;
      truncate_to_repo = false;
      style = "";
      # FIX: Escape the last ] with \\
      format = "[$path]($style)\\] ";
    };

    # (git:branch)
    git_branch = {
      symbol = "git:";
      style = "";
      # Optional: Escape parens just to be safe, though not strictly required
      format = "\\([$symbol$branch]($style)\\) ";
    };

    # ... rest remains the same
    git_status = {
      ahead = ">";
      behind = "<";
      diverged = "<>";
      modified = "*";
      untracked = "?";
      stashed = "$";
      deleted = "x";
      renamed = "r";
      style = "";
      format = "([$all_status$ahead_behind]($style) )";
    };

    cmd_duration = {
      min_time = 2000;
      style = "";
      format = "took [$duration]($style) ";
    };

    character = {
      success_symbol = "[>](bold)";
      error_symbol = "[x](bold)";
      format = "$symbol ";
    };
  };


  tomlFormat = pkgs.formats.toml {};
in {
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername} = { config, ... }: {
      programs.starship = {
        enable = true;
        settings = normalSettings;
      };

      # Generate the MC-specific config file
      xdg.configFile."starship-mc.toml".source =
        tomlFormat.generate "starship-mc.toml" mcSettings;

      # Switch config based on MC_SID environment variable
      programs.zsh.initContent = lib.mkOrder 500 ''
        if [[ -n "$MC_SID" ]]; then
          export STARSHIP_CONFIG="${config.xdg.configHome}/starship-mc.toml"
        else
          unset STARSHIP_CONFIG
        fi
      '';
    };
  };
}

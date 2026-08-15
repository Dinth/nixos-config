{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;

  mc_catppuccin = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "mc";
    rev = "23562615818820900c8967fb3fe2779182763f12";
    hash = "sha256-3qnbAt1AjyCNfoBT6vVGmAwNGYS2zOh81GRA7/shbVA=";
  };

  # Every helper under libexec/mc/ext.d shells out to bare command names
  # (`file`, `pdftotext`, `unzip`, ...). Rather than dumping all of them into
  # the system PATH, mc itself is wrapped with them so its handlers always
  # resolve; children inherit the wrapper's PATH.
  mcHelpers = with pkgs; [
    file # ext.d/* all start by running `file` on the target
    p7zip # 7z / 7za (archive.sh, misc.sh); cli.nix only ships 7zz
    unrar
    unzip
    zip
    cabextract
    zstd
    lz4
    lzop
    brotli
    squashfsTools
    cdrkit # isoinfo, for ISO9660 viewing
    poppler-utils # pdftotext
    catdoc # catdoc, xls2csv
    odt2txt
    w3m # web.sh html rendering
    exiftool # image.sh
    mediainfo # sound.sh / video.sh
    sqlite.bin
    groff # nroff, for man/troff pages
  ];

  mcPackage = pkgs.symlinkJoin {
    name = "mc-${pkgs.mc.version}-wrapped";
    paths = [pkgs.mc];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      for bin in mc mcedit mcview mcdiff; do
        [ -e "$out/bin/$bin" ] || continue
        wrapProgram "$out/bin/$bin" \
          --suffix PATH : ${lib.makeBinPath mcHelpers}
      done
    '';
  };

  extD = "${pkgs.mc}/libexec/mc/ext.d";

  openCmd =
    if pkgs.stdenv.isDarwin
    then "open %d/%p"
    else "${lib.getExe' pkgs.util-linux "setsid"} -f ${lib.getExe' pkgs.xdg-utils "xdg-open"} %d/%p";

  # mc reads mc.ext.ini with GKeyFile, which unescapes a value before handing
  # it to the regex engine, so a literal backslash has to be doubled on disk.
  # Nix strings below hold the plain pattern; this puts the file escaping back.
  escapeIniValue = lib.replaceStrings ["\\"] ["\\\\"];
  toExtIni = groups:
    lib.generators.toINI {} (lib.mapAttrs (_: lib.mapAttrs (_: escapeIniValue)) groups);

  # Rules layered on top of mc's own mc.ext.ini. They are emitted *before* the
  # stock rules because mc walks groups in file order and stops at the first
  # match. Group names must not collide with a stock one — GKeyFile folds
  # duplicate groups together and the later (stock) keys would win.
  extraExtGroups = {
    apk = {
      Type = "Android package \\(APK\\)";
      TypeIgnoreCase = "true";
      Open = "%cd %p/uzip://";
      View = "%view{ascii} ${extD}/archive.sh view zip";
    };
    squashfs = {
      Type = "^Squashfs filesystem";
      # No usqfs:// VFS ships with mc, so there is no Open here; listing the
      # image is the most that can be done without an external extfs handler.
      View = "%view{ascii} ${lib.getExe' pkgs.squashfsTools "unsquashfs"} -stat %f ; ${lib.getExe' pkgs.squashfsTools "unsquashfs"} -lls -d \"\" %f";
    };
    brotli = {
      Shell = ".br";
      ShellIgnoreCase = "true";
      # ext.d/archive.sh has no brotli case and there is no brotli:// VFS, so
      # drive the decompressor directly, the way stock does for gzip.
      Open = "${lib.getExe pkgs.brotli} -dc %f | %var{PAGER:more}";
      View = "%view{ascii} ${lib.getExe pkgs.brotli} -dc %f";
    };
    heic = {
      Shell = ".heic";
      ShellIgnoreCase = "true";
      Include = "image";
    };
    heif = {
      Shell = ".heif";
      ShellIgnoreCase = "true";
      Include = "image";
    };
    hif = {
      Shell = ".hif";
      ShellIgnoreCase = "true";
      Include = "image";
    };
  };

  # F3/F4 dispatch. mc asks mc.ext.ini for a "View" action on F3 and an "Edit"
  # action on F4 (src/filemanager/cmd.c); when neither the matched group nor
  # [Default] supplies one, it falls back to its own viewer/editor. So:
  #
  #   * no [Default] View       -> F3 always stays inside mc, binary included
  #   * [Default] Edit=xdg-open -> F4 on a binary hands off to the desktop
  #   * Edit= (empty) on a group stops the [Default] lookup for that group,
  #     which is how text keeps F4 inside mc (ext.c treats an empty value as
  #     "no action" *without* consulting [Default])
  #
  # A headless host has nothing to hand off to, so there the desktop actions
  # are left empty and everything stays in mc.
  guiHandoff = config.graphical.enable;

  defaultExtGroup.Default = {
    Open =
      if guiHandoff
      then openCmd
      else "";
    Edit =
      if guiHandoff
      then openCmd
      else "";
  };

  # Emitted after the stock rules, so these only catch what upstream has no
  # opinion about — plain text (.txt, .log, .conf, .nix, READMEs) that would
  # otherwise reach [Default] and get opened in a GUI editor. mc matches Type
  # against file(1) output, and every text file reports "... text".
  textHandoffGroups = {
    "text-stays-in-mc" = {
      Type = "text";
      Edit = "";
    };
    # Source files match a stock group that routes to Include/editor, which has
    # no Edit of its own — without this, F4 on a .c or .md would fall through to
    # [Default]. GKeyFile merges duplicate groups key by key, so stock's Open=
    # survives and only Edit is added.
    "Include/editor".Edit = "";
  };

  mcExtIni =
    pkgs.runCommandLocal "mc.ext.ini" {
      extra = toExtIni extraExtGroups;
      handoff = toExtIni textHandoffGroups;
      fallback = toExtIni defaultExtGroup;
      passAsFile = ["extra" "handoff" "fallback"];
    } ''
      {
        echo '# Generated by nixos-config modules/apps/mc — do not edit.'
        echo
        cat "$extraPath"
        # Stock rules verbatim, so they track the mc package on every bump. The
        # stock [Default] group is empty and terminates the file; drop it so the
        # fallback below is the only one.
        sed '/^\[Default\]/,$d' ${pkgs.mc}/etc/mc/mc.ext.ini
        cat "$handoffPath"
        cat "$fallbackPath"
      } > $out
    '';

  # Stock filehighlight.ini's extension lists predate most of this stack —
  # [source] has no nix/toml/yaml/rs/lua, so a config checkout renders
  # monochrome. mc replaces the file wholesale, so rather than restating
  # upstream's lists these are appended to whatever it ships.
  #
  # `ts` is deliberately absent: it is already claimed by [media] for transport
  # streams, and [source] sorts first, so adding it would recolour those.
  extraHighlightExtensions = {
    source = ["nix" "toml" "yaml" "yml" "jsonc" "rs" "lua" "zig" "vim" "fish" "zsh" "nu" "kt" "dart" "ex" "exs" "clj" "cljs" "scala" "groovy" "tf" "hcl" "proto" "cmake" "gradle"];
    doc = ["rst" "adoc" "asciidoc" "org" "typ" "epub" "mobi" "djvu" "csv" "tsv" "log" "conf" "cfg" "ini" "service" "timer" "socket" "desktop"];
    archive = ["br" "iso" "img" "sfs" "squashfs" "whl" "jar" "war" "ear" "dmg" "pkg"];
    database = ["sqlite" "sqlite3" "db3" "duckdb"];
  };

  mcFileHighlight =
    pkgs.runCommandLocal "filehighlight.ini" {
      spec =
        lib.concatStringsSep "\n"
        (lib.mapAttrsToList (g: exts: "${g}=${lib.concatStringsSep ";" exts}") extraHighlightExtensions);
      passAsFile = ["spec"];
    } ''
      awk -v specfile="$specPath" '
        BEGIN {
          while ((getline line < specfile) > 0) {
            eq = index(line, "=")
            if (eq > 0) add[substr(line, 1, eq - 1)] = substr(line, eq + 1)
          }
        }
        /^\[/ { group = substr($0, 2, length($0) - 2) }
        /^[[:space:]]*extensions=/ && (group in add) { print $0 ";" add[group]; next }
        { print }
      ' ${pkgs.mc}/etc/mc/filehighlight.ini > $out
    '';

  # F2 user menu. Stock mc.menu is a museum piece — uudecoding Usenet articles,
  # latex + xdvi, "copy file to remote host" — so it is replaced outright.
  # shell_patterns=0 puts the conditions below into regex mode.
  mcMenu = pkgs.writeText "mc.menu" ''
    shell_patterns=0

    + t r
    x       Extract archive here
            ${lib.getExe' pkgs.unar "unar"} -D -f %f

    + t r
    X       Extract archive into a subdirectory
            ${lib.getExe' pkgs.unar "unar"} -f %f

    + t t | t r
    z       Compress selection to tar.zst
            NAME=%{Archive name (without extension)}
            tar --use-compress-program=${lib.getExe' pkgs.zstd "zstd"} -cf "$NAME.tar.zst" %s && echo "$NAME.tar.zst created."

    + t t | t r
    Z       Compress selection to zip
            NAME=%{Archive name (without extension)}
            ${lib.getExe' pkgs.zip "zip"} -r "$NAME.zip" %s

    + t t | t r
    s       sha256sum of selection
            %view{ascii} sha256sum %s

    + f \.nix$ & t r
    n       Format this file with alejandra
            ${lib.getExe pkgs.alejandra} %f

    + f \.nix$ & t r
    p       Syntax-check this file (nix-instantiate --parse)
            %view{ascii} nix-instantiate --parse %f

    g       git status here
            %view{ascii} ${lib.getExe pkgs.git} -C %d status -sb

    G       git diff here
            %view{ascii} ${lib.getExe pkgs.git} -C %d diff --stat

    u       Disk usage here, largest first
            %view{ascii} du -sh %d/* 2>/dev/null | sort -rh
  '';

  # Ctrl-\ hotlist. mc speaks sh:// (FISH over SSH) natively, so the remote
  # entries browse as ordinary panels using the keys from modules/apps/ssh.
  # Managing this declaratively means the interactive "Add to hotlist" can no
  # longer write to it — save_hotlist() fopen()s the file and it is a read-only
  # store symlink — so new bookmarks belong in this list.
  mcHotlist = pkgs.writeText "hotlist" ''
    GROUP "NixOS"
        ENTRY "nixos-config" URL "/home/${primaryUsername}/Documents/nixos-config"
        ENTRY "/etc/nixos" URL "/etc/nixos"
        ENTRY "current system" URL "/run/current-system"
    ENDGROUP
    GROUP "Mounts"
        ENTRY "omv Data" URL "/mnt/omv/Data"
        ENTRY "omv opt/docker" URL "/mnt/omv/opt/docker"
        ENTRY "Home Assistant config" URL "/mnt/haos"
    ENDGROUP
    GROUP "Hosts (SSH)"
        ENTRY "omv 10.10.1.13 opt/docker" URL "sh://root@10.10.1.13/opt/docker"
        ENTRY "omv 10.10.1.13 /" URL "sh://root@10.10.1.13/"
        ENTRY "r230-nixos 10.10.1.12" URL "sh://${primaryUsername}@10.10.1.12/"
        ENTRY "r230-proxmox 10.10.1.16" URL "sh://dinth@10.10.1.16/"
        ENTRY "wazuh 10.10.1.18" URL "sh://wazuh-user@10.10.1.18/"
    ENDGROUP
  '';

  mcHomeConfig = {
    xdg.dataFile."mc/skins/catppuccin.ini".source = "${mc_catppuccin}/catppuccin.ini";

    xdg.configFile."mc/filehighlight.ini".source = mcFileHighlight;
    xdg.configFile."mc/menu".source = mcMenu;
    xdg.configFile."mc/hotlist".source = mcHotlist;

    # mc replaces its extension file wholesale rather than merging, and
    # home-manager's extensionSettings renders through `toINI` which sorts
    # groups alphabetically. mc needs the stock order (filename rules before
    # `file`-magic rules), so the file is assembled directly instead.
    xdg.configFile."mc/mc.ext.ini".source = mcExtIni;

    programs.mc = {
      enable = true;
      package = mcPackage;
      settings = {
        Midnight-Commander = {
          verbose = true;
          shell_patterns = true;
          auto_save_setup = false;
          preallocate_space = false;
          auto_menu = false;
          use_internal_view = true;
          use_internal_edit = false;
          clear_before_exec = true;
          confirm_delete = true;
          confirm_overwrite = true;
          confirm_execute = false;
          confirm_history_cleanup = true;
          confirm_exit = false;
          confirm_directory_hotlist_delete = false;
          confirm_view_dir = false;
          safe_delete = false;
          safe_overwrite = false;
          use_8th_bit_as_meta = false;
          mouse_move_pages_viewer = true;
          mouse_close_dialog = false;
          fast_refresh = false;
          drop_menus = false;
          wrap_mode = true;
          old_esc_mode = true;
          cd_symlinks = false;
          show_all_if_ambiguous = false;
          use_file_to_guess_type = true;
          alternate_plus_minus = false;
          only_leading_plus_minus = true;
          show_output_starts_shell = false;
          xtree_mode = false;
          file_op_compute_totals = true;
          classic_progressbar = true;
          use_netrc = false;
          ftpfs_always_use_proxy = false;
          ftpfs_use_passive_connections = true;
          ftpfs_use_passive_connections_over_proxy = false;
          ftpfs_use_unix_list_options = true;
          ftpfs_first_cd_then_ls = true;
          ignore_ftp_chattr_errors = true;
          editor_backspace_through_tabs = false;
          editor_option_save_position = true;
          editor_option_auto_para_formatting = false;
          editor_option_typewriter_wrap = false;
          editor_edit_confirm_save = true;
          editor_syntax_highlighting = true;
          editor_persistent_selections = true;
          editor_drop_selection_on_copy = true;
          editor_cursor_beyond_eol = false;
          editor_cursor_after_inserted_block = false;
          editor_visible_tabs = true;
          editor_visible_spaces = true;
          editor_line_state = false;
          editor_simple_statusbar = false;
          editor_check_new_line = false;
          editor_show_right_margin = false;
          editor_group_undo = false;
          editor_state_full_filename = false;
          editor_ask_filename_before_edit = false;
          nice_rotating_dash = true;
          shadows = true;
          mcview_remember_file_position = false;
          auto_fill_mkdir_name = true;
          copymove_persistent_attr = true;
          pause_after_run = 2;
          mouse_repeat_rate = 100;
          double_click_speed = 250;
          old_esc_mode_timeout = 1000000;
          max_dirt_limit = 10;
          num_history_items_recorded = 60;
          vfs_timeout = 60;
          ftpfs_directory_timeout = 900;
          ftpfs_retry_seconds = 30;
          shell_directory_timeout = 900;
          editor_tab_spacing = 2;
          editor_fill_tabs_with_spaces = true;
          editor_return_does_auto_indent = true;
          editor_fake_half_tabs = false;
          editor_word_wrap_line_length = 100;
          editor_option_save_mode = 0;
          editor_backup_extension = "~";
          editor_filesize_threshold = "64M";
          editor_stop_format_chars = "-+*\\,.;:&>";
          skin = "catppuccin";
        };
        Layout = {
          output_lines = 0;
          top_panel_size = 0;
          message_visible = true;
          keybar_visible = true;
          xterm_title = true;
          command_prompt = true;
          menubar_visible = true;
          free_space = true;
          horizontal_split = false;
          vertical_equal = true;
          horizontal_equal = true;
        };
        Misc = {
          timeformat_recent = "%b %d %H:%M";
          timeformat_old = "%b %d  %Y";
          ftp_proxy_host = "gate";
          ftpfs_password = "anonymous@";
          display_codepage = "UTF-8";
          # Left off deliberately: any non-empty value other than "off" turns
          # enca autodetection on and feeds it this string as the language.
          autodetect_codeset = "off";
          clipboard_store =
            if config.graphical.enable
            then "${pkgs.wl-clipboard}/bin/wl-copy"
            else null;
          clipboard_paste =
            if config.graphical.enable
            then "${pkgs.wl-clipboard}/bin/wl-paste"
            else null;
        };
        Panels = {
          show_mini_info = true;
          kilobyte_si = false;
          mix_all_files = false;
          show_backups = true;
          show_dot_files = true;
          fast_reload = false;
          fast_reload_msg_shown = false;
          mark_moves_down = true;
          reverse_files_only = false;
          auto_save_setup_panels = false;
          navigate_with_arrows = false;
          panel_scroll_pages = true;
          panel_scroll_center = false;
          mouse_move_pages = true;
          filetype_mode = true;
          permission_mode = false;
          torben_fj_mode = false;
          quick_search_mode = 2;
          select_flags = 2;
        };
      };
      # Merged over mc's built-in keymap, so only the listed actions change.
      # ctrl-shift-r is indistinguishable from ctrl-r at the terminal, so the
      # default has to stay listed or panel reread becomes unreachable.
      keymapSettings.panel.Reread = "ctrl-r;ctrl-shift-r";
    };
  };

  # Quitting mc leaves the shell in the directory mc was last showing. mc ships
  # libexec/mc/mc-wrapper.sh for this, but it hardcodes the *unwrapped* mc
  # binary and would bypass the helper PATH above, so drive `mc -P` directly.
  # Independent of the MC_SID handling in modules/apps/starship, which is about
  # the prompt inside mc's subshell.
  mcCdOnExit = lib.mkOrder 1200 ''
    mc() {
      local pwd_file ret dir
      pwd_file=$(mktemp "''${TMPDIR:-/tmp}/mc.pwd.XXXXXX") || return 1
      command mc -P "$pwd_file" "$@"
      ret=$?
      if [[ -r $pwd_file ]]; then
        dir=$(<"$pwd_file")
        [[ -n $dir && -d $dir && $dir != $PWD ]] && cd -- "$dir"
      fi
      rm -f -- "$pwd_file"
      return $ret
    }
  '';
in {
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs;
      [
        file # also useful outside mc, and nothing else in the tree ships it
        p7zip
        unrar
        unzip
        zip
        mediainfo
      ]
      ++ lib.optionals config.graphical.enable [
        wl-clipboard
      ];
    home-manager.users.${primaryUsername} = lib.mkMerge [
      mcHomeConfig
      {programs.zsh.initContent = mcCdOnExit;}
    ];
    # root has no home-manager zsh here, so it gets the files but not the
    # shell function.
    home-manager.users.root = mcHomeConfig;
  };
}

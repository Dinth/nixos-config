{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;

  mc_catppuccin = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "mc";
    rev = "23562615818820900c8967fb3fe2779182763f12";
    hash = "sha256-3qnbAt1AjyCNfoBT6vVGmAwNGYS2zOh81GRA7/shbVA=";
  };
  openCmd = if pkgs.stdenv.isDarwin then
    "open %d/%p"
  else
    "${lib.getExe pkgs.detach} ${lib.getExe' pkgs.xdg-utils "xdg-open"} %d/%p";
in
{
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      p7zip unrar unzip zip
      ripgrep
      fd
      jq
      mediainfo
    ] ++ lib.optionals config.graphical.enable [
      wl-clipboard
    ];
    home-manager.users.${primaryUsername} = {
      home.file."/.local/share/mc/skins/catppuccin.ini" = {
        source = "${mc_catppuccin}/catppuccin.ini";
      };
      programs.mc = {
        enable = true;
        settings = {
    #   xdg.configFile."mc.ini".text = lib.generators.toINI { } {
          Midnight-Commander = {
            verbose = true;
            shell_patterns = true;
            auto_save_setup = false;
            preallocate_space = false;
            auto_menu = false;
            use_internal_view = true;
            use_internal_edit = true;
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
            mcview_eof = null;
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
            autodetect_codeset = null;
            clipboard_store = if config.graphical.enable
              then "${pkgs.wl-clipboard}/bin/wl-copy"
              else null;
            clipboard_paste = if config.graphical.enable
              then "${pkgs.wl-clipboard}/bin/wl-paste"
              else null;
          };
          Colors = {
            base_color = null;
            alacritty = null;
            color_terminals = null;
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
        extensionSettings = {
          "mc.ext.ini" = {
            "version" = "4.0";
          };
          "gitfs changeset" = {
            "regex" = "^\\[git\\]";
            "open" = "%cd %p/changesetfs://";
            "view" = "%cd %p/patchsetfs://";
          };
          "tar.gzip" = {
            "regex" = "\\.t([gp]?z|ar\\.g?[zZ])$";
            "include" = "tar.gz";
          };
          "gem" = {
            "shell" = ".gem";
            "include" = "tar.gz";
          };
          "crate" = {
            "shell" = ".crate";
            "include" = "tar.gz";
          };
          "tar.bzip" = {
            "shell" = ".tar.bz";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view tar.bzip";
          };
          "tar.bzip2" = {
            "regex" = "\\.t(ar\\.bz2|bz2?|b2)$";
            "open" = "%cd %p/utar://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view tar.bzip2";
          };
          "tar.lzma" = {
            "regex" = "\\.t(ar\\.lzma|lz)$";
            "open" = "%cd %p/utar://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view tar.lzma";
          };
          "tar.lz" = {
            "shell" = ".tar.lz";
            "open" = "%cd %p/utar://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view tar.lz";
          };
          "tar.lz4" = {
            "regex" = "\\.t(ar\\.lz4|lz4)$";
            "open" = "%cd %p/utar://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view tar.lz4";
          };
          "tar.lzo" = {
            "regex" = "\\.t(ar\\.lzo|zo)$";
            "open" = "%cd %p/utar://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view tar.lzo";
          };
          "tar.xz" = {
            "regex" = "\\.t(ar\\.xz|xz)$";
            "open" = "%cd %p/utar://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view tar.xz";
          };
          "tar.zst" = {
            "regex" = "\\.t(ar\\.zst|zst)$";
            "open" = "%cd %p/utar://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view tar.zst";
          };
          "tar.F" = {
            "shell" = ".tar.F";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view tar.F";
          };
          "tar.qpr" = {
            "regex" = "\\.qp[rk]$";
            "open" = "%cd %p/utar://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view tar.qpr";
          };
          "tar" = {
            "shell" = ".tar";
            "shellignorecase" = "true";
            "open" = "%cd %p/utar://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view tar";
          };
          "arj" = {
            "regex" = "\\.a(rj|[0-9][0-9])$";
            "regexignorecase" = "true";
            "open" = "%cd %p/uarj://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view arj";
          };
          "cab" = {
            "shell" = ".cab";
            "shellignorecase" = "true";
            "open" = "%cd %p/ucab://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view cab";
          };
          "ha" = {
            "shell" = ".ha";
            "shellignorecase" = "true";
            "open" = "%cd %p/uha://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view ha";
          };
          "rar" = {
            "regex" = "\\.r(ar|[0-9][0-9])$";
            "regexignorecase" = "true";
            "open" = "%cd %p/urar://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view rar";
          };
          "alz" = {
            "shell" = ".alz";
            "shellignorecase" = "true";
            "open" = "%cd %p/ualz://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view alz";
          };
          "cpio.Z" = {
            "shell" = ".cpio.Z";
            "open" = "%cd %p/ucpio://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view cpio.z";
          };
          "cpio.lz" = {
            "shell" = ".cpio.lz";
            "open" = "%cd %p/ucpio://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view cpio.lz";
          };
          "cpio.lz4" = {
            "shell" = ".cpio.lz4";
            "open" = "%cd %p/ucpio://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view cpio.lz4";
          };
          "cpio.lzo" = {
            "shell" = ".cpio.lzo";
            "open" = "%cd %p/ucpio://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view cpio.lzo";
          };
          "cpio.xz" = {
            "shell" = ".cpio.xz";
            "open" = "%cd %p/ucpio://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view cpio.xz";
          };
          "cpio.zst" = {
            "shell" = ".cpio.zst";
            "open" = "%cd %p/ucpio://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view cpio.zst";
          };
          "cpio.gz" = {
            "shell" = ".cpio.gz";
            "open" = "%cd %p/ucpio://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view cpio.gz";
          };
          "cpio" = {
            "shell" = ".cpio";
            "shellignorecase" = "true";
            "include" = "cpio";
          };
          "initrd" = {
            "regex" = "^(initramfs.*\\.img|initrd(-.+)?\\.img(-.+)?)$";
            "include" = "cpio";
          };
          "7zip" = {
            "shell" = ".7z";
            "shellignorecase" = "true";
            "open" = "%cd %p/u7z://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view 7z";
          };
          "patch" = {
            "regex" = "\\.(diff|patch)$";
            "open" = "%cd %p/patchfs://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view cat";
          };
          "patch.gz" = {
            "regex" = "\\.(diff|patch)\\.(gz|Z)$";
            "open" = "%cd %p/patchfs://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view gz";
          };
          "patch.bz2" = {
            "regex" = "\\.(diff|patch)\\.bz2$";
            "open" = "%cd %p/patchfs://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view bz2";
          };
          "patch.xz" = {
            "regex" = "\\.(diff|patch)\\.xz$";
            "open" = "%cd %p/patchfs://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view xz";
          };
          "patch.zst" = {
            "regex" = "\\.(diff|patch)\\.zst$";
            "open" = "%cd %p/patchfs://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view zst";
          };
          "ls-lR" = {
            "regex" = "(^|\\.)ls-?lR(\\.gz|Z|bz2)$";
            "open" = "%cd %p/lslR://";
          };
          "trpm" = {
            "shell" = ".trpm";
            "open" = "%cd %p/trpm://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/package.sh view trpm";
          };
          "src.rpm" = {
            "regex" = "\\.(src\\.rpm|spm)$";
            "open" = "%cd %p/rpm://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/package.sh view src.rpm";
          };
          "rpm" = {
            "shell" = ".rpm";
            "open" = "%cd %p/rpm://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/package.sh view rpm";
          };
          "deb" = {
            "regex" = "\\.u?deb$";
            "open" = "%cd %p/deb://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/package.sh view deb";
          };
          "dpkg" = {
            "shell" = ".debd";
            "open" = "%cd %p/debd://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/package.sh view debd";
          };
          "apt" = {
            "shell" = ".deba";
            "open" = "%cd %p/deba://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/package.sh view deba";
          };
          "ISO9660" = {
            "shell" = ".iso";
            "shellignorecase" = "true";
            "open" = "%cd %p/iso9660://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view iso9660";
          };
          "ar" = {
            "regex" = "\\.s?a$";
            "open" = "%cd %p/uar://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view ar";
          };
          "gplib" = {
            "shell" = ".lib";
            "shellignorecase" = "true";
            "open" = "%cd %p/ulib://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view lib";
          };
          "C/C++" = {
            "regex" = "\\.(c|cc|cpp|cxx|c\\+\\+)$";
            "regexignorecase" = "true";
            "include" = "editor";
          };
          "C/C++ header" = {
            "regex" = "\\.(h|hh|hpp|hxx|h\\+\\+)$";
            "regexignorecase" = "true";
            "include" = "editor";
          };
          "Fortran" = {
            "shell" = ".f";
            "shellignorecase" = "true";
            "include" = "editor";
          };
          "Assembler" = {
            "regex" = "\\.(s|asm)$";
            "regexignorecase" = "true";
            "include" = "editor";
          };
          "Typescript" = {
            "shell" = ".ts";
            "shellignorecase" = "true";
            "type" = "^Java source";
            "include" = "editor";
          };
          "so" = {
            "regex" = "\\.(so|so\\.[0-9\\.]*)$";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view so";
          };
          "dylib" = {
            "regex" = "\\.(dylib|dylib\\.[0-9\\.]*)$";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view dylib";
          };
          "info-by-shell" = {
            "shell" = ".info";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open info";
          };
          "3gp" = {
            "shell" = ".3gp";
            "shellignorecase" = "true";
            "type" = "^ISO Media.*3GPP";
            "include" = "video";
          };
          "read.me" = {
            "shell" = "read.me";
            "open" = "";
            "view" = "";
          };
          "troff" = {
            "shell" = ".me";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open nroff.me %var{PAGER:more}";
            "view" = "%view{ascii,nroff} ${pkgs.mc}/libexec/mc/ext.d/text.sh view nroff.me %var{PAGER:more}";
          };
          "roff with ms macros" = {
            "shell" = ".ms";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open nroff.ms %var{PAGER:more}";
            "view" = "%view{ascii,nroff} ${pkgs.mc}/libexec/mc/ext.d/text.sh view nroff.ms %var{PAGER:more}";
          };
          "man.lz" = {
            "regex" = "([^0-9]|^[^\\.]*)\\.([1-9][A-Za-z]*|[ln])\\.lz$";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open man.lz %var{PAGER:more}";
            "view" = "%view{ascii,nroff} ${pkgs.mc}/libexec/mc/ext.d/text.sh view man.lz %var{PAGER:more}";
          };
          "man.lz4" = {
            "regex" = "([^0-9]|^[^\\.]*)\\.([1-9][A-Za-z]*|[ln])\\.lz4$";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open man.lz4 %var{PAGER:more}";
            "view" = "%view{ascii,nroff} ${pkgs.mc}/libexec/mc/ext.d/text.sh view man.lz4 %var{PAGER:more}";
          };
          "man.lzma" = {
            "regex" = "([^0-9]|^[^\\.]*)\\.([1-9][A-Za-z]*|[ln])\\.lzma$";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open man.lzma %var{PAGER:more}";
            "view" = "%view{ascii,nroff} ${pkgs.mc}/libexec/mc/ext.d/text.sh view man.lzma %var{PAGER:more}";
          };
          "man.lzo" = {
            "regex" = "([^0-9]|^[^\\.]*)\\.([1-9][A-Za-z]*|[ln])\\.lzo$";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open man.lzo %var{PAGER:more}";
            "view" = "%view{ascii,nroff} ${pkgs.mc}/libexec/mc/ext.d/text.sh view man.lzo %var{PAGER:more}";
          };
          "man.xz" = {
            "regex" = "([^0-9]|^[^\\.]*)\\.([1-9][A-Za-z]*|[ln])\\.xz$";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open man.xz %var{PAGER:more}";
            "view" = "%view{ascii,nroff} ${pkgs.mc}/libexec/mc/ext.d/text.sh view man.xz %var{PAGER:more}";
          };
          "man.zst" = {
            "regex" = "([^0-9]|^[^\\.]*)\\.([1-9][A-Za-z]*|[ln])\\.zst$";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open man.zst %var{PAGER:more}";
            "view" = "%view{ascii,nroff} ${pkgs.mc}/libexec/mc/ext.d/text.sh view man.zst %var{PAGER:more}";
          };
          "pod" = {
            "shell" = ".pod";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open pod %var{PAGER:more}";
            "view" = "%view{ascii,nroff} ${pkgs.mc}/libexec/mc/ext.d/text.sh view pod %var{PAGER:more}";
          };
          "chm" = {
            "shell" = ".chm";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open chm";
          };
          "svg" = {
            "shell" = ".svg";
            "shellignorecase" = "true";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/image.sh view svg";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/image.sh open svg";
          };
          "xbm" = {
            "shell" = ".xbm";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/image.sh open xbm";
          };
          "xcf" = {
            "shell" = ".xcf";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/image.sh open xcf";
          };
          "xpm" = {
            "shell" = ".xpm";
            "shellignorecase" = "true";
            "include" = "image";
          };
          "ico" = {
            "shell" = ".ico";
            "shellignorecase" = "true";
            "include" = "image";
          };
          "webp" = {
            "shell" = ".webp";
            "shellignorecase" = "true";
            "include" = "image";
          };
          "avif" = {
            "shell" = ".avif";
            "shellignorecase" = "true";
            "include" = "image";
          };
          "heic" = {
            "shell" = ".heic";
            "shellignorecase" = "true";
            "include" = "image";
          };
          "heif" = {
            "shell" = ".heif";
            "shellignorecase" = "true";
            "include" = "image";
          };
          "hif" = {
            "shell" = ".hif";
            "shellignorecase" = "true";
            "include" = "image";
          };
          "sound" = {
            "regex" = "\\.(wav|snd|voc|au|smp|aiff|snd|m4a|ape|aac|wv|spx|flac)$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/sound.sh open common";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/sound.sh view common";
          };
          "mod" = {
            "regex" = "\\.(mod|s3m|xm|it|mtm|669|stm|ult|far)$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/sound.sh open mod";
          };
          "wav22" = {
            "shell" = ".waw22";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/sound.sh open wav22";
          };
          "mp3" = {
            "shell" = ".mp3";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/sound.sh open mp3";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/sound.sh view mp3";
          };
          "ogg" = {
            "regex" = "\\.og[gax]$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/sound.sh open ogg";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/sound.sh view ogg";
          };
          "opus" = {
            "shell" = ".opus";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/sound.sh open opus";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/sound.sh view opus";
          };
          "midi" = {
            "regex" = "\\.(midi?|rmid?)$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/sound.sh open midi";
          };
          "wma" = {
            "shell" = ".wma";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/sound.sh open wma";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/sound.sh view wma";
          };
          "playlist" = {
            "regex" = "\\.(m3u|pls)$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/sound.sh open playlist";
          };
          "avi" = {
            "shell" = ".avi";
            "shellignorecase" = "true";
            "include" = "video";
          };
          "asf" = {
            "regex" = "\\.as[fx]$";
            "regexignorecase" = "true";
            "include" = "video";
          };
          "divx" = {
            "shell" = ".divx";
            "shellignorecase" = "true";
            "include" = "video";
          };
          "mkv" = {
            "shell" = ".mkv";
            "shellignorecase" = "true";
            "include" = "video";
          };
          "mov" = {
            "regex" = "\\.(mov|qt)$";
            "regexignorecase" = "true";
            "include" = "video";
          };
          "mp4" = {
            "regex" = "\\.(mp4|m4v|mpe?g)$";
            "regexignorecase" = "true";
            "include" = "video";
          };
          "mts" = {
            "shell" = ".mts";
            "shellignorecase" = "true";
            "include" = "video";
          };
          "ts" = {
            "shell" = ".ts";
            "shellignorecase" = "true";
            "include" = "video";
          };
          "bob" = {
            "shell" = ".vob";
            "shellignorecase" = "true";
            "include" = "video";
          };
          "wmv" = {
            "shell" = ".wmv";
            "shellignorecase" = "true";
            "include" = "video";
          };
          "fli" = {
            "regex" = "\\.fl[icv]$";
            "regexignorecase" = "true";
            "include" = "video";
          };
          "ogv" = {
            "shell" = ".ogv";
            "shellignorecase" = "true";
            "include" = "video";
          };
          "realaudio" = {
            "regex" = "\\.ra?m$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/video.sh open ram";
          };
          "webm-by-shell" = {
            "shell" = ".webm";
            "shellignorecase" = "true";
            "include" = "video";
          };
          "html" = {
            "regex" = "\\.s?html?$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/web.sh open html";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/web.sh view html";
          };
          "StarOffice-5.2" = {
            "shell" = ".sdw";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open ooffice";
          };
          "OpenOffice.org" = {
            "regex" = "\\.(odt|fodt|ott|sxw|stw|ods|fods|ots|sxc|stc|odp|fodp|otp|sxi|sti|odg|fodg|otg|sxd|std|odb|odf|sxm|odm|sxg)$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open ooffice";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/doc.sh view odt";
          };
          "AbiWord" = {
            "shell" = ".abw";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open abw";
          };
          "Gnumeric" = {
            "shell" = ".gnumeric";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open gnumeric";
          };
          "rtf" = {
            "shell" = ".rtf";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open msdoc";
          };
          "msdoc-by-shell" = {
            "regex" = "\\.(do[ct]|wri|docx)$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open msdoc";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/doc.sh view msdoc";
          };
          "msxls-by-shell" = {
            "regex" = "\\.(xl[sw]|xlsx)$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open msxls";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/doc.sh view msxls";
          };
          "msppt" = {
            "regex" = "\\.(pp[ts]|pptx)$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open msppt";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/doc.sh view msppt";
          };
          "dvi" = {
            "shell" = ".dvi";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open dvi";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/doc.sh view dvi";
          };
          "tex" = {
            "shell" = ".tex";
            "shellignorecase" = "true";
            "include" = "editor";
          };
          "markdown" = {
            "regex" = "\\.mk?d$";
            "regexignorecase" = "true";
            "include" = "editor";
          };
          "djvu" = {
            "regex" = "\\.djvu?$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open djvu";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/doc.sh view djvu";
          };
          "cbr" = {
            "regex" = "\\.cb[zr]$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open comic";
          };
          "ebook" = {
            "regex" = "\\.(epub|mobi|fb2)$";
            "regexignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open ebook";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/doc.sh view ebook";
          };
          "javaclass" = {
            "shell" = ".class";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view javaclass";
          };
          "Imakefile" = {
            "shell" = "Imakefile";
            "open" = "xmkmf -a";
          };
          "Makefile.pl" = {
            "regex" = "^Makefile\\.(PL|pl)$";
            "open" = "%var{PERL:perl} %f";
          };
          "Makefile" = {
            "regex" = "^[Mm]akefile$";
            "open" = "make -f %f %{Enter parameters}";
          };
          "dbf" = {
            "shell" = ".dbf";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/misc.sh open dbf";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view dbf";
          };
          "rexx" = {
            "regex" = "\\.(rexx?|cmd)$";
            "open" = "rexx %f %{Enter parameters};echo \"Press ENTER\";read y";
          };
          "d64" = {
            "shell" = ".d64";
            "shellignorecase" = "true";
            "open" = "%cd %p/uc1541://";
            "view" = "%view{ascii} c1541 %f -list";
          };
          "glade" = {
            "shell" = ".glade";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/misc.sh open glade";
          };
          "mo" = {
            "regex" = "\\.g?mo$";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view mo";
          };
          "po" = {
            "shell" = ".po";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/misc.sh open po";
          };
          "lyx" = {
            "shell" = ".lyx";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/misc.sh open lyx";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view lyx";
          };
          "torrent" = {
            "shell" = ".torrent";
            "shellignorecase" = "true";
            "open" = "%cd %p/torrent://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view torrent";
          };
          "ace" = {
            "shell" = ".ace";
            "shellignorecase" = "true";
            "open" = "%cd %p/uace://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view ace";
          };
          "arc" = {
            "shell" = ".arc";
            "shellignorecase" = "true";
            "open" = "%cd %p/uarc://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view arc";
          };
          "zip-by-shell" = {
            "shell" = ".zip";
            "shellignorecase" = "true";
            "open" = "%cd %p/uzip://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view zip";
          };
          "zoo" = {
            "shell" = ".zoo";
            "shellignorecase" = "true";
            "open" = "%cd %p/uzoo://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view zoo";
          };
          "lz4" = {
            "shell" = ".lz4";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/archive.sh view lz4 %var{PAGER:more}";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view lz4";
          };
          "lzo" = {
            "shell" = ".lzo";
            "shellignorecase" = "true";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/archive.sh view lzo %var{PAGER:more}";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view lzo";
          };
          "wim" = {
            "shell" = ".wim";
            "shellignorecase" = "true";
            "open" = "%cd %p/uwim://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view wim";
          };
          "brotli" = {
            "shell" = ".br";
            "shellignorecase" = "true";
            "open" = "Open=%cd %p/brotli://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view br";
          };
          "mailbox" = {
            "type" = "^ASCII mail text";
            "open" = "%cd %p/mailfs://";
          };
          "ipk-deb" = {
            "shell" = ".ipk";
            "type" = "^Debian binary package";
            "open" = "%cd %p/deb://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/package.sh view deb";
          };
          "ipk-openwrt" = {
            "shell" = ".ipk";
            "type" = "\\(gzip compressed";
            "include" = "tar.gz";
          };
          "squashfs" = {
            "type" = "^Squashfs filesystem";
            "open" = "%cd %p/usqfs://";
            "view" = "%view{ascii} unsquashfs -stat %f ; unsquashfs -lls -d \"\" %f";
          };
          "elf" = {
            "type" = "^ELF";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view elf";
          };
          "Mach-O" = {
            "type" = "^Mach-O";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view dylib";
          };
          "info-by-type" = {
            "type" = "^Info text";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open info";
          };
          "troff.gz" = {
            "type" = "troff.*gzip compressed";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open man.gz %var{PAGER:more}";
            "view" = "%view{ascii,nroff} ${pkgs.mc}/libexec/mc/ext.d/text.sh view man.gz %var{PAGER:more}";
          };
          "troff.bzip" = {
            "type" = "troff.*bzip compressed";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open man.bz %var{PAGER:more}";
            "view" = "%view{ascii,nroff} ${pkgs.mc}/libexec/mc/ext.d/text.sh view man.bz %var{PAGER:more}";
          };
          "troff.bzip2" = {
            "type" = "troff.*bzip2 compressed";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open man.bz2 %var{PAGER:more}";
            "view" = "%view{ascii,nroff} ${pkgs.mc}/libexec/mc/ext.d/text.sh view man.bz2 %var{PAGER:more}";
          };
          "man" = {
            "type" = "troff or preprocessor input";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/text.sh open man %var{PAGER:more}";
            "view" = "%view{ascii,nroff} ${pkgs.mc}/libexec/mc/ext.d/text.sh view man %var{PAGER:more}";
          };
          "gif" = {
            "type" = "^GIF";
            "include" = "image";
          };
          "jpeg" = {
            "type" = "^JPEG";
            "include" = "image";
          };
          "bitmap" = {
            "type" = "^PC bitmap";
            "include" = "image";
          };
          "png" = {
            "type" = "^PNG";
            "include" = "image";
          };
          "jng" = {
            "type" = "^JNG";
            "include" = "image";
          };
          "mng" = {
            "type" = "^MNG";
            "include" = "image";
          };
          "tiff" = {
            "type" = "^TIFF";
            "include" = "image";
          };
          "rbm" = {
            "type" = "^PBM";
            "include" = "image";
          };
          "pgm" = {
            "type" = "^PGM";
            "include" = "image";
          };
          "ppm" = {
            "type" = "^PPM";
            "include" = "image";
          };
          "netpbm" = {
            "type" = "^Netpbm";
            "include" = "image";
          };
          "webm-by-type" = {
            "type" = "WebM";
            "include" = "video";
          };
          "postscript" = {
            "type" = "^PostScript";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open ps";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/doc.sh view ps";
          };
          "pdf" = {
            "type" = "^PDF";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open pdf";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/doc.sh view pdf";
          };
          "msdoc-by-type" = {
            "type" = "^Microsoft Word";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open msdoc";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/doc.sh view msdoc";
          };
          "msxls-by-type" = {
            "type" = "^Microsoft Excel";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open msxls";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/doc.sh view msxls";
          };
          "mso-doc-1" = {
            "type" = "^Microsoft Office Document";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open ooffice";
          };
          "mso-doc-2" = {
            "type" = "^Microsoft OOXML";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open ooffice";
          };
          "framemaker" = {
            "type" = "^FrameMaker";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/doc.sh open framemaker";
          };
          "sqlite3.db" = {
            "type" = "^SQLite 3.x database";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/misc.sh open sqlite";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/misc.sh view sqlite";
          };
          "gzip" = {
            "type" = "\\(gzip compressed";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/archive.sh view gz %var{PAGER:more}";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view gz";
          };
          "bzip" = {
            "type" = "\\(bzip compressed";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/archive.sh view bzip %var{PAGER:more}";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view bzip";
          };
          "bzip2" = {
            "type" = "\\(bzip2 compressed";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/archive.sh view bzip2 %var{PAGER:more}";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view bz2";
          };
          "compress" = {
            "type" = "\\(compress'd";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/archive.sh view gz %var{PAGER:more}";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view gz";
          };
          "lz" = {
            "type" = "\\(lzip compressed";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/archive.sh view lz %var{PAGER:more}";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view lz";
          };
          "lzma" = {
            "type" = "\\(LZMA compressed";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/archive.sh view lzma %var{PAGER:more}";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view lzma";
          };
          "xz" = {
            "type" = "\\(XZ compressed";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/archive.sh view xz %var{PAGER:more}";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view xz";
          };
          "zstd" = {
            "type" = "\\(Zstandard compressed";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/archive.sh view zst %var{PAGER:more}";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view zst";
          };
          "zip-by-type" = {
            "type" = "\\(Zip archive";
            "open" = "%cd %p/uzip://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view zip";
          };
          "jar" = {
            "type" = "\\(Java (Jar file|archive) data \\((zip|JAR)\\)\\)";
            "typeignorecase" = "true";
            "open" = "%cd %p/uzip://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view zip";
          };
          "apk" = {
            "type" = "Android package \\(APK\\)";
            "typeignorecase" = "true";
            "open" = "%cd %p/uzip://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view zip";
          };
          "lha" = {
            "type" = "^LHa .*archive";
            "open" = "%cd %p/ulha://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view lha";
          };
          "pak" = {
            "type" = "^PAK .*archive";
            "open" = "%cd %p/unar://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view pak";
          };
          "par2" = {
            "type" = "^Parity Archive Volume Set";
            "open" = "${pkgs.mc}/libexec/mc/ext.d/archive.sh open par2";
          };
          "Include/tar.gz" = {
            "open" = "%cd %p/utar://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view tar.gz";
          };
          "Include/cpio" = {
            "open" = "%cd %p/ucpio://";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/archive.sh view cpio";
          };
          "Include/editor" = {
            "open" = "%var{EDITOR:vi} %f";
          };
          "Include/image" = {
            "open" = "${pkgs.mc}/libexec/mc/ext.d/image.sh open ALL_FORMATS";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/image.sh view ALL_FORMATS";
          };
          "Include/video" = {
            "open" = "${pkgs.mc}/libexec/mc/ext.d/video.sh open ALL_FORMATS";
            "view" = "%view{ascii} ${pkgs.mc}/libexec/mc/ext.d/video.sh view ALL_FORMATS";
          };
          "Default" = {
            "open" = openCmd;
            "view" = openCmd;
          };
        };
      };
    };
  };
}

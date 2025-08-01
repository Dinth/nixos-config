{ config, lib, pkgs, ... }:
let
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
        clipboard_store = null;
        clipboard_paste = null;
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
          Version = 4.0;
        };
      Default = {
        Open = openCmd;
        View = openCmd;
      };
    };
  };
}

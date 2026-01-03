{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkOption types optionals;
  cfg = config.weechat;
  graphical = config.graphical;
  primaryUsername = config.primaryUser.name;
  weechatCustom = pkgs.weechat.override {
    configure = { availablePlugins, ... }: {
      plugins = with availablePlugins; [
        (python.withPackages (ps: with ps; [ websocket-client ]))
      ];
      scripts = with pkgs.weechatScripts; [
        wee-slack
        weechat-autosort
        colorize_nicks
        buffer_autoset
        multiline
        weechat-grep
        weechat-go
        url_hint
      ] ++ optionals graphical.enable [
        weechat-notify-send
      ];
      init = ''
       # ---------------------------------------------------------------------
        # Core & Interface
        # ---------------------------------------------------------------------
        # Enable mouse support in ncurses
        /mouse enable
        # Enable mouse event handling
        /set weechat.look.mouse on
        # Disable built-in paste dialog (let multiline plugin handle it)
        /set weechat.look.paste_max_lines -1
        # Limit width of the buffer list to 30 chars
        /set weechat.bar.buflist.size_max 30
        # Set custom log filename format
        /set logger.file.mask "$plugin.$name.weechatlog"

        # ---------------------------------------------------------------------
        # Spell Check (Aspell)
        # ---------------------------------------------------------------------
        # Enable spell checking
        /set spell.check.enabled on
        # Set default dictionaries to English and Polish
        /set spell.check.default_dict "en,pl"
        # Show top 3 suggestions when correcting
        /set spell.check.suggestions 3

        # ---------------------------------------------------------------------
        # IRC Plugin Settings
        # ---------------------------------------------------------------------
        # Keep server status messages in a separate buffer
        /set irc.look.server_buffer independent

        # ---------------------------------------------------------------------
        # Completion & Typing
        # ---------------------------------------------------------------------
        # Add emoji to default completion tab
        /set weechat.completion.default_template "%(nicks)|%(irc_channels)|%(emoji)"

        # ---------------------------------------------------------------------
        # Plugin: Multiline (Better input/paste)
        # ---------------------------------------------------------------------
        # Prevent sending messages with only whitespace
        /set plugins.var.perl.multiline.send_empty_lines off
        # Only use multiline magic when pasting text
        /set plugins.var.perl.multiline.magic_paste_only on

        # ---------------------------------------------------------------------
        # Plugin: Autosort (Buffer organization)
        # ---------------------------------------------------------------------
        # Group all slack buffers together
        /autosort rules add slack.*.&slack
        # Define standard sort order (server > channel > private)
        /autosort rules add ''${info:autosort_order,''${type},server,*,channel,private}

        # ---------------------------------------------------------------------
        # Plugin: Wee-Slack (Functionality)
        # ---------------------------------------------------------------------
        # Increase timeout to 50s for slow connections
        /set plugins.var.python.slack.slack_timeout 50000
        # Prevent auto-away status while WeeChat is open
        /set plugins.var.python.slack.never_away true
        # Automatically open thread buffers when mentioned
        /set plugins.var.python.slack.auto_open_threads true
        # Hide thread replies from main channel buffer
        /set plugins.var.python.slack.thread_messages_in_channel false
        # Smart notification for threads you follow
        /set plugins.var.python.slack.notify_subscribed_threads auto
        # Load history in background to unblock UI
        /set plugins.var.python.slack.background_load_all_history true
        # Fetch 50 messages at a time
        /set plugins.var.python.slack.history_fetch_count 50
        # Set download path for Slack files
        /set plugins.var.python.slack.files_download_location "~/Downloads/weeslack"

        # ---------------------------------------------------------------------
        # Plugin: Wee-Slack (Appearance)
        # ---------------------------------------------------------------------
        # Use short names to save buffer list space
        /set plugins.var.python.slack.short_buffer_names true
        # Use Slack display names instead of real names
        /set plugins.var.python.slack.use_full_names false
        # Show who reacted to messages
        /set plugins.var.python.slack.show_reaction_nicks true
        # Render emoji as :smile: text (good for terminals)
        /set plugins.var.python.slack.render_emoji_as_string true
        # Show previews for links
        /set plugins.var.python.slack.link_previews true
        # Show both URL and preview content
        /set plugins.var.python.slack.unfurl_auto_link_display both
        # Disable coloring for DM buffers
        /set plugins.var.python.slack.colorize_private_chats false
        # Send typing indicators to others
        /set plugins.var.python.slack.send_typing_notice true
        # Show when others are typing in channel list
        /set plugins.var.python.slack.channel_name_typing_indicator true

        # ---------------------------------------------------------------------
        # Plugin: Wee-Slack (Colors & Indicators)
        # ---------------------------------------------------------------------
        # Prefix for thread messages broadcast to channel
        /set plugins.var.python.slack.thread_broadcast_prefix "+ "
        # Color for reaction count suffix
        /set plugins.var.python.slack.color_reaction_suffix 058
        # Color for thread count suffix
        /set plugins.var.python.slack.color_thread_suffix 013
        # Color for (edited) marker
        /set plugins.var.python.slack.color_edited_suffix 196

        # ---------------------------------------------------------------------
        # Keybindings (Slack Mouse & Cursor)
        # ---------------------------------------------------------------------
        # Middle-click to trigger Slack actions
        /key bindctxt mouse @chat(python.*):button2 hsignal:slack_mouse
        # 'R' in cursor mode to reply to thread
        /key bindctxt cursor @chat(python.*):R hsignal:slack_cursor_reply
        # 'T' in cursor mode to open thread
        /key bindctxt cursor @chat(python.*):T hsignal:slack_cursor_thread

        ${lib.optionalString graphical.enable ''
          # ---------------------------------------------------------------------
          # Graphical Notifications
          # ---------------------------------------------------------------------
          # Send desktop notification on highlights
          /set plugins.var.python.notify_send.notify_on_highlights on
          # Send desktop notification on DMs
          /set plugins.var.python.notify_send.notify_on_privmsgs on
        ''}
      '';
    };
  };
  aspellDicts = pkgs.aspellWithDicts (d: [ d.en d.en-computers d.pl ]);
in
{
  options = {
    weechat = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable weechat client.";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = lib.optionals graphical.enable [
      pkgs.libnotify
    ];
    home-manager.users.${primaryUsername} = {
      home.packages = [
        weechatCustom
        aspellDicts
      ];

    xdg.configFile."autostart/weechat.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=WeeChat
      GenericName=IRC Client
      Comment=Fast, light and extensible chat client
      Exec=${pkgs.kdePackages.konsole}/bin/konsole -e ${weechatCustom}/bin/weechat
      Terminal=false
      Categories=Network;IRCClient;
      Icon=weechat
      StartupNotify=false
      X-KDE-autostart-phase=1
    '';

      home.file.".weechat/weemoji.json".source = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/wee-slack/wee-slack/master/weemoji.json";
        sha256 = "sha256-dQkHlLLGtxUv7WSv/HxJza6CNBIjLt5FxO+iTOSH6oA=";
      };
    };
  };
}

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
        /mouse enable
        /set weechat.look.mouse on
        /set weechat.look.paste_max_lines -1            # Disable built-in paste dialog (let multiline plugin handle it)
        /set weechat.bar.buflist.size_max 30            # Limit width of the buffer list
        /set logger.file.mask "$plugin.$name.weechatlog" # Custom log filename format

        # ---------------------------------------------------------------------
        # Spell Check (Aspell)
        # ---------------------------------------------------------------------
        /set spell.check.enabled on
        /set spell.check.default_dict "en,pl"           # English and Polish
        /set spell.check.suggestions 3                  # Limit suggestion count

        # ---------------------------------------------------------------------
        # IRC Plugin Settings
        # ---------------------------------------------------------------------
        /set irc.look.server_buffer independent         # Keep server messages in separate buffer

        # ---------------------------------------------------------------------
        # Completion & Typing
        # ---------------------------------------------------------------------
        /set weechat.completion.default_template "%(nicks)|%(irc_channels)|%(emoji)"

        # ---------------------------------------------------------------------
        # Plugin: Multiline (Better input/paste)
        # ---------------------------------------------------------------------
        /set plugins.var.perl.multiline.send_empty_lines off
        /set plugins.var.perl.multiline.magic_paste_only on

        # ---------------------------------------------------------------------
        # Plugin: Autosort (Buffer organization)
        # ---------------------------------------------------------------------
        /autosort rules add slack.*.&slack
        /autosort rules add ''${info:autosort_order,''${type},server,*,channel,private}

        # ---------------------------------------------------------------------
        # Plugin: Wee-Slack (Functionality)
        # ---------------------------------------------------------------------
        /set plugins.var.python.slack.slack_timeout 50000
        /set plugins.var.python.slack.never_away true
        /set plugins.var.python.slack.auto_open_threads true
        /set plugins.var.python.slack.thread_messages_in_channel false
        /set plugins.var.python.slack.notify_subscribed_threads auto
        /set plugins.var.python.slack.background_load_all_history true
        /set plugins.var.python.slack.history_fetch_count 50
        /set plugins.var.python.slack.files_download_location "~/Downloads/weeslack"

        # ---------------------------------------------------------------------
        # Plugin: Wee-Slack (Appearance)
        # ---------------------------------------------------------------------
        /set plugins.var.python.slack.short_buffer_names true
        /set plugins.var.python.slack.use_full_names false
        /set plugins.var.python.slack.show_reaction_nicks true
        /set plugins.var.python.slack.render_emoji_as_string true
        /set plugins.var.python.slack.link_previews true
        /set plugins.var.python.slack.unfurl_auto_link_display both
        /set plugins.var.python.slack.colorize_private_chats false
        /set plugins.var.python.slack.send_typing_notice true
        /set plugins.var.python.slack.channel_name_typing_indicator true

        # ---------------------------------------------------------------------
        # Plugin: Wee-Slack (Colors & Indicators)
        # ---------------------------------------------------------------------
        /set plugins.var.python.slack.thread_broadcast_prefix "+ "
        /set plugins.var.python.slack.color_reaction_suffix 058
        /set plugins.var.python.slack.color_thread_suffix 013
        /set plugins.var.python.slack.color_edited_suffix 196

        # ---------------------------------------------------------------------
        # Keybindings (Slack Mouse & Cursor)
        # ---------------------------------------------------------------------
        /key bindctxt mouse @chat(python.*):button2 hsignal:slack_mouse
        /key bindctxt cursor @chat(python.*):R hsignal:slack_cursor_reply
        /key bindctxt cursor @chat(python.*):T hsignal:slack_cursor_thread

        ${lib.optionalString graphical.enable ''
          # ---------------------------------------------------------------------
          # Graphical Notifications
          # ---------------------------------------------------------------------
          /set plugins.var.python.notify_send.notify_on_highlights on
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

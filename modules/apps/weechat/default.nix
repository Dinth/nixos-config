{ config, pkgs, lib,...}:
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
        # to add vimode in the future
      ] ++ optionals graphical.enable [
        weechat-notify-send
      ];
      init = ''
        /mouse enable
        /set weechat.look.mouse on
        /set irc.look.server_buffer independent
        /set plugins.var.python.slack.short_buffer_names true
        /set plugins.var.python.slack.show_reaction_nicks true
        /set plugins.var.python.slack.link_previews true
        /set plugins.var.python.slack.colorize_private_chats false
        /set plugins.var.python.slack.use_full_names false
        /set plugins.var.python.slack.unfurl_auto_link_display both
        /set plugins.var.python.slack.files_download_location "~/Downloads/weeslack"
        /set plugins.var.python.slack.auto_open_threads true
        /set plugins.var.python.slack.never_away true
        /set plugins.var.python.slack.render_emoji_as_string true
        /set plugins.var.python.slack.channel_name_typing_indicator true
        /set plugins.var.python.slack.slack_timeout 50000
        /set plugins.var.python.slack.history_fetch_count 50
        /set plugins.var.python.slack.background_load_all_history true
        /set plugins.var.python.slack.send_typing_notice true
        /set plugins.var.python.slack.thread_messages_in_channel false
        /set plugins.var.python.slack.notify_subscribed_threads auto
        /set plugins.var.python.slack.thread_broadcast_prefix "+ "
        /set plugins.var.python.slack.color_reaction_suffix 058
        /set plugins.var.python.slack.color_thread_suffix 013
        /set plugins.var.python.slack.color_edited_suffix 196
        /autosort rules add slack.*.&slack
        /autosort rules add ''${info:autosort_order,''${type},server,*,channel,private}
        /set weechat.bar.buflist.size_max 30
        /set weechat.completion.default_template "%(nicks)|%(irc_channels)|%(emoji)"
        /set plugins.var.perl.multiline.send_empty_lines off
        /set plugins.var.perl.multiline.magic_paste_only on
        ${lib.optionalString graphical.enable ''
          /set plugins.var.python.notify_send.notify_on_highlights on
          /set plugins.var.python.notify_send.notify_on_privmsgs on
        ''}
      '';
    };
  };
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
    home-manager.users.${primaryUsername}.home = {
      file."Downloads/weeslack/.keep".text = "";
      file.".weechat/weemoji.json".source = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/wee-slack/wee-slack/master/weemoji.json";
        sha256 = "sha256-dQkHlLLGtxUv7WSv/HxJza6CNBIjLt5FxO+iTOSH6oA=";
      };
      packages = [ weechatCustom ];
    };
  };
}

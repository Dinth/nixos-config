{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
in
{
  config = mkIf cfg.enable {
    nixpkgs.overlays = [
      (self: super: {
        weechat = super.weechat.override {
          configure = { availablePlugins, ... }: {
            plugins = with availablePlugins; [ python ];
            scripts = with super.weechatScripts; [
              wee-slack
            ];
            init = ''
              /set irc.look.server_buffer independent
              /set plugins.var.python.slack.files_download_location "~/Downloads/weeslack"
              /set plugins.var.python.slack.auto_open_threads true
              /set plugins.var.python.slack.never_away true
              /set plugins.var.python.slack.render_emoji_as_string true
            '';
          };
        };
      })
    ];
  };
}

{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.weechat;
  primaryUsername = config.primaryUser.name;
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
    home-manager.users.${primaryUsername}.home.packages = with pkgs; [
      weechat
    ];
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

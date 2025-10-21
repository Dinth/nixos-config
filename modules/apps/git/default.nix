{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername}.programs.git = {
      enable = true;
      settings.user.name  = "Michal Gawronski-Kot";
      settings.user.email = "michal@gawronskikot.com";
      settings = {
#        url = {
#          "ssh://git@github.com" = {
#            insteadOf = [ "https://github.com" "gh" ];
#          };
#        };
        url = {
          "ssh://git@bitbucket.org" = {
            insteadOf = "https://bitbucket.org";
          };
        };
        url = {
          "ssh://git@gitlab.com" = {
            insteadOf = "https://gitlab.com";
          };
        };
      };
    };
  };
}

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
      userName  = "Michal Gawronski-Kot";
      userEmail = "michal@gawronskikot.com";
      extraConfig = {
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

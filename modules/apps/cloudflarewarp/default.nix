{ config, lib, pkgs, ...}:
let
  inherit (lib) mkIf mkOption;
  cfg = config.cloudflarewarp;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    cloudflarewarp = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Install and setup Cloudflare WARP client";
      };
    };
  };
  config = mkIf cfg.enable {
    services.cloudflare-warp.enable = true;
    systemd.tmpfiles.rules = [
      "d /var/lib/cloudflare-warp 0755 root root -"
      "L /var/lib/cloudflare-warp/mdm.xml - - - - ${config.age.secrets.cloudflare-mdm.path}"
    ];
    systemd.services.cloudflare-warp.preStart = ''
      ${pkgs.coreutils}/bin/install -Dm644 ${config.age.secrets.cloudflare-cert.path} /etc/ssl/certs/cloudflare-warp.pem
      ${pkgs.cacert}/bin/update-ca-certificates
    '';
  };
}

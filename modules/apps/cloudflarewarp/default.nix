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
    security.pki.certificateFiles = [ ./cloudflare-warp.pem ];

    # Global CA bundle environment variables for WARP TLS inspection
    # These ensure all tools (Python, Node.js, curl, etc.) use the system CA bundle
    environment.variables = {
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
      NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-certificates.crt";
      NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      CURL_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
    };
  };
}

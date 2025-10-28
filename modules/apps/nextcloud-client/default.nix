let
  inherit (lib) mkIf;
  cfg = config.graphical;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nextcloud-client
    ];
  };
}

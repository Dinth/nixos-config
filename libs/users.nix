{
  config,
  lib,
  ...
}: {
  options.primaryUser = lib.mkOption {
    type = lib.types.submodule {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          description = "The username of the primary user.";
        };
        fullName = lib.mkOption {
          type = lib.types.str;
          description = "The full name of the primary user.";
        };
        email = lib.mkOption {
          type = lib.types.str;
          description = "The email address of the primary user.";
        };
        uid = lib.mkOption {
          type = lib.types.int;
          default = 1000;
          description = ''
            Numeric UID of the primary user. Pinned so modules can derive
            /run/user/<uid> reliably (e.g. dashcam-sd notify-send, sshfs uid=).
          '';
        };
        publicKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "A list of SSH public keys for the primary user.";
          default = [];
        };
      };
    };
    description = "Configuration for the main user of this system.";
  };

  config = {
    users.users.${config.primaryUser.name}.uid = lib.mkDefault config.primaryUser.uid;
  };
}

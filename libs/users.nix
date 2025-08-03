{ lib, ... }:
{
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
      };
    };
    description = "Configuration for the main user of this system.";
  };
}

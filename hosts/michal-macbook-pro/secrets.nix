{
  config,
  lib,
  ...
}: let
  user = config.primaryUser.name;

  # The Mac imports this instead of secrets/deployment.nix, so it only
  # declares (and only needs to be a recipient of) what its modules use:
  # SSH keys for modules/apps/ssh and the GOG import, and the MCP tokens for
  # claude-code/opencode. mosyle-knowledge is declared by modules/apps/opencode.
  #
  # Same owner/mode/path as the NixOS declarations, except the group: macOS
  # has no "users" group (a user's primary group is "staff"), and agenix's
  # chown fails on a group that doesn't exist.
  userSecret = name: {
    file = ../../secrets + "/${name}.age";
    owner = user;
    group = "staff";
    mode = "0400";
  };
in {
  age.secrets =
    lib.genAttrs [
      "id-ed25519"
      "id-ed25519-passphrase"
      "id-ed25519-sk-rk-1"
      "id-ed25519-sk-rk-2"
      "id-ed25519-sk-rk-3"
      "ha-mcp-url"
      "firefly-mcp-token"
      "nextcloud-mcp-auth"
    ]
    userSecret;
}

# Trading 212 MCP server (KyuRish/trading212-mcp-server), pinned from PyPI —
# bump `version` + `hash` deliberately; it wraps a live brokerage API.
# Called from modules/apps/{claude-code,opencode} via callPackage with
# `envFile` set to the ragenix secret holding the ISA API credentials.
#
# The `trading212-mcp` wrapper sources that env file (TRADING212_API_KEY,
# TRADING212_API_SECRET, ENVIRONMENT=live) into the server process only, so
# the credentials never sit in the interactive shell environment. Upstream
# defaults ENVIRONMENT to `demo` when it's unset.
{
  lib,
  python3Packages,
  fetchPypi,
  writeShellApplication,
  envFile,
}: let
  server = python3Packages.buildPythonApplication rec {
    pname = "trading212-mcp-server";
    version = "0.4.0";
    pyproject = true;

    src = fetchPypi {
      pname = "trading212_mcp_server";
      inherit version;
      hash = "sha256-3o43MeV0N+heEq38fvWvX4IL9zQFEZ1aJYopwmi/gC4=";
    };

    build-system = [python3Packages.hatchling];

    # `mcp[cli]` only adds typer for the `mcp` dev CLI; the server itself
    # runs on mcp.server.fastmcp, so the plain package is enough.
    pythonRemoveDeps = ["mcp"];
    dependencies = with python3Packages; [
      httpx
      mcp
      pydantic
      python-dotenv
    ];

    # The upstream suite runs against live API fixtures.
    doCheck = false;
    pythonImportsCheck = ["trading212_mcp_server"];

    meta = {
      description = "MCP server for the Trading 212 public API";
      homepage = "https://github.com/KyuRish/trading212-mcp-server";
      license = lib.licenses.mit;
      mainProgram = "trading212-mcp-server";
    };
  };
in
  writeShellApplication {
    name = "trading212-mcp";
    text = ''
      if [ ! -r ${lib.escapeShellArg envFile} ]; then
        echo "trading212-mcp: credentials file ${envFile} is missing or unreadable" >&2
        exit 1
      fi
      set -a
      # shellcheck disable=SC1091
      . ${lib.escapeShellArg envFile}
      set +a
      exec ${lib.getExe server} "$@"
    '';
  }

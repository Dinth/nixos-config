{ config, lib,...}:
let
  inherit (lib) mkIf mkOption;
  cfg = config.opencode;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    opencode = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Install opencode.";
      };
    };
  };
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername} = {
      programs.opencode = {
        enable = true;
        settings = {
          model = "ollama/qwen2.5-coder:14b";
          provider = {
            google = {
              name = "Google Gemini";
              npm = "@ai-sdk/google";
              options = { apiKey = lib.trim (builtins.readFile config.age.secrets.opencode-gemini.path); };
              models = {
                "gemini-3-flash-preview" = { name = "Gemini 3.0 Flash Preview"; tools = true; };
                "gemini-2.5-pro" = { name = "Gemini 2.5 Pro"; tools = true; };
              };
            };
            ollama = {
              name = "Ollama (10.10.1.13)";
              npm = "@ai-sdk/openai-compatible";
              options = { baseURL = "http://10.10.1.13:11434/v1"; };
              models = {
                "qwen2.5-coder:14b" = { name = "Qwen Coder 2.5 14B"; tools = true; };
              };
            };
          };
        };
      };
#      programs.zsh.initExtra = ''
#        opencode() {
#          GOOGLE_GENERATIVE_AI_API_KEY="$(cat ${config.age.secrets.opencode-gemini.path})" command opencode "$@"
#        }
#      '';
    };
  };
}

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Validate Nix syntax (always run before presenting code)
nix-instantiate --parse /path/to/file.nix

# Check if a package exists in nixpkgs
nix search nixpkgs#<package>

# Debug build failures
nix-instantiate --show-trace /path/to/file.nix

# Rebuild and switch (requires root)
sudo nixos-rebuild switch --flake .#<hostname>

# Hostnames (live nixosConfigurations): dinth-nixos-desktop, michal-surface-go, r230-nixos
```

## Architecture

**Flake-based NixOS configuration managing 3 live hosts with integrated Home Manager.**

- `flake.nix` — Entry point defining inputs (nixpkgs, home-manager, plasma-manager, catppuccin, nixos-hardware, agenix) and `nixosConfigurations` outputs
- System and Home Manager configs are **mixed in the same modules** — a single file may contain both `environment.systemPackages` and `home-manager.users.${user}.programs.*`

### Hosts

| Host | Type | Use |
|------|------|-----|
| `dinth-nixos-desktop` | desktop | Primary workstation (KDE Plasma 6, gaming, graphical tools) |
| `michal-surface-go` | tablet | Mobile Surface Go 3 (KDE with tablet optimizations) |
| `r230-nixos` | server | Dell PowerEdge R230 (Docker only, no GUI) |
| `michal-macbook-pro` | laptop | **WIP / not wired** — scaffolding for an aarch64-darwin (nix-darwin) host. The `nix-darwin` input and `darwinConfigurations` block in `flake.nix` are commented out ("Doesnt work"), so this host does **not** build yet. See `modules/system/darwin.nix`. |

Host configs branch on `machineType` via `config.specialArgs.machineType`.

**Darwin support is aspirational, not functional.** `modules/system/darwin.nix` is an empty stub gated on `pkgs.stdenv.isDarwin`, and `hosts/michal-macbook-pro/` exists but is unreachable until the commented-out `nix-darwin` input and `darwinConfigurations` output in `flake.nix` are restored. Do not assume darwin builds work; only the three NixOS hosts above are live.

### Module Layout

```
modules/
  apps/       # Single-app configs (zsh, git, neovim, etc.)
  hardware/   # Hardware-specific (amd_gpu, yubikey, printers)
  services/   # System services (ssh)
  system/     # Cross-cutting subsystems (cli.nix, kde.nix, security.nix, docker.nix)
```

All modules auto-imported via `modules/default.nix`.

## Module Conventions

Every module must follow this pattern:

```nix
{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.<moduleName>;
  primaryUsername = config.primaryUser.name;
in {
  options.<moduleName> = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
  config = mkIf cfg.enable {
    # System-level config here
    environment.systemPackages = [ ... ];

    # Home Manager config uses primaryUsername
    home-manager.users.${primaryUsername}.programs.X = { ... };
  };
}
```

Key patterns:
- Use `lib.getExe pkgs.foo` or `lib.getExe' pkgs.foo "binary"` for command references
- Use `lib.optionals (machineType == "tablet") [ ... ]` for conditional packages
- Use `mkDefault` for overridable defaults (e.g., kernel selection)

## Secrets

**Use ragenix only** — never introduce sops or plain agenix.

- `secrets/secrets.nix` — Public key declarations
- `secrets/deployment.nix` — Imports decrypted secrets
- `secrets/*.age` — Encrypted files (git-ignored)

Reference in configs: `config.age.secrets.<name>.path` or `/run/agenix/<name>`

## Git Workflow

**MANDATORY: Every completed task MUST end with a commit before responding to the user.**

After completing a task (which may involve multiple file edits):
1. Validate syntax (for .nix files: `nix-instantiate --parse`)
2. Format all Nix files: `rtk nix run nixpkgs#alejandra -- .`
3. Stage all related changes and commit — do NOT wait for user to ask

```bash
git add <changed-files>
git commit -m "description of changes"
```

Do not include Co-Authored-By lines. Do not push unless explicitly asked.

## Key Files

| File | Purpose |
|------|---------|
| `hosts/common.nix` | Shared bootloader, kernel, nixpkgs config |
| `hosts/*/configuration.nix` | Host-specific module enables |
| `libs/users.nix` | User declarations (`primaryUser` attribute set) |
| `modules/system/security.nix` | Kernel hardening, audit rules, AppArmor |
| `modules/system/cli.nix` | Modern CLI tools (bat, eza, fd, ripgrep, fzf) |
| `modules/apps/zsh/default.nix` | Zsh with advanced completion caching |

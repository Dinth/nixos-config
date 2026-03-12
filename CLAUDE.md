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

# Hostnames: dinth-nixos-desktop, michal-surface-go, r230-nixos
```

## Architecture

**Flake-based NixOS configuration managing 3 hosts with integrated Home Manager.**

- `flake.nix` — Entry point defining inputs (nixpkgs, home-manager, plasma-manager, catppuccin, nixos-hardware, agenix) and `nixosConfigurations` outputs
- System and Home Manager configs are **mixed in the same modules** — a single file may contain both `environment.systemPackages` and `home-manager.users.${user}.programs.*`

### Hosts

| Host | Type | Use |
|------|------|-----|
| `dinth-nixos-desktop` | desktop | Primary workstation (KDE Plasma 6, gaming, graphical tools) |
| `michal-surface-go` | tablet | Mobile Surface Go 3 (KDE with tablet optimizations) |
| `r230-nixos` | server | Dell PowerEdge R230 (Docker only, no GUI) |

Host configs branch on `machineType` via `config.specialArgs.machineType`.

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

**Always commit changes after completing a task.** After making edits, run:

```bash
git add .
git commit -m "description of changes"
```

Do not include Co-Authored-By lines in commits. Do not push to remote unless explicitly asked.

## Key Files

| File | Purpose |
|------|---------|
| `hosts/common.nix` | Shared bootloader, kernel, nixpkgs config |
| `hosts/*/configuration.nix` | Host-specific module enables |
| `libs/users.nix` | User declarations (`primaryUser` attribute set) |
| `modules/system/security.nix` | Kernel hardening, audit rules, AppArmor |
| `modules/system/cli.nix` | Modern CLI tools (bat, eza, fd, ripgrep, fzf) |
| `modules/apps/zsh/default.nix` | Zsh with advanced completion caching |

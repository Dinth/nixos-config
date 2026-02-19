# NixOS Configuration

## Repo location
The NixOS config is the working directory when `nixos-engineer` is active.
Physically its located in /home/dinth/Documents/nixos-config.
Always read the relevant existing module before writing or modifying anything.

## Architecture
- **Flakes** — `flake.nix` is the entry point
- **System + Home Manager are mixed in the same files** — do not assume
  separation. A single module file may contain both `environment.systemPackages`
  and `home-manager.users.${user}.programs.*` side by side.
- **Secrets** — managed with **ragenix**. Never use sops or plain agenix.
  Secrets live in `secrets/` as age-encrypted files.

## Hosts
| Hostname | Hardware | Role |
|----------|----------|------|
| `dinth-nixos-desktop` | Desktop PC | Primary workstation |
| `michal-surface-go` | Microsoft Surface Go 3 | Mobile workstation |
| `r230-nixos` | Dell PowerEdge R230 | Docker server — see `hosts.md` for IP/services |

Host-specific configs and hardware configurations live in `hosts/<hostname>/`.

### dinth-nixos-desktop
- **CPU:** AMD Ryzen 7 5800X
- **GPU:** Radeon RX6700XT
- **Boot:** UEFI
- **Quirks:** 

### michal-surface-go
- **Model:** Microsoft Surface Go 2
- **CPU:** Intel M3-8100Y
- **Boot:** UEFI
- **Known Linux quirks:** <!-- e.g. WiFi chipset, touchscreen driver, type cover, suspend/resume issues -->
- **Kernel:** <!-- any custom kernel or patches needed, e.g. linux-surface -->

### r230-nixos
- **CPU:** <!-- e.g. Intel Xeon E3-1220 v5 -->
- **Boot:** <!-- UEFI or legacy BIOS — R230 supports both -->
- **Storage:** <!-- e.g. RAID controller, HBA, plain SATA -->
- **IPMI/iDRAC:** <!-- configured? accessible at what IP? -->
- **Quirks:** <!-- anything unusual for a headless server -->

## Folder Structure
```
flake.nix
hosts/                        # Per-host entry points + hardware config
  dinth-nixos-desktop/
  michal-surface-go/
  r230-nixos/
libs/                         # Reusable declarations, helper functions
modules/
  apps/                       # Single-app configs (when app is complex/distinguishable)
  hardware/                   # Hardware-specific configuration
  services/                   # System services
  system/                     # Large subsystems spanning multiple apps/system config
secrets/                      # ragenix-encrypted secrets
```

## Module Conventions

### Enable pattern
Always use `mkOption` with an `enable` option as the primary toggle:
```nix
{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.<moduleName>;
in {
  options.<moduleName> = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable <description>.";
    };
    # additional options...
  };
  config = mkIf cfg.enable {
    # implementation
  };
}
```

### Where to put a new module
- **`modules/apps/`** — single app, has non-trivial configuration, can be
  referenced by name from a system module. Examples: `kate.nix`, `konsole.nix`.
- **`modules/system/`** — a subsystem that configures multiple apps and/or
  system settings together. Can import from `modules/apps/` for complex
  sub-components. Example: `kde.nix` sets up the full KDE environment but
  imports `kate.nix` and `konsole.nix` for their detailed configs.
- **`modules/services/`** — system services (daemons, background processes).
- **`modules/hardware/`** — hardware-specific settings (drivers, firmware).
- **`libs/`** — shared helper functions or reusable declarations, not
  standalone modules.

When unsure whether something belongs in `apps/` vs `system/`: if it's a
single distinguishable app with enough config to warrant its own file, use
`apps/`. If it orchestrates multiple things, use `system/`.

### Referencing a single-app module from a system module
```nix
# modules/system/kde.nix
imports = [ ../apps/kate.nix ../apps/konsole.nix ];
config = mkIf cfg.enable {
  kate.enable = true;
  konsole.enable = true;
  # rest of KDE setup...
};
```

## Key constraints
- Always run `nix-instantiate --parse` to check syntax before presenting output
- Verify package availability with `nix search nixpkgs#<package>` if unsure
- On build failures, use `nix-instantiate --show-trace` for detailed errors
- Never introduce a new secrets mechanism — use ragenix for anything sensitive
- Never separate system and Home Manager config into different files unless
  the existing host already does so — match what's already there

# NixOS Configuration Context

## Architecture

- Using flakes.
- System-level configuration and user-level configuration (Home Manager) are mixed up in the same files. 
- 'hosts/' - Main configuration and hardware configuration for each of the hosts.
- 'libs/' - Declarations and reusable content.
- 'modules/apps/' - Application-specific configuration.
- 'modules/harwdare/' - Hardware-specific configuration.
- 'modules/services/' - Configuration for services running on the hosts.
- 'modules/system/' - Configuration for large subsystems (for example graphical subsystem) involving multiple apps and/or system configuration.
- 'secrets/' - encoded secrets (using ragenix).

## Hosts Inventory

1. Host: 'dinth-nixos-desktop'
  - Hardware: desktop computer 
  - Usecase: primary workstation
2. Host: 'michal-surface-go'
  - Hardware: Microsoft Surface Go 3
  - Usecase: highly mobile workstation
3. Host: 'r230-nixos'
  - Hardware: Dell PowerEdge R230
  - Usecase: docker server

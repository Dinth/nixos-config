{
  config,
  pkgs,
  lib,
  machineType ? "desktop",
  ...
}: let
  inherit (lib) mkDefault mkIf;
in {
  # Server remote deployment settings (no TTY available)
  security.doas.extraRules = mkIf (machineType == "server") (lib.mkForce [
    {
      users = [config.primaryUser.name];
      noPass = true;
      keepEnv = true;
    }
  ]);
  # nix.settings.trusted-users is set globally in modules/system/nix.nix to
  # ["root" "@wheel"]; the primary user is in wheel on every host, so a
  # server-specific override here would be redundant (lists merge anyway).

  nixpkgs = {
    config = {
      allowUnfree = true;
      # heroic and signal-desktop pin pnpm 10.29.2 to match their lockfiles and
      # use it only as a build-time tool to fetch node deps (sandboxed, never
      # shipped at runtime). A recent nixpkgs bump flagged that pnpm version as
      # insecure, which blocks evaluation; permitting it is the upstream-advised
      # fix. Revisit when those packages bump their pinned pnpm.
      permittedInsecurePackages = [
        "pnpm-10.29.2"
      ];
    };
  };
  # Cap systemd-boot generations on the ESP. The rolling-latest workflow
  # (`nh os switch -u` every rebuild) drops a fresh kernel+initrd into the
  # small vfat /boot each time, and GC only prunes generations after 30d — a
  # busy fortnight can fill the ESP and fail a switch mid-write. No-op on the
  # GRUB server (r230). mkDefault so a host can override.
  boot.loader.systemd-boot.configurationLimit = mkDefault 15;

  # Kernel: stable for servers, latest for desktops/tablets
  boot.kernelPackages = mkDefault (
    if machineType == "server"
    then pkgs.linuxPackages
    else pkgs.linuxPackages_latest
  );
  # Kernel ≥ 7.0 builds DAMON_STAT=y with DAMON_STAT_ENABLED_DEFAULT=y, so a
  # kdamond kernel thread samples memory-access patterns from boot (~9% of a
  # core observed on the desktop) for telemetry nothing here consumes. Scoped
  # to workstations: servers run the stable 6.12 kernel without DAMON_STAT,
  # where the unknown param would only log a boot-time notice.
  boot.kernelParams = lib.optionals (machineType != "server") ["damon_stat.enabled=0"];
  # boot.tmp is fully configured in modules/system/security.nix (with tmpfsSize).
  services.fwupd.enable = true;
  # Userspace OOM-prevention daemon — workstations only. Its value is keeping
  # an interactive session responsive during swap thrash, which doesn't apply
  # to the headless, swapless r230; there, per-container mem_limit plus the
  # kernel cgroup OOM killer handle memory pressure more surgically than
  # nohang's host-wide process-size heuristic would.
  services.nohang = {
    enable = machineType != "server";
    configPath = "desktop";
  };

  # Base home-manager config for root (required when modules apply HM config to root)
  home-manager.users.root.home = {
    stateVersion = "25.05";
    username = "root";
    homeDirectory = "/root";
  };
}

{lib, ...}: {
  options.homeNetwork = {
    workstationSubnets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Subnets the primary user's own machines connect from — the trusted
        sources for interactive access (SSH ban exemptions, RDP). Deliberately
        not the whole 10.10.0.0/16: that also covers IoT (10.10.25.0/24) and
        CCTV (10.10.30.0/24), the devices most likely to be compromised.
        One list, so a workstation moving subnets is a one-line change rather
        than a hunt for every allowlist that hard-coded the old one.
      '';
      default = [
        "10.10.10.0/24" # workstations / mobile devices / DHCP pool
        "10.40.0.0/24" # dinth-nixos-desktop (10.40.0.10), routed via pfSense
      ];
    };
  };
}

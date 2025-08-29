{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption mkMerge;
  cfg = config.antivirus;
in
{
  options = {
    antivirus = {
      enable = mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable ClamAV antivirus services";
      };
      accessScanning = {
        enable = mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable on-access file scanning";
        };
        homeDirectories = mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "Downloads"
          ];
          description = "Directories to scan on access, relative to the home directory of each user";
        };
        directories = mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "/run/media"
            "/tmp"
          ];
          description = "Additional directories to scan on access. Must be absolute paths.";
        };
      };
    };
  };
  config =
  let
    allNormalUsers = lib.attrsets.filterAttrs (username: config: config.isNormalUser) config.users.users;
    allACScanHomeDirs = builtins.concatMap (
      dir: lib.attrsets.mapAttrsToList (username: config: config.home + "/" + dir) allNormalUsers
    )
    cfg.accessScanning.homeDirectories;
  in
  {
    antivirus.accessScanning.directories = allACScanHomeDirs;
    services.clamav = {
      daemon = {
        enable = true;
        settings = {
          LogFile = "/var/log/clamav/clamav.log";
          DatabaseDirectory = "/var/lib/clamav";
          ExtendedDetectionInfo = "yes";
          OnAccessIncludePath = cfg.accessScanning.directories;
          OnAccessPrevention = true;
          OnAccessExtraScanning = false;
          OnAccessExcludeUname = "clamav";
          MaxFileSize = "250M";
          MaxScanSize = "4000M";
          MaxScanTime = "60000";
          MaxRecursion = 3;
          MaxFiles = 5000;
          StreamMaxLength = "100M";
          OnAccessMaxFileSize = "100M";
          BytecodeTimeout = "60000";
          User = "clamav";
          ScanPE = true;
          ScanELF = true;
          ScanMail = true;
          ScanArchive = true;
          ScanHTML = true;
          ScanOLE2 = true;
          ScanPDF = true;
          ScanSWF = true;
          OnAccessMaxThreads = 8;
          MaxThreads = 12;
          MaxQueue = 200;
          CrossFilesystems = false;
        };
      };
      updater = {
        enable = true;
        settings = {
          UpdateLogFile = "/var/log/clamav/freshclam.log";
          DatabaseDirectory = "/var/lib/clamav";
          CompressLocalDatabase = false;
        };
          interval = "daily";
          frequency = 1;
      };
      fangfrisch = {
        enable = true;
        interval = "daily";
        settings = {
          DEFAULT.db_url = "sqlite:////var/lib/clamav/fangfrisch_db.sqlite";
          DEFAULT.local_directory = "/var/lib/clamav";
          DEFAULT.log_level = "INFO";
          urlhaus.enabled = "yes";
          urlhaus.max_size = "2MB";
          sanesecurity.enabled = "yes";
        };
      };
      scanner = {
        scanDirectories = [
          "/"
        ];
        interval = "*-*-* 09:00:00";
      };
    };
    systemd.services."clamav-clamonacc" = {
      description = "ClamAV On-Access Scanner";
      documentation = ["man:clamonacc(8)" "man:clamd.conf(5)" "https://docs.clamav.net/"];
      requires = ["clamav-daemon.service"];
      after = ["clamav-daemon.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        User = "root";
        ExecStartPre = ''${lib.getExe pkgs.bash} -c "while [ ! -S /run/clamav/clamd.ctl ]; do sleep 1; done"'';
        ExecStart = ''${lib.getExe' pkgs.clamav "clamonacc"} -F --log=/var/log/clamav/clamonacc.log -c /etc/clamav/clamd.conf --move /var/lib/quarantine  --fdpass --allmatch'';
        ExecReload = ''${lib.getExe' pkgs.coreutils "kill"} -USR2 $MAINPID'';
        PrivateTmp = "yes";
        PrivateDevices = "yes";
        PrivateNetwork = "yes";
      };
    };
    systemd.tmpfiles.rules = [
      "d /var/log/clamav 0755 clamav clamav - -"
      "d /var/quarantine 0755 root root - -"
    ];
    environment.variables = {
      CLAMAV_ONACCESS_FLAGS = "--fanotify";  # Avoid legacy inotify
    };
  };
}

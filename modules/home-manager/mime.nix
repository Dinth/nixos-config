{ config, lib, pkgs, ... }:
{
  xdg.enable = true;
  xdg.dataFile."mime/packages/x-plist.xml".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
      <mime-type type="application/x-plist">
        <comment>Apple Property List</comment>
        <glob pattern="*.plist"/>
      </mime-type>
    </mime-info>
  '';
  xdg.dataFile."mime/packages/x-applescript.xml".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
      <mime-type type="text/x-applescript">
        <comment>AppleScript Source</comment>
        <glob pattern="*.applescript"/>
      </mime-type>
    </mime-info>
  '';
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/orcaslicer" = "OrcaSlicer.desktop";
      "x-scheme-handler/bambustudio" = "OrcaSlicer.desktop"; # makerworld
      "x-scheme-handler/prusaslicer" = "OrcaSlicer.desktop"; # printables
      "x-scheme-handler/applescript" = "Kate.desktop"; # applescript:// urls
      "application/x-plist" = "Kate.desktop"; # mac plist files
      "text/x-applescript" = "Kate.desktop"; # applescript
    };
  };
}

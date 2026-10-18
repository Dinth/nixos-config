# notify-send look-alike for macOS (a package, not a module: callPackage it).
# Takes the libnotify command line that the Linux side already speaks
# (weechat-notify-send, the Claude Code stop hook) and posts it through
# Notification Center with osascript. --app-name becomes the title and the
# summary the subtitle; icon, urgency, hints, expire time and the rest have no
# macOS equivalent and are skipped. Notifications show up as Script Editor's,
# so macOS asks once to allow them.
{writeShellApplication}:
writeShellApplication {
  name = "notify-send";
  text = ''
    app=""
    while [ $# -gt 0 ]; do
      case $1 in
        --)
          shift
          break
          ;;
        --app-name=*) app=''${1#*=} ;;
        -a | --app-name)
          app=''${2:-}
          shift
          ;;
        --*=*) ;;
        # Options that take a separate value: skip the value too.
        -u | --urgency | -t | --expire-time | -i | --icon | -c | --category | -h | --hint | -A | --action | -r | --replace-id)
          shift
          ;;
        -*) ;;
        *) break ;;
      esac
      shift
    done
    summary=''${1:-}
    body=''${2:-}
    if [ -z "$app" ]; then
      app=$summary
      summary=""
    fi

    # Passed as arguments, not spliced into the AppleScript, so quotes in a
    # chat message can't break (or inject into) the script.
    exec /usr/bin/osascript \
      -e 'on run argv' \
      -e 'display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv)' \
      -e 'end run' \
      "$body" "$app" "$summary"
  '';
}

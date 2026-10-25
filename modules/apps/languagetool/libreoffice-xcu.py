"""Point LibreOffice's remote grammar checker at a LanguageTool server.

Purpose:
    Idempotently rewrites the handful of LanguageTool entries in a LibreOffice
    user profile's registrymodifications.xcu, leaving every other setting
    alone. LibreOffice has no system config layer outside its read-only store
    path, so the user layer is the only place these can go. LibreOffice
    rewrites this file on exit, so a running instance can undo the change
    until it is restarted.

    Usage: libreoffice-xcu.py <registrymodifications.xcu> <base-url> <locale>...

Dependencies:
    Python 3 standard library only.

Author:
    AI (Claude)
"""

import sys
from pathlib import Path
from xml.sax.saxutils import escape

LT_PATH = "/org.openoffice.Office.Linguistic/GrammarChecking/LanguageTool"
CHECKERS_PATH = "/org.openoffice.Office.Linguistic/ServiceManager/GrammarCheckerList"
LT_SERVICE = "org.openoffice.lingu.LanguageToolGrammarChecker"

SKELETON = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<oor:items xmlns:oor="http://openoffice.org/2001/registry"'
    ' xmlns:xs="http://www.w3.org/2001/XMLSchema"'
    ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n'
    "</oor:items>\n"
)


def item(path: str, prop: str, body: str) -> str:
    """Render one registrymodifications.xcu line."""
    return f'<item oor:path="{path}"><prop oor:name="{prop}" oor:op="fuse"{body}</prop></item>'


def main() -> None:
    """Replace the managed entries and write the file back."""
    xcu = Path(sys.argv[1])
    base_url = sys.argv[2]
    locales = sys.argv[3:]

    managed = [
        item(LT_PATH, "BaseURL", f"><value>{escape(base_url)}</value>"),
        item(LT_PATH, "IsEnabled", "><value>true</value>"),
    ] + [
        item(
            CHECKERS_PATH,
            locale,
            f' oor:type="oor:string-list"><value><it>{LT_SERVICE}</it></value>',
        )
        for locale in locales
    ]
    # Match on the path+prop prefix, so stale values are dropped too.
    prefixes = tuple(line.split(' oor:op="fuse"')[0] for line in managed)

    text = xcu.read_text() if xcu.exists() else SKELETON
    lines = [line for line in text.splitlines() if not line.startswith(prefixes)]
    end = next(i for i, line in enumerate(lines) if line.strip() == "</oor:items>")
    lines[end:end] = managed

    xcu.parent.mkdir(parents=True, exist_ok=True)
    xcu.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()

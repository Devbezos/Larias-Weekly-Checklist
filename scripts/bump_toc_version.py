#!/usr/bin/env python3

import argparse
import re


def main() -> int:
    parser = argparse.ArgumentParser(description="Bump ## Version: in a WoW addon .toc")
    parser.add_argument("--toc", default="LariasWeeklyMidnightChecklist.toc")
    args = parser.parse_args()

    with open(args.toc, "r", encoding="utf-8") as f:
        text = f.read()

    nl = "\r\n" if "\r\n" in text else "\n"

    # Accept MAJOR.MINOR.PATCH and optionally ignore an existing 4th component.
    m = re.search(
        r"^##\s*Version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)(?:\.[0-9]+)?\s*$",
        text,
        flags=re.MULTILINE,
    )

    if m:
        major, minor, patch = int(m.group(1)), int(m.group(2)), int(m.group(3))
        new_version = f"{major}.{minor}.{patch + 1}"
    else:
        new_version = "0.0.1"

    new_line = f"## Version: {new_version}"
    updated, n = re.subn(r"^##\s*Version:.*$", new_line, text, flags=re.MULTILINE)
    if n == 0:
        updated = new_line + nl + text

    with open(args.toc, "w", encoding="utf-8") as f:
        f.write(updated)

    print(new_version)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

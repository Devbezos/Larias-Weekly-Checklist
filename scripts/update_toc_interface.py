#!/usr/bin/env python3

import argparse
import json
import re
import sys
import urllib.error
import urllib.request


DEFAULT_URL = "https://wago.tools/api/builds"
DEFAULT_COUNT = 3


def interface_from_version(version: str) -> int | None:
    parts = (version or "").split(".")
    if len(parts) < 3:
        return None
    try:
        major, minor, patch = map(int, parts[:3])
    except ValueError:
        return None
    return major * 10000 + minor * 100 + patch


def parse_existing_interfaces(toc_text: str) -> list[int] | None:
    m = re.search(r"^##\s*Interface:\s*(.+?)\s*$", toc_text, flags=re.MULTILINE)
    if not m:
        return None
    raw = m.group(1)
    parts = [p.strip() for p in raw.split(",") if p.strip()]
    values: list[int] = []
    for p in parts:
        if p.isdigit():
            values.append(int(p))
    return values


def replace_or_insert_line(toc_text: str, key: str, new_line: str) -> str:
    nl = "\r\n" if "\r\n" in toc_text else "\n"
    updated, n = re.subn(rf"^##\s*{re.escape(key)}:.*$", new_line, toc_text, flags=re.MULTILINE)
    if n == 0:
        return new_line + nl + toc_text
    return updated


def main() -> int:
    parser = argparse.ArgumentParser(description="Update ## Interface: line in a WoW addon .toc")
    parser.add_argument("--toc", default="LariasWeeklyMidnightChecklist.toc")
    parser.add_argument("--url", default=DEFAULT_URL)
    parser.add_argument("--count", type=int, default=DEFAULT_COUNT)
    args = parser.parse_args()

    try:
        with open(args.toc, "r", encoding="utf-8") as f:
            toc_text = f.read()
    except FileNotFoundError:
        print(f"ERROR: TOC file not found: {args.toc}", file=sys.stderr)
        return 2

    existing = parse_existing_interfaces(toc_text)

    try:
        req = urllib.request.Request(
            args.url,
            headers={
                "User-Agent": "LariasWeeklyMidnightChecklist-GitHubActions/1.0",
                "Accept": "application/json",
            },
        )
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.load(resp)
    except urllib.error.HTTPError as e:
        # Wago sometimes blocks anonymous requests from CI (403). Don't hard-fail.
        print(
            f"WARNING: Failed to fetch Wago builds from {args.url}: HTTP {e.code}. Keeping existing Interface line.",
            file=sys.stderr,
        )
        return 0
    except Exception as e:
        print(
            f"WARNING: Failed to fetch Wago builds from {args.url}: {e}. Keeping existing Interface line.",
            file=sys.stderr,
        )
        return 0

    retail = data.get("wow")
    if not isinstance(retail, list) or not retail:
        print("ERROR: Wago response missing 'wow' retail builds", file=sys.stderr)
        return 1

    interfaces: set[int] = set()
    for item in retail:
        if not isinstance(item, dict):
            continue
        iface = interface_from_version(str(item.get("version", "")))
        if iface is not None:
            interfaces.add(iface)

    newest = sorted(interfaces, reverse=True)[: args.count]
    if len(newest) < args.count:
        print(f"ERROR: Expected >= {args.count} interface versions, got {newest}", file=sys.stderr)
        return 1

    if existing is not None and existing[: args.count] == newest:
        # Nothing to do
        return 0

    new_line = "## Interface: " + ", ".join(str(x) for x in newest)
    updated = replace_or_insert_line(toc_text, "Interface", new_line)

    with open(args.toc, "w", encoding="utf-8") as f:
        f.write(updated)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

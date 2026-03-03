#!/usr/bin/env python3
import csv
import hashlib
import re
import sys
from pathlib import Path

# Matches the stored spreadsheet version comment written by this script.
# Line format:  -- @sheet-version: <value>
SHEET_VERSION_LINE_RE = re.compile(r"^--\s*@sheet-version:\s*(.+)$", re.MULTILINE)

# Matches the runtime Lua variable line  reg.sheet_version = "<value>"
SHEET_VERSION_VAR_RE  = re.compile(r'^reg\.sheet_version\s*=\s*"[^"]*"$', re.MULTILINE)

HEADER_PREFIX_RE = re.compile(r"^\s*(Early Access|Emergency|Pre-Season|Season|Week(?:s)?)\b", re.IGNORECASE)


def is_section_header(text: str) -> bool:
    if "\n" in text:
        return False
    return bool(HEADER_PREFIX_RE.match(text.strip()))


def wow_safe_text(s: str) -> str:
    # common replacements for WoW-safe output
    repl = {
        "\u2192": "->",  # →
        "\u21d2": "=>",  # ⇒
        "\u27a1": "->",  # ➡
        "\u2013": "-",   # –
        "\u2014": "-",   # —
        "\u2212": "-",   # −
        "\u2026": "...", # …
        "\u00a0": " ",   # nbsp
        "\u2018": "'", "\u2019": "'",  # ‘ ’
        "\u201c": '"', "\u201d": '"',  # “ ”
    }
    for k, v in repl.items():
        s = s.replace(k, v)

    # strip any remaining non-ascii chars
    s = s.encode("ascii", "ignore").decode("ascii")
    return s

def hash_id(s: str) -> str:
    """Stable 8-character hex ID derived from the normalised text.
    Using a content hash keeps IDs short, unique, and stable across renames
    as long as the canonical English text doesn't change."""
    cleaned = wow_safe_text(s.strip())
    return hashlib.md5(cleaned.encode("utf-8")).hexdigest()[:8]


def slug(s: str) -> str:
    s = s.strip().lower()
    s = re.sub(r"[^a-z0-9]+", "_", s)
    s = s.strip("_")
    return s or "section"

def lua_escape(s: str) -> str:
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    return s


def detect_newline(text: str) -> str:
    return "\r\n" if "\r\n" in text else "\n"


def get_sheet_version(rows: list) -> str:
    """Return the value of cell F2 (row index 1, column index 5) as the sheet version.
    Returns an empty string if the cell is missing or blank."""
    try:
        val = rows[1][5].strip() if len(rows) > 1 and len(rows[1]) > 5 else ""
        return wow_safe_text(val)
    except (IndexError, AttributeError):
        return ""


def get_stored_sheet_version(existing_text: str) -> str:
    """Extract the @sheet-version value previously written into the Lua file."""
    m = SHEET_VERSION_LINE_RE.search(existing_text)
    return m.group(1).strip() if m else ""


def strip_version_line(text: str) -> str:
    """Remove both the @sheet-version comment and the reg.sheet_version variable
    line so we can compare pure data content, independent of version changes."""
    text = SHEET_VERSION_LINE_RE.sub("", text)
    text = SHEET_VERSION_VAR_RE.sub("", text)
    return text.strip()


def build_enus_data_header(sheet_version: str = "") -> list[str]:
    lines = [
        "--[[",
        "English (enUS) checklist data for Larias's Weekly Checklist",
        "",
        "NOTE: This is the canonical enUS dataset; other locales must keep IDs identical",
        "so completion tracking stays consistent across locales.",
        "]]",
        "",
    ]
    if sheet_version:
        lines.append(f"-- @sheet-version: {sheet_version}")
        lines.append("")
    return lines

def main(csv_in: str, lua_out: str) -> None:
    with open(csv_in, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))

    # Read spreadsheet version from F2 (row 1, col 5).
    sheet_version = get_sheet_version(rows)

    sections = []
    current = None

    for row in rows:
        if not row:
            continue
        text = wow_safe_text((row[0] or "").strip())
        if not text:
            continue

        if is_section_header(text):
            current = {"id": hash_id(text), "title": text, "items": []}
            sections.append(current)
        else:
            if current is None:
                continue
            current["items"].append({"id": hash_id(text), "text": text})
    out: list[str] = []

    existing_text = None
    out_path = Path(lua_out)
    nl = "\n"

    if out_path.exists():
        existing_text = out_path.read_text(encoding="utf-8")
        nl = detect_newline(existing_text)

    out.extend(build_enus_data_header(sheet_version))

    out.append('local LOCALE = "enUS"')
    out.append("")
    out.append('local LOCALE_REGISTRY_KEY = "LARIASWEEKLYCHECKLIST_LOCALE_REGISTRY"')
    out.append("")
    out.append("local reg = _G[LOCALE_REGISTRY_KEY]")
    out.append('if type(reg) ~= "table" then')
    out.append("    reg = {}")
    out.append("    _G[LOCALE_REGISTRY_KEY] = reg")
    out.append("end")
    out.append('if type(reg.data) ~= "table" then reg.data = {} end')
    if sheet_version:
        out.append(f'reg.sheet_version = "{lua_escape(sheet_version)}"')
    out.append("")
    out.append("local DATASET = {")
    out.append("")

    for s in sections:
        out.append("    {")
        out.append(f'        id = "{lua_escape(s["id"])}",')
        out.append(f'        title = "{lua_escape(s["title"])}",')
        out.append("        items = {")
        for it in s["items"]:
            out.append(f'            {{ id = "{lua_escape(it["id"])}", text = "{lua_escape(it["text"])}" }},')
        out.append("        },")
        out.append("    },")
    out.append("}")
    out.append("")
    out.append("reg.data[LOCALE] = DATASET")
    out.append("")

    new_text = nl.join(out)
    if not new_text.endswith(nl):
        new_text += nl

    if existing_text is not None:
        # Gate: only write when BOTH the sheet version has changed AND the
        # underlying data content has changed.
        stored_version = get_stored_sheet_version(existing_text)
        version_changed = sheet_version != stored_version

        # Compare content with the version line stripped so a pure version bump
        # (no data change) never triggers a write, and vice-versa.
        existing_data = strip_version_line(existing_text.replace("\r\n", "\n"))
        new_data      = strip_version_line(new_text.replace("\r\n", "\n"))
        content_changed = existing_data != new_data

        if not version_changed or not content_changed:
            return

    out_path.write_text(new_text, encoding="utf-8")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: sheet_to_lua.py <input.csv> <output.lua>")
        sys.exit(2)
    main(sys.argv[1], sys.argv[2])



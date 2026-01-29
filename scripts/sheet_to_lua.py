#!/usr/bin/env python3
import csv
import re
import sys
from pathlib import Path

SHEET_URL = "https://docs.google.com/spreadsheets/d/1iK2SZUcz_ljnkdTG7KW6pqfzaUDuSgnlh1HupcLrkus/edit?gid=53744607"

def slug(s: str) -> str:
    s = s.strip().lower()
    s = re.sub(r"[^a-z0-9]+", "_", s)
    s = s.strip("_")
    return s or "section"

def lua_escape(s: str) -> str:
    # keep output stable + safe for Lua strings
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    return s

def is_section_header_row(row: list[str]) -> bool:
    """
    User rule:
    - Only care about first column (A)
    - Treat a row as a section header if A has text and the other columns are empty/falsey
    - Assume col C may be a checkbox; any non-empty in other columns means it's an item row
    """
    if not row:
        return False
    a = (row[0] or "").strip()
    if not a:
        return False
    # if all other cells are blank, it's a header row
    for cell in row[1:]:
        if (cell or "").strip():
            return False
    return True

def main(csv_in: str, lua_out: str) -> None:
    csv_path = Path(csv_in)
    out_path = Path(lua_out)

    with csv_path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.reader(f)
        rows = list(reader)

    sections: list[dict] = []
    current = None

    for row in rows:
        # normalize row length
        row = [c if c is not None else "" for c in row]
        a_text = (row[0] if len(row) > 0 else "").strip()
        if not a_text:
            continue

        if is_section_header_row(row):
            current = {
                "id": slug(a_text),
                "title": a_text,
                "items": []
            }
            sections.append(current)
        else:
            if current is None:
                # ignore items before the first header
                continue
            current["items"].append({
                "id": slug(a_text),
                "text": a_text
            })

    lines: list[str] = []
    lines.append("-- Data file for Larias Weekly Midnight Checklist")
    lines.append("-- AUTO-GENERATED. DO NOT EDIT MANUALLY.")
    lines.append(f"-- Source: {SHEET_URL}")
    lines.append("")
    lines.append("local addonName = ...")
    lines.append("")
    lines.append('_G[addonName .. "_LIST_DATA"] = {')

    for s in sections:
        lines.append("    {")
        lines.append(f'        id = "{lua_escape(s["id"])}",')
        lines.append(f'        title = "{lua_escape(s["title"])}",')
        lines.append("        items = {")
        for it in s["items"]:
            lines.append(
                f'            {{ id = "{lua_escape(it["id"])}", text = "{lua_escape(it["text"])}" }},'
            )
        lines.append("        },")
        lines.append("    },")
    lines.append("}")
    lines.append("")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines), encoding="utf-8")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: sheet_to_lua.py <input.csv> <output.lua>")
        sys.exit(2)
    main(sys.argv[1], sys.argv[2])

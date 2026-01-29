#!/usr/bin/env python3
import csv
import re
import sys
from pathlib import Path

SHEET_URL = "https://docs.google.com/spreadsheets/d/1iK2SZUcz_ljnkdTG7KW6pqfzaUDuSgnlh1HupcLrkus/edit?gid=53744607"

HEADER_PREFIX_RE = re.compile(r"^\s*(Early Access|Pre-Season|Season|Week)\b", re.IGNORECASE)

MONTHS = r"(Jan|January|Feb|February|Mar|March|Apr|April|May|Jun|June|Jul|July|Aug|August|Sep|Sept|September|Oct|October|Nov|November|Dec|December)"
MONTH_DAY_RE = re.compile(rf"\b{MONTHS}\s+\d{{1,2}}\b", re.IGNORECASE)

def slug(s: str) -> str:
    s = s.strip().lower()
    s = re.sub(r"[^a-z0-9]+", "_", s)
    s = s.strip("_")
    return s or "section"

def lua_escape(s: str) -> str:
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    return s

def is_section_header(text: str) -> bool:
    t = text.strip()
    if not HEADER_PREFIX_RE.match(t):
        return False
    return bool(MONTH_DAY_RE.search(t))

def main(csv_in: str, lua_out: str) -> None:
    with open(csv_in, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))

    sections = []
    current = None

    for row in rows:
        if not row:
            continue
        text = (row[0] or "").strip()
        if not text:
            continue

        if is_section_header(text):
            current = {"id": slug(text), "title": text, "items": []}
            sections.append(current)
        else:
            if current is None:
                continue
            current["items"].append({"id": slug(text), "text": text})

    out = []
    out.append("-- Data file for Larias Weekly Midnight Checklist")
    out.append("-- AUTO-GENERATED. DO NOT EDIT MANUALLY.")
    out.append(f"-- Source: {SHEET_URL}")
    out.append("")
    out.append("local addonName = ...")
    out.append("")
    out.append('_G[addonName .. "_LIST_DATA"] = {')

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

    Path(lua_out).write_text("\n".join(out), encoding="utf-8")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: sheet_to_lua.py <input.csv> <output.lua>")
        sys.exit(2)
    main(sys.argv[1], sys.argv[2])

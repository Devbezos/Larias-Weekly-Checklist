#!/usr/bin/env python3
import csv
import re
import sys
from pathlib import Path

SHEET_URL = "https://docs.google.com/spreadsheets/d/1iK2SZUcz_ljnkdTG7KW6pqfzaUDuSgnlh1HupcLrkus/edit?gid=53744607"

SEASON_RE = re.compile(r"^\s*Season\b", re.IGNORECASE)
WEEK_RE   = re.compile(r"^\s*Week\b", re.IGNORECASE)

MONTHS = r"(Jan|January|Feb|February|Mar|March|Apr|April|May|Jun|June|Jul|July|Aug|August|Sep|Sept|September|Oct|October|Nov|November|Dec|December)"
DATE_TEXT_RE = re.compile(rf"\b{MONTHS}\s+\d{{1,2}}\b", re.IGNORECASE)
DATE_NUM_RE  = re.compile(r"\b(\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}([-/]\d{2,4})?)\b")

def slug(s: str) -> str:
    s = s.strip().lower()
    s = re.sub(r"[^a-z0-9]+", "_", s)
    s = s.strip("_")
    return s or "section"

def lua_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')

def is_section_header(text: str) -> bool:
    t = text.strip()
    return bool(
        SEASON_RE.match(t)
        or WEEK_RE.match(t)
        or DATE_TEXT_RE.search(t)
        or DATE_NUM_RE.search(t)
    )

def main(csv_in: str, lua_out: str) -> None:
    with open(csv_in, encoding="utf-8") as f:
        rows = list(csv.reader(f))

    sections = []
    current = None

    for row in rows:
        if not row:
            continue
        text = row[0].strip()
        if not text:
            continue

        if is_section_header(text):
            current = {"id": slug(text), "title": text, "items": []}
            sections.append(current)
        else:
            if current:
                current["items"].append({"id": slug(text), "text": text})

    out = []
    out.append("-- AUTO-GENERATED. DO NOT EDIT.")
    out.append("local addonName = ...")
    out.append('_G[addonName .. "_LIST_DATA"] = {')

    for s in sections:
        out.append("    {")
        out.append(f'        id = "{lua_escape(s["id"])}",')
        out.append(f'        title = "{lua_escape(s["title"])}",')
        out.append("        items = {")
        for i in s["items"]:
            out.append(f'            {{ id = "{lua_escape(i["id"])}", text = "{lua_escape(i["text"])}" }},')
        out.append("        },")
        out.append("    },")
    out.append("}")

    Path(lua_out).write_text("\n".join(out), encoding="utf-8")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

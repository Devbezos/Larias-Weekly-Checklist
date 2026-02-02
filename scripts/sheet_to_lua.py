#!/usr/bin/env python3
import csv
import re
import sys
from pathlib import Path

SHEET_URL = "https://docs.google.com/spreadsheets/d/1iK2SZUcz_ljnkdTG7KW6pqfzaUDuSgnlh1HupcLrkus/edit?gid=53744607"

HEADER_PREFIX_RE = re.compile(r"^\s*(Early Access|Pre-Season|Season|Week(?:s)?)\b", re.IGNORECASE)

MONTHS = r"(Jan|January|Feb|February|Mar|March|Apr|April|May|Jun|June|Jul|July|Aug|August|Sep|Sept|September|Oct|October|Nov|November|Dec|December)"
MONTH_DAY_RE = re.compile(rf"\b{MONTHS}\s+\d{{1,2}}\b", re.IGNORECASE)

LEADING_LUA_BLOCK_COMMENT_RE = re.compile(r"\A--\[\[.*?\]\]\s*", re.DOTALL)

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


def detect_newline(text: str) -> str:
    return "\r\n" if "\r\n" in text else "\n"


def extract_leading_block_comment(text: str) -> str | None:
    m = LEADING_LUA_BLOCK_COMMENT_RE.match(text)
    if not m:
        return None
    return m.group(0)

def main(csv_in: str, lua_out: str) -> None:
    with open(csv_in, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))

    sections = []
    current = None

    for row in rows:
        if not row:
            continue
        text = wow_safe_text((row[0] or "").strip())
        if not text:
            continue

        if is_section_header(text):
            current = {"id": slug(text), "title": text, "items": []}
            sections.append(current)
        else:
            if current is None:
                continue
            current["items"].append({"id": slug(text), "text": text})
    out: list[str] = []

    existing_text = None
    out_path = Path(lua_out)
    nl = "\n"
    existing_header = None

    if out_path.exists():
        existing_text = out_path.read_text(encoding="utf-8")
        nl = detect_newline(existing_text)
        existing_header = extract_leading_block_comment(existing_text)

    if existing_header:
        header_norm = existing_header.replace("\r\n", "\n").replace("\r", "\n").rstrip("\n")
        out.extend(header_norm.split("\n"))
        out.append("")
    else:
        out.append("--[[")
        out.append("Localization (checklist data)")
        out.append("")
        out.append("This file provides the default (enUS) checklist data.")
        out.append("To add a new language:")
        out.append("1) Copy Locales\\\\enUS.lua -> Locales\\\\<locale>.lua (example: Locales\\\\deDE.lua)")
        out.append("2) Copy Locales\\\\enUS_Data.lua -> Locales\\\\<locale>_Data.lua (example: Locales\\\\deDE_Data.lua)")
        out.append('3) In both copies, change the locale string ("enUS") to your locale ("deDE")')
        out.append("4) Translate section titles and item text in the _Data file")
        out.append("5) Add BOTH files to LariasWeeklyMidnightChecklist.toc AFTER the enUS entries")
        out.append("")
        out.append("Common locale codes: enUS, enGB, frFR, deDE, esES, esMX, itIT, ptBR, ruRU, koKR, zhCN, zhTW")
        out.append("]]")
        out.append("")

    out.append("local addonName = ...")
    out.append("local locale = (GetLocale and GetLocale()) or nil")
    out.append('local LOCALE = "enUS"')
    out.append('local listKey = addonName .. "_LIST_DATA"')
    out.append("")
    out.append('if locale == LOCALE or type(_G[listKey]) ~= "table" then')
    out.append("_G[listKey] = {")
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
    out.append("end")
    out.append("")

    new_text = nl.join(out)
    if not new_text.endswith(nl):
        new_text += nl

    if existing_text is not None:
        if existing_text.replace("\r\n", "\n") == new_text.replace("\r\n", "\n"):
            return

    out_path.write_text(new_text, encoding="utf-8")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: sheet_to_lua.py <input.csv> <output.lua>")
        sys.exit(2)
    main(sys.argv[1], sys.argv[2])



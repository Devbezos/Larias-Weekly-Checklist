#!/usr/bin/env python3
import csv
import re
import sys
from pathlib import Path

HEADER_PREFIX_RE = re.compile(r"^\s*(Early Access|Pre-Season|Season|Week(?:s)?)\b", re.IGNORECASE)

MONTHS = r"(Jan|January|Feb|February|Mar|March|Apr|April|May|Jun|June|Jul|July|Aug|August|Sep|Sept|September|Oct|October|Nov|November|Dec|December)"
MONTH_DAY_RE = re.compile(rf"\b{MONTHS}\s+\d{{1,2}}\b", re.IGNORECASE)


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


def build_enus_data_header() -> list[str]:
    return [
        "--[[",
        "English (enUS) checklist data for Larias's Weekly Checklist",
        "",
        "NOTE: This is the canonical enUS dataset; other locales must keep IDs identical",
        "so completion tracking stays consistent across locales.",
        "]]",
        "",
    ]

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

    if out_path.exists():
        existing_text = out_path.read_text(encoding="utf-8")
        nl = detect_newline(existing_text)

    out.extend(build_enus_data_header())

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
        if existing_text.replace("\r\n", "\n") == new_text.replace("\r\n", "\n"):
            return

    out_path.write_text(new_text, encoding="utf-8")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: sheet_to_lua.py <input.csv> <output.lua>")
        sys.exit(2)
    main(sys.argv[1], sys.argv[2])



#!/usr/bin/env python3

from pathlib import Path


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    path = repo_root / "features" / "footer" / "LariasWeeklyChecklist_CharPicker.lua"
    content = path.read_text(encoding="utf-8")

    replacements = {
        r'        btn:SetText("|cffff4040\u2716|r")':
            '        btn:SetText("|TInterface\\\\RaidFrame\\\\ReadyCheck-NotReady:12:12|t")',
        r'        local CHECK = "|cff00ff00\u2714|r"':
            '        local CHECK = "|TInterface\\\\RaidFrame\\\\ReadyCheck-Ready:12:12|t"',
    }

    updated = content
    for old, new in replacements.items():
        updated = updated.replace(old, new)

    if updated == content:
        print("No icon replacements needed.")
        return 0

    path.write_text(updated, encoding="utf-8")
    print(f"Updated {path.relative_to(repo_root)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

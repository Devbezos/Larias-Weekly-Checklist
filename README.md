# Larias' Weekly Checklist

[![CurseForge](https://img.shields.io/badge/CurseForge-Install-F16436?logo=curseforge&logoColor=white)](https://www.curseforge.com/wow/addons/larias-weekly-midnight-checklist)
[![Wago](https://img.shields.io/badge/Wago-Install-C1272D)](https://addons.wago.io/addons/mKOD5RGx)
[![GitHub Release](https://img.shields.io/github/v/release/Devbezos/Larias-Weekly-Checklist?label=GitHub&color=181717&logo=github&logoColor=white)](https://github.com/Devbezos/Larias-Weekly-Checklist/releases/latest)

## Install

Pick whichever you prefer:

- **CurseForge / Wago** — click a badge above, then install and keep it updated through the CurseForge App or Wago App. This is the easiest option and handles updates automatically.
- **GitHub** — click the GitHub badge above to open the latest release, download the attached zip, and extract it into your WoW `Interface/AddOns/` directory. Updates are manual with this option.

## How releases are built

```mermaid
flowchart TD

    A((Start)):::start

    B[Triggered: hourly schedule or manual dispatch]:::process
    E[Download Larias Sheet as CSV]:::process
    F[Convert CSV -> LUA]:::process
    W[Check Wago for latest WoW version]:::process
    G{Did WoW version or Spreadsheet change?}:::decision
    H((Do nothing)):::finish
    I[Bump Addon Version]:::process
    J[Commit + push]:::process
    K[Tag release]:::process
    L[Build addon package]:::process
    M[Upload to CurseForge & Wago]:::process
    O[Post Discord webhook]:::process
    P((Job's done)):::finish

    B --> E --> F --> W --> G
    G -- No --> H
    G -- Yes --> I --> J --> K --> L --> M --> O --> P

    A --> B

classDef start fill:#1E8449,color:#FFFFFF,stroke:#0B3D1F,stroke-width:2px;
classDef process fill:#27AE60,color:#FFFFFF,stroke:#145A32,stroke-width:1.5px;
classDef decision fill:#F4D03F,color:#1B2631,stroke:#B7950B,stroke-width:2px;
classDef finish fill:#2C3E50,color:#FFFFFF,stroke:#1B2631,stroke-width:2px;
```

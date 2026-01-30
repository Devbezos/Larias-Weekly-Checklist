```mermaid
flowchart TD

    A((Start)):::start
    B[Schedule Triggered<br/>Hourly or Manual]:::process
    E[Download Google Sheet - CSV]:::process
    F[Convert CSV to Lua File]:::process
    G{Did Lua File Change?}:::decision

    H((No Changes)):::finish
    I[Bump Version in .toc]:::process
    J[Commit and Push Changes]:::process
    K[Create Git Tag]:::process
    L[Build Addon Package]:::process
    M[Upload to CurseForge]:::process
    N[Upload to Wago]:::process
    O[Post Discord Webhook]:::process
    P((Release Complete)):::finish

    A --> B --> E --> F --> G
    G -- No --> H
    G -- Yes --> I --> J --> K --> L --> M --> N --> O --> P

    classDef start fill:#145A32,color:#FFFFFF,stroke:#0B3D1F,stroke-width:2px;
    classDef process fill:#1E8449,color:#FFFFFF,stroke:#0B3D1F,stroke-width:1.5px;
    classDef decision fill:#52BE80,color:#0B3D1F,stroke:#1D8348,stroke-width:2px;
    classDef finish fill:#0E6251,color:#FFFFFF,stroke:#0B3D1F,stroke-width:2px;

```

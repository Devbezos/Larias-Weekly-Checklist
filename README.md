flowchart TD

    ```
    A((Start)):::start
    B[Schedule Triggered<br/>Hourly or Manual]:::process
    C[Checkout Repository]:::process
    D[Setup Python 3.11]:::process
    E[Download Google Sheet (CSV)]:::process
    F[Convert CSV → Lua File]:::process
    G{Did Lua File Change?}:::decision

    H((End - No Changes)):::end
    I[Bump Version in .toc]:::process
    J[Commit & Push Changes]:::process
    K[Create Git Tag]:::process
    L[Build Addon Package]:::process
    M[Upload to CurseForge]:::process
    N[Upload to Wago]:::process
    O[Post Discord Webhook]:::process
    P((End - Release Complete)):::end

    A --> B --> C --> D --> E --> F --> G
    G -- No --> H
    G -- Yes --> I --> J --> K --> L --> M --> N --> O --> P

    classDef start fill:#4CAF50,color:#fff,stroke:#2E7D32,stroke-width:2px;
    classDef end fill:#E53935,color:#fff,stroke:#B71C1C,stroke-width:2px;
    classDef process fill:#2196F3,color:#fff,stroke:#0D47A1,stroke-width:1px;
    classDef decision fill:#FFC107,color:#000,stroke:#FF8F00,stroke-width:2px;
```

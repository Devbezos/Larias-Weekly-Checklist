param([switch]$Update = $false, [switch]$Clean = $false)

$LibDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Libs"
$Libs = @{
    "LibStub" = "https://github.com/zerosnake0/LibStub.git"
    "CallbackHandler-1.0" = "https://github.com/zerosnake0/CallbackHandler-1.0.git"
    "LibDataBroker-1.1" = "https://github.com/tekkub/libdatabroker-1-1.git"
    "LibDBIcon-1.0" = "https://github.com/zerosnake0/LibDBIcon-1.0.git"
    "Ace3" = "https://github.com/WoWUIDev/Ace3.git"
}

if (-not (git --version 2>$null)) {
    Write-Host "ERROR: Git not found" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $LibDir)) {
    New-Item -ItemType Directory -Path $LibDir -Force | Out-Null
}

if ($Clean) {
    foreach ($lib in $Libs.GetEnumerator()) {
        $path = Join-Path $LibDir $lib.Key
        if (Test-Path $path) { Remove-Item $path -Recurse -Force }
    }
    Write-Host "Libraries cleaned" -ForegroundColor Green
} else {
    foreach ($lib in $Libs.GetEnumerator()) {
        $path = Join-Path $LibDir $lib.Key
        if (Test-Path $path) {
            if ($Update) { git -C $path pull --quiet }
        } else {
            git clone --quiet $lib.Value $path
        }
    }
    Write-Host "Libraries ready" -ForegroundColor Green
}

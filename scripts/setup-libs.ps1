param([switch]$Update = $false, [switch]$Clean = $false)

$LibDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Libs"
$Libs = @{
    "LibStub" = "https://github.com/zerosnake0/LibStub.git"
    "CallbackHandler-1.0" = "https://github.com/zerosnake0/CallbackHandler-1.0.git"
    "LibDataBroker-1.1" = "https://github.com/tekkub/libdatabroker-1-1.git"
    "LibDBIcon-1.0" = "https://github.com/zerosnake0/LibDBIcon-1.0.git"
    "LibWindow-1.1" = "https://github.com/wowace-clone/LibWindow-1.1.git"
    "Ace3" = "https://github.com/WoWUIDev/Ace3.git"
}

# Some repos (especially when packaged) can leave placeholder directories behind.
# Validate libs by checking for a sentinel entrypoint file; if missing, re-clone.
$LibSentinels = @{
	"LibStub" = "LibStub.lua"
	"CallbackHandler-1.0" = "CallbackHandler-1.0.lua"
	"LibDataBroker-1.1" = "LibDataBroker-1.1.lua"
	"LibDBIcon-1.0" = "LibDBIcon-1.0.lua"
	"LibWindow-1.1" = (Join-Path "LibWindow-1.1" "LibWindow-1.1.lua")
	"Ace3" = (Join-Path "AceTimer-3.0" "AceTimer-3.0.lua")
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
        $exists = Test-Path $path
        $hasGit = $false
        if ($exists) {
            $hasGit = Test-Path (Join-Path $path ".git")
            # If a placeholder directory exists but is empty, treat it as missing so we can clone it.
            $entries = @(Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue)
            if ($entries.Count -eq 0) {
                Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
                $exists = $false
                $hasGit = $false
            }
        }

        # If a directory exists but doesn't contain its expected entrypoint file and isn't a git clone,
        # it's likely a placeholder. Re-clone it.
        if ($exists -and (-not $hasGit) -and $LibSentinels.ContainsKey($lib.Key)) {
            $sentinel = Join-Path $path $LibSentinels[$lib.Key]
            if (-not (Test-Path $sentinel)) {
                Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
                $exists = $false
            }
        }

        if (-not $exists) {
            git clone --quiet $lib.Value $path
        } elseif ($Update -and (Test-Path (Join-Path $path ".git"))) {
            git -C $path pull --quiet
        }
    }
    Write-Host "Libraries ready" -ForegroundColor Green
}

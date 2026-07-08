# watch_deploy.ps1
# Watches the addon source every 5 minutes and deploys when both are true:
#   1. The source TOC version differs from the deployed TOC version.
#   2. The combined content hash of TOC-loaded source files changed since the
#      last successful deploy in this watcher session.
#
# Run this in a persistent terminal. Press Ctrl+C to stop.

$IntervalSeconds = 300

$here         = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot     = Split-Path -Parent $here
$deployScript = Join-Path $here "deploy_to_wow.ps1"

$srcTocPath = Join-Path $repoRoot "LariasWeeklyChecklist.toc"

$destBase    = "D:\Battle.NET\World Of Warcraft\_retail_\Interface\AddOns\LariasWeeklyChecklist"
$destTocPath = Join-Path $destBase "LariasWeeklyChecklist.toc"

function Get-TocVersion {
    param([string]$TocPath)

    if (-not (Test-Path -LiteralPath $TocPath)) { return $null }

    $line = Get-Content -LiteralPath $TocPath |
        Where-Object { $_ -match '^\s*##\s*Version\s*:' } |
        Select-Object -First 1

    if (-not $line) { return $null }

    $version = ($line -replace '^\s*##\s*Version\s*:\s*', '').Trim()
    return $version -replace '-dev$', ''
}

function Get-SourceHash {
    $tocLines = @()
    if (Test-Path -LiteralPath $srcTocPath) {
        $tocLines = Get-Content -LiteralPath $srcTocPath |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith("##") -and -not $_.StartsWith("#") } |
            ForEach-Object { $_ -replace '\\', '\' -replace '/', '\' }
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $files = @($srcTocPath)

    foreach ($relativePath in $tocLines) {
        $fullPath = Join-Path $repoRoot $relativePath
        if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
            $files += $fullPath
        }
    }

    $combined = New-Object System.IO.MemoryStream
    foreach ($file in $files) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $combined.Write($bytes, 0, $bytes.Length)
        } catch {
            Write-Warning "Could not hash $file"
        }
    }

    $combined.Position = 0
    $hashBytes = $sha.ComputeHash($combined)
    $combined.Dispose()
    $sha.Dispose()

    return [BitConverter]::ToString($hashBytes) -replace '-', ''
}

if (-not (Test-Path -LiteralPath $deployScript -PathType Leaf)) {
    throw "Missing deploy script: $deployScript"
}

Write-Host "Watch-deploy started (interval: $IntervalSeconds s, ~$([math]::Round($IntervalSeconds / 60, 0)) min)"
Write-Host "Source  : $srcTocPath"
Write-Host "Deployed: $destTocPath"
Write-Host "Press Ctrl+C to stop."
Write-Host ""

$lastDeployedHash = $null

while ($true) {
    $timestamp = Get-Date -Format "HH:mm:ss"

    $srcVersion  = Get-TocVersion -TocPath $srcTocPath
    $destVersion = Get-TocVersion -TocPath $destTocPath
    $versionChanged = ($srcVersion -ne $null) -and ($srcVersion -ne $destVersion)

    $currentHash = Get-SourceHash
    $contentChanged = ($currentHash -ne $lastDeployedHash)

    if ($versionChanged -and $contentChanged) {
        Write-Host "[$timestamp] Version $destVersion -> $srcVersion | content changed -> deploying..." -ForegroundColor Cyan
        & $deployScript -WowAddonPath $destBase
        $lastDeployedHash = $currentHash
        Write-Host "[$timestamp] Deploy complete." -ForegroundColor Green
    } else {
        $reason = @()
        if (-not $versionChanged) { $reason += "version unchanged ($srcVersion)" }
        if (-not $contentChanged) { $reason += "content unchanged" }
        Write-Host "[$timestamp] Skipped: $($reason -join ', ')." -ForegroundColor DarkGray
    }

    Start-Sleep -Seconds $IntervalSeconds
}

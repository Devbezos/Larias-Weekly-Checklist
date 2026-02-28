# watch_deploy.ps1
# Watches the addon source every 5 minutes and only deploys when:
#   1. The ## Version: in the source .toc differs from the deployed .toc
#      (the deployed copy has a -dev suffix appended by deploy_to_wow.ps1,
#       so we strip that before comparing).
#   2. The combined content hash of all tracked source files has changed
#      since the last successful deploy.
# Run this in a persistent terminal; press Ctrl+C to stop.

$IntervalSeconds = 300   # 5 minutes

$here     = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $here
$deployScript = Join-Path $here "deploy_to_wow.ps1"

$srcTocPath = Join-Path $repoRoot "LariasWeeklyChecklist.toc"

$destBase    = "D:\Battle.NET\World Of Warcraft\_retail_\Interface\AddOns\LariasWeeklyChecklist"
$destTocPath = Join-Path $destBase "LariasWeeklyChecklist.toc"

# ── Helpers ───────────────────────────────────────────────────────────────────

function Get-TocVersion ([string]$tocPath) {
    if (-not (Test-Path -LiteralPath $tocPath)) { return $null }
    $line = Get-Content -LiteralPath $tocPath |
        Where-Object { $_ -match '^\s*##\s*Version\s*:' } |
        Select-Object -First 1
    if (-not $line) { return $null }
    # Strip "## Version: " prefix and any trailing -dev suffix.
    $ver = ($line -replace '^\s*##\s*Version\s*:\s*', '').Trim()
    $ver = $ver -replace '-dev$', ''
    return $ver
}

# Returns a SHA256 hash of the combined content of every source file listed in
# the TOC plus the TOC itself.  Changes to any tracked file will change the hash.
function Get-SourceHash {
    $tocLines = @()
    if (Test-Path -LiteralPath $srcTocPath) {
        $tocLines = Get-Content -LiteralPath $srcTocPath |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith("##") -and -not $_.StartsWith("#") } |
            ForEach-Object { $_ -replace '\\\\', '\' -replace '/', '\' }
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $files = @($srcTocPath)
    foreach ($rel in $tocLines) {
        $full = Join-Path $repoRoot $rel
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $files += $full
        }
    }

    $combined = New-Object System.IO.MemoryStream
    foreach ($f in $files) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($f)
            $combined.Write($bytes, 0, $bytes.Length)
        } catch { }
    }
    $combined.Position = 0
    $hashBytes = $sha.ComputeHash($combined)
    $combined.Dispose()
    $sha.Dispose()
    return [BitConverter]::ToString($hashBytes) -replace '-', ''
}

# ── Main loop ─────────────────────────────────────────────────────────────────

Write-Host "Watch-deploy started  (interval: $IntervalSeconds s, ~$([math]::Round($IntervalSeconds/60,0)) min)"
Write-Host "Source  : $srcTocPath"
Write-Host "Deployed: $destTocPath"
Write-Host "Press Ctrl+C to stop."
Write-Host ""

$lastDeployedHash = $null

while ($true) {
    $ts = Get-Date -Format "HH:mm:ss"

    # ── Version check ─────────────────────────────────────────────────────────
    $srcVersion  = Get-TocVersion $srcTocPath
    $destVersion = Get-TocVersion $destTocPath   # $null if not yet deployed

    $versionChanged = ($srcVersion -ne $null) -and ($srcVersion -ne $destVersion)

    # ── Content hash check ────────────────────────────────────────────────────
    $currentHash   = Get-SourceHash
    $contentChanged = ($currentHash -ne $lastDeployedHash)

    # ── Decision ──────────────────────────────────────────────────────────────
    if ($versionChanged -and $contentChanged) {
        Write-Host "[$ts] Version $destVersion → $srcVersion  |  content changed  →  deploying..." -ForegroundColor Cyan
        & $deployScript
        # Record the hash we just deployed so we don't redeploy on next tick
        # unless content changes again.
        $lastDeployedHash = $currentHash
        Write-Host "[$ts] Deploy complete." -ForegroundColor Green
    } else {
        $reason = @()
        if (-not $versionChanged) { $reason += "version unchanged ($srcVersion)" }
        if (-not $contentChanged) { $reason += "content unchanged" }
        Write-Host "[$ts] Skipped — $($reason -join ', ')." -ForegroundColor DarkGray
    }

    Start-Sleep -Seconds $IntervalSeconds
}

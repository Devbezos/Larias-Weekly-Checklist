# watch_deploy.ps1
# Watches the addon source every 5 minutes and deploys when either the source
# version or any TOC-loaded content differs from what is currently deployed.
# The deployed TOC's "-dev" suffix is normalised away during comparison so it
# does not cause false positives.
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

function Get-TocAddonFiles {
    param([string]$TocPath)

    if (-not (Test-Path -LiteralPath $TocPath -PathType Leaf)) {
        return @()
    }

    return Get-Content -LiteralPath $TocPath |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("##") -and -not $_.StartsWith("#") } |
        ForEach-Object { $_ -replace '\\', '\' -replace '/', '\' }
}

function Get-NormalizedFileBytes {
    param(
        [string]$FilePath,
        [string]$RelativePath,
        [switch]$NormalizeDeployedArtifacts
    )

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    if (-not $NormalizeDeployedArtifacts) {
        return $bytes
    }

    if ($RelativePath -ieq "LariasWeeklyChecklist.toc") {
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        $text = $text -replace '(?m)^(##\s*Version:\s*[^\r\n]+?)-dev(\s*)$', '$1$2'
        return [System.Text.Encoding]::UTF8.GetBytes($text)
    }

    return $bytes
}

function Get-AddonHash {
    param(
        [string]$BasePath,
        [string]$TocPath,
        [switch]$NormalizeDeployedArtifacts
    )

    if (-not (Test-Path -LiteralPath $TocPath -PathType Leaf)) {
        return $null
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $files = @(
        [PSCustomObject]@{
            RelativePath = "LariasWeeklyChecklist.toc"
            FullPath = $TocPath
        }
    )

    foreach ($relativePath in Get-TocAddonFiles -TocPath $TocPath) {
        $fullPath = Join-Path $BasePath $relativePath
        if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
            $files += [PSCustomObject]@{
                RelativePath = $relativePath
                FullPath = $fullPath
            }
        }
    }

    $combined = New-Object System.IO.MemoryStream
    foreach ($file in $files) {
        try {
            $bytes = Get-NormalizedFileBytes -FilePath $file.FullPath -RelativePath $file.RelativePath -NormalizeDeployedArtifacts:$NormalizeDeployedArtifacts
            $combined.Write($bytes, 0, $bytes.Length)
        } catch {
            Write-Warning "Could not hash $($file.FullPath)"
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

while ($true) {
    $timestamp = Get-Date -Format "HH:mm:ss"

    $srcVersion  = Get-TocVersion -TocPath $srcTocPath
    $destVersion = Get-TocVersion -TocPath $destTocPath
    $versionChanged = ($srcVersion -ne $null) -and ($srcVersion -ne $destVersion)

    $sourceHash = Get-AddonHash -BasePath $repoRoot -TocPath $srcTocPath
    $deployedHash = Get-AddonHash -BasePath $destBase -TocPath $destTocPath -NormalizeDeployedArtifacts
    $contentChanged = ($sourceHash -ne $null) -and ($sourceHash -ne $deployedHash)

    if ($versionChanged -or $contentChanged) {
        $reasons = @()
        if ($versionChanged) { $reasons += "version $destVersion -> $srcVersion" }
        if ($contentChanged) { $reasons += "content changed" }
        Write-Host "[$timestamp] $($reasons -join ' | ') -> deploying..." -ForegroundColor Cyan
        & $deployScript -WowAddonPath $destBase
        Write-Host "[$timestamp] Deploy complete." -ForegroundColor Green
    } else {
        $reason = @()
        if (-not $versionChanged) { $reason += "version unchanged ($srcVersion)" }
        if (-not $contentChanged) { $reason += "content unchanged" }
        Write-Host "[$timestamp] Skipped: $($reason -join ', ')." -ForegroundColor DarkGray
    }

    Start-Sleep -Seconds $IntervalSeconds
}

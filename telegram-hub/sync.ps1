param(
    [string]$RepoUrl = "https://github.com/ninamc4e/my_ai_opencode_server.git",
    [string]$Branch = "main",
    [switch]$Verbose,
    [switch]$Quiet
)

function Invoke-Git {
    param([string[]]$Arguments)
    $origErrorPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & "git" @Arguments 2>&1 | ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } }
    $global:LASTEXITCODE = $LASTEXITCODE
    $ErrorActionPreference = $origErrorPref
}

$nodeName = if (Test-Path "$PSScriptRoot\sync.json") {
    (Get-Content "$PSScriptRoot\sync.json" | ConvertFrom-Json).node_name
} else { "unknown" }

if (-not $Quiet) { Write-Host "=== Sync [$nodeName] ===" -ForegroundColor Cyan }

# 1. Clone sync repo to temp
$syncDir = Join-Path $env:TEMP "opencode_sync_$(Get-Random)"
if (-not $Quiet) { Write-Host "Cloning $RepoUrl ($Branch)..." }
Invoke-Git @("clone", "--depth", "1", "-b", $Branch, $RepoUrl, $syncDir) | Out-Null
if ($LASTEXITCODE -ne 0) { throw "git clone failed (exit $LASTEXITCODE)" }

# 2. Get current dir (where HANDOVER.md lives)
$srcDir = (Get-Item $PSScriptRoot).Parent.FullName

# 3. Merge HANDOVER.md
$remoteFile = Join-Path $syncDir "HANDOVER.md"
$localFile  = Join-Path $srcDir "HANDOVER.md"
$dirty = $false

if ((Test-Path $localFile) -and (Test-Path $remoteFile)) {
    $remoteContent = Get-Content $remoteFile -Raw
    $localContent  = Get-Content $localFile -Raw

    if ($localContent -ne $remoteContent) {
        if (-not $Quiet) { Write-Host "Merging HANDOVER.md..." -ForegroundColor Yellow }

        if ($remoteContent.StartsWith($localContent.Substring(0, [Math]::Min(200, $localContent.Length)))) {
            if (-not $Quiet) { Write-Host "  Local is newer: pushing local version" }
            Set-Content $remoteFile $localContent -NoNewline
            $dirty = $true
        } elseif ($localContent.StartsWith($remoteContent.Substring(0, [Math]::Min(200, $remoteContent.Length)))) {
            if (-not $Quiet) { Write-Host "  Remote is newer: keeping remote + appending local suffix" }
            $remoteLines = $remoteContent -split "`r`n|`n"
            $localLines  = $localContent -split "`r`n|`n"
            $newLines = @()
            $foundDiff = $false
            for ($i = 0; $i -lt $localLines.Count; $i++) {
                if ($i -lt $remoteLines.Count) {
                    if ($localLines[$i] -ne $remoteLines[$i]) { $foundDiff = $true }
                } else {
                    $foundDiff = $true
                }
                if ($foundDiff) { $newLines += $localLines[$i] }
            }
            if ($newLines.Count -gt 0) {
                $merged = $remoteContent.TrimEnd() + "`r`n" + ($newLines -join "`r`n") + "`r`n"
                Set-Content $remoteFile $merged -NoNewline
                $dirty = $true
            }
        } else {
            if (-not $Quiet) { Write-Host "  Content differs: taking local version" }
            Set-Content $remoteFile $localContent -NoNewline
            $dirty = $true
        }
    }
} elseif (Test-Path $localFile) {
    Copy-Item $localFile $remoteFile -Force
    $dirty = $true
}

# 4. Copy CONTEXT.md and USER.md (one-way: local -> remote if newer)
foreach ($file in @("CONTEXT.md", "USER.md")) {
    $src = Join-Path $srcDir $file
    $dst = Join-Path $syncDir $file
    if (Test-Path $src) {
        $copy = $false
        if (-not (Test-Path $dst)) {
            $copy = $true
        } else {
            $srcTime = (Get-Item $src).LastWriteTime
            $dstTime = (Get-Item $dst).LastWriteTime
            if ($srcTime -gt $dstTime) { $copy = $true }
        }
        if ($copy) {
            Copy-Item $src $dst -Force
            $dirty = $true
            if (-not $Quiet) { Write-Host "  Updated $file" }
        }
    }
}

# 5. Push if changed
if ($dirty) {
    Push-Location $syncDir
    $commitMsg = "sync [$nodeName] $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    Invoke-Git @("add", "-A") | Out-Null
    Invoke-Git @("diff", "--cached", "--quiet") | Out-Null
    $hasDiff = $LASTEXITCODE
    if ($hasDiff -ne 0) {
        Invoke-Git @("commit", "-m", $commitMsg) | Out-Null
        if (-not $Quiet) { Write-Host "Pushing... $commitMsg" }
        Invoke-Git @("push", "origin", $Branch) | Out-Null
        if ($LASTEXITCODE -eq 0) {
            if (-not $Quiet) { Write-Host "Sync OK: pushed to $Branch" -ForegroundColor Green }
        } else {
            if (-not $Quiet) { Write-Host "Push failed (exit $LASTEXITCODE). Check auth." -ForegroundColor Red }
        }
    } else {
        if (-not $Quiet) { Write-Host "No changes to push" -ForegroundColor Gray }
    }
    Pop-Location
} else {
    if (-not $Quiet) { Write-Host "Already in sync" -ForegroundColor Green }
}

# 6. Cleanup
Remove-Item $syncDir -Recurse -Force -ErrorAction SilentlyContinue

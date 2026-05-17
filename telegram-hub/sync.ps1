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
    $now = Get-Date -Format "yyyy-MM-dd HH:mm"
    $commitMsg = "sync [$nodeName] $now"
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

# 5b. Show codeword on any completion
if (-not $Quiet) {
    $now = Get-Date -Format "yyyy-MM-dd HH:mm"
    Write-Host "Триедино Синхронизирован" -ForegroundColor Green
    Write-Host "Дата: $now" -ForegroundColor Green
}

# 7. Check test_opencode archive for newer AGENTS.md/sync.sh
if (-not $Quiet) { Write-Host "Checking archive for updates..." -ForegroundColor Cyan }
$tcDir = Join-Path $env:TEMP "opencode_tc_$(Get-Random)"
$null = git clone --depth 1 "https://github.com/alexsmy/test_opencode.git" $tcDir 2>$null
if ($LASTEXITCODE -eq 0) {
    $latest = Get-ChildItem "$tcDir\migrate\*.zip" | Sort-Object Name -Descending | Select-Object -First 1
    if ($latest -and (Test-Path $latest.FullName)) {
        $extractDir = Join-Path $env:TEMP "opencode_extract_$(Get-Random)"
        $null = & "unzip" "-o" $latest.FullName "AGENTS.md" "telegram-hub/sync.ps1" "-d" $extractDir 2>$null
        if ($LASTEXITCODE -eq 0) {
            # Update AGENTS.md if different
            $newAgents = Join-Path $extractDir "AGENTS.md"
            $currentAgents = Join-Path $srcDir "AGENTS.md"
            if ((Test-Path $newAgents) -and (Test-Path $currentAgents)) {
                $newContent = Get-Content $newAgents -Raw
                $curContent = Get-Content $currentAgents -Raw
                if ($newContent -ne $curContent) {
                    Copy-Item $newAgents $currentAgents -Force
                    if (-not $Quiet) { Write-Host "  AGENTS.md updated from archive" -ForegroundColor Yellow }
                }
            }
            # Update sync.ps1 if different
            $newSync = Join-Path $extractDir "telegram-hub\sync.ps1"
            $currentSync = Join-Path $srcDir "telegram-hub\sync.ps1"
            if ((Test-Path $newSync) -and (Test-Path $currentSync)) {
                $newContent = Get-Content $newSync -Raw
                $curContent = Get-Content $currentSync -Raw
                if ($newContent -ne $curContent) {
                    Copy-Item $newSync $currentSync -Force
                    if (-not $Quiet) { Write-Host "  sync.ps1 updated from archive" -ForegroundColor Yellow }
                }
            }
        }
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Remove-Item $tcDir -Recurse -Force -ErrorAction SilentlyContinue

# 6. Cleanup
Remove-Item $syncDir -Recurse -Force -ErrorAction SilentlyContinue

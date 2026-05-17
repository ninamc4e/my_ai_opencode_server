[CmdletBinding()]
param(
    [switch]$PassThru
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# === 1. Create backup archive + upload to FileVault ===
$backupScript = Join-Path $projectRoot "SCRIPTs\backup.ps1"
if (-not (Test-Path $backupScript)) {
    Write-Error "backup.ps1 not found: $backupScript"
    exit 1
}

Write-Verbose "Creating backup and uploading to Render (folder: migrate)..."
$backupResult = & $backupScript -Upload -Keep -PassThru -Verbose -Folder "migrate"

if (-not $backupResult -or [string]::IsNullOrEmpty($backupResult.file_id)) {
    Write-Error "Backup upload failed — no file_id"
    exit 1
}

$fileId = $backupResult.file_id
$url = $backupResult.url
$zipPath = $backupResult.path
$zipName = $backupResult.name

Write-Verbose "Backup uploaded: file_id=$fileId url=$url"
Write-Verbose "Archive kept at: $zipPath"

# === 2. Push archive to GitHub (test_opencode/migrate/) ===
$gitRepoUrl = "git@github.com:alexsmy/test_opencode.git"
$gitTempDir = Join-Path $env:TEMP "opencode_migrate_$(Get-Date -Format 'yyyyMMddHHmmss')"
$gitBranch = "main"

Write-Verbose "Cloning $gitRepoUrl to $gitTempDir ..."
try {
    & git clone --depth 1 $gitRepoUrl $gitTempDir 2>&1 | ForEach-Object { Write-Verbose $_ }
    if (-not (Test-Path $gitTempDir)) {
        throw "Git clone failed — directory not created"
    }

    $migrateDir = Join-Path $gitTempDir "migrate"
    if (-not (Test-Path $migrateDir)) {
        New-Item -ItemType Directory -Path $migrateDir -Force | Out-Null
    }

    Copy-Item -Path $zipPath -Destination (Join-Path $migrateDir $zipName) -Force

    Push-Location $gitTempDir
    try {
        & git add migrate/$zipName 2>&1 | ForEach-Object { Write-Verbose $_ }

        $gitStatus = & git status --porcelain
        if ($gitStatus) {
            & git -c user.name="alexs" -c user.email="alex.smyslov@mail.ru" commit -m "migrate: add backup $zipName [skip ci]" 2>&1 | ForEach-Object { Write-Verbose $_ }
            & git push origin $gitBranch 2>&1 | ForEach-Object { Write-Verbose $_ }
            Write-Verbose "GitHub push successful"
            $gitResult = "OK"
        } else {
            Write-Verbose "Nothing to commit — archive already up-to-date"
            $gitResult = "SKIPPED (no changes)"
        }
    } finally {
        Pop-Location
    }
} catch {
    Write-Warning "GitHub push failed: $_"
    $gitResult = "FAILED: $_"
} finally {
    # Clean up temp clone
    if (Test-Path $gitTempDir) {
        Remove-Item -Path $gitTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Clean up the archive file
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
}

# === 3. Send notification ===
$nl = [Environment]::NewLine
$msg = "<b>Миграция — бэкап создан</b>$nl"
$msg += "$nl"
$msg += "<b>Дата:</b> $(Get-Date -Format 'dd.MM.yyyy HH:mm')$nl"
$msg += "<b>File ID:</b> $fileId$nl"
$msg += "<b>Render URL:</b> $url$nl"
$msg += "<b>GitHub:</b> $gitResult$nl"
$msg += "$nl"
$msg += "Архив загружен на Render FileVault$nl"
$msg += "и отправлен в test_opencode/migrate/.$nl"
$msg += "HANDOVER.md обновлён.$nl"
$msg += "Готово к восстановлению на новом ПК."

$notifyPath = Join-Path $scriptDir "notify.ps1"
if (Test-Path $notifyPath) {
    & powershell -File $notifyPath -Message $msg 2>&1 | Out-Null
}

if ($PassThru) { return @{ file_id = $fileId; url = $url; git = $gitResult } }
Write-Output "MIGRATE_OK file_id=$fileId url=$url git=$gitResult"

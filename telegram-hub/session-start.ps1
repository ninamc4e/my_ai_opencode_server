[CmdletBinding()]
param(
    [string]$Model = "unknown",
    [string]$ProjectRoot = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $scriptDir
}

# === 1. Opencode version ===
$opencodeVersion = "unknown"
try {
    $ver = opencode version 2>$null
    if ($ver) { $opencodeVersion = $ver.Trim() }
} catch {
    try {
        $raw = & opencode --version 2>$null
        if ($raw) { $opencodeVersion = $raw.Trim() }
    } catch {}
}

# === 2. Last session topic from HANDOVER.md ===
$lastTopic = "not found"
$handoverPath = Join-Path $ProjectRoot "HANDOVER.md"
if (Test-Path $handoverPath) {
    $lines = Get-Content $handoverPath -Encoding UTF8
    $inWhatSection = $false
    foreach ($line in $lines) {
        if ($line -match "^#{1,3}\s+(.*)") {
            $heading = $matches[1].Trim()
            if ($heading -match "Что было сделано") {
                $inWhatSection = $true
                continue
            }
            if ($inWhatSection) {
                $skipHeadings = @(
                    "Текущее состояние",
                    "Архитектура",
                    "Быстрый старт",
                    "Ключевые моменты",
                    "Полезные ссылки"
                )
                $skip = $false
                foreach ($s in $skipHeadings) {
                    if ($heading -match [regex]::Escape($s)) { $skip = $true; break }
                }
                if (-not $skip) {
                    $lastTopic = $heading
                    break
                }
            }
        }
    }
}

# === 3. Date and time ===
$now = Get-Date
$dateStr = $now.ToString("dd.MM.yyyy")
$timeStr = $now.ToString("HH:mm")

# === 4. Build HTML message ===
$nl = [Environment]::NewLine
$msg = "<b>Opencode — сессия запущена</b>$nl"
$msg += "$nl"
$msg += "<b>Версия:</b> $opencodeVersion$nl"
$msg += "<b>Модель ИИ:</b> $Model$nl"
$msg += "<b>Дата:</b> $dateStr, $timeStr$nl"
$msg += "<b>Последняя тема:</b> $lastTopic$nl"
$msg += "$nl"
$msg += "<b>Статус:</b> Все системы работают. Готов к задачам."

# === 5. Send via notify.ps1 ===
$notifyPath = Join-Path $scriptDir "notify.ps1"
if (Test-Path $notifyPath) {
    Write-Verbose "Sending notification via notify.ps1"
    Write-Verbose "Message:`n$msg"
    & powershell -File $notifyPath -Message $msg
} else {
    Write-Error "notify.ps1 not found: $notifyPath"
    exit 1
}
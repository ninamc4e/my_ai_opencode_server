[CmdletBinding()]
param(
    [string]$Summary = "",
    [string]$ProjectRoot = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $scriptDir
}

# Date and time
$now = Get-Date
$dateStr = $now.ToString("dd.MM.yyyy")
$timeStr = $now.ToString("HH:mm")

# Build message
$nl = [Environment]::NewLine
$msg = "<b>Сессия завершена</b>$nl"
$msg += "$nl"
$msg += "<b>Дата:</b> $dateStr, $timeStr$nl"
if (-not [string]::IsNullOrEmpty($Summary)) {
    $msg += "<b>Итог:</b> $Summary$nl"
    $msg += "$nl"
}
$msg += "<b>HANDOVER.md</b> обновлён для следующей сессии."

# Send via notify.ps1
$notifyPath = Join-Path $scriptDir "notify.ps1"
if (Test-Path $notifyPath) {
    Write-Verbose "Sending session-end notification"
    & powershell -File $notifyPath -Message $msg
} else {
    Write-Error "notify.ps1 not found: $notifyPath"
    exit 1
}
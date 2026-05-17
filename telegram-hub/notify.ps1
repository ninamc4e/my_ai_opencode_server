[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [string]$Kind = "single",
    [int]$DeleteAfterSeconds = 0,
    [bool]$DisableWebPagePreview = $true,
    [int]$MessageId = 0
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Проверяем, включены ли уведомления
$notifyPath = Join-Path $scriptDir "telegram-notify.json"
if (Test-Path $notifyPath) {
    $notify = Get-Content $notifyPath -Encoding UTF8 | ConvertFrom-Json
    if (-not $notify.enabled) {
        Write-Verbose "Notifications disabled (telegram-notify.json: enabled=false)"
        Write-Output "SKIPPED"
        exit 0
    }
    Write-Verbose "Notifications enabled, level=$($notify.level)"
}

# Читаем конфиг маршрутизации
$routePath = Join-Path $scriptDir "telegram-route.json"
if (!(Test-Path $routePath)) {
    Write-Error "Route config not found: $routePath"
    exit 1
}
try {
    $route = Get-Content $routePath -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-Error "Cannot read route config: $_"
    exit 1
}

Write-Verbose "Mode: $($route.mode)"

if ($route.mode -eq "server") {
    # === SERVER MODE (основной) ===
    $secretEnvName = $route.server.secret_env
    $secret = [Environment]::GetEnvironmentVariable($secretEnvName, "Process")
    if ([string]::IsNullOrEmpty($secret)) {
        $secret = [Environment]::GetEnvironmentVariable($secretEnvName, "User")
    }
    if ([string]::IsNullOrEmpty($secret)) {
        $secret = [Environment]::GetEnvironmentVariable($secretEnvName, "Machine")
    }
    if ([string]::IsNullOrEmpty($secret)) {
        Write-Error "Environment variable '$secretEnvName' is not set (checked Process/User/Machine)"
        exit 1
    }

    $body = @{
        text                     = $Message
        format                   = $route.server.format
        kind                     = $Kind
        disable_web_page_preview = $DisableWebPagePreview
        delete_after_seconds     = $DeleteAfterSeconds
    }
    if ($MessageId -gt 0) {
        $body.message_id = $MessageId
    }

    # ConvertTo-Json экранирует < > & как \u003c \u003e \u0026 — заменяем обратно
    $jsonBody = $body | ConvertTo-Json -Compress
    $jsonBody = $jsonBody.Replace('\u003c', '<').Replace('\u003e', '>').Replace('\u0026', '&')

    Write-Verbose "POST $($route.server.endpoint)`n$jsonBody"

    try {
        $utf8Body = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
        Invoke-RestMethod -Uri $route.server.endpoint -Method Post `
            -Body $utf8Body -ContentType "application/json; charset=utf-8" `
            -Headers @{ "X-Telegram-Tunnel-Secret" = $secret } `
            -TimeoutSec $route.server.timeout_seconds | Out-Null
        Write-Output "OK"
        exit 0
    } catch {
        Write-Error "Server send failed ($($_.Exception.Response.StatusCode.value__)): $_"
        exit 1
    }
} else {
    # === LOCAL MODE (браузерный, fallback) ===
    $configPath = Join-Path $scriptDir "telegram-config.json"

    if (!(Test-Path $configPath)) {
        Write-Error "Config not found: $configPath"
        exit 1
    }

    try {
        $config = Get-Content $configPath -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Error "Cannot read config: $_"
        exit 1
    }

    $encoded = [uri]::EscapeDataString($Message)
    $url = "https://api.telegram.org/bot$($config.token)/sendMessage?chat_id=$($config.chat_id)&text=$encoded&parse_mode=HTML&disable_web_page_preview=true"

    Write-Verbose "Local browser send: $url"

    $tmpFile = Join-Path $env:TEMP "tg-notify-$([System.IO.Path]::GetRandomFileName()).html"
    $html = @"
<!DOCTYPE html><html><body><script>
var img = new Image();
img.src = "$url";
img.style.display = 'none';
document.body.appendChild(img);
setTimeout(function(){ window.close(); }, 3000);
</script></body></html>
"@
    Set-Content -Path $tmpFile -Value $html -Encoding UTF8

    $browsers = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    )

    $browserPath = $null
    foreach ($b in $browsers) {
        if (Test-Path $b) { $browserPath = $b; break }
    }

    $timeout = if ($route.PSObject.Properties.Name -contains "local" -and $route.local.PSObject.Properties.Name -contains "browser_timeout_seconds") { $route.local.browser_timeout_seconds } else { 5 }

    if ($browserPath) {
        Start-Process -FilePath $browserPath -ArgumentList "--new-window `"$tmpFile`""
        Start-Sleep -Seconds $timeout
    } else {
        Start-Process $url
    }

    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue

    Write-Output "OK"
    exit 0
}

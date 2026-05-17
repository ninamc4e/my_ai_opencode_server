"""Скрипт для загрузки MCP-инструмента на сервер через API.
Использование: .\upload_mcp_tool.ps1 -Name current_time -CodeFile .\mcp_tools_examples\current_time.py
"""
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [string]$CodeFile,
    [string]$ServerUrl = "https://bot-29-nx0w.onrender.com",
    [string]$Description = "",
    [switch]$Verbose
)

$code = Get-Content $CodeFile -Encoding UTF8 -Raw

$body = @{
    name = $Name
    code = $code
}
if ($Description) { $body.description = $Description }

$jsonBody = $body | ConvertTo-Json -Compress -Depth 3
$utf8Body = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)

$secret = [Environment]::GetEnvironmentVariable("AGENTS_TUNNEL_SECRET", "Process")
if ([string]::IsNullOrEmpty($secret)) {
    $secret = [Environment]::GetEnvironmentVariable("AGENTS_TUNNEL_SECRET", "User")
}
if ([string]::IsNullOrEmpty($secret)) {
    Write-Error "AGENTS_TUNNEL_SECRET не задан"
    exit 1
}

$url = "$ServerUrl/api/agents/mcp-tools/register"
if ($Verbose) { Write-Host "POST $url" }

try {
    $resp = Invoke-RestMethod -Uri $url -Method Post `
        -Body $utf8Body -ContentType "application/json; charset=utf-8" `
        -Headers @{ "X-Agents-Tunnel-Secret" = $secret }
    Write-Host "OK: $($resp.result)"
    exit 0
} catch {
    Write-Error "Ошибка: $_"
    exit 1
}

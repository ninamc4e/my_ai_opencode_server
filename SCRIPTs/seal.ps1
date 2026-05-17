[CmdletBinding()]
param(
    [string]$MasterPassword = ""
)

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$secretsDir = Join-Path $projectRoot "secrets"

if (-not (Test-Path $secretsDir)) {
    New-Item -ItemType Directory -Path $secretsDir -Force | Out-Null
}

# Master password
$masterPwd = $MasterPassword
if ([string]::IsNullOrEmpty($masterPwd)) {
    $secPwd = Read-Host "Vvedite master-parol (zapomnite ego!)" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPwd)
    $masterPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

if ([string]::IsNullOrEmpty($masterPwd)) {
    Write-Error "Parol ne mozhet byt pustym"
    exit 1
}

Write-Host ""
Write-Host "=== Shifrovanie SSH klyucha ===" -ForegroundColor Cyan

$sshPath = "$env:USERPROFILE\.ssh\id_ed25519"
if (Test-Path $sshPath) {
    $reader = [System.IO.File]::Open($sshPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    $plain = New-Object byte[] ($reader.Length)
    $reader.Read($plain, 0, $reader.Length) | Out-Null
    $reader.Close()
    $salt = [System.Text.Encoding]::UTF8.GetBytes("opencode-ssh-salt-v1")
    $derive = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($masterPwd, $salt, 100000)
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $derive.GetBytes(32)
    $aes.GenerateIV()
    $enc = $aes.CreateEncryptor()
    $cipher = $enc.TransformFinalBlock($plain, 0, $plain.Length)
    $data = $aes.IV + $cipher
    $sshEncPath = Join-Path $secretsDir "ssh.enc"
    [System.IO.File]::WriteAllBytes($sshEncPath, $data)
    Write-Host "SSH klyuch zashifrovan: $sshEncPath" -ForegroundColor Green
} else {
    Write-Warning "SSH klyuch ne naiden: $sshPath. Propuskayu."
}

Write-Host ""
Write-Host "=== Shifrovanie peremennyh okruzheniya ===" -ForegroundColor Cyan

$envFile = Join-Path $secretsDir "env.json"
$envData = @{}

$currentSecret = [Environment]::GetEnvironmentVariable("AGENTS_TUNNEL_SECRET", "User")
$telegramSecret = [Environment]::GetEnvironmentVariable("TELEGRAM_TUNNEL_SECRET", "User")

if ([string]::IsNullOrEmpty($currentSecret)) {
    $currentSecret = Read-Host "Vvedite AGENTS_TUNNEL_SECRET"
} else {
    Write-Host "AGENTS_TUNNEL_SECRET: naiden v sisteme" -ForegroundColor Green
}
$envData.AGENTS_TUNNEL_SECRET = $currentSecret

if ([string]::IsNullOrEmpty($telegramSecret)) {
    $telegramSecret = Read-Host "Vvedite TELEGRAM_TUNNEL_SECRET"
} else {
    Write-Host "TELEGRAM_TUNNEL_SECRET: naiden v sisteme" -ForegroundColor Green
}
$envData.TELEGRAM_TUNNEL_SECRET = $telegramSecret

$jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($($envData | ConvertTo-Json -Compress))
$saltEnv = [System.Text.Encoding]::UTF8.GetBytes("opencode-env-salt-v1")
$deriveEnv = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($masterPwd, $saltEnv, 100000)
$aesEnv = [System.Security.Cryptography.Aes]::Create()
$aesEnv.Key = $deriveEnv.GetBytes(32)
$aesEnv.GenerateIV()
$encEnv = $aesEnv.CreateEncryptor()
$cipherEnv = $encEnv.TransformFinalBlock($jsonBytes, 0, $jsonBytes.Length)
$dataEnv = $aesEnv.IV + $cipherEnv
$envEncPath = Join-Path $secretsDir "env.enc"
[System.IO.File]::WriteAllBytes($envEncPath, $dataEnv)

Write-Host "Peremennye zashifrovany: $envEncPath" -ForegroundColor Green

Write-Host ""
Write-Host "=== Gotovo ===" -ForegroundColor Green
Write-Host "Zashifrovannye dannye v: $secretsDir"
Write-Host "Oni budut avtomaticheski vklyucheny v backup."
Write-Host "Na novom PK zapusti: powershell -File SCRIPTs\bootstrap.ps1"

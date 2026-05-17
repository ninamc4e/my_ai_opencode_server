[CmdletBinding()]
param(
    [switch]$PassThru,
    [string]$MasterPassword = ""
)

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$secretsDir = Join-Path $projectRoot "secrets"

$sshEncPath = Join-Path $secretsDir "ssh.enc"
$envEncPath = Join-Path $secretsDir "env.enc"

$hasSomething = (Test-Path $sshEncPath) -or (Test-Path $envEncPath)
if (-not $hasSomething) {
    Write-Error "Net zashifrovannyh dannyh v $secretsDir"
    Write-Host "Snachala zapusti seal.ps1 na starom PK" -ForegroundColor Yellow
    exit 1
}

# Master password
$masterPwd = $MasterPassword
if ([string]::IsNullOrEmpty($masterPwd)) {
    $secPwd = Read-Host "Vvedite master-parol" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPwd)
    $masterPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

if ([string]::IsNullOrEmpty($masterPwd)) {
    Write-Error "Parol ne mozhet byt pustym"
    exit 1
}

function Decrypt-File {
    param([string]$Path, [string]$Password, [string]$SaltStr)
    if (-not (Test-Path $Path)) { return $null }
    $data = [System.IO.File]::ReadAllBytes($Path)
    $salt = [System.Text.Encoding]::UTF8.GetBytes($SaltStr)
    try {
        $derive = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $salt, 100000)
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $derive.GetBytes(32)
        $aes.IV = $data[0..15]
        $dec = $aes.CreateDecryptor()
        $cipher = $data[16..($data.Length - 1)]
        $plain = $dec.TransformFinalBlock($cipher, 0, $cipher.Length)
        return $plain
    } catch {
        return $null
    }
}

# Decrypt SSH key
if (Test-Path $sshEncPath) {
    Write-Host "Rasshifrovka SSH klyucha..." -ForegroundColor Cyan
    $sshData = Decrypt-File -Path $sshEncPath -Password $masterPwd -SaltStr "opencode-ssh-salt-v1"
    if ($sshData -eq $null) {
        Write-Error "Ne udalos rasshifrovat SSH klyuch. Nepravilny parol?"
        if ($PassThru) { return @{ status = "error"; message = "Wrong password for SSH" } }
        exit 1
    }

    Write-Host "Ustanovka SSH klyucha..." -ForegroundColor Cyan
    $sshDir = "$env:USERPROFILE\.ssh"
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }
    $sshKeyPath = Join-Path $sshDir "id_ed25519"
    [System.IO.File]::WriteAllBytes($sshKeyPath, $sshData)
    & icacls $sshKeyPath /reset 2>&1 | Out-Null
    & icacls $sshKeyPath /inheritance:r 2>&1 | Out-Null
    & icacls $sshKeyPath /grant "$env:USERNAME:(R)" 2>&1 | Out-Null
    Write-Host "SSH klyuch sohranen: $sshKeyPath" -ForegroundColor Green

    & ssh-add $sshKeyPath 2>&1 | ForEach-Object { Write-Verbose $_ }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SSH agent: klyuch dobavlen" -ForegroundColor Green
    } else {
        Write-Warning "Ne udalos dobavit klyuch v SSH agent. Zapusti vruchnuyu: ssh-add $sshKeyPath"
    }

    $testResult = & ssh -T git@github.com 2>&1
    if ($LASTEXITCODE -eq 1 -and $testResult -match "successfully authenticated") {
        Write-Host "GitHub SSH: podklyuchenie rabotaet!" -ForegroundColor Green
    } else {
        Write-Warning "GitHub SSH: $testResult"
    }
}

# Decrypt env vars
if (Test-Path $envEncPath) {
    Write-Host "Rasshifrovka peremennyh okruzheniya..." -ForegroundColor Cyan
    $envData = Decrypt-File -Path $envEncPath -Password $masterPwd -SaltStr "opencode-env-salt-v1"
    if ($envData -eq $null) {
        Write-Error "Ne udalos rasshifrovat peremennye. Nepravilny parol?"
        if ($PassThru) { return @{ status = "error"; message = "Wrong password for env" } }
        exit 1
    }

    $envJson = [System.Text.Encoding]::UTF8.GetString($envData) | ConvertFrom-Json
    $setCount = 0
    foreach ($key in $envJson.PSObject.Properties.Name) {
        $val = $envJson.$key
        [Environment]::SetEnvironmentVariable($key, $val, "User")
        Write-Host "  $key = ... (ustanovleno)" -ForegroundColor Green
        $setCount++
    }
    Write-Host "Peremennye ustanovleny: $setCount" -ForegroundColor Green
    Write-Host "PEREMENNYE BUDUT DOSTUPNY POSLE PEREOZAPUSKA POWERSHELL" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Gotovo ===" -ForegroundColor Green

if ($PassThru) {
    return @{
        status = "ok"
        ssh    = if (Test-Path $sshEncPath) { "restored" } else { "none" }
        env    = if (Test-Path $envEncPath) { "restored" } else { "none" }
    }
}

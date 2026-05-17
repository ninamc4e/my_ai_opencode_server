[CmdletBinding()]
param(
    [switch]$FromScratch,
    [string]$Destination = ""
)

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$scriptDir = Join-Path $projectRoot "SCRIPTs"

if ([string]::IsNullOrEmpty($Destination)) {
    $Destination = $projectRoot
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BOOTSTRAP - nastrojka novogo PK" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# === Step 1: Check prerequisites ===
Write-Host "=== Krok 1: Proverka programm ===" -ForegroundColor Cyan
$allOk = $true

# Git
$gitOk = $false
try {
    $gitVer = & git --version 2>&1
    if ($gitVer -match "git version") { $gitOk = $true }
} catch {}
if ($gitOk) {
    Write-Host "  Git: OK ($gitVer)" -ForegroundColor Green
} else {
    Write-Host "  Git: net" -ForegroundColor Red
    Write-Host "  Ustanovi: https://git-scm.com/download/win (vyberi 'Git from the command line')" -ForegroundColor Yellow
    $allOk = $false
}

# Python
$pyOk = $false
$pyPaths = @("C:\Python312\python.exe", "C:\Python313\python.exe", "C:\Python311\python.exe")
foreach ($p in $pyPaths) {
    if (Test-Path $p) { $pyOk = $true; $pyPath = $p; break }
}
if (-not $pyOk) {
    try {
        $pyVer = & python --version 2>&1
        if ($pyVer -match "Python") { $pyOk = $true; $pyPath = "python" }
    } catch {}
}
if ($pyOk) {
    Write-Host "  Python: OK ($pyPath)" -ForegroundColor Green
} else {
    Write-Host "  Python: net" -ForegroundColor Red
    Write-Host "  Ustanovi Python 3.12: https://www.python.org/downloads/" -ForegroundColor Yellow
    $allOk = $false
}

# Node.js
$nodeOk = $false
try {
    $nodeVer = & node --version 2>&1
    if ($nodeVer -match "v") { $nodeOk = $true }
} catch {}
if ($nodeOk) {
    Write-Host "  Node.js: OK ($nodeVer)" -ForegroundColor Green
} else {
    Write-Host "  Node.js: net" -ForegroundColor Red
    Write-Host "  Ustanovi: https://nodejs.org/" -ForegroundColor Yellow
    $allOk = $false
}

# Opencode
$ocOk = $false
try {
    $ocVer = & opencode --version 2>&1
    if ($ocVer) { $ocOk = $true }
} catch {}
if ($ocOk) {
    Write-Host "  Opencode: OK ($ocVer)" -ForegroundColor Green
} else {
    Write-Host "  Opencode: net" -ForegroundColor Red
    Write-Host "  Ustanovi: https://opencode.ai/download" -ForegroundColor Yellow
    $allOk = $false
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "Ustanovi nedostayuschie programmy i zapusti bootstrap snova." -ForegroundColor Yellow
    Write-Host "Posle ustanovki perezapusti PowerShell." -ForegroundColor Yellow
    exit 1
}

Write-Host "Vse programmy ustanovleny!" -ForegroundColor Green
Write-Host ""

# === Step 2: From scratch mode - clone and restore ===
if ($FromScratch) {
    Write-Host "=== Krok 2: Klonirovanie repozitoriya ===" -ForegroundColor Cyan
    $parentDir = Split-Path $Destination -Parent
    $cloneDir = Join-Path $parentDir "test_opencode_temp"

    if (Test-Path $cloneDir) {
        Remove-Item -Path $cloneDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Klonirayu test_opencode (HTTPS)..." -ForegroundColor Cyan
    & git clone --depth 1 https://github.com/alexsmy/test_opencode.git $cloneDir 2>&1 | ForEach-Object { Write-Host "  $_" }

    if (-not (Test-Path $cloneDir)) {
        Write-Error "Ne udalos sklonirovat repozitoriy"
        exit 1
    }

    # Restore latest archive
    $restoreScript = Join-Path $cloneDir "SCRIPTs\restore.ps1"
    if (Test-Path $restoreScript) {
        Write-Host "Vosstanavlivayu poslednij arhiv..." -ForegroundColor Cyan
        & powershell -File $restoreScript -Latest -Destination $Destination -Verbose
    } else {
        Write-Error "restore.ps1 ne naiden v sklonirovannom repozitorii"
        exit 1
    }

    # Clean up clone
    Remove-Item -Path $cloneDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Repozitorij udalen." -ForegroundColor Green
    Write-Host ""

    # Reload project root to restored path
    $projectRoot = $Destination
}

# === Step 3: Decrypt secrets ===
Write-Host "=== Krok 3: Rasshifrovka sekretov ===" -ForegroundColor Cyan
$unsealScript = Join-Path $projectRoot "SCRIPTs\unseal.ps1"
if (Test-Path $unsealScript) {
    & powershell -File $unsealScript -Verbose
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Rasshifrovka ne udalas. Prover master-parol."
        Write-Host "Mozhesh prodolzhit vruchnuyu." -ForegroundColor Yellow
    }
} else {
    Write-Warning "unseal.ps1 ne naiden. Zapusti ego vruchnuyu posle."
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BOOTSTRAP ZAVERSHYON!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Chto delat dalshe:" -ForegroundColor Cyan
Write-Host "  1. Zakryj etot PowerShell" -ForegroundColor White
Write-Host "  2. Otkroj NOVYJ PowerShell (chtoby primenilis peremennye)" -ForegroundColor White
Write-Host "  3. Perejdi v papku:" -ForegroundColor White
Write-Host "     cd $Destination" -ForegroundColor White
Write-Host "  4. Zapusti opencode i napishi: Privet" -ForegroundColor White
Write-Host ""

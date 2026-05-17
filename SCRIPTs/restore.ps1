[CmdletBinding()]
param(
    [string]$FileId,
    [switch]$Latest,
    [string]$Destination = "",
    [switch]$PassThru
)

$endpoint = "https://bot-29-nx0w.onrender.com"

if ([string]::IsNullOrEmpty($FileId) -and -not $Latest) {
    Write-Host "=== Vosstanovlenie my_best_work ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "SPOSOB 1 - poslednij arhiv s GitHub (rekomenduetsya):"
    Write-Host "  powershell -File SCRIPTs\restore.ps1 -Latest"
    Write-Host ""
    Write-Host "SPOSOB 2 - po file_id s Render FileVault:"
    Write-Host "  powershell -File SCRIPTs\restore.ps1 -FileId file_id"
    Write-Host ""
    Write-Host "Gde vzyt file_id: https://github.com/alexsmy/test_opencode/tree/main/migrate"
    Write-Host "  (v AGENTS.md sekciya Poslednij backup)"
    Write-Host ""
    Write-Host "Posle vosstanovleniya nuzhno nastroit:"
    Write-Host "  1. SSH klyuch: ssh-keygen -t ed25519 i dobavit v GitHub (alexsmy)"
    Write-Host "  2. Peremennye okruzheniya (User):"
    Write-Host "     setx AGENTS_TUNNEL_SECRET znachenie"
    Write-Host "  3. Git config:"
    Write-Host "     git config --global user.name alexs"
    Write-Host "     git config --global user.email alex.smyslov@mail.ru"
    Write-Host ""
    Write-Host "Podrobnee: https://github.com/alexsmy/bot_29"
    exit 0
}

if ([string]::IsNullOrEmpty($Destination)) {
    $Destination = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

Write-Verbose "Destination: $Destination"

$tempDir = Join-Path $env:TEMP "opencode-restore"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$zipPath = Join-Path $tempDir "restore.zip"

function Expand-ArchiveToDestination {
    param([string]$ZipPath, [string]$Dest)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        if (Test-Path $Dest) {
            $backupDir = Join-Path (Split-Path $Dest) "my_best_work_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Rename-Item -Path $Dest -NewName $backupDir -ErrorAction SilentlyContinue
            Write-Warning "Sushestvuyuschaya papka pereimenovana v: $backupDir"
        }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $Dest)
    } catch {
        Write-Error "Extract failed: $_"
        exit 1
    }
}

if ($Latest) {
    Write-Host "Poisk poslednego arhiva na GitHub..." -ForegroundColor Cyan

    $gitRepoUrlSsh = "git@github.com:alexsmy/test_opencode.git"
    $gitRepoUrlHttps = "https://github.com/alexsmy/test_opencode.git"
    $gitCloneDir = Join-Path $env:TEMP "opencode_restore_git_$(Get-Date -Format 'yyyyMMddHHmmss')"

    try {
        & git clone --depth 1 $gitRepoUrlSsh $gitCloneDir 2>&1 | ForEach-Object { Write-Verbose $_ }
        if (-not (Test-Path $gitCloneDir)) {
            Write-Host "SSH ne rabotaet, probuyu HTTPS..." -ForegroundColor Yellow
            & git clone --depth 1 $gitRepoUrlHttps $gitCloneDir 2>&1 | ForEach-Object { Write-Verbose $_ }
        }
        if (-not (Test-Path $gitCloneDir)) {
            throw "Git clone failed (SSH and HTTPS)"
        }

        $migrateDir = Join-Path $gitCloneDir "migrate"
        if (-not (Test-Path $migrateDir)) {
            throw "Papka migrate ne naidena v repozitorii"
        }

        $zips = Get-ChildItem -Path $migrateDir -Filter "*.zip" | Sort-Object Name -Descending
        if (-not $zips) {
            throw "V migrate net arhivov"
        }

        $newestZip = $zips[0]
        Write-Host "Naiden: $($newestZip.Name)" -ForegroundColor Green

        Copy-Item -Path $newestZip.FullName -Destination $zipPath -Force
    } catch {
        Write-Error "GitHub restore failed: $_"
        Write-Host ""
        Write-Host "Poprobuj sposob 2 - ukazhi file_id vruchnuyu:" -ForegroundColor Yellow
        Write-Host "  powershell -File SCRIPTs\restore.ps1 -FileId file_id"
        exit 1
    } finally {
        if (Test-Path $gitCloneDir) {
            Remove-Item -Path $gitCloneDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Expand-ArchiveToDestination -ZipPath $zipPath -Dest $Destination
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "=== Vosstanovlenie zaversheno ===" -ForegroundColor Green
    Write-Host "Papka: $Destination"
    Write-Host ""
    Write-Host "Teper nuzhno:"
    Write-Host "  1. Esli eshe net - sozdat SSH klyuch i dobavit v GitHub"
    Write-Host "  2. Ustanovit Python 3.12 i Node.js (esli net)"
    Write-Host "  3. Ustanovit peremennye okruzheniya User:"
    Write-Host "     setx AGENTS_TUNNEL_SECRET znachenie"
    Write-Host "  4. Nastroit git:"
    Write-Host "     git config --global user.name alexs"
    Write-Host "     git config --global user.email alex.smyslov@mail.ru"
    Write-Host "  5. Otkryt opencode v papke:"
    Write-Host "     cd $Destination && opencode"
    Write-Host "  6. Vvesti /start - sessiya prodolzhaetsya!"

    $output = @{
        action        = "restored"
        source        = "github"
        destination   = $Destination
        files         = (Get-ChildItem $Destination -Recurse | Measure-Object).Count
    }

    if ($PassThru) { return $output }
    Write-Output "RESTORE_OK"
    exit 0
}

if (-not [string]::IsNullOrEmpty($FileId)) {
    $downloadUrl = "$endpoint/files/open/$FileId"

    Write-Verbose "Downloading: $downloadUrl"
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
    } catch {
        Write-Error "Download failed: $_"
        exit 1
    }

    Write-Verbose "Downloaded: $( (Get-Item $zipPath).Length ) bytes"
    Expand-ArchiveToDestination -ZipPath $zipPath -Dest $Destination
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "=== Vosstanovlenie zaversheno ===" -ForegroundColor Green
    Write-Host "Papka: $Destination"
    Write-Host ""
    Write-Host "Teper nuzhno:"
    Write-Host "  1. Nastroit SSH: ssh-keygen -t ed25519, cat .ssh-id_ed25519.pub, dobavit v GitHub"
    Write-Host "  2. Ustanovit Python 3.12 i Node.js (esli net)"
    Write-Host "  3. Ustanovit peremennye okruzheniya User:"
    Write-Host "     setx AGENTS_TUNNEL_SECRET znachenie"
    Write-Host "  4. Nastroit git:"
    Write-Host "     git config --global user.name alexs"
    Write-Host "     git config --global user.email alex.smyslov@mail.ru"
    Write-Host "  5. Otkryt opencode v papke:"
    Write-Host "     cd $Destination && opencode"
    Write-Host "  6. Vvesti /start - sessiya prodolzhaetsya!"

    $output = @{
        action        = "restored"
        source        = "filevault"
        file_id       = $FileId
        destination   = $Destination
        files         = (Get-ChildItem $Destination -Recurse | Measure-Object).Count
    }

    if ($PassThru) { return $output }
    Write-Output "RESTORE_OK"
    exit 0
}

Write-Error "Ne ukazan ni -FileId, ni -Latest"
exit 1

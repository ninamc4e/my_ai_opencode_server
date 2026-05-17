[CmdletBinding()]
param(
    [string]$OutputDir = "$env:TEMP",
    [switch]$Upload,
    [switch]$PassThru,
    [switch]$Keep,
    [string]$Folder = ""
)

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$zipName = "my_best_work_$timestamp.zip"
$zipPath = Join-Path $OutputDir $zipName

Write-Verbose "Project root: $projectRoot"
Write-Verbose "Archive: $zipPath"

# Создаём архив всех файлов, кроме .gitignore
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

$archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    Get-ChildItem -Path $projectRoot -Recurse | ForEach-Object {
        if (-not $_.PSIsContainer) {
            $relativePath = $_.FullName.Substring($projectRoot.Length + 1)
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $relativePath, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
} finally {
    $archive.Dispose()
}

Write-Verbose "Archive created: $( (Get-Item $zipPath).Length ) bytes"

if (-not $Upload) {
    Write-Output "BACKUP_FILE=$zipPath"
    if ($PassThru) { return @{ path = $zipPath; name = $zipName; timestamp = $timestamp } }
    exit 0
}

# === Загрузка на Render FileVault ===
Write-Verbose "Uploading to Render FileVault..."

$endpoint = "https://bot-29-nx0w.onrender.com/api/filevault/upload"

Add-Type -AssemblyName System.Net.Http

$client = New-Object System.Net.Http.HttpClient
$content = New-Object System.Net.Http.MultipartFormDataContent

# Если указана папка, добавляем поле folder (сервер создаст её если нет)
if (-not [string]::IsNullOrEmpty($Folder)) {
    $folderContent = New-Object System.Net.Http.StringContent($Folder)
    $folderContent.Headers.ContentDisposition = [System.Net.Http.Headers.ContentDispositionHeaderValue]::Parse('form-data; name="folder"')
    $content.Add($folderContent)
    Write-Verbose "Target folder: $Folder"
}

$fileStream = [System.IO.File]::OpenRead($zipPath)
$fileContent = New-Object System.Net.Http.StreamContent($fileStream)
$disposition = [System.Net.Http.Headers.ContentDispositionHeaderValue]::Parse('form-data; name="files"; filename="' + $zipName + '"')
$fileContent.Headers.ContentDisposition = $disposition
$fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/zip")
$content.Add($fileContent)

try {
    $response = $client.PostAsync($endpoint, $content).Result
    $responseText = $response.Content.ReadAsStringAsync().Result
} finally {
    $fileStream.Close()
    $client.Dispose()
}

if (-not $Keep) {
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
}

if (-not $response.IsSuccessStatusCode) {
    Write-Error "Upload failed ($($response.StatusCode)): $responseText"
    exit 1
}

$result = $responseText | ConvertFrom-Json
$fileId = $result.files[0].file_id
$publicUrl = $result.files[0].public_url

Write-Verbose "Uploaded: file_id=$fileId url=$publicUrl"

$output = @{
    action     = "uploaded"
    file_id    = $fileId
    name       = $zipName
    path       = $zipPath
    url        = $publicUrl
    timestamp  = $timestamp
    size_bytes = $result.files[0].size_bytes
}

if ($PassThru) { return $output }
Write-Output "BACKUP_OK file_id=$fileId url=$publicUrl"

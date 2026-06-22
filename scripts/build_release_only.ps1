$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Flutter = Join-Path $RepoRoot '.fvm\flutter_sdk\bin\flutter.bat'
$AppDir = Join-Path $RepoRoot 'app'
$ReleaseDir = Join-Path $AppDir 'build\windows\x64\runner\Release'
$ExePath = Join-Path $ReleaseDir 'localsend_app.exe'

try {
  if (-not (Test-Path $Flutter)) {
    throw "Flutter SDK not found at $Flutter."
  }

  $env:GIT_CONFIG_COUNT = '1'
  $env:GIT_CONFIG_KEY_0 = 'safe.directory'
  $env:GIT_CONFIG_VALUE_0 = (Join-Path $RepoRoot '.fvm\flutter_sdk').Replace('\', '/')
  $env:PUB_CACHE = Join-Path $RepoRoot '.fvm\pub-cache'
  $env:APPDATA = Join-Path $RepoRoot '.fvm\appdata\Roaming'
  $env:LOCALAPPDATA = Join-Path $RepoRoot '.fvm\appdata\Local'
  $env:DART_SUPPRESS_ANALYTICS = 'true'

  Write-Host 'Building Windows release...' -ForegroundColor Cyan
  Push-Location $AppDir
  try {
    & $Flutter build windows --release --no-pub
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter build failed with exit code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }

  if (-not (Test-Path $ExePath)) {
    throw "Executable not found at $ExePath."
  }

  Write-Host ''
  Write-Host 'Release build completed.' -ForegroundColor Green
  Write-Host "Executable: $ExePath"
  Write-Host "Release folder: $ReleaseDir"
} catch {
  Write-Host ''
  Write-Host 'Release build failed.' -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  exit 1
}

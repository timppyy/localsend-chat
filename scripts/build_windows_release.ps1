param(
  [switch]$Clean,
  [switch]$SkipTests,
  [switch]$SkipAnalyze,
  [switch]$SkipCodegen
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Flutter = Join-Path $RepoRoot '.fvm\flutter_sdk\bin\flutter.bat'
$Dart = Join-Path $RepoRoot '.fvm\flutter_sdk\bin\dart.bat'
$AppDir = Join-Path $RepoRoot 'app'
$CommonDir = Join-Path $RepoRoot 'common'
$ReleaseDir = Join-Path $AppDir 'build\windows\x64\runner\Release'
$ExePath = Join-Path $ReleaseDir 'localsend_app.exe'

function Invoke-Step {
  param(
    [string]$Title,
    [string]$WorkingDirectory,
    [scriptblock]$Command
  )

  Write-Host ''
  Write-Host "==> $Title" -ForegroundColor Cyan
  Push-Location $WorkingDirectory
  try {
    & $Command
  } finally {
    Pop-Location
  }
}

try {
  Set-Location $RepoRoot

  if (-not (Test-Path $Flutter)) {
    throw "Flutter SDK not found at $Flutter. Clone Flutter 3.38.10 into .fvm\flutter_sdk first."
  }

  if (-not (Test-Path $Dart)) {
    throw "Dart executable not found at $Dart."
  }

  $env:GIT_CONFIG_COUNT = '1'
  $env:GIT_CONFIG_KEY_0 = 'safe.directory'
  $env:GIT_CONFIG_VALUE_0 = (Join-Path $RepoRoot '.fvm\flutter_sdk').Replace('\', '/')
  $env:PUB_CACHE = Join-Path $RepoRoot '.fvm\pub-cache'
  $env:APPDATA = Join-Path $RepoRoot '.fvm\appdata\Roaming'
  $env:LOCALAPPDATA = Join-Path $RepoRoot '.fvm\appdata\Local'
  $env:DART_SUPPRESS_ANALYTICS = 'true'

  New-Item -ItemType Directory -Force -Path $env:PUB_CACHE, $env:APPDATA, $env:LOCALAPPDATA | Out-Null

  Write-Host "LocalSend Chat Windows build" -ForegroundColor Green
  Write-Host "Repo: $RepoRoot"
  Write-Host "Flutter: $Flutter"

  Invoke-Step 'Flutter version' $RepoRoot {
    & $Flutter --version
  }

  if ($Clean) {
    Invoke-Step 'Clean app build outputs' $AppDir {
      & $Flutter clean
    }
  }

  Invoke-Step 'Install common dependencies' $CommonDir {
    & $Flutter pub get
  }

  Invoke-Step 'Install app dependencies' $AppDir {
    & $Flutter pub get
  }

  if (-not $SkipCodegen) {
    Invoke-Step 'Generate common code' $CommonDir {
      & $Dart run build_runner build -d
    }

    Invoke-Step 'Generate app translations' $AppDir {
      & $Dart run slang
    }

    Invoke-Step 'Generate app code' $AppDir {
      & $Dart run build_runner build -d
    }
  }

  if (-not $SkipTests) {
    Invoke-Step 'Run unit tests' $AppDir {
      & $Flutter test test/unit
    }
  }

  if (-not $SkipAnalyze) {
    Invoke-Step 'Analyze app code' $AppDir {
      & $Flutter analyze lib test
    }
  }

  Invoke-Step 'Build Windows release' $AppDir {
    & $Flutter build windows
  }

  if (-not (Test-Path $ExePath)) {
    throw "Build completed but executable was not found at $ExePath."
  }

  Write-Host ''
  Write-Host 'Build completed successfully.' -ForegroundColor Green
  Write-Host "Executable: $ExePath"
  Write-Host "Release folder: $ReleaseDir"
  Write-Host ''
  Write-Host 'To test on another PC, copy the whole Release folder, not only the .exe.'
} catch {
  Write-Host ''
  Write-Host 'Build failed.' -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  exit 1
}

param(
  [string]$ReleaseDir = (Join-Path $PSScriptRoot '..\app\build\windows\x64\runner\Release'),
  [int]$StartupDelayMs = 100,
  [int]$SettleSeconds = 8
)

$ErrorActionPreference = 'Stop'

$resolvedReleaseDir = (Resolve-Path -LiteralPath $ReleaseDir).Path
$sourceExe = Join-Path $resolvedReleaseDir 'localsend_app.exe'
if (-not (Test-Path -LiteralPath $sourceExe)) {
  throw "localsend_app.exe was not found in $resolvedReleaseDir"
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ('localsend-single-instance-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $workDir | Out-Null
$testReleaseDir = Join-Path $workDir 'Release'

try {
  Copy-Item -LiteralPath $resolvedReleaseDir -Destination $testReleaseDir -Recurse
  $testExe = Join-Path $testReleaseDir 'localsend_app.exe'
  $testPort = Get-Random -Minimum 20000 -Maximum 60000
  $settingsPath = Join-Path $testReleaseDir 'settings.json'
  if (Test-Path -LiteralPath $settingsPath) {
    $settings = Get-Content -LiteralPath $settingsPath -Raw
    if ($settings -match '"flutter\.ls_port"\s*:') {
      $settings = $settings -replace '"flutter\.ls_port"\s*:\s*\d+', "`"flutter.ls_port`": $testPort"
    } else {
      $settings = $settings -replace "\r?\n}\s*$", ",`r`n  `"flutter.ls_port`": $testPort`r`n}"
    }
    Set-Content -LiteralPath $settingsPath -Value $settings -NoNewline
  }

  $first = Start-Process -FilePath $testExe -WorkingDirectory $testReleaseDir -PassThru -WindowStyle Hidden
  Start-Sleep -Milliseconds $StartupDelayMs
  $second = Start-Process -FilePath $testExe -WorkingDirectory $testReleaseDir -PassThru -WindowStyle Hidden
  Start-Sleep -Seconds $SettleSeconds

  $running = Get-Process -Name 'localsend_app' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $testExe -and -not $_.HasExited }

  if ($running.Count -ne 1) {
    $ids = ($running | Select-Object -ExpandProperty Id) -join ', '
    throw "Expected exactly one LocalSend process for $testExe, found $($running.Count): $ids"
  }

  Write-Host "Single-instance check passed. Process id: $($running[0].Id)"
} finally {
  Get-Process -Name 'localsend_app' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "$testReleaseDir*" -and -not $_.HasExited } |
    Stop-Process -Force -ErrorAction SilentlyContinue

  Start-Sleep -Milliseconds 300
  if (Test-Path -LiteralPath $workDir) {
    Remove-Item -LiteralPath $workDir -Recurse -Force
  }
}

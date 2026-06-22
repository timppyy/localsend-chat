@echo off
setlocal

cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build_release_only.ps1"

echo.
echo Press any key to close this window.
pause >nul

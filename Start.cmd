@echo off
setlocal
where pwsh.exe >nul 2>nul
if errorlevel 1 (
  echo PowerShell 7 is required for this launcher. No software was installed.
  echo See README.md for supported PowerShell 5.1 commands and policy limits.
  pause
  exit /b 1
)
pwsh.exe -NoProfile -File "%~dp0scripts\Start-Workflow.ps1"
if errorlevel 1 pause

@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-TownDefenseRptAnalyzer.ps1"

if errorlevel 1 (
	echo.
	echo Town Defense RPT Analyzer failed to start or ended with an error.
	echo.
	pause
)

@echo off
setlocal
set "TASK_NAME=WASP Warfare - Game PC rig health"
set "RUNNER=%~dp0run-hidden.vbs"

if not exist "%RUNNER%" (
  echo Missing runner: "%RUNNER%"
  exit /b 2
)

echo Installing weekly task "%TASK_NAME%" for Sundays at 04:00 local time.
echo If schtasks reports access denied, rerun this installer from an elevated prompt.
schtasks.exe /Create /TN "%TASK_NAME%" /TR "wscript.exe \"%RUNNER%\"" /SC WEEKLY /D SUN /ST 04:00 /F /RL LIMITED
if errorlevel 1 (
  echo Installation failed. The owner can create the same task in Task Scheduler using:
  echo   wscript.exe "%RUNNER%"
  exit /b 1
)
echo Installed. The task runs the hidden probe; failures write weekly-status.json and create a Fleet card.
exit /b 0

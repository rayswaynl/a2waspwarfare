@echo off
set SteamAppId=33930
cd /d "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; try { $hc1Token = '-name=(?:HC-AI-Control-1|\x22HC-AI-Control-1\x22)'; @(Get-CimInstance -ClassName Win32_Process | Where-Object { $_.Name -eq 'ArmA2OA.exe' -and [string]$_.CommandLine -match ('(^|\s)' + $hc1Token + '(\s|$)') }) | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop }; exit 0 } catch { exit 1 }"
if errorlevel 1 exit /b 1
timeout /t 2 /nobreak >nul
"ArmA2OA.exe" -client -connect=127.0.0.1 -port=2302 -window -cfg="C:\WASP\hc-profile\hc-video.cfg" "-mod=C:\Program Files (x86)\Steam\steamapps\common\Arma 2;expansion;ACR;@CBA_CO;@adwasp;@admkswf" -name="HC-AI-Control-1" -exThreads=3 -cpuCount=2 -malloc=tbb4malloc_bi -maxMem=2047 -world=empty -nosplash -noPause -noSound


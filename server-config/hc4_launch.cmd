@echo off
REM HC4 runs inside Sandboxie box "HC4" with its own sandboxed Steam (account #4).
REM The sandbox isolates Steam's single-instance mutex + session, so HC1 (real Steam)
REM and HC4 (sandboxed Steam) can both hold a game session on one machine.
set SteamAppId=33930
set SBIE=C:\Program Files\Sandboxie-Plus\Start.exe

REM 1) Ensure the sandboxed Steam is running (no-op if already up).
"%SBIE%" /box:HC4 "C:\Program Files (x86)\Steam\steam.exe" -silent
timeout /t 30 /nobreak >nul

REM 2) Launch the game inside the same box.
cd /d "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead"
"%SBIE%" /box:HC4 "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\ArmA2OA.exe" -client -connect=127.0.0.1 -port=2302 -window -cfg="C:\WASP\hc-profile\hc-video.cfg" "-mod=C:\Program Files (x86)\Steam\steamapps\common\Arma 2;expansion;ACR;@CBA_CO;@adwasp;@admkswf" -name="HC-AI-Control-4" -exThreads=3 -cpuCount=2 -malloc=tbb4malloc_bi -maxMem=2047 -world=empty -nosplash -noPause -noSound


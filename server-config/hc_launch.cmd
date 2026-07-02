@echo off
set SteamAppId=33930
cd /d "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead"
taskkill /f /im ArmA2OA.exe >nul 2>&1
timeout /t 2 /nobreak >nul
"ArmA2OA.exe" -client -connect=127.0.0.1 -port=2302 -window -cfg="C:\WASP\hc-profile\hc-video.cfg" "-mod=C:\Program Files (x86)\Steam\steamapps\common\Arma 2;expansion;@CBA_CO;@adwasp;@admkswf" -name="HC-AI-Control-1" -exThreads=3 -cpuCount=2 -malloc=tbb4malloc_bi -maxMem=2047 -world=empty -nosplash -noPause -noSound


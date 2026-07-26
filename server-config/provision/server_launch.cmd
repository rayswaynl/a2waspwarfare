@echo off
REM server_launch.cmd - WASP dedicated server (4-HC box). Copy to C:\WASP\.
REM Server mod line intentionally has NO ACR (server-side ACR terrain pbos crash the
REM dedi - see ../README.md "ACR asymmetric" section). HCs carry ACR on their lines.
REM Allocator: mimalloc for the server (HCs use tbb4malloc_bi in their launchers).
set SteamAppId=33930
cd /d "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead"
taskkill /f /im arma2oaserver.exe >nul 2>&1
timeout /t 2 /nobreak >nul
start "WASP-Server" "arma2oaserver.exe" -port=2302 "-config=C:\WASP\profiles-pr8\server-pr8.cfg" "-cfg=C:\WASP\profiles-pr8\basic.cfg" "-profiles=C:\WASP\profiles-pr8" "-mod=C:\Program Files (x86)\Steam\steamapps\common\Arma 2;expansion;@CBA_CO;@adwasp;@admkswf" -malloc=mimalloc

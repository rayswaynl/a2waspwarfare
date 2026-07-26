@echo off
REM Login-Steams.cmd - THE one manual step: log the HC Steam accounts in.
REM Optional argument = HC count 1..4 (default 4): only steps 1..N run, so a
REM 1-HC or 2-HC box uses this same script (Login-Steams.cmd 2).
REM HC1 = real (unsandboxed) Steam. HC2/HC3/HC4 = Sandboxie boxes HC2/HC3/HC4.
REM Sessions persist per sandbox, so this is one-time per box rebuild.
REM
REM Have each account's Steam Guard code ready - a first login from a NEW server IP
REM will challenge every account.
REM
REM Account order below matches the HC numbering used by the launchers
REM (-name=HC-AI-Control-N) and by the core-affinity map.
setlocal
set "HC_COUNT=%~1"
if "%HC_COUNT%"=="" set HC_COUNT=4
set SBIE=C:\Program Files\Sandboxie-Plus\Start.exe
set STEAM=C:\Program Files (x86)\Steam\steam.exe

echo ============================================================
echo  STEP 1 of %HC_COUNT%  --  HC1  --  account: zwanontest
echo  REAL Steam (not sandboxed)
echo ============================================================
start "" "%STEAM%"
echo Log in as zwanontest. When the library is visible, press a key here.
pause
if %HC_COUNT% LSS 2 goto done

echo ============================================================
echo  STEP 2 of %HC_COUNT%  --  HC2  --  account: zwanontest 2
echo  Sandboxie box HC2
echo ============================================================
"%SBIE%" /box:HC2 "%STEAM%"
echo Log in as "zwanontest 2" in THAT window. Then press a key here.
pause
if %HC_COUNT% LSS 3 goto done

echo ============================================================
echo  STEP 3 of %HC_COUNT%  --  HC3  --  account: zwanontest 3
echo  Sandboxie box HC3
echo ============================================================
"%SBIE%" /box:HC3 "%STEAM%"
echo Log in as "zwanontest 3" in THAT window. Then press a key here.
pause
if %HC_COUNT% LSS 4 goto done

echo ============================================================
echo  STEP 4 of %HC_COUNT%  --  HC4  --  account: ikkeweethetniet94
echo  Sandboxie box HC4
echo ============================================================
"%SBIE%" /box:HC4 "%STEAM%"
echo Log in as ikkeweethetniet94 in THAT window. Then press a key here.
pause

:done
echo.
echo All %HC_COUNT% Steam session(s) logged in. Nothing else is needed from you -
echo tell Claude and it will start the server + HCs and verify.
pause

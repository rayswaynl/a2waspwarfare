@echo off
REM Login-Steams.cmd - THE one manual step: log the 4 HC Steam accounts in.
REM HC1 = real (unsandboxed) Steam. HC2/HC3/HC4 = Sandboxie boxes HC2/HC3/HC4.
REM Sessions persist per sandbox, so this is one-time per box rebuild.
REM
REM Have each account's Steam Guard code ready - a first login from a NEW server IP
REM will challenge every account.
REM
REM Account order below matches the HC numbering used by the launchers
REM (-name=HC-AI-Control-N) and by the core-affinity map.
setlocal
set SBIE=C:\Program Files\Sandboxie-Plus\Start.exe
set STEAM=C:\Program Files (x86)\Steam\steam.exe

echo ============================================================
echo  STEP 1 of 4  --  HC1  --  account: zwanontest
echo  REAL Steam (not sandboxed)
echo ============================================================
start "" "%STEAM%"
echo Log in as zwanontest. When the library is visible, press a key here.
pause

echo ============================================================
echo  STEP 2 of 4  --  HC2  --  account: zwanontest 2
echo  Sandboxie box HC2
echo ============================================================
"%SBIE%" /box:HC2 "%STEAM%"
echo Log in as "zwanontest 2" in THAT window. Then press a key here.
pause

echo ============================================================
echo  STEP 3 of 4  --  HC3  --  account: zwanontest 3
echo  Sandboxie box HC3
echo ============================================================
"%SBIE%" /box:HC3 "%STEAM%"
echo Log in as "zwanontest 3" in THAT window. Then press a key here.
pause

echo ============================================================
echo  STEP 4 of 4  --  HC4  --  account: ikkeweethetniet94
echo  Sandboxie box HC4
echo ============================================================
"%SBIE%" /box:HC4 "%STEAM%"
echo Log in as ikkeweethetniet94 in THAT window. Then press a key here.
pause

echo.
echo All 4 Steam sessions logged in. Nothing else is needed from you -
echo tell Claude and it will start the server + HCs and verify.
pause

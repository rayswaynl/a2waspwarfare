@echo off
REM Login-Steams.cmd - THE one manual step: log the 4 HC Steam accounts in.
REM HC1 = real (unsandboxed) Steam. HC2/HC3/HC4 = Sandboxie boxes.
REM Sessions persist per sandbox, so this is one-time per box rebuild.
REM Have each account's Steam Guard code (e-mail or authenticator) ready.
setlocal
set SBIE=C:\Program Files\Sandboxie-Plus\Start.exe
set STEAM=C:\Program Files (x86)\Steam\steam.exe

echo ============================================================
echo  STEP 1 of 4: REAL Steam - log in with the HC1 account.
echo ============================================================
start "" "%STEAM%"
echo When the Steam client shows the library (logged in), close this prompt:
pause

for %%N in (2 3 4) do (
    echo ============================================================
    echo  STEP %%N of 4: Sandboxed Steam in box HC%%N - log in with the HC%%N account.
    echo ============================================================
    "%SBIE%" /box:HC%%N "%STEAM%"
    echo When THAT Steam window shows the library, continue:
    pause
)

echo All 4 Steam sessions are logged in. Next: Start-Wasp-4HC.ps1
pause

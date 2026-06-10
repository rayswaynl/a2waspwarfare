# WASP Experital TEST — Deploy Runbook

Deploy the Experital branch as an **optional additional mission** on the Hetzner
test server (78.46.107.142), without removing or replacing the current PR8
default (`[55-2hc]warfarev2_073v48co.chernarus.pbo`).

---

## Prerequisites

- Experital worktree: `C:\Users\Steff\a2waspwarfare-experital` (branch `experital`)
- Harness worktree: `C:\Users\Steff\a2waspwarfare-pr-builds\ReusableHarness` (branch `tools/reusable-pr-test-harness`)
- A PBO packing tool: `cpbo.exe` (Arma 3 Tools, Steam ID 233800) or `armake2`
  on PATH, or pass `-PboToolPath` to the pack script.
- SSH access to Hetzner box (RDP: `mstsc /v:78.46.107.142`, credentials in
  Windows Credential Manager: `cmdkey /list | findstr 78.46.107.142`).

---

## Step 1 — Verify the experital worktree is current

```powershell
git -C "C:\Users\Steff\a2waspwarfare-experital" log -1 --oneline
git -C "C:\Users\Steff\a2waspwarfare-experital" status
```

Confirm the worktree is on the `experital` branch and clean (or has only
intentional WIP).  The mission folder to pack is:

```
C:\Users\Steff\a2waspwarfare-experital\Missions\[55-2hc]warfarev2_073v48co.chernarus
```

---

## Step 2 — Generate version.sqf and pack the PBO

`version.sqf` is **gitignored** and required.  The pack script generates it
automatically (11 `#define` lines, including `WF_MISSIONNAME "WASP Experital TEST"`).

```powershell
powershell -ExecutionPolicy Bypass -File `
  "C:\Users\Steff\a2waspwarfare-pr-builds\ReusableHarness\Tools\PrTestHarness\Experital\Pack-WaspExperital.ps1" `
  -ExperitalWorktree "C:\Users\Steff\a2waspwarfare-experital" `
  -OutputDir "C:\WASP\pbo-staging"
```

Default output: `C:\WASP\pbo-staging\WASP_Experital_TEST.Chernarus.pbo`

**PBO naming note:** The internal folder name is `WASP_Experital_TEST.Chernarus`.
Arma 2 OA reads the folder name inside the PBO as the mission identity shown in
the server rotation — this name is intentionally distinct from the PR8 default
(`[55-2hc]warfarev2_073v48co.chernarus`) so both can coexist in MPMissions.

---

## Step 3 — Local dedicated boot smoke

Before uploading to Hetzner, boot the packed PBO on the local Miksuu
dedicated rig (see `miksuu-local-test-rig` memory) or any local A2OA dedicated.

### 3a. Static smoke

Run the engine-free structural checks against the source (catches class errors,
A3-dialect, missing PVF registrations):

```powershell
powershell -ExecutionPolicy Bypass -File `
  "C:\Users\Steff\a2waspwarfare-pr-builds\ReusableHarness\Tools\PrTestHarness\Smoke\Test-WaspStaticSmoke.ps1" `
  -SourceMissionRoot "C:\Users\Steff\a2waspwarfare-experital\Missions\[55-2hc]warfarev2_073v48co.chernarus"
```

All 30+ checks must pass (`PASS: PR8 static smoke checks clean.`).

### 3b. Boot the local dedicated with the PBO

Copy the PBO to your local dedicated's MPMissions folder, start the server,
and let it boot to the mission lobby.  The standard local rig install does NOT
need cpbo — you can run the harness folder-install instead for local smoke:

```powershell
powershell -ExecutionPolicy Bypass -File `
  "C:\Users\Steff\a2waspwarfare-pr-builds\ReusableHarness\Tools\PrTestHarness\Install-WaspPrTestHarness.ps1" `
  -SourceMissionRoot "C:\Users\Steff\a2waspwarfare-experital\Missions\[55-2hc]warfarev2_073v48co.chernarus" `
  -DestinationMissionRoot "C:\Users\Steff\Documents\ArmA 2 Other Profiles\Zwanon\MPMissions\WASP_Experital_TEST.Chernarus" `
  -Overlay "pr8-stress" `
  -MissionTitle "WASP Experital TEST" `
  -Force
```

Note: the stress overlay's `Test-ActiveStressMissionCopy` smoke check expects
the title to start with `"TEST PR8 Stress"` — skip that single check for the
Experital mission (its mission briefingName is `"WASP Experital TEST"`, not
the PR8 stress contract).  All other checks apply.

### 3c. Classcheck smoke

Copy `Smoke-ExperitalClasscheck.sqf` into the installed mission's `test\` folder
and `execVM` it from init.sqf, then watch the RPT for:

```
WFBE_CLASSCHECK OK: Land_Pneu
WFBE_CLASSCHECK OK: FlagCarrierRU
WFBE_CLASSCHECK OK: Land_Mil_hangar_EP1
WFBE_CLASSCHECK OK: Land_Antenna
WFBE_CLASSCHECK FAIL: T72M4CZ_ACR    <- expected on non-DLC server
WFBE_CLASSCHECK FAIL: RM70_ACR       <- expected on non-DLC server
WFBE_CLASSCHECK FAIL: L39_TK_EP1     <- expected on non-DLC server
WFBE_CLASSCHECK FAIL: An2_TK_EP1     <- expected on non-DLC server
WFBE_CLASSCHECK FAIL: Mi17_Ins       <- may pass with OA DLC intact
WFBE_CLASSCHECK SUMMARY: ok=4 fail=5 total=9 ...
```

**Any FAIL on `Land_Pneu`, `FlagCarrierRU`, `Land_Mil_hangar_EP1`, or
`Land_Antenna` is a genuine blocker** — those are base OA/Chernarus classes
that should always resolve.  Do not deploy if they fail.

---

## Step 4 — RPT scan after first boot

Run Analyze-WaspStressRpt against the local boot RPT:

```powershell
powershell -ExecutionPolicy Bypass -File `
  "C:\Users\Steff\a2waspwarfare-pr-builds\ReusableHarness\Tools\PrTestHarness\Rpt\Analyze-WaspStressRpt.ps1" `
  -CurrentRun -LiveSummary
```

Grep the RPT for:

| Pattern | Verdict |
|---------|---------|
| `class not found` | BLOCKER — mission is trying to spawn a missing class |
| `Undefined variable.*WFBE_UP_UNITCOST` | Known noise (pre-existing when no units purchased) |
| `Error in expression.*select` | BLOCKER if new (investigate before deploying) |
| `Missing addons:` | BLOCKER — missing PBO dependency |
| `WFBE_CLASSCHECK OK:` | Good — confirm Land_Pneu, FlagCarrierRU, Land_Mil_hangar_EP1, Land_Antenna |
| `Server_CounterBattery` | Positive — CBR subsystem active |
| `Server_BankIncome.*Dividend` | Positive — bank income running |
| `Server_SiteClearance` | Positive — site clearance compiled |
| `WASPSTAT.*KILL\|CAPTURE\|ROUNDEND` | Positive — telemetry producing records |

The live watcher's "experital" row already monitors all of these (see
`Watch-WaspLiveRpt.ps1` line ~191 — do not duplicate that tooling here,
reference it for ongoing live monitoring):

```powershell
powershell -ExecutionPolicy Bypass -File `
  "C:\Users\Steff\a2waspwarfare-pr-builds\ReusableHarness\Tools\PrTestHarness\Rpt\Watch-WaspLiveRpt.ps1" `
  -Once
```

---

## Step 5 — Copy PBO to Hetzner MPMissions

**This is a manual operator step.** The Hetzner server runs Windows, so the
transfer is SCP or RDP file copy.  Credentials are stored on Main PC.

### Option A — SCP (via Posh-SSH or native OpenSSH)

The Hetzner server hosts the MPMissions folder at:
```
C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions\
```

Transfer command shape (fill in your SCP tool and auth):

```powershell
# Native OpenSSH scp (replace password auth with key auth if available):
scp "C:\WASP\pbo-staging\WASP_Experital_TEST.Chernarus.pbo" `
    "Administrator@78.46.107.142:C:/Program Files (x86)/Steam/steamapps/common/Arma 2 Operation Arrowhead/MPMissions/WASP_Experital_TEST.Chernarus.pbo"
```

Or stage to `C:\WASP` first (avoids spaced-path quoting issues with some SCP clients):

```powershell
# Stage to short path on the remote, then copy:
scp "C:\WASP\pbo-staging\WASP_Experital_TEST.Chernarus.pbo" `
    "Administrator@78.46.107.142:C:/WASP/WASP_Experital_TEST.Chernarus.pbo"

# Then on the server (via SSH):
ssh Administrator@78.46.107.142 `
    "copy C:\WASP\WASP_Experital_TEST.Chernarus.pbo ""C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions\"""
```

### Option B — RDP drag-and-drop

1. `mstsc /v:78.46.107.142` (credentials via `cmdkey`)
2. Enable "Local Resources → Drives" in RDP connection settings to mount Main PC drives.
3. Drag PBO from local `C:\WASP\pbo-staging\` into remote MPMissions folder via Explorer.

---

## Step 6 — Add to server mission rotation (optional)

The PR8 default mission (`[55-2hc]warfarev2_073v48co.chernarus.pbo`) remains
the primary rotation entry.  To add Experital as an optional second mission
that the server cycles to, edit the Hetzner `server-pr8.cfg`:

```cpp
class Missions {
    class WASP_PR8 {
        template = "[55-2hc]warfarev2_073v48co.chernarus";
        difficulty = "veteran";
    };
    class WASP_Experital {
        template = "WASP_Experital_TEST.Chernarus";
        difficulty = "veteran";
    };
};
```

The `template` value must match the PBO base name minus `.pbo` minus `.Chernarus`
extension — i.e. `WASP_Experital_TEST.Chernarus` maps to the class `WASP_Experital`.

If you only want to make the mission **selectable from the server lobby** without
auto-rotation, leave the Missions class with only the PR8 entry and tell players
to pick Experital from the mission list once a HC connects.

---

## Step 7 — First-boot RPT pulls from Hetzner

After the server restarts with the new PBO:

1. SSH to the box to pull the fresh RPT:
   ```powershell
   ssh Administrator@78.46.107.142 `
       "type C:\Users\Administrator\AppData\Local\ArmA 2 OA\Arma2OA.RPT" > C:\WASP\hetzner-experital-boot.rpt
   ```
2. Run the analyzer against the pulled RPT:
   ```powershell
   powershell -ExecutionPolicy Bypass -File `
     "C:\Users\Steff\a2waspwarfare-pr-builds\ReusableHarness\Tools\PrTestHarness\Rpt\Analyze-WaspStressRpt.ps1" `
     -RptPath "C:\WASP\hetzner-experital-boot.rpt" -LiveSummary
   ```
3. Confirm `WFBE_CLASSCHECK OK:` for the four non-DLC base classes and that
   no `class not found` or `Missing addons:` errors appear.

---

## Rollback

To remove the Experital mission from the server without touching the PR8 default:

1. Delete `WASP_Experital_TEST.Chernarus.pbo` from the remote MPMissions folder.
2. Remove the `class WASP_Experital` block from `server-pr8.cfg` if you added it.
3. Restart the Arma2OAServer process (via the `MiksuuPR8` scheduled task
   or `Restart-ScheduledTask -TaskName MiksuuPR8` via SSH).

The PR8 default mission is unaffected — it was never modified.

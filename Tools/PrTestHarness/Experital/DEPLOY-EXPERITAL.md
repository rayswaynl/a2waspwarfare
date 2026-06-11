# WASP Experital TEST — Deploy Runbook

Deploy the Experital branch as an **optional additional mission** on the Hetzner
test server (78.46.107.142), without removing or replacing the current PR8
default (`[55-2hc]warfarev2_073v48co.chernarus.pbo`).

> **CONSENT POLICY:** Do NOT deploy to the Hetzner server without Steff's
> explicit go-ahead in this session.  Claude may prepare and verify locally,
> but no PBO copy, no cfg edit, and no server restart may happen autonomously.

---

## Prerequisites

- Experital worktree: `C:\Users\Steff\a2waspwarfare-experital` (branch `experital`)
- Harness worktree: `C:\Users\Steff\a2waspwarfare-pr-builds\ReusableHarness` (branch `tools/reusable-pr-test-harness`)
- A PBO packing tool: `cpbo.exe` (Arma 3 Tools, Steam ID 233800) or `armake2`
  on PATH, or pass `-PboToolPath` to the pack script.
- SSH access to Hetzner box (RDP: `mstsc /v:78.46.107.142`, credentials in
  Windows Credential Manager: `cmdkey /list | findstr 78.46.107.142`).

---

## Mission identity

| Field | Value |
|-------|-------|
| Mission title (in-game) | `[PLAY] WASP Experimental Test` |
| `WF_MAXPLAYERS` | `56` (1 server + 2 HC + 53 human slots) |
| PBO base name | `WASP_Experital_TEST.Chernarus` |
| PR8 default (untouched) | `[55-2hc]warfarev2_073v48co.chernarus.pbo` |

---

## Box time note

The Hetzner box clock runs **9 hours behind owner local time**.
Scheduled maintenance windows in **box time**:

| Window | Box time |
|--------|----------|
| AICOM telemetry window | 18:00 box time |
| Experital deploy window | 06:00 box time |

Convert from owner local: subtract 9 hours.

---

## Hotfix staging directories

Pre-staged hotfix builds on the Hetzner box live at:

| Dir | Contents |
|-----|----------|
| `C:\WASP\hotfix-v061` | V0.6.1 candidate PBOs |
| `C:\WASP\hotfix-coin` | CoIn-specific hotfix staging |

Do not overwrite these dirs during an Experital deploy; they are for PR8 hotfixes.

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

## Step 2 — A2-compatibility lint

Run the A2 linter before packing.  Any FAIL exit means the mission contains
an A3-only command that will crash on the A2 OA dedicated:

```powershell
powershell -ExecutionPolicy Bypass -File `
  "C:\Users\Steff\a2waspwarfare-pr-builds\ReusableHarness\Tools\PrTestHarness\Smoke\Lint-A2Compat.ps1" `
  -MissionLiteralPath "C:\Users\Steff\a2waspwarfare-experital\Missions\[55-2hc]warfarev2_073v48co.chernarus"
```

FAIL items (e.g. `select {`, `findIf`, `pushBack`) are hard blockers — do not
proceed until resolved.  REVIEW items (find-quote usages) require manual
inspection to confirm whether the left operand is a string or an array.

---

## Step 3 — Generate version.sqf and pack the PBO

`version.sqf` is **gitignored** and required.  The pack script generates it
automatically including `WF_MISSIONNAME "[PLAY] WASP Experimental Test"` and
`WF_MAXPLAYERS 56`.

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

## Step 4 — Local dedicated boot smoke

Before uploading to Hetzner, boot the packed PBO on the local Miksuu
dedicated rig (see `miksuu-local-test-rig` memory) or any local A2OA dedicated.

### 4a. Static smoke

Run the engine-free structural checks against the source (catches class errors,
A3-dialect, missing PVF registrations):

```powershell
powershell -ExecutionPolicy Bypass -File `
  "C:\Users\Steff\a2waspwarfare-pr-builds\ReusableHarness\Tools\PrTestHarness\Smoke\Test-WaspStaticSmoke.ps1" `
  -SourceMissionRoot "C:\Users\Steff\a2waspwarfare-experital\Missions\[55-2hc]warfarev2_073v48co.chernarus"
```

All 30+ checks must pass (`PASS: PR8 static smoke checks clean.`).

### 4b. Boot the local dedicated with the PBO

Copy the PBO to your local dedicated's MPMissions folder, start the server,
and let it boot to the mission lobby.  The standard local rig install does NOT
need cpbo — you can run the harness folder-install instead for local smoke:

```powershell
powershell -ExecutionPolicy Bypass -File `
  "C:\Users\Steff\a2waspwarfare-pr-builds\ReusableHarness\Tools\PrTestHarness\Install-WaspPrTestHarness.ps1" `
  -SourceMissionRoot "C:\Users\Steff\a2waspwarfare-experital\Missions\[55-2hc]warfarev2_073v48co.chernarus" `
  -DestinationMissionRoot "C:\Users\Steff\Documents\ArmA 2 Other Profiles\Zwanon\MPMissions\WASP_Experital_TEST.Chernarus" `
  -Overlay "pr8-stress" `
  -MissionTitle "[PLAY] WASP Experimental Test" `
  -Force
```

Note: the stress overlay's `Test-ActiveStressMissionCopy` smoke check expects
the title to start with `"TEST PR8 Stress"` — skip that single check for the
Experital mission (its mission briefingName is `"[PLAY] WASP Experimental Test"`,
not the PR8 stress contract).  All other checks apply.

### 4c. Classcheck smoke

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

## Step 5 — RPT scan after first boot

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

## Step 6 — Copy PBO to Hetzner MPMissions

**CONSENT REQUIRED.** Confirm with Steff before executing this step.

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

## Step 7 — Add to server mission rotation (optional)

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

## Step 8 — Restart the chain

**CONSENT REQUIRED.** Confirm with Steff before executing this step.

Use the shared restart library to restart the full chain in the correct order:

```powershell
# On the Hetzner box (via SSH or RDP):
powershell -ExecutionPolicy Bypass -File "C:\WASP\Restart-MiksuuChain.ps1"
```

See `Tools\PrTestHarness\Ops\Restart-MiksuuChain.ps1` for parameter details
(`-SkipStop`, `-LogPath`).

---

## Step 9 — Post-deploy verification

After the restart:

```powershell
# On the Hetzner box (via SSH or RDP):
powershell -ExecutionPolicy Bypass -File "C:\WASP\post-deploy-verify.ps1"
```

This will:
- Wait for all 3 processes (server + 2 HC) to appear
- Wait up to 8 minutes for the first AICOMSTAT TICK from both sides
- Scan the new RPT region for error blocks

Then pull the RPT and run the analyzer from Main PC:

```powershell
ssh Administrator@78.46.107.142 `
    "type C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT" > C:\WASP\hetzner-experital-boot.rpt

powershell -ExecutionPolicy Bypass -File `
  "C:\Users\Steff\a2waspwarfare-pr-builds\ReusableHarness\Tools\PrTestHarness\Rpt\Analyze-WaspStressRpt.ps1" `
  -RptPath "C:\WASP\hetzner-experital-boot.rpt" -LiveSummary
```

Confirm `WFBE_CLASSCHECK OK:` for the four non-DLC base classes and that
no `class not found` or `Missing addons:` errors appear.

---

## Rollback

To remove the Experital mission from the server without touching the PR8 default:

1. Delete `WASP_Experital_TEST.Chernarus.pbo` from the remote MPMissions folder.
2. Remove the `class WASP_Experital` block from `server-pr8.cfg` if you added it.
3. Restart the chain:
   ```powershell
   powershell -ExecutionPolicy Bypass -File "C:\WASP\Restart-MiksuuChain.ps1"
   ```

The PR8 default mission is unaffected — it was never modified.

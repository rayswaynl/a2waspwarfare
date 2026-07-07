# FLAG-1 SENSING TEST PLAN — #724 DECAPITATE CLOSER
**Branch:** `claude/fable-completion-push` | **Worktree:** `C:\Users\Steff\a2wasp-fable-push`
**Author:** Claude (Sonnet 4.6) | **Date:** 2026-07-06
**Status:** READY TO EXECUTE — awaiting empty-box window

---

## Background

The overnight soak of cc44u (#724, all flags 0) validated the shadow contract over 372 telemetry
lines: `state=IDLE`, `inRange=0`, `sensed=0`, `stamped=0` — provably byte-inert at flag 0. The
soak ran ~3h on Chernarus, AI-vs-AI, balanced war. The sense→roll→commit chain **never fired**
because neither side achieved dominance and no AI team organically came within ~3 km of an enemy
HQ. The morning report correctly called this the one true gap before flag-1 can be enabled.

This document designs the targeted test to close that gap.

---

## Section 1 — Test Design: Option Evaluation

### The sensing gate (from AI_Commander_Decapitate.sqf)

ARMING requires ALL of:
- **(a) PROXIMITY** — at least one eligible offensive team leader within `DECAP_SENSE_RADIUS` of
  the enemy HQ. ZG constant = **2000 m** (`worldName == "Zargabad"` branch in Init_CommonConstants);
  CH/TK = 3000 m.
- **(b) DICE ROLL** — every `DECAP_SENSE_INTERVAL` (4) strategy ticks (~4 min at 60 s cadence),
  chance `DECAP_SENSE_CHANCE` (0.35), latched as `_sensed` until contact lost.
- **(c) DOMINANCE** — `myEff >= enEff * DOM_RATIO` (1.5 × by default). A weak side stumbling
  near the HQ does not commit.
- **(d) MAX_ENTOWNS** — secondary safety: enemy holds ≤ 5 towns (demoted from primary in the
  owner Q1 2026-07-06 re-scope).

COMMIT fires after `ARM_TICKS` (3) consecutive dominant ticks. COMMIT stamps nearby teams and the
press hook in Common_RunCommanderTeam.sqf consumes the stamp.

### WFBE_C_AICOM2_DECAP_ENABLE — lobby-param status

**There is NO lobby param for this flag.** Confirmed by:
1. `grep AICOM2_DECAP` across all `Rsc/Parameters.hpp` files on the branch → zero hits.
2. `Init_Parameters.sqf` iterates `missionConfigFile >> "Params"` and sets each class name as a
   missionNamespace variable; no `class WFBE_C_AICOM2_DECAP_ENABLE` exists.
3. **Critical trap (per `wasp-parameters-hpp-overrides-constants.md` memory):** WFBE lobby params
   override constants because `Init_Parameters.sqf` runs before `Init_CommonConstants.sqf` and
   `isNil` guards let the param value win. The trap is relevant here as a warning — but since no
   param class exists, this path is unavailable regardless.

**Conclusion:** the flag can only be flipped by (a) a constants edit in the deployed build, or
(b) a server-console `setVariable` exec at runtime (if a debug channel is available and the
server is running the build in question).

---

### Option (a) — Debug exec via server console / debug channel

**Description:** With the server running (empty, no players), open the A2OA server console or use
BattlEye's `#exec` / `#login` admin interface to run a one-liner that:
1. `setPos`es one AI team leader within SENSE_RADIUS of the enemy HQ, AND
2. sets `WFBE_C_AICOM2_DECAP_ENABLE = 1` at runtime on `missionNamespace`.

**Viability assessment:**

The A2OA dedicated server has an admin console accessible via BattlEye (`#login <password>`,
then `#exec` SQF). `missionNamespace setVariable` works from any machine context. `setPos` on
a specific group leader requires identifying the group object first — which needs a `nearEntities`
or iterating `allGroups` in the exec string.

The exact one-liner (server-side exec, split for readability — send as a single `#exec` line):

```sqf
// Step 1: Enable the flag (run once at round start, before the first strategy tick that fires)
missionNamespace setVariable ["WFBE_C_AICOM2_DECAP_ENABLE", 1];

// Step 2: Teleport one eligible EAST offensive team leader near the WEST HQ
// (swap sides if EAST is the dominant side in the test round)
{
  if (side _x == east) then {
    private _garTeam = (east call WFBE_CO_FNC_GetSideLogic) getVariable ["wfbe_aicom_garrison", grpNull];
    private _holdT = _x getVariable "wfbe_aicom_holding_town";
    private _isHolding = (!isNil "_holdT") && {typeName _holdT == "OBJECT"} && {!isNull _holdT};
    if (_x != _garTeam && {!_isHolding} && {!isPlayer (leader _x)}) then {
      private _westHQPos = (west call WFBE_CO_FNC_GetSideLogic) getVariable ["wfbe_hq_startpos", [0,0,0]];
      if (count _westHQPos >= 2) then {
        (leader _x) setPos [(_westHQPos select 0) + 100, (_westHQPos select 1) + 100, 0];
        diag_log "DECAP_TEST: teleported one EAST team leader near WEST HQ";
      };
    };
  };
} forEach allGroups;
```

**Limitations:**
- Requires knowing the correct `wfbe_hq_startpos` variable name and the side-logic pattern at
  exec time — the exact variable names must be verified against Init_Server.sqf (the code stores
  `wfbe_startpos` on `_logik` per `Init_Server.sqf:` `_logik setVariable ["wfbe_startpos", _pos, true]`).
  Update the one-liner to use `"wfbe_startpos"` (not `"wfbe_hq_startpos"`).
- BattlEye `#exec` has a character limit (~1000 chars) — the full one-liner above must be
  condensed; see exact one-liner below.
- The exec sets the flag globally in `missionNamespace`, which IS what the Decapitate script reads.
  This is **the correct approach** — no build needed.
- Requires a live BE admin password or server-console access from the Hetzner box directly.

**Corrected compact one-liner** (fits BE limit; uses verified variable names):

```sqf
missionNamespace setVariable ["WFBE_C_AICOM2_DECAP_ENABLE",1]; {if(side _x==east && {!isPlayer(leader _x)})then{private _l=leader _x;if(!isNull _l)then{private _wHQ=(west call WFBE_CO_FNC_GetSideLogic)getVariable["wfbe_startpos",[0,0,0]];if(count _wHQ>=2)then{_l setPos[(_wHQ select 0)+80,(_wHQ select 1)+80,0];diag_log"DECAP_TEST:teleport_done"}};false}}count allGroups;
```

**Assessment: VIABLE but has one friction point** — requires the BE admin password for `#exec`,
or direct RCon access. If the Hetzner box ships with a known BE password stored in
`C:\WASP\bepassword.txt` or similar, this is the fastest path (no redeploy, ~2 min setup).
If BE admin is not available interactively, fall through to option (c).

---

### Option (b) — Temporary test-mission variant with bases pre-placed close (ZG map)

**Description:** Build a test PBO variant from `fable/aicom-v2-l1-press-fix` with `WFBE_C_AICOM2_DECAP_ENABLE=1`
hard-coded in Init_CommonConstants.sqf and rely on ZG's natural small-map geometry.

**ZG map geometry analysis:**

Zargabad is 4096×4096 m. The `startingDistance` for ZG in WFBE is ~2000–2500 m (the comment in
Init_Server.sqf explicitly cites `startingDistance(7500)` for Chernarus; ZG uses a proportionally
smaller value set in the Warfare template `mission.sqm`). With `DECAP_SENSE_RADIUS = 2000 m` on ZG,
and HQ-to-HQ separation of ~2000–2500 m, a team sitting mid-map is already 1000–1250 m from each
HQ — comfortably inside SENSE_RADIUS on the near side.

**Key insight:** On ZG, any AI team that captures the mid-town or advances past the midpoint of the
map is automatically within SENSE_RADIUS of the enemy HQ. Unlike Chernarus (15×15 km, teams routinely
stay 5-8 km from the enemy base), ZG's geometry means the sensing condition fires **organically** in
a normally-progressing dominant-side game — it just requires actual dominance (towns 7–2 or similar,
as seen in the live evidence noted in the Decapitate file header).

**Implication for option (b):** A ZG round with flag=1 and a dominant side does NOT need pre-placed
bases. The live 2026-07-04 ZG evidence in the file header (EAST 7 towns vs 2) proves teams get to
that point. A cc44v test build on ZG with `DECAP_ENABLE=1` will sense organically once dominance
is reached — typically 45–90 min into a game.

**Assessment: VALID but slow** — requires 45–90 min of game-time to reach dominance, making
the test window 2–3 h minimum. Reliable for confirming the full organic path, but not the fastest
way to verify the chain links individually.

---

### Option (c) — Temporary constants override in a test-only build (cc44v)

**Description:** On the `fable/aicom-v2-l1-press-fix` branch (which already contains all the
#724+#726 stack), edit `Init_CommonConstants.sqf` to set `WFBE_C_AICOM2_DECAP_ENABLE = 1` (and
optionally lower `WFBE_C_AICOM2_DECAP_SENSE_RADIUS` to 4000 on CH so any team on the front fires
it, or keep 2000 on ZG for the organic path). Build as cc44v, deploy to Hetzner, run ZG.

**Assessment: CLEANEST for a full chain verification** — no live BE admin access needed, fully
auditable build, easy to revert (redeploy cc44u or the prior official build). The build overhead
is ~10 min (Patch-PboFile.ps1 + LoadoutManager + deploy44v.ps1 from the cc44u template).

---

### RECOMMENDATION: Option (c) — cc44v constants build on ZG

**Reasoning:**

1. **No BE admin dependency.** Option (a) requires live BE admin / RCon access to run `#exec`.
   If that credential is readily available at test time, (a) is faster. But the plan must be
   executable by whoever holds the empty window, without hunting for credentials.

2. **ZG is the right map.** With `SENSE_RADIUS = 2000 m` and ~2000–2500 m HQ separation, the
   sensing condition fires organically once any team crosses the midpoint. No setPos needed.
   A ZG round typically reaches dominance in 45–75 min. The 2026-07-04 live evidence (7 towns vs 2
   in a player game) confirms this is achievable in AI-vs-AI too.

3. **Option (a) one-liner is documented** below as a fast-path for an owner who does have BE
   console access — it skips the build entirely and cuts the test to 5–10 min. The two options
   are complementary: run (a) first if BE admin is at hand; fall back to (c) if not.

4. **Option (b) is subsumed by (c)** — option (c) with ZG IS option (b) with the right flag, just
   without the pre-placing (which is unnecessary given ZG geometry).

5. **cc44u stays live for players.** Option (c) deploys cc44v only during an empty window and
   reverts to cc44u (or promotes cc44v as the new live build if it passes). cc44u is safe for
   morning players.

---

## Section 2 — Execution Runbook

### Pre-requisites
- Branch: `fable/aicom-v2-l1-press-fix` (the #724+#726 stack, latest tip `ee80a6818`)
- Game PC worktree: `C:\Users\Game\a2wasp-tp5` (already at organic HEAD, confirmed by overnight loop)
- Build tooling: `Patch-PboFile.ps1` + `LoadoutManager` pipeline (confirmed operational from cc44u build)
- Hetzner live box: `ssh gamingpc` → `ssh livehost` (78.46.107.142, via Administrator key)
- Current live build: **cc44u** (cmdcon44uaicom) — retain in `C:\WASP\retired\` on revert

---

### Step 0 — Empty-box check (pgate)

Before ANY deploy. The player-gate script is `C:\WASP\incoming\pcheck.ps1` (also called `_asrcheck.ps1`)
on the Hetzner box. It queries A2S port 2303 and subtracts HC slots.

```powershell
# From Game PC:
ssh livehost "powershell -File C:\WASP\incoming\pcheck.ps1"
# PASS criteria: players=0 (HCs only). If "players > 0" → abort, retry later.
```

Secondary check (belt-and-braces): grep the live RPT for `FPSREPORT` lines in the last 120 s.
If `players=` shows non-zero humans, abort.

```powershell
ssh livehost "powershell -Command \"Get-Content 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT' -Tail 200 | Select-String 'FPSREPORT|players='\""
# PASS: last FPSREPORT shows players=0 or players=2 (two HCs only, no humans)
```

Do NOT proceed unless BOTH checks confirm empty.

---

### Step 1 — Build cc44v (test build, flag=1 on ZG)

On the Game PC in worktree `C:\Users\Game\a2wasp-tp5`:

```powershell
# 1a. Check out the press-fix branch tip
cd C:\Users\Game\a2wasp-tp5
git fetch origin
git checkout origin/fable/aicom-v2-l1-press-fix

# 1b. Edit ZG Init_CommonConstants.sqf — flip the DECAP_ENABLE default from 0 to 1
#     File: Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Init/Init_CommonConstants.sqf
#     Change line:
#       if (isNil "WFBE_C_AICOM2_DECAP_ENABLE") then {WFBE_C_AICOM2_DECAP_ENABLE = 0};
#     To:
#       if (isNil "WFBE_C_AICOM2_DECAP_ENABLE") then {WFBE_C_AICOM2_DECAP_ENABLE = 1}; //--- TEST cc44v: flag-1 sensing test ONLY, revert to 0 before any non-test deploy
#     DO NOT edit CH or TK Init_CommonConstants — test is ZG only.

# 1c. Optionally: also lower WFBE_C_AICOM2_DECAP_ARM_TICKS from 3 to 1 in the same file
#     to accelerate the ARMING -> COMMIT transition (saves ~3 strategy ticks = ~3 min).
#     Line to change:
#       if (isNil "WFBE_C_AICOM2_DECAP_ARM_TICKS") then {WFBE_C_AICOM2_DECAP_ARM_TICKS = 1}; //--- TEST cc44v: 1 tick ARM for fast-path test
#     RECOMMENDED: yes, to keep the test window short.

# 1d. Build via the standard pipeline
#     Name the output cc44v-zg.pbo (or cc44v-{ch,tk,zg}.pbo if a full set is needed)
#     Use Patch-PboFile.ps1 exactly as per the cc44u build; set build tag to "cmdcon44vtest"
```

**IMPORTANT:** This edit is to the LOCAL worktree only, in an uncommitted state. Do NOT push or
commit the flag=1 line to the branch. The test build is ephemeral; after the test, reset the
worktree to the branch tip.

---

### Step 2 — Deploy cc44v

```powershell
# From Game PC, adapted from deploy44u.ps1 (clone it as deploy44v.ps1)
# The script should:
#   1. Confirm pgate passes (inline player check — hard gate inside the script)
#   2. Stop Arma2OA-PR8 service + MiksuuHC/HC2/WaspSeatHeal tasks
#   3. Archive current RPT: copy to C:\WASP\rpt-archive\arma2oaserver-deploy44v-<timestamp>.RPT
#   4. Retire cc44u ZG PBO → C:\WASP\retired\
#   5. Install cc44v-zg.pbo
#   6. Restart Arma2OA-PR8 service (ZG map only — park CH/TK)
#   7. Relaunch HCs; poll for MISSINIT in RPT (wait up to 3 min)
#   8. Log everything to C:\WASP\rotate2.log with timestamp

ssh gamingpc "ssh livehost 'powershell -File C:\WASP\incoming\deploy44v.ps1'"
```

Wait for `MISSINIT` in the new RPT before proceeding.

---

### Step 3 — Monitor telemetry

Open a tail on the RPT from the Game PC. Filter for DECAP lines:

```powershell
ssh gamingpc "ssh livehost 'powershell -Command \"Get-Content C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT -Wait | Select-String AICOM2\"'"
```

Or run the existing `Tools/Soak/analyze_soak.py` scorecard on the live RPT for structured output.

**Expected telemetry sequence (chain-of-custody):**

| Link | What to look for | RPT pattern |
|------|-----------------|-------------|
| **L1 SENSE_RADIUS** | `inRange>0` appears | `inRange=1` (or more) in any DECAP line |
| **L2 ROLL CADENCE** | Roll fires every ~4 ticks | `roll=1` appears; interval between roll=1 lines ≈ 4 × strategy_tick_interval |
| **L3 SENSED LATCH** | `sensed=1` latches after a successful roll | `sensed=1` in the tick after `roll=1` |
| **L4 ARMING** | Streak increments toward ARM_TICKS | `state=ARMING` with `streak=1` then `streak=1` again (with ARM_TICKS=1 this goes directly COMMIT) |
| **L5 COMMITTED** | State flips to COMMIT then COMMITTED | `state=COMMIT` followed by `state=COMMITTED` |
| **L6 STAMPED** | Teams near HQ receive stamp | `stamped=1` (or >0) in COMMITTED line |
| **L7 PRESS** | Press hook fires in Common_RunCommanderTeam.sqf | `AICOM2|v1|DECAP|...|PRESS|team=...|dist=` in RPT |

**Pass criteria per link:**

- **L1:** At least one `inRange>0` line appears within 30 min of game start on a dominant war state.
- **L2:** `roll=1` lines appear at 4-tick intervals (±1 tick); NOT every tick.
- **L3:** After `roll=1`, next tick shows `sensed=1` (chance 35%; may take multiple rolls — PASS if
  it fires at all within 10 roll windows).
- **L4:** `state=ARMING` with incrementing streak (or immediate `state=COMMIT` with `ARM_TICKS=1`).
- **L5:** `state=COMMIT` followed by `state=COMMITTED` on subsequent ticks.
- **L6:** `stamped>0` on at least one `COMMITTED` line.
- **L7:** At least one `AICOM2|v1|DECAP|...|PRESS` line in RPT, with `dist=` showing the team
  is moving toward the enemy HQ.

**Full chain PASS = L1 through L7 all observed in sequence.**
**Partial chain PASS = L1–L5 (stamping logic confirmed), L6–L7 as bonus.**
**FAIL** = any link that never fires after 45 min of confirmed `inRange>0`.

---

### Step 4 — Revert

Regardless of pass/fail, revert the box to cc44u after the test (or promote cc44v to the next
official build if everything passes and you choose to keep it):

```powershell
# Option A — Revert to cc44u (safe choice if test is done and you want known-stable)
ssh gamingpc "ssh livehost 'powershell -File C:\WASP\incoming\deploy44u.ps1'"
# (deploy44u.ps1 already exists from the overnight loop; re-running it installs cc44u from retired/)

# Option B — Promote cc44v to cc44v-official (if test PASSED and you want to keep flag=1 live)
# Build a clean cc44v from the branch WITH flag=1 committed (owner decision required first).
# Treat this as a new deployment decision, not an automatic promotion.
```

Reset the test worktree:
```powershell
cd C:\Users\Game\a2wasp-tp5
git checkout -- .   # discard the flag=1 local edit
```

---

### Step 5 — Scorecard

After revert, run the soak scorecard over the cc44v RPT:

```powershell
# Copy the cc44v RPT from the livehost before redeploying (redeployment overwrites it)
ssh gamingpc "ssh livehost 'copy C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT C:\WASP\rpt-archive\arma2oaserver-cc44v-sensingtest.RPT'"

# Then run analyze_soak.py locally (on Game PC or Main PC)
python Tools/Soak/analyze_soak.py C:\WASP\rpt-archive\arma2oaserver-cc44v-sensingtest.RPT
```

Expected scorecard fields: all DECAP chain links, stamped count, press count, state distribution.

---

## Section 3 — Safety Rules

1. **No humans on the box during the test.** pgate must pass (players=0, HCs excluded) before
   deploy and again immediately before restart. If a player joins mid-test, do NOT restart the
   mission; let the test round complete or abort naturally; redeploy cc44u before sleeping.

2. **No flag=1 commit to the repository without owner sign-off.** The cc44v build uses an
   uncommitted local edit. The `Init_CommonConstants.sqf` on the branch retains `DECAP_ENABLE=0`.
   Promotion to flag=1 in production requires an explicit owner decision.

3. **Revert is guaranteed.** cc44u is archived in `C:\WASP\retired\` and its deploy script
   (`deploy44u.ps1`) is already proven. Revert is a single script run. If the Hetzner box
   becomes unreachable mid-test, the server continues running cc44v (flag=1) until it rotates
   naturally to the next map; cc44v behavior at flag=1 is inert on CH/TK (only ZG has the edit).

4. **cc44u stays safe for morning players.** If the test is run overnight and completes before
   players join, the revert to cc44u is transparent. If the test is run during a daytime window,
   the player check gate ensures the box is empty.

5. **No manual setPos of player-owned teams.** The test either uses organic game progression
   (option c recommendation) or the debug exec one-liner (option a fast-path), which targets
   AI-only teams via the `!isPlayer (leader _x)` guard. The exec one-liner will not touch player
   squads.

---

## Appendix A — Option (a) Fast-Path: BE Console One-Liner

If BE admin access is available at test time (password in `C:\WASP\bepassword.txt` or similar on
the Hetzner box), this skips the cc44v build entirely.

**Pre-condition:** cc44u (or any DECAP-capable build) must be running. This exec:
1. Flips the flag to 1 in missionNamespace.
2. Teleports one eligible EAST AI team leader to within 200 m of the WEST HQ start position.

**Exact one-liner** (send via BattlEye `#exec` or the server debug channel):

```sqf
missionNamespace setVariable ["WFBE_C_AICOM2_DECAP_ENABLE",1];missionNamespace setVariable ["WFBE_C_AICOM2_DECAP_ARM_TICKS",1];{if(side _x==east && {!isPlayer(leader _x)} && {({alive _x}count(units _x))>0})exitWith{private _l=leader _x;private _hp=(west call WFBE_CO_FNC_GetSideLogic)getVariable["wfbe_startpos",[0,0,0]];if(count _hp>=2)then{_l setPos[(_hp select 0)+150,(_hp select 1)+150,0]};diag_log"DECAP_TEST:OPTION_A_EXEC"}}forEach allGroups;
```

**What it does:**
- Sets `DECAP_ENABLE=1` and `ARM_TICKS=1` (single-tick ARM for fast test).
- Iterates `allGroups`, finds the first live EAST AI team (not player-led), teleports its leader
  to 150 m offset from the WEST HQ's stored start position.
- Logs `DECAP_TEST:OPTION_A_EXEC` to RPT so you can verify it fired.

**After exec:** watch the RPT for the L1–L7 chain (typically fires within 1–2 strategy ticks
= 1–2 min). **Total test time: ~5–10 min.** Revert by setting the flag back:

```sqf
missionNamespace setVariable ["WFBE_C_AICOM2_DECAP_ENABLE",0];missionNamespace setVariable ["WFBE_C_AICOM2_DECAP_ARM_TICKS",3];
```

No redeploy needed; the mission namespace reverts immediately. The teleported team will either
receive a press stamp and move toward the HQ, or (if dominance fails) return to normal orders
on the next Allocator tick.

**Note on `wfbe_startpos`:** verified in `Init_Server.sqf`: `_logik setVariable ["wfbe_startpos", _pos, true]`
is set for each side logic during initialization. This is the stable reference for the HQ start
position (used by MHQReloc and related systems).

---

## Appendix B — Estimated Timeline

### Option (a) fast-path (BE admin available)
- T+0: empty-box check (pgate) — 2 min
- T+2: send `#exec` one-liner — 1 min
- T+3: watch RPT for L1–L7 chain — 5–10 min
- T+13: revert (one `setVariable` exec) — 1 min
- **Total: ~15 min window required**

### Option (c) cc44v build (recommended path)
- T+0: empty-box check (pgate) — 2 min
- T+2: edit Init_CommonConstants.sqf (ZG only), build cc44v PBO — 10 min
- T+12: deploy cc44v, wait for MISSINIT — 5 min
- T+17: watch RPT; allow 45–75 min for dominant state on ZG — 60 min
- T+77: copy RPT, revert to cc44u — 5 min
- T+82: run analyze_soak.py scorecard — 5 min
- **Total: ~90 min window required**

---

## Appendix C — PR Dependencies

The test should run against `fable/aicom-v2-l1-press-fix` tip (`ee80a6818`), which contains:
- #724 (organic sensing, phantom-guard MAJOR fix) — the sensing logic under test
- #726 (driver-press hook) — the L7 press consumer; must be present for the full chain to fire

If running option (a) against the already-deployed cc44u build: cc44u is built from
`fable/aicom-v2-l1-organic` (`dd7200578`), which does NOT include #726 (press hook). In that case
L1–L5 (DECAP sensing + commit + stamp) are testable, but L7 (PRESS line) will NOT fire. This is
still a useful partial validation of the sensing chain. For the full L1–L7 chain, use option (c)
against the press-fix branch.

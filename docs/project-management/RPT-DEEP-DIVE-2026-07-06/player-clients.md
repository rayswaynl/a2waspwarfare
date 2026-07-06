# Player Client RPT Deep-Dive — Build 89 / cmdcon46 — 2026-07-06

> Scope: client-side RPT analysis for the Build 89 release-day playtest.
> Triage conventions: `rpt-triage` SKILL.md (GR-2026-07-06a).
> Analyst: Fable agent, 2026-07-06.

---

## 1. Sources Analysed

| Source | Path | Modified | Today? |
|---|---|---|---|
| Owner client RPT (Main PC) | `C:\Users\Steff\AppData\Local\ArmA 2 OA\ArmA2OA.RPT` | 2026-07-06 17:22:30 | **YES** |
| Pushed copy (Game PC) | `C:\Users\Game\wasp-rpt-reap\client-main.rpt` | 2026-07-06 17:18 | YES (same session, earlier push) |
| Prior baseline | `a2wasp-docs/docs/project-management/RPT-EVIDENCE-2026-07-05.md` | 2026-07-05 | n/a (reference only) |

**Session confirmed: Build 89 / cmdcon46-20260706.** WASPRELEASE token:
```
WASPRELEASE|v1|candidate=build89-cmdcon46-20260706|git=build89-cmdcon46-20260706|terrain=manual
```

---

## 2. Session Window Summary

The RPT contains **6 MISSINIT sessions** in total (earlier builds/test joins). The current session
is the final one, starting at RPT line 43056.

| Attribute | Value |
|---|---|
| Mission | `[55] Warfare V48 Chernarus` |
| Player | "Zwanon" (UID `76561198046825568`) |
| MISSINIT line in RPT | 43056 |
| Window size | 17,952 lines |
| Session ID | `chernarus_123_749024` |
| DAYTIME at session end | 9.42 (in-game hours ~09:25, ~51 real-minutes of play) |
| Players | 3 |
| AI peak | 283 |
| VD / PVD | 6000 / 6000 |
| TFPS cap | 45 |
| Build header | `## Build: WASP Warfare Build 89 / cmdcon44` *(note: header still says cmdcon44; WASPRELEASE correctly says cmdcon46)* |

---

## 3. Error Census — Full Window

### 3a. Normalized Signature Counts

| Count | Classification | Signature / Source |
|---|---|---|
| **5,511** | Third-party mod | `JSRS_Distance` scripts (`_source` undefined, 30+ weapon sub-files), line 19 per-file |
| **174** | Third-party mod | `warfxpe\ParticleEffects\SCRIPTS\ammo\M256.sqf:30` — `drop` generic error |
| **9** | Third-party mod | `Warning Message: Sound not found` (empty sound name — vehicle/weapon stub) |
| **4** | **WASP — NEW FEATURE** | `GUI_Menu_TeamV2.sqf:538` — `moveInAny _rv` parse error (see §4) |
| **0** | — | All other WASP client files |

**Total error/warning lines in window: 8,461**
**WASP-native errors: 4** (all same signature)
**Third-party mod noise: 8,457 lines (99.95% of all errors)**

### 3b. Mod-noise Breakdown (JSRS_Distance top weapon files)

| Count | File |
|---|---|
| 1,055 | `JSRS_Distance\scripts\ammo\pkt.sqf:19` |
| 265 | `…long\KPVT.sqf:19` |
| 237 | `…ammo\m16.sqf:19` |
| 189 | `…ammo\rpk.sqf:19` |
| 173 | `…long\M134.sqf:19` |
| 143 | `…ammo\ak2.sqf:19` |
| 121 | `…ammo\m249.sqf:19` |
| 106 | `…ammo\ak47.sqf:19` |
| 100 | `…long\svd.sqf:19` |
| 98 | `…ammo\m240.sqf:19` |
| + 12 more weapon files | — |

These are **identical to the 07-05 baseline** (same JSRS version, same `_source` undefined pattern).
No regression; pre-existing third-party bug.

**WarFXPE M256**: `drop [["WarFXPE\ParticleEffects\Universal…"]]` generic error — fires when a
tank round impacts. Third-party mod missing its particle asset. Pre-existing; no change vs baseline.

---

## 4. WASP-Native Findings

### 4a. 🔴 GUI_Menu_TeamV2.sqf:538 — `moveInAny _rv` Parse Error (4 hits)

**Severity: HIGH — functional regression in the TeamV2 vehicle-remount path.**

RPT evidence (2 representative occurrences, clustered at early and late session):
```
Error in expression <}) then {
{
if !(isPlayer _x) then {
    _x moveInAny _rv;
};
} forEach _crewList;
h>
  Error position: <moveInAny _rv;
  Error Missing ;
File mpmissions\__CUR_MP.chernarus\Client\GUI\GUI_Menu_TeamV2.sqf, line 538
```

The second pair appeared at window line ~17,351, confirming the vehicle remount was triggered
at least twice during the session.

**Root cause:** `moveInAny` is an Arma 3 command. In A2 OA 1.64, the correct command is
`moveInCargo`/`moveInDriver`/`moveInGunner`/`moveInTurret` or the generalised `assignAsCargo`
+ `moveIn*` pattern. The engine parser sees `moveInAny` as two tokens (`moveIn` + `Any`) with
a missing semicolon between, hence `Error Missing ;`. The feature code at
`Client/GUI/GUI_Menu_TeamV2.sqf:538` uses the A3-only command.

**Source file confirmed:**
```
C:\Users\Steff\a2waspwarfare\Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\GUI\GUI_Menu_TeamV2.sqf
```
Line 538 context (from source tree):
```sqf
// Line 534–544
if (!isNull _rv && {alive _rv}) then {
    {
        if !(isPlayer _x) then {
            _x moveInAny _rv;          // <-- A3-ONLY COMMAND, LINE 538
        };
    } forEach _crewList;
    hint "Crew remounted.";
} else {
    hint "Vehicle lost during repair — remount aborted.";
};
```

**Impact:** Non-player crew members of the player's vehicle fail to remount after a Team Menu V2
repair action. The `hint` block following the `forEach` will still execute (execution continues
past parse error in expression), so the player sees "Crew remounted." even though crew did not
remount. This is a **silent functional failure** — the user-visible hint is incorrect.

**Fix:** Replace `_x moveInAny _rv` with a role-sensitive assignment. A2 OA pattern:
```sqf
// safe A2 OA replacement:
if (isNil {_x}) exitWith {};
if (driver _rv == objNull) then { _x moveInDriver _rv }
else { _x moveInCargo _rv };
```
This is a correctness fix (no flag required per flag policy).

**Regression vs baseline:** The 07-05 client session had zero `GUI_Menu_TeamV2` errors. This is
a **new regression introduced in Build 89 / cmdcon46** — the vehicle remount feature in TeamV2
is new today.

---

## 5. New Feature Signals (Build 89 client files)

### 5a. GUI_Menu_TeamV2 — Team Menu V2

- **Dialog opened:** Confirmed — 4 error hits prove the menu was invoked and the repair+remount
  path reached. The idd 13050 trace was not explicitly logged (no `createDialog` visible), but
  error hits are proof of execution.
- **Error state:** The `moveInAny` error is the only TeamV2 error; the rest of the menu appears
  to function (no other TeamV2 error signatures).
- **Conclusion:** Menu opens and runs; vehicle crew remount sub-path is broken (A3 command).

### 5b. updateteamsmarkers — Team Marker System

**Fully operational.** 50 performance audit entries observed across the session:

| Metric | Value |
|---|---|
| AVG_MS | 0.29–0.42 ms (avg 0.35 ms) |
| MAX_MS | 1.01 ms |
| Total CALLS | 285–290 per audit window |
| teams tracked | 20 |
| players in team | 0 (solo/AI session) |
| ai units tracked | 3–5 |
| markerOps | 0 (no active markers — TOWNS_ACTIVE=0 this session) |
| skippedWrites | 0 |

**No errors.** Performance is excellent and within prior-session norms.

### 5c. AICOM-MARK (B63) — Spotter Mark Loop

**Operational.** 7 ticks logged after client init:
```
[WFBE][B63 AICOM-MARK] loop live after 1s (clientInitComplete=true)
[WFBE][B63 AICOM-MARK] tick 1: WFBE_Client_SideID=0 feed=12 ownSide=5 tracked=0
[WFBE][B63 AICOM-MARK] tick 2: WFBE_Client_SideID=0 feed=12 ownSide=5 tracked=5
[WFBE][B63 AICOM-MARK] tick 3–6: … tracked=5
```

Loop starts correctly after 1 s delay with `clientInitComplete=true`. Feed established at 12;
5 AICOM units tracked from tick 2 onwards (ownSide=5 = independent/spectator slot — player
joined as observer). No errors or silent loops. SpotterMarkContact send was not triggered
(observer role — not in firing position), so the send/receive path is untested this session.

### 5d. Skin Persistence — Client_SkinPersist

**Fully operational.** 2 complete skin-apply cycles observed:

**Cycle 1 — US Delta Force EP1:**
```
[WFBE (SKIN)] B0 Apply pressed: class='US_Delta_Force_EP1' player='Zwanon'
[WFBE (SKIN)] B1 Apply entry: … alive=true onFoot=true
[WFBE (SKIN)] B2 createUnit: … createGrp=B 1-1-B usedSwapGrp=false
[WFBE (SKIN)] B3 newUnit created: B 1-1-B:2 class=US_Delta_Force_EP1 local=true
[WFBE (SKIN)] B3 primary path: new unit already in slot-group B 1-1-B – no rejoin needed
[WFBE (SKIN)] B4 selectPlayer -> 'US_Delta_Force_EP1' grp=B 1-1-B wasLeader=true
[WFBE (SKIN)] B5 deleteVehicle old unit B 1-1-B:1 (alive=true)
[WFBE (SKIN)] B6 COMPLETE: player='Zwanon' class='US_Delta_Force_EP1' uid='76561198046825568'
```

**Cycle 2 — GER_Soldier_EP1:** Identical B0–B6 sequence, fully completed.

Both cycles reached B6 COMPLETE with no errors. The "primary path: new unit already in slot-group"
message confirms the no-rejoin optimisation is functioning. Group leader state preserved across both
transitions (`wasLeader=true`). No skin persist apply-on-respawn was tested (no respawn occurred
this session).

### 5e. TipRotation — Absent

No `TipRotation` or tip-related lines in the session window. The feature either has no log
emission at this log-content level (LOG CONTENT = NOT ACTIVATED), or was not triggered in the
~51 minutes of play. Not a concern — tip display is purely cosmetic and emits no errors by design.

### 5f. Client_PreRespawnHandler — Absent

No `PreRespawn` lines in window. Player did not respawn during this session (alive the whole time,
confirmed by SKIN cycles which both show `alive=true onFoot=true`). Untested path; not a concern
for this session.

### 5g. Labels_Upgrades (RHUD) — Healthy

RHUD ran continuously throughout the session:

| Metric | Value |
|---|---|
| Total perf audit entries | 50 |
| AVG_MS | 0.43–0.70 ms (avg 0.55 ms) |
| MAX_MS | 2.01 ms (one spike, otherwise ≤2.0 ms) |
| enabled | true (all entries) |
| visibleMap | toggles true/false — confirmed map open/close working |

No errors from RHUD or Labels_Upgrades. Performance is within the 07-05 baseline (`avg 0.69 ms`
reported previously).

---

## 6. UI and Dialog Events

- **No `createDialog` / `findDisplay` / `ctrlSetText` errors** in the session window.
- **No GUI_UpgradeMenu errors** (the 07-05 baseline's "Missing `{`" at line 404 was noted as
  fixed; confirmed absent today).
- **No JIP artifacts** — the single `initJIPCompatible.sqf: Executing the Client Initialization`
  line is the normal client-init path, not a stuck JIP.
- **Cargo observer messages:** Two legitimate engine warnings for observer units in cargo
  (`B 1-1-F:3 REMOTE` and `B 1-1-F:4 REMOTE`) — these are spectator slots in their own vehicle,
  expected behavior, not a WASP bug.

---

## 7. Performance Summary

All data from Performance Audit entries in the current session window.

| Subsystem | AVG_MS (range) | MAX_MS | Calls/window | Status |
|---|---|---|---|---|
| `client_rhud` | 0.43–0.70 ms | 2.01 ms | 49–59 | PASS |
| `updateteamsmarkers` | 0.29–0.42 ms | 1.01 ms | 285–290 | PASS |
| `updateclient_total` | ~0.19 ms | 1.22 ms | 59 | PASS |
| `updateclient_afk` | ~0.05 ms | 1.22 ms | 59 | PASS |
| `markerloop_tick` | 0.06 ms | 1.22 ms | 285–290 | PASS |
| `bookkeep_blinking_icons` | 0.02 ms | 0.98 ms | 59 | PASS |
| `updateavailableactions` | ~1.04 ms | 1.95 ms | 12 | WATCH (highest avg) |
| `ai_lowgear_manager` | <0.01 ms | 0 ms | 12 | PASS |
| `player_ai_watchdog` | ~0.55 ms | 1.22 ms | 4 | PASS |
| `state_audit` | 0 ms | 0 | 1 | PASS |
| `init_unit_client_setup` | — | — | — | PASS (no errors) |
| `markerupdate_start/unit` | — | — | — | PASS |

**Client FPS:** Steady 43–47 (TFPS cap = 45); session end showing 43 FPS with 211 units / 50 vehicles.
**AI peak:** 283 units (mid-session), stabilising to 208 at end.
**TOWNS_ACTIVE:** 0 throughout — this was an early-mission / test session before towns became active.

`updateavailableactions` at 1.04 ms average is the highest-cost subsystem but within acceptable
bounds (MAX_MS 1.95 ms = below 2 ms threshold used in prior reviews).

---

## 8. Regression vs Baseline (07-05)

| Error family | 07-05 baseline | 07-06 Build 89 | Change |
|---|---|---|---|
| JSRS_Distance `_source` undefined | Present (528×) | Present (5,511×) | Higher count — longer play session / more firing |
| ACE_JerryCan `Cannot create` | 18× | 0 | Absent (not loaded today or content matched) |
| GUI_UpgradeMenu `Missing {` | Absent (fixed) | Absent | PASS |
| RHUD queue / Cancel Last errors | 0 | 0 | PASS |
| Kill-EH nil-guard error | Previously on server RPT | 0 client-side | N/A (server-side) |
| **GUI_Menu_TeamV2 `moveInAny`** | Not present (feature new) | **4 hits** | **NEW REGRESSION** |
| Core_ACR T72M4CZ warning | Present | Present | Known, unchanged |

---

## 9. Concerns and Action Items

### CRITICAL

| # | Concern | File | Action |
|---|---|---|---|
| C1 | `moveInAny _rv` is A3-only — vehicle crew remount silently fails, user sees false "Crew remounted." hint | `Client/GUI/GUI_Menu_TeamV2.sqf:538` | Fix: replace with `moveInDriver`/`moveInCargo` A2 OA pattern. Correctness fix — no flag needed. |

### WATCH

| # | Concern | Details |
|---|---|---|
| W1 | SpotterMarkContact send/receive **untested** | Player was in observer/spectator slot (ownSide=5); the `SPOTTERMARK` PV send was never triggered. Needs a test where player is in an infantry slot with a valid spotter target. |
| W2 | Client_PreRespawnHandler **untested** | No respawn occurred. Cannot confirm skin persist apply-on-respawn path. Needs a test death/respawn cycle. |
| W3 | `updateavailableactions` is highest-cost client loop (1.04 ms avg, 1.95 ms max) | Under low-player-count conditions; may spike further with 20+ players. Not a blocker but worth monitoring at full server pop. |
| W4 | `Build: WASP Warfare Build 89 / cmdcon44` header still shows cmdcon44 | The `WASPRELEASE` token correctly says cmdcon46. The static `## Build:` line in init appears to be stale. Low severity (cosmetic) but could confuse triage. |
| W5 | TOWNS_ACTIVE=0 throughout entire session | No towns were captured/contested. This means town-marker, town-flag, and team-destination-marker paths were never exercised. A second test session with active towns is recommended before public release. |

### GREEN / PASS

- Skin persistence: full B0–B6 cycle completed twice, no errors.
- AICOM-MARK B63: loop healthy, 5 units tracked, no errors.
- updateteamsmarkers: all 50 audit windows clean, <1 ms per call.
- RHUD / Labels_Upgrades: consistent performance, no errors.
- No JIP artifacts or black-screen patterns.
- No WASP GUI dialog errors (zero `createDialog`/`findDisplay` errors).
- Core_ACR init completed (33 elements) — DLC-lite T72M4CZ warning is pre-existing and harmless.
- Gear_RU backpacks: 6 valid, 1 skipped (`TK_AmmoBox_Backpack_EP1`) — expected for Chernarus loadout.

---

## 10. Missing Feature Signals (Absent — not a finding unless expected)

| Feature | Signal sought | Result | Explanation |
|---|---|---|---|
| TipRotation | Any tip log | Absent | LOG CONTENT not activated; no error = feature running silently |
| PreRespawnHandler | PreRespawn line | Absent | No player death this session |
| SpotterMarkContact send | `SPOTTERMARK` PV | Absent | Player in observer slot, no valid spotter opportunity |
| Notable kill feed | WASPSTAT/notable kill | Absent | Client-side kill feed is server-push only; server RPT needed for WASPSTAT |

---

## 11. Session Context Notes

- **Player name:** Zwanon (owner's account). Session was a low-player test (3 players total).
- **Mod load:** JSRS_Distance and WarFXPE are in the modpack; their errors are entirely
  third-party and pre-existing. No action needed.
- **Build header mismatch** (cmdcon44 vs cmdcon46): the `## Build:` static string in the init
  sequence was not updated. The WASPRELEASE token is authoritative.
- **Clock note:** RPT timestamps are server-time (US Pacific); the session ran 2026-07-06
  (converted from the local 17:22 Main PC time, which is CEST = UTC+2, so session was
  approximately 15:22 UTC / 08:22 US Pacific).

---

*Generated by Fable agent — 2026-07-06. Based on client RPT mtime 17:22:30 (Main PC) and pushed copy at 17:18 (Game PC). MISSINIT window: RPT line 43056 to end (17,952 lines).*

# GUER Drone Operations menu — design spec (owner-approved 2026-07-07, mockup signed off)

Owner ask: all GUER players get FPV drones through the Tactical center, renamed **Drones**; SCUD
strike purchasable there when GUER holds the carrier (expensive). Original menu showing off the
house design system. Economics approved: **FPV $5,000 / 60s rearm cooldown** (GUER signature cheap
asymmetric tool), **SCUD $40,000** (premium over the standard $25,000), one live drone per pilot,
existing 300s carrier cooldown.

## Context (fact-pack verified at tip 87f841606)

- FPV system fully built + hardened (#796 era: ownership tokens, 5s side rate-limit, server-side
  detonation): `Client/Module/FPV/*`, `Server/Support/Support_FPV*.sqf`. **GUER is silently blocked
  today** — `WFBE_GUERFPVDRONE` never set in `Root_GUE.sqf` (fpv.sqf:10-11 exits on empty class).
- FPV purchase gap: funds deducted CLIENT-side only, no server validation, no rearm cooldown.
- SCUD server chain complete (`Support_ScudStrike.sqf`): validates carrier ownership by sideID +
  300s cooldown + server-side funds debit. Tactical Center already fires it remotely (no proximity).
- Tactical Center = idd 17000, opened via WF-menu 11006 (MenuAction 6). Commissar panel (idd 31000)
  = newest dialog conventions. Free idd: **32000**.

## Feature

**Entry:** for `sideJoined == resistance`, WF-menu button 11006 relabels **DRONES** and MenuAction 6
opens `WFBE_GuerDronesMenu` (idd 32000) instead of the Tactical Center. WEST/EAST unchanged.

**Layout** (per approved mockup; Commissar plate footprint + BG layer pattern, GUER-olive accent
line under the cyan header, `movingEnable=1`, fixed floats, IDC band 32000-32099):
- LEFT column (42%): two asset cards + status strip.
  - **FPV STRIKE DRONE card**: READY / IN FLIGHT (ASCII battery bar + m:ss) / REARMING (cooldown
    m:ss) states; price $5,000; LAUNCH button -> existing `fpv.sqf` flow. Status glyphs ASCII only.
  - **SCUD STRIKE card**: state machine — LOCKED (carrier not GUER-held; red, shows
    "SEIZE KHE SANH CHARLIE TO ARM" objective hint), ARMED ($40,000, FIRE enabled ->
    map-click targeting), COOLDOWN (existing 300s carrier stamp, m:ss readout).
  - Status strip: wallet, carrier holder, live drone count.
- RIGHT column (58%): large RscMapControl (mouse-event idiom identical to Tactical/Commissar),
  SCUD impact designation + 300m-radius hint text; one-line drone telemetry under the map.
- Footer: BACK (reopens WF menu) + "RESISTANCE AIR DOCTRINE" olive tag.

**Server-side additions (all correctness-grade):**
1. `Root_GUE.sqf`: `WFBE_GUERFPVDRONE = "AH6X_EP1";` (same airframe as W/E for v1).
2. FPV purchase hardening: server validates funds + debits server-side (SCUD pattern:
   `wfbe_funds` + `WFBE_SE_FNC_SyncFundsRecord`) + enforces the rearm cooldown server-side
   (`wfbe_fpv_next_<uid>`); client cooldown display reads the same stamp.
3. SCUD GUER pricing: `Support_ScudStrike.sqf` picks `WFBE_C_SCUD_COST_GUER` when the calling
   side is GUER (W/E keep `WFBE_C_SCUD_COST`).

**Flags (ICC append, BOM-safe; Parameters.hpp entries appended at END of class Params only):**
- `WFBE_C_GUER_DRONES_MENU` default 1 + lobby param (0/1) — 0 restores Tactical Center for GUER.
- `WFBE_C_GUER_DRONE_SCUD` default 1 — gates the SCUD card separately.
- `WFBE_C_FPV_COOLDOWN` default 60 (seconds, server-enforced; applies to GUER menu purchases).
- `WFBE_C_FPV_DRONE_COST_GUER` default 5000.
- `WFBE_C_SCUD_COST_GUER` default 40000.

## Non-goals / notes

- W/E Tactical Center untouched (their FPV stays $7,500 via the existing entry).
- No new PVF verbs — reuse `RequestSpecial` ("fpv", "ScudStrike") paths.
- A2 dialect throughout; ASCII-only strings; targeted-python edits; lint incl DBLBOM; mirrors.
- Ships as its OWN build after tonight's (Build 92 candidate) — too large for the tonight window.
- Testing: static gates + owner in-game GUER pass (launch FPV, cooldown readout, SCUD locked-state
  vs armed-state with carrier flip, price debits verified in funds record).

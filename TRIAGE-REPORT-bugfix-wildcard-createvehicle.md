# Bug Triage Report — 2026-06-16 (claude-gaming, lane: wasp-bug-triage)

Branch: `claude/bugfix-wildcard-createvehicle` (from `origin/claude/b39` @ 8a395f88)
Source of truth: live chernarus B39 RPT (`arma2oaserver.RPT`, read-only). Branch-only, no deploy.

## Bug #1 — AI-commander wildcards W13/W17 call undefined `Common_CreateVehicle` — FIXED

**Symptom (live RPT, chernarus B39):**
```
Error in expression <... ] Call Common_CreateVehicle;
  Error position: <Common_CreateVehicle;
  Error Undefined variable in expression: common_createvehicle
File ...\Server\Functions\AI_Commander_Wildcard.sqf, line 844
```
Repeated every time wildcard W13 (and, by the same code, W17) is drawn — for both
WEST and EAST commanders.

**Root cause:** the vehicle-spawn function is compiled into the variable
`WFBE_CO_FNC_CreateVehicle` (Common/Init/Init_Common.sqf:115:
`WFBE_CO_FNC_CreateVehicle = Compile preprocessFileLineNumbers "Common\Functions\Common_CreateVehicle.sqf";`).
There is no variable named `Common_CreateVehicle`. W13 (line 844, gunship strike)
and W17 (line 954, supply convoy) called the bare `Common_CreateVehicle`, which
evaluates to nil → the spawn statement errors and aborts → `_w13Heli`/`_w17Truck`
never get a vehicle → the wildcard silently does nothing (no gunship pass, no
supply convoy). Both wildcards have been dead since they were added.

**Fix:** rename the two call sites per map to `WFBE_CO_FNC_CreateVehicle`.
Files (chernarus + takistan `AI_Commander_Wildcard.sqf` are byte-identical):
- line 844 — W13 `_w13Heli`
- line 954 — W17 `_w17Truck`

**Proof / adversarial verification (no deploy available overnight):**
1. The error is deterministic ("Undefined variable"); after the rename the variable
   resolves to a real compiled function, so the undefined-variable error cannot recur.
2. Signature match — `Common_CreateVehicle.sqf` reads `[_type,_position,_side,_direction,_locked,_bounty?,_global?,_special?]`
   and internally converts a SIDE arg via `WFBE_CO_FNC_GetSideID`. Both call sites pass
   `[class, pos, _side(SIDE), random 360, locked, true]` (6 args) — valid.
3. Fix does NOT move the error downstream: every callee reached after the spawn
   (`WFBE_CO_FNC_CreateGroup`, `WFBE_CO_FNC_CreateUnit`, `AIPatrol`, `SideMessage`,
   `WFBE_CO_FNC_SendToClients`) is confirmed defined (Init_Common.sqf / Init_Server.sqf).
4. The same `WFBE_CO_FNC_CreateVehicle` is already called without RPT error from other
   server-scope sites (Server_BuyUnit, Server_OnHQKilled, Init_Server), proving it is
   defined at server scope when the wildcard runs.
5. Post-fix RPT scan: `Common_CreateVehicle` was the ONLY "Undefined variable" error in
   the live tail — no other undefined-var regressions to chase.

## Bug #2 — `GetSideFromID` watch-list item — NOT A BUG (false alarm confirmed)

Live RPT scan (last ~8000 lines): **0** `GetSideFromID` errors. Matches the prior
false-alarm note in the overnight briefing. No action — correct code, not touched.

## Bug #3 — empty-group / persistent-empty "leak" watch-list item — INCONCLUSIVE, NO FIX

Telemetry seen: `EMPTYGRP|v1|west=2|east=3|guer=9|persW=2|persE=3|persG=9` and
`GCSTAT|...|reaped=0|emptyFound=14|...`.

`server_groupsGC.sqf` reaps **all non-persistent** empty groups every 60s (so they
cannot accumulate); persistent-empty groups (`wfbe_persistent`==true) are
**intentionally preserved** (JIP / commander-team slots). `persG=9` is preserved
slots, not unreaped garbage; `reaped=0` in a pass just means every empty that pass
was persistent. The available data is only ~96s post-restart (t=21→96, persG
5→6→9→9, plateauing) — not enough to distinguish a real persistent-slot leak (which
would trend toward the GUER soft cap of 80) from normal steady-state.

Decision: **do not change the reaper.** Reaping persistent groups would risk the hard
"never a player-visible vanishing/standing AI" guardrail and break JIP/commander-team
logic. A persistent-empty leak must be confirmed with a multi-hour EMPTYGRP/GUERCAP
trend first — handed to the Telemetry Watch lane via the brain.

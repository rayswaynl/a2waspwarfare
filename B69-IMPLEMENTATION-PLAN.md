# B69 Implementation Plan — AICOM finisher + robustness + QoL/spectacle

Scope locked by Ray 2026-06-22. Findings + full SQF sketches: wiki pages
`AI-Commander-B69-Improvement-Roadmap` and `AI-Commander-B69-Implementation-Sketches`.
One MISSINIT marker `_b69`. Build by overlaying changed files onto the last DEPLOYED B68
zip (NOT a fresh git tree — misses version.sqf + live-build guards); boot-smoke `ErrInExpr=0`
gate; back up staging; never detach the switch via ssh.

## Ship order & atomic rules
- **Patch A is ATOMIC** — order + gate + picker mis-fire if split (gate-without-order hits the wrong objective; order-without-picker sends infantry at a fortified base).
- 5 before 6 · 7 before 8 · 14 before tuning 15 · A before B (B reuses A's picker idiom).
- A is the keystone (the verified stalemate root); E/G are independent and can land anytime.

## Patch A — HQ-strike finisher (ATOMIC)  [strategic-targeting]
Files: `Server/AI/Commander/AI_Commander_Strategy.sqf`, `Common/Functions/Common_RunCommanderTeam.sqf`, `Common/Init/Init_CommonConstants.sqf`
1. **Order contract** — `Strategy.sqf:544` swap order mode `"towns-target"` → `"defense"` (keep `getPos _enemyHQ`); strikers then SAD-on-HQ instead of capturing the nearest town. `[hqstrike-hc-order-contract]`
2. **Town gate = fraction** — replace `_myTowns > 8` at `:513,515` with `_myTowns >= round(totalTowns * WFBE_C_AICOM_HQSTRIKE_TOWN_FRAC)`; new nil-guarded const **`WFBE_C_AICOM_HQSTRIKE_TOWN_FRAC = 0.5`** (= half the map; live map is 40+ towns, NOT 7 — `WFBE_C_TOWNS_AMOUNT` is a town-MODE index). `[hqstrike-town-gate-fraction]`
3. **Vehicle-punch picker** — `Strategy.sqf:528-538` rank candidates by punch (armour/attack-heli bonus via `isKindOf Tank/APC/Air` idiom) + an infantry size floor, vehicle teams floor-exempt. `[hqstrike-picker-weight-vehicle-punch]`
4. **Capture-phase interrupt** — capture/camp/depot while-loops honour a fresh order seq + disband flag so a re-tasked team breaks out. `[capture-phase-seq-interrupt]`

Smoke: `AICOMSTAT|...|HQ_STRIKE|launched` still logs; strikers drive onto + SAD the HQ; strike only arms at ≈half-map dominance.

## Patch B — Town-assault punch / anti-truck-spam  [team-composition]  (Ray addition #16)
Extend the punch/combined-arms preference to GENERAL town assaults: lead with armour/AT-capable teams; stop sending soft transport-truck infantry that get blown before reaching the town.
Files: `AI_Commander_AssignTypes.sqf` / `AI_Commander_AssignTowns.sqf` / `AI_Commander_Produce.sqf`.
**OPEN: needs a small new sketch** (not among the 78; closest idioms = the Patch-A picker + `fill-to-floor-composition-aware-pad`). Ships after A.

## Patch C — HC units-bleed  (5 → 6)  [hc-refill-merge]
5. **Stamp teamtype at founding** (harmless alone; prerequisite). `[hctopup-stamp-teamtype-at-founding]`
6. **Same-HC depleted-team MERGE** (fewer+bigger groups → net FPS-DOWN; the count-safe fix for the 4-5 vs 8-12 dribble). `[hctopup-same-hc-merge-depleted-pairs]`
Files: `AI_Commander_Teams.sqf`, `Client/PVFunctions/HandleSpecial.sqf`, `Init_CommonConstants.sqf`. PV consumer route needs a timeout (PV not JIP-durable).

## Patch D — Supervisor resilience  (7 → 8)  [supervisor-watchdog]
7. **Heartbeat stamp** at top of the supervisor loop (the signal). `[aicom-supervisor-heartbeat-stamp]`
8. **Watchdog restart** — server loop re-Spawns a dead/wedged supervisor. `[aicom-supervisor-watchdog-restart-loop]`
Files: `AI_Commander.sqf`, `Init_Server.sqf`. (Decision pending: re-adopt teams in place vs brief gap — recommend re-adopt for the no-freeze guardrail.)

## Patch E — Robustness quick-wins (independent)
9. Phase-jitter the two supervisors (FPS-positive). `[supervisor-spawn-phase-jitter]`
10. Relief strength floor. `[relief-reliever-strength-gate]`
11. MHQ re-drive / unstuck nudge. `[mhq-redrive-unstuck-nudge]`
12. Pending-founding-slot timeout reaper. `[pending-slot-timeout-reaper]`
13. Bootstrap-stipend hoist out of build-grace. `[bootstrap-stipend-out-of-canbuild]`

## Patch F — Stall: measure → tune  (14 before 15)
14. **Garrison-body telemetry** — instrument STALL/POSTURE (measurement-only, ships live). `[stall-telemetry-add-garrison-bodies]`
15. **Territory-credited press-gate** — keeps the dominant side attacking; ship behind a conservative default and validate after one soak reads #14's numbers. `[territory-credited-press-gate]`

## Patch G — QoL / spectacle bundle
- **Q2** town name on the capture bar — `Client/FSM/client_title_capture.sqf`
- **Q9** fast-travel arrival confirmation — `Client/GUI/GUI_Menu_Tactical.sqf`
- **S2** intro music (REMADE) — round-start hook in `Init_Client.sqf`; **WIRE NOW, no-op until Ray's track `.ogg` lands**, then add to `Music/description.ext` CfgMusic + point the hook at it.
- **S6** HQ-fall black smoke pillar + server-wide sting — `Server/PVFunctions/Server_OnHQKilled.sqf` (`createVehicle "SmokeShellBlack"` at wreck + `SendToClients` sound)
- **S7** victory flares + light over winning HQ — `Client_EndGame.sqf` (client-local, post-`gameOver`)

## Open items before/while coding
- **#16 (Patch B):** author the small town-assault-punch sketch first.
- **S2:** awaiting Ray's intro track; hook + asset slot reserved.
- **Owner decisions still relevant:** HQ-strike atomic-vs-staged (recommend atomic, single `_b69` marker); town-gate fraction = 0.5 (set); merge-vs-refill = merge (set); watchdog re-adopt (recommend yes); press-gate timing (#14 first); AICOM default-on flip (defer to post-validation).

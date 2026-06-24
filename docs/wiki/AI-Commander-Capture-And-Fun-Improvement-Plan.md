# AI Commander — Capture & Fun Improvement Plan

> Source-verified 2026-06-21 against the AI-commander development branch (`deploy/2026-06-12-aicom-experital`, HEAD `b0975da9c`). Paths relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/` unless noted. Arma 2 OA 1.64. Produced by a 25-agent analysis fleet (8 subsystem readers → synthesis → adversarial verification against the live SQF). Constant values are branch-specific: this development branch carries `WFBE_C_AI_COMMANDER_TEAMS_TARGET = 4`, whereas live master halved it to 2 (B36) for headless-client FPS — read every number below as "on the experital branch".

This page is a **design proposal**, not a behavior reference. For what the commander does today see [AI Commander Execution Loop Reference](AI-Commander-Execution-Loop-Reference), [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit), and [AI Commander Tunable Constants Reference](AI-Commander-Tunable-Constants-Reference). For the capture mechanic see [Towns, Camps and Capture Atlas](Towns-Camps-And-Capture-Atlas).

2026-06-24 branch update: current `origin/claude/b74.2-aicom@21b62b04` implements several adjacent quick wins, but remains source Chernarus branch evidence only: no GitHub PR route was found, the merge-base/current stable is `origin/master@f8a76de34`, `git diff --check origin/master..origin/claude/b74.2-aicom` is clean, and the branch has no `Missions_Vanilla` payload. The full current payload is 29 source Chernarus files / +424 / -38. The old documented head `d472da6a` advanced by four source Chernarus files / +100 / -14: `b9515ef57` decouples GUER stipend/tier launch at `Init_Server.sqf:808-814` and seeds/rebroadcasts `WFBE_GUER_VEHICLE_TIER` at `Server_GuerStipend.sqf:35,44-46,57-63,95`, while `21b62b04` adds join/connect ACK failovers at `Init_Client.sqf:654-681,693-714` and retry-budget recovery at `Server_OnPlayerConnected.sqf:22-56`. Earlier branch commits add the pop-tier AICOM cap model, `WFBE_C_AICOM_CAMP_STALL_PASSES = 3`, camp range 11.5, small AA trims in `Squad_RU.sqf` / `Squad_USMC.sqf`, marker-feed recovery, carrier air-shop/respawn hooks and stats fast-follow writers. Treat this as candidate evidence routed through [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit#b69-roadmap-and-sketch-route), not as a replacement for Hetzner smoke or maintained Vanilla propagation.

## How "capture" actually works (the binary bar)

A town is **not** a flag you stand on. `Server/FSM/server_town.sqf` runs a per-town loop that, every ~5 s, scans `nearEntities` inside `WFBE_C_TOWNS_CAPTURE_RANGE = 40 m` (`unitsBelowHeight 10`), counts the attacker's presence, and drains the town's `supplyValue` by roughly `round(presence × rate)` per cycle — **but only while the defender's `_activeEnemies == 0`** inside that same 40 m circle. Ownership flips when `supplyValue` falls below 1. Supply *regenerates* on a separate 60 s tick whenever no enemy is present.

So "good at capturing" is three simultaneous engine demands, and missing any one captures **nothing**:

1. **Arrive** — get armed bodies *inside the 40 m ring* (movement/execution).
2. **Clear** — kill the last defender and hold every camp so the active-enemy gate opens and the drain multiplier stays high (force composition).
3. **Stay** — remain long enough to drain supply faster than the 60 s regen restores it (concentration + holding).

A commander that masses force but parks its trucks 50 m out, or clears 90 % and leaves one hidden defender, makes zero progress. This binary bar is why most of the fixes below are about *presence inside the ring*, not about buying more units.

## Why the AI under-captures (thesis)

Four compounding failures strip the AI of effective assault force before teams ever satisfy the bar:

1. **Teams arrive undermanned.** Live `CMDRSTAT` telemetry showed `unitsPerTeam = 5.4–5.8` against an 8–12 target, with **captures = 0 over 212 activations**. Root causes: the Produce deficit-fill floor (existing teams refilled at floor = 1 and plateaued at their founding size) and a supply-starvation spiral (`WFBE_C_AICOM_SUPPLY_RESERVE = 8000` hoards supply away from the vehicle-tech upgrades, so the AI stays infantry-only).
2. **Full teams still register no pressure.** Mounted crews stop outside the 40 m scan; the arc-approach can drop to **zero waypoints** when both flanks are unsafe (`Server_AI_SetTownAttackPath.sqf:49`); pure-crew templates (RU Armor-AA, Ka-52 squadron) carry no dismounts and trip the "capture done" path with nobody on the flag; cargo infantry ride trucks into the ring and die to one RPG.
3. **Forward teams can't be reinforced.** `WFBE_C_AI_COMMANDER_REINFORCE_RANGE = 1200 m` keeps resupply at base while spearheads are 3–6 km out, and the forward-reinforce exception only fires near an **owned** town — so a team fighting *to take* an enemy town is ineligible and bleeds out.
4. **Captured towns are naked.** Garrison is off by owner decision, static defenses spawn 300 s late (`WFBE_C_TOWNS_DEFENSE_SPAWN_DELAY = 300`), and the post-capture mop-up squad's despawn scan only looks for resistance units — so in a WEST-vs-EAST fight it leaves immediately. Humans recapture in the free window and reset all progress.

## Why fighting it is less fun (thesis)

The AI is **opaque and clockwork-predictable at the same time** — the worst combination. Players can't read its intent (posture, HQ-strike launch, wildcard draws, relief dispatch are all RPT-only), so there's no counterplay signal; yet its decisions are fully deterministic (same two spearhead towns, same coin-flip doctrine, same 120 s reassignment cadence, same truck-into-the-depot wave). Relief arrives before the attacker is even in position (detection-triggered, not combat-triggered), but the AI never retreats a bleeding team, never feints, never varies tempo, never relocates its HQ, and never reacts to its own base being demolished. The result feels simultaneously **unfair** (omniscient reaction) and **easy** (exploit the one predictable axis), collapsing the tension arc that makes combined-arms PvE compelling.

## Design constraints the plan respects

- **Capture power competes directly with server FPS.** The team caps (`TEAMS_TARGET`, `TOTAL_AI_MAX = 60`), `WFBE_C_TOWNS_ACTIVE_MAX = 12`, and `SPEARHEAD_TOWNS_MAX = 2` are FPS/headless-client levers, not game-design choices. Any "field more force" change is also a frame-rate bet and belongs behind a Hetzner playtest gate.
- **The 144-groups/side engine hard cap** bounds everything (see [Server Group GC, Cap Warning and Zombie Reaper](Server-Group-GC-Cap-Warning-And-Zombie-Reaper)). Empty founded teams and over-garrisoning both burn the budget.
- **Two deliberate owner vetoes** (do not flip without sign-off): AI artillery is hard-locked off (`WFBE_C_AI_COMMANDER_ARTILLERY = 0`, Steff 2026-06-13) and the mobile garrison is off by default (Owner call 2026-06-11, "everything goes to the front").

## Already fixed (do not re-propose)

- **The `distTgt = 8122` piecemeal bug** — teams cherry-picking the enemy's rich rear 8 km away instead of the front — is fixed by the **coherent-front scorer** in `AI_Commander_Strategy.sqf` (distance-to-front divisor dropped 150 → 50, `WFBE_C_AICOM_DISTANCE_DIVISOR`). `AICOMDBG` confirms front-adjacent targeting.

## Recommendations

Every item below survived adversarial verification against the live code. The verifier **rejected** three synthesis items as already-shipped or factually wrong and **corrected** several others (noted inline). Effort/risk use the standard scale; "Status" distinguishes new work from already-built branches and owner-gated flips.

### Tier 0 — Merge the four in-flight branches (highest ROI, playtest-pending)

The biggest wins are already coded on feature branches and only need a Hetzner playtest + merge. This is the single highest-leverage action.

| Branch | Fixes | Axis | Verified note |
|---|---|---|---|
| `claude/aicom-deficitfill-0618` | Under-strength teams refill to 8+ (`_floorN` raises the produce target; adds a FILL-TO-FLOOR pad). Directly targets the `unitsPerTeam 5.4` / captures-0 root cause. | capture | **Supersedes** the synthesis "deficit-fill floor" idea, which was a no-op against the deployed file. Merge the branch, don't re-patch. |
| `claude/aicom-punchy` | Kill-rewards credited per kill (wired in `RequestOnUnitKilled.sqf`, was missing outside the W12 flag); `SUPPLY_RESERVE 8000→1000`; `BOOTSTRAP_SUPPLY 50→120`; bigger team count; `ASSAULT_HOLD`/`ASSAULT_SAD` extracted; time-curve income. | both | Breaks the supply-starvation spiral and keeps the late-game treasury solvent. **FPS bet** (more teams / higher `TOTAL_AI_MAX`) — gate on playtest. |
| `claude/aicom-freewins` | Garrison stance locked to RED/AWARE/NORMAL (was a random roll that left defenders passive ~25 % of spawns); W21 VBIED water/forest re-roll; W17 supply convoy targets the **front**, not the rear HQ town. | both | 4 small behavior fixes, low risk. Replicate the garrison-stance fix across all map copies of `Common_WaypointPatrolTown.sqf`. |
| `claude/aicom-light-team-redo` | Light/motorized teams **dismount at 400 m standoff**, hull supports by fire, infantry clear on foot, survivors remount after the flip. Ends the infanticidal truck-into-the-ring assault. | both | **Supersedes** the synthesis "light-team dismount" idea (whose sketch contained the A3-only `select {}` filter and `vectorAdd` — both fatal in A2). Use the branch. |

### Tier 1 — New capture quick-wins (verified A2-safe, not yet built)

| # | Change | Files | Effort | Risk | Verifier correction |
|---|---|---|---|---|---|
| C1 | **Arc fallback.** When both flanking paths are unsafe the arc builder hits a bare `exitWith {}` and the team gets **zero waypoints** and freezes. Replace with a direct `AIMoveTo … "SAD"` to town centre. | `Server/Functions/Server_AI_SetTownAttackPath.sqf:49` | trivial | low | The freeze is via the **AssignTowns sticky-order guard** (it won't re-dispatch a team that already has a valid target), *not* `wfbe_exec_sig` as first claimed. The final-SAD jitter is already tight on this branch — verify before changing it. |
| C2 | **Mop-up despawn scan → all hostiles.** The post-capture squad counts only resistance units, so in WEST-vs-EAST it despawns instantly and leaves the town open. Count every side hostile to the new owner. | `Server/FSM/server_town.sqf` (mop-up block) | trivial | low | Use the existing `_townRange` and entity-class list (not a hardcoded 200 m / Man-only), keep the vehicle-crew inner loop, and declare the new var in the `Private[]` array. |
| C3 | **Arc shortcut + hop depth.** A hardcoded `random 100 < 30` early-`exitWith` gives ~1 in 3 dispatches only a single flanking hop; a second `random 100 < 50` per-hop exit dominates path quality. Parameterise the 30 % to 0 and raise the hop ceiling. | `Server/Functions/Server_AI_SetTownAttackPath.sqf:41,62`; `Init_CommonConstants.sqf` | trivial | low | The shortcut does **not** reduce the team to one waypoint (depot WPs are always appended after) — it skips the *flanking variety*. Address the 50 % per-hop exit in the same pass or the effect is small. |
| C4 | **Forward reinforcement reach.** Raise `WFBE_C_AICOM_FWD_REINFORCE_RANGE` from 500 → 800 m so spearheads with a recently-captured town nearby get replacements. | `Init_CommonConstants.sqf:189` | small | low | **Keep the owned-town gate** — it is intentional (front-line resupply, not a bug). Do *not* remove it as first proposed; that would let teams resupply next to enemy towns. |

### Tier 2 — Fun quick-wins (telegraph + counterplay)

The unifying theme: **make the AI's intent legible and give players a reaction window.** Most of the "unfair" feeling is opacity, and most of the "easy" feeling is determinism.

| # | Change | Files | Effort | Risk | Verifier correction |
|---|---|---|---|---|---|
| F1 | **Broadcast posture + HQ-strike.** Surface `PRESS`/`DEFEND`/`HOLD`/`HQ_STRIKE` transitions and the HQ-strike launch as side radio/subtitle messages (fire-on-change). Turns invisible strategy into dramatic, reactable beats. | `AI_Commander_Strategy.sqf`; `Server_SideMessage.sqf`; `Client/kb/hq.bikb`; constants | small | low | Requires **all four steps** or it silently no-ops: add the `Server_SideMessage` switch case, register the sentence classes in `hq.bikb`, gate on a new `WFBE_C_AICOM_ANNOUNCE`, and note `enableSentences = false` ⇒ **subtitle text only, no VO**. The "600 m trigger" in the draft was invented. |
| F2 | **Relief deliberation delay.** Today relief dispatches the instant `wfbe_active` fires (detection, ~600 m), before the attacker is in position — the AI "reads your mind". Buffer threatened towns and only commit if still contested on the next strategy tick (`WFBE_C_AICOM_RELIEF_DELAY = 60`). Enables the feint: poke a town, draw the reliever, hit the real objective. | `AI_Commander_Strategy.sqf`; constants | small | low | Verified accurate and A2-safe — but the draft showed only the consumer loop. Must also add the **producer** that inserts `[town, time]` tuples, or the buffer is always empty. |
| F3 | **Spread the capture force.** The depot hold uses `WEDGE`, so one grenade/mortar wipes a 150 s capture attempt. Alternate `LINE`/`STAG COLUMN` at the hold. | `Common_RunCommanderTeam.sqf:637` | trivial | low | Scope to the **depot-hold line only** — the road-march arrival handoff (different lines) is a separate posture; don't change both in one edit. |
| F4 | **Break the clockwork camp dwell.** A fixed `sleep 45` per camp lets defenders time the AI to the second. Randomise it (`sleep (35 + random 20)`). | `Common_RunCommanderTeam.sqf:551` | trivial | low | Do **not** use the proposed "exit when the camp flips" poll here — it causes a zero-dwell regression on already-held camps and abandons freshly-flipped camps. Randomised dwell is the safe form; the flip-gated loop already exists in the separate camp-first phase. |

### Tier 3 — Capture levers behind an owner veto (sign-off required)

Both are one-line flips with the supporting code already in place, but each reverses an explicit, dated owner decision. **Do not ship without Steff's go.** Note: the `isNil`-guard form does *not* work here — both constants are bare unconditional assignments, so the value must be changed *at the assignment line*.

| # | Change | Owner decision being reversed |
|---|---|---|
| G1 | **Enable mobile garrison** (`WFBE_C_AI_COMMANDER_GARRISON = 1`) and cut the static-defense delay (`WFBE_C_TOWNS_DEFENSE_SPAWN_DELAY` 300 → 90 at line 565). If garrison is on, **raise** `TEAMS_TARGET` to keep attacker count, don't lower it. | "Owner call 2026-06-11: OFF by default — everything goes to the front." |
| G2 | **Enable AI artillery** (`WFBE_C_AI_COMMANDER_ARTILLERY = 1` at line 139). The friendly-fire guard (`_ownNear == 0`) and range check are already implemented; adds a real suppressive-threat dimension. | "Steff 2026-06-13: the AI must NOT be able to use artillery. Forced off so no param can enable it." Likely placed after a team-kill/imbalance incident — confirm the original concern is resolved first. |

### Bigger bets (design work, not yet built)

These need design before code and are where the AI stops feeling like a script and starts feeling like an opponent:

- **Retreat / withdrawal.** The AI never gives ground — sub-30 % teams sit and die in place. A fallback-and-regroup behavior adds maneuver and the "exploit a retreat" moment.
- **HQ relocation + base-defense reaction.** The MHQ never moves (always the start grid) and the AI never reacts to its own Command Center being demolished. Counter-basing is currently a human-only tactic; the AI should both relocate under threat and recall teams when its base is hit.
- **Adaptive composition.** The type mix is a static `[0.65,0.20,0.12,0.03]`; the AI never answers an all-air or all-armor human with AA/AT. Read the enemy order of battle and bias the next teams.
- **Player agency on the AI side.** Players commanded by the AI are spectators — no way to donate, request, or suggest a target (and the donation path currently double-charges, see below). A lightweight "request attack / reinforce here" channel would restore agency.
- **Reusable air.** Air teams do a one-shot insert then walk for the rest of the match (heli refunded). Let them re-task as air.
- **Decisive endgame.** HQ-hunt needs *both* a 1.5× town edge **and** 1.1× strength, so balanced rounds never end. Loosen so AI-vs-AI and stalemated rounds reach a conclusion.

### Discovered bugs (fix regardless of the plan)

- **Donation double-debit** — donating to the AI commander charges the donor twice (`GUI_TransferMenu.sqf` client-side debit + `RequestAIComDonate.sqf` server-side debit; confirmed in the deploy JOURNAL as G6). Discourages the co-op economy entirely.
- **Wildcard announce — conflicting reads.** Two subsystem readers reported wildcard draws (paradrop, air cavalry, supply surge) are silent to players; the adversarial verifier re-read the file and found a shared announce block (`WFBE_CO_FNC_SendToClients … "LocalizeMessage"`) already present. **Quick human check** which is true on the deployed build before acting.

## Telemetry to confirm any change

The commander already emits a rich diag stream (see [AICOM Logging and AICOMSTAT Telemetry](AI-Commander-Logging-And-AICOMSTAT-Telemetry)). Read these to grade a fix without guessing:

- `CMDRSTAT … unitsPerTeam` — should climb from ~5.5 toward 8–11 after the deficit-fill / punchy merges.
- `AICOMSTAT … FRONT / POSTURE` — front coherence and stance transitions.
- `AICOMDBG … SPEARHEAD` — target choice (town, supply, distance-to-front, on-front?).
- `STUCKSTAT` — dispatch-vs-arrive ratio; the live baseline was **256 dispatches : 13 arrivals**. Arrivals should rise sharply after the arc-fallback (C1) and reach fixes.
- `AICOMSTAT … ECONOMY netFunds` — should stop going negative in long sessions once kill-rewards land.

## Continue Reading

- [AI Commander Execution Loop Reference](AI-Commander-Execution-Loop-Reference) — the supervisor loop and worker cadences these changes touch.
- [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit) — which workers are actually wired vs dead.
- [AI Commander Tunable Constants Reference](AI-Commander-Tunable-Constants-Reference) — every constant cited here, by source line and default.
- [Towns, Camps and Capture Atlas](Towns-Camps-And-Capture-Atlas) — the supply-attrition capture mechanic in full.
- [AI Commander Logging and AICOMSTAT Telemetry](AI-Commander-Logging-And-AICOMSTAT-Telemetry) — the diag tags used to grade these fixes.
- [Quad AI Commander](Quad-AI-Commander) — the multi-side AI-commander architecture.
- [Pending Owner Decisions](Pending-Owner-Decisions) — where the Tier 3 artillery/garrison flips should be logged for sign-off.

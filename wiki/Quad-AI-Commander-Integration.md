# Quad AI Commander Integration Notes

These notes map the Quad AI Commander concept onto the current `feat/ai-commander` branch.

## Current AI Commander Branch Shape

The current branch is a good execution substrate:

- `AI_Commander.sqf` runs one supervisor per side and switches between `full`, `assist`, and `stopped` states.
- `AI_Commander_Execute.sqf` turns stored commander Move/Patrol/Defense orders into real waypoints.
- `AI_Commander_AssignTowns.sqf` sends eligible AI teams toward uncaptured towns.
- `AI_Commander_AssignTypes.sqf` assigns unlocked team templates.
- `AI_Commander_Produce.sqf` reinforces under-strength AI teams through the existing `AIBuyUnit` path.
- `Server_AI_Com_Upgrade.sqf` advances AI commander upgrades when affordable.

That means Quad AI Commander should be added as a planning and context layer above the existing workers, not as a replacement for them.

```text
structured logs -> contact beliefs -> planner priorities -> existing team orders -> executor / town worker
```

## Suggested Layering

### 1. Execution Layer

Keep the current branch responsible for executing orders:

- store team mode with `SetTeamMoveMode`
- store team destination with `SetTeamMovePos`
- execute Move/Patrol/Defense through `AI_Commander_Execute`
- execute town capture through `AI_Commander_AssignTowns`
- handle production and upgrades through the existing economy workers

This is the stable base.

### 2. Context Layer

Add a per-side context store on the side logic:

```sqf
_logik setVariable ["wfbe_aicom_context", _context];
```

The context should contain beliefs, not perfect knowledge.

Example belief:

```sqf
// [id, enemySide, category, pos, townObj, countMin, countMax, confidence, firstSeen, lastSeen, sources, status]
[
  "contact-gorka-001",
  east,
  "armor",
  [9610,8790,0],
  _gorka,
  3,
  6,
  0.78,
  time - 240,
  time - 30,
  ["BLUEFOR-C1", "INTEL-FUZZY"],
  "moving-east"
]
```

### 3. Log Layer

Use structured log records for AI consumption. Free text can still be emitted to RPT or player-facing displays.

```sqf
// [kind, time, friendlySide, source, payload]
["CONTACT", time, west, _team, [east, "armor", _pos, 3, 6, 0.75, "Gorka"]]
```

Useful event kinds:

- `CONTACT`: enemy sighting or detection
- `INTEL`: fuzzy scripted intelligence
- `ORDER`: HQ or commander order
- `RESULT`: outcome of an order
- `LOSS`: casualties, destroyed vehicles, or broken contact
- `STATE`: supervisor lifecycle state such as full, assist, or stopped

## First Planner Rules

Start with rules that bias the existing workers:

- High-confidence enemy near a friendly town: assign delegated or idle AI teams to `defense` near that town.
- Medium-confidence enemy near an enemy town: send one team to scout or attack while other teams keep normal town capture.
- Multiple reports near the same town: merge them and raise confidence.
- Stale report: decay confidence each planner pass and drop it after expiry.
- Human explicit Move/Patrol/Defense orders are sacred; do not override them.
- Fuzzy intel can influence priorities, but should not directly spend funds or supply.

## Branch-Specific Watchlist

### Repeated Town Retargeting

`AI_Commander_AssignTowns.sqf` marks a team as needing a new target when its leader is more than 1500m from the assigned town. On large maps this can repeatedly rebuild waypoints before the team gets close. Because `SetTownAttackPath` clears and rebuilds waypoints, runtime smoke should watch for teams resetting their path every town interval.

Possible mitigation: only retarget on captured target, null target, missing waypoint, stuck detection, or a much slower reassessment interval.

### Handoff Reset Scope

When a human commander leaves, `AI_Commander.sqf` clears every team to `towns` so full-auto can retake cleanly. That may also rewrite stored mission mode for AI-led teams that had explicit human orders, and possibly player-led teams that are in `wfbe_teams`.

Runtime smoke should confirm this feels right. If it is too aggressive, only clear AI-led teams or only teams whose previous orders came from the AI commander.

### Executor Signature Staleness

`AI_Commander_Execute.sqf` avoids reissuing unchanged orders through `wfbe_exec_sig`. That is good for stability, but if another system clears waypoints while the stored mode and destination remain unchanged, the executor may not restore them.

Possible mitigation: include a cheap waypoint sanity check for explicit orders, for example reissue when `count waypoints _team == 0` or when the current waypoint is invalid.

### Side AI Cap Semantics

`AI_Commander_Produce.sqf` counts all non-player units on the side for `WFBE_C_AI_COMMANDER_TOTAL_AI_MAX`. This is safe for FPS, but it may include non-commander units such as defense crews or support units depending on mission state.

Runtime smoke should confirm the cap does not starve commander teams too early.

### Default-On Risk

The lobby parameter defaults the AI commander on. That makes the in-engine hybrid tests important before the branch becomes ready:

- no human commander: full-auto type assignment, town assignment, production, upgrade
- human commander present: executor works, delegated teams auto-drive, economy stays frozen
- human leaves: full-auto retakes without confusing existing teams
- HQ destroyed or disabled param: supervisor stops cleanly

## Recommended Follow-Up PR

After the current branch is stable, add Quad AI Commander as a separate follow-up PR:

1. Add structured log append helpers.
2. Record existing commander lifecycle, order, production, upgrade, and town-assignment events.
3. Add the per-side context store.
4. Merge contact/intel logs into beliefs.
5. Bias town assignment and template selection from beliefs.
6. Add slow debug summaries so players and developers can understand the AI commander's reasoning.

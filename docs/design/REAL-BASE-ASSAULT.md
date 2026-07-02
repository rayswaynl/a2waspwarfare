# Design: REAL-COMBAT BASE ASSAULT - status

Ray (2026-07-02): the AI must WIN by physically assaulting and destroying the enemy base - units engage
defenders and destroy the HQ + factory structures with WEAPONS - NOT the siege presence-timer that scripts
the base away. Fleet design woxi685l8 (verified against code). Flag-gated, A2-OA-1.64-safe.

---

## Build 86 live status (2026-07-02)

This design is implemented on the build84/cmdcon36 line. The implementation uses slightly different flag names
than the original plan below, so treat the plan sections as historical design context.

Live anchors:
- `Common/Init/Init_CommonConstants.sqf:735-740` defaults real-combat assault on with
  `WFBE_C_AICOM_ASSAULT_STRUCTURES = 1`, `WFBE_C_STRUCTURES_ENEMY_DESTROYABLE = 1`,
  `WFBE_C_STRUCTURES_ENEMY_REDU = 2`, `WFBE_C_AICOM_OVERRUN_SIEGE_DECAY = 1`, and
  `WFBE_C_AICOM_OVERRUN_SCRIPTRAZE = 0`.
- `Server/Functions/Server_BuildingHandleDamages.sqf:12-18` lets enemy weapon damage reach the normal structure
  damage path while still blocking own-side friendly fire.
- `Server/Functions/Server_HandleBuildingDamage.sqf:6-12` and `Server/Functions/Server_BuildingDamaged.sqf:6-11`
  apply the enemy-destroyable damage reducer.
- `Common/Functions/Common_RunCommanderTeam.sqf:1338-1452` runs the `BASE-ASSAULT` target/fire phase against
  enemy HQ and structures.
- `Server/AI/Commander/AI_Commander_Strategy.sqf:856-907` keeps overrun telemetry and siege decay but leaves
  scripted raze disabled by default through `WFBE_C_AICOM_OVERRUN_SCRIPTRAZE = 0`.
- `server_victory_threeway.sqf` still resolves victory from real HQ/factory state, so no victory-script change was needed.

Open follow-up:
- Soak until a base actually falls to weapon fire and capture the `BASE-ASSAULT` / `BASE_OVERRUN` log story for review.
- The proposed per-structure `ASSAULT_STRUCT_KILL` telemetry line was not found in the live implementation. If more
  proof is needed, add it later as telemetry only, without changing assault behavior.

## Historical implementation plan

## Root-cause correction to the two analyses
Both analyses missed the single most important fact for part (1). The enemy HQ/factories are **NOT** killable by AI/enemy weapons today — not because of `allowDamage false`, but because the `handleDamage` handler **zeroes enemy damage**:

`Server\Functions\Server_BuildingHandleDamages.sqf:12`
```
if (_side in [_sideBuilding, sideEnemy]) then { _dammages = false; }
```
`_side = side _origin` (the shooter). `sideEnemy` is A2's global "OPFOR-side-of-the-mission" alias, so on these missions `_side in [_sideBuilding, sideEnemy]` is true for **both** the owner AND the enemy shooter → all incoming damage is dropped to `false` (no damage). Only a shooter whose side is neither the owner nor `sideEnemy` (resistance / environment) reaches `HandleBuildingDamage`. That is why the designers had to add the scripted `setDamage 1` overrun — real fire genuinely cannot kill the base. This gate is attached to:
- HQ (deploy): `Server\Construction\Construction_HQSite.sqf:38` — **unconditional**
- HQ (mobilize): `Server\Construction\Construction_HQSite.sqf:106` — unconditional
- Factories/small: `Server\Construction\Construction_SmallSite.sqf:143` — only when `WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE > 0` (default **1**, `Init_CommonConstants.sqf:1026`), else falls to `HandleBuildingDamage:145`
- Medium: `Server\Construction\Construction_MediumSite.sqf:183/185` (same pattern)

Also note the damage-reduction divisor is **6**, not 1 (`Init_CommonConstants.sqf:1106 WFBE_C_STRUCTURES_DAMAGES_REDUCTION = 6`), and HQ gets `_redu = 5` (`Server_HandleBuildingDamage.sqf:6`, `Server_BuildingDamaged.sqf:6`). Even after unblocking enemy fire, effective HP is very high.

---

## (1) Make HQ + factories genuinely destroyable by weapons — without breaking the player-built lifecycle

The lifecycle we must preserve: `killed` EH → `WFBE_SE_FNC_OnHQKilled` / `BuildingKilled` (bounty, wreck, broadcast, telemetry). Those already fire on real death; they are untouched. We only need to stop the `handleDamage` handler from nulling *enemy* damage, while still nulling *friendly* damage.

**Change the gate in `Server\Functions\Server_BuildingHandleDamages.sqf:12`** from a two-membership drop to a **friendly-only** drop, behind the master flag:

- New behaviour (flag ON): drop damage only when the shooter is the **owner's own side** (true friendly fire) OR `isNull _origin` (unattributed engine damage we don't want auto-razing the base). Let genuine enemy fire through to `HandleBuildingDamage`.
- A2-OA-safe comparison: `_side == _sideBuilding` (side `==`/`!=` is allowed; the memory hazard is `==` on Bool, not on Side). Do **not** use `_side in [...]` for the enemy — that's exactly the bug. Keep the existing `_side in [_sideBuilding, sideEnemy]` path as the flag-OFF fallback so rollback is a one-flag flip.

Sketch (plan only):
```
// Server_BuildingHandleDamages.sqf, replacing the L12 branch
_ff = (missionNamespace getVariable ["WFBE_C_STRUCTURES_ENEMY_DESTROYABLE", 0]) > 0;
if (_ff) then {
    if ((isNull _origin) || {_side == _sideBuilding}) then {
        _dammages = false;                               // still block own-side friendly fire + unattributed
    } else {
        _dammages = [_building, _dammages, _ammo] Call HandleBuildingDamage;   // enemy fire now counts
    };
} else {
    // legacy behaviour (current live) — unchanged
    if (_side in [_sideBuilding, sideEnemy]) then { _dammages = false; }
    else { _dammages = [_building, _dammages, _ammo] Call HandleBuildingDamage; };
};
```

Two supporting knobs so the base is killable in a realistic assault window but not by a stray rifle round:
- Lower effective HP for the assault: add a flag-gated override so `_redu` for the enemy-destroyable path uses `WFBE_C_STRUCTURES_ENEMY_REDU` (propose default 2, vs the live 6) in `Server_HandleBuildingDamage.sqf:6` and `Server_BuildingDamaged.sqf:6` (HQ keeps a higher multiplier than factories, e.g. HQ `_redu`≈3, factory≈2, both far below the never-dies 5/6). Keep the special `B_30mm_HE`/`B_23mm_AA` = 20 cases in `Server_HandleBuildingDamage.sqf:9-10` (those are AA-round soft-caps; leave them).
- Do **not** touch the `killed`/`hit`/`BuildingKilled`/`OnHQKilled` wiring at all — the normal player-vs-player base kill already works through them; unblocking enemy `handleDamage` simply lets accumulated damage *reach* the `killed` EH the same way a player attacker eventually would.

**Why this doesn't break the player-built lifecycle:** player-built structures are created and destroyed through the identical EHs; friendly fire (own side) is still nulled, so a team-mate can't grief the base, and JIP/replication is unaffected (server-side EH only). The `wfbe_structures` registry and `GetFactories`/`GetSideStructures` (`Common_GetFactories.sqf:12`, `Common_GetSideStructures.sqf:8-10`) already filter on `alive _x`, so a genuinely-killed factory drops out of the count exactly as a razed one does.

---

## (2) Make the AI strike force actually ATTACK the structures (target + fire, prioritise AT/armour/GL, keep pressing)

Today the strike order is `[seq, "goto", getPos _enemyHQ]` (`AI_Commander_Strategy.sqf:660`). In `Common_RunCommanderTeam.sqf` the arrival branch only special-cases `_mode == "defense"` (L900) and `"towns-target"` (L903/L934); `"goto"` falls into the `else` SAD at **L903** and never enters a capture/attack-structure phase. SAD makes units fight nearby *men*, never the building. Fix in two coordinated spots:

**2a. New "assault-structures" phase in `Common_RunCommanderTeam.sqf`, mirrored on the existing camp-attack idiom (L1092-1105).** Add a phase parallel to the towns-target capture block (guarded by `_arrived && _mode == "goto"` and the new flag). Reuse the proven, A2-safe idioms already in this file:
- resolve targets: `_eHQ = _enemySide Call WFBE_CO_FNC_GetSideHQ;` and `_eStructs = _enemySide Call WFBE_CO_FNC_GetSideStructures;` (both already used at Strategy L707; both are alive-filtered).
- prioritise the shooters: build the firing list from the team's AT/GL/armour first. A2-OA-safe detection mirrors the existing heavy-detect idiom at `AI_Commander_Strategy.sqf:646` (`(vehicle _x) isKindOf "Tank" / "APC"`) plus a launcher check via `secondaryWeapon _x != ""` / `(getText (configFile >> "CfgWeapons" >> _w >> "type"))`-free test — simplest A2-safe approach: `count (magazines _x)` scan for AT magazine class substrings is fragile; instead order **all** live units to target the structure but *select the launcher/main gun first* with `selectWeapon` only for crewed hulls (same pattern as the heli nudge `selectWeapon _cannonMuzzle`, L203). Infantry with a launcher will auto-pick it against an armoured target; ordering `doTarget`+`doFire` is enough.
- the loop (per ~tick, keep pressing until dead), reusing L1099-1105 pattern:
```
{ if (alive _x) then { _x reveal _eHQ; _x doTarget _eHQ; _x doFire _eHQ; } } forEach (units _team Call WFBE_CO_FNC_GetLiveUnits);
```
Then step to the nearest still-alive factory once the HQ is down, so fire is concentrated (kill order: HQ last or factories-first is a tuning choice; propose **factories-first** so `_factories==0` lands, then HQ). Use `nearestObjects`-free selection: iterate `_eStructs`, pick nearest alive to the team leader via the existing `WFBE_CO_FNC_GetClosestEntity` (used all over this file), target+fire that one, re-evaluate next tick. `reveal` is the 2-operand form only (L1017/L1088 note: array form is A3-only).
- never-frozen guardrail: the team still holds a live SAD/move order underneath (lay the assault SAD at L903 first, then overlay doTarget/doFire), so if the structure is out of LOS the squad still manoeuvres — satisfies the MEMORY "never a standing AI" rule.

**2b. Change the strike order mode so it routes into 2a.** In `AI_Commander_Strategy.sqf:660`, keep the driver-branch routing note but switch the mode token used for the *press* from `"goto"` to a new `"assault-hq"` (or keep `"goto"` and add the `_mode=="goto"` case in the arrival branch — lower-risk, no other reader of `"goto"` exists per the grep). Recommend: add `_mode == "goto"` handling in `Common_RunCommanderTeam.sqf` (no token rename → smaller blast radius, and the existing L660 comment already documents "goto" as the strike press).

**AT/GL/armour prioritisation for team *selection*** is already half-built: the striker picker at `AI_Commander_Strategy.sqf:644-649` scores `_hasHeavy` (+`WFBE_C_AICOM_STRIKE_VEH_BONUS` 100). Extend that scoring (flag-gated) to also bonus teams carrying launchers so the decapitation force is weighted toward base-killers, not pure rifle infantry.

---

## (3) Win from the REAL state; demote the scripted siege-raze to a default-OFF soft fallback

The victory check is already correct and reads real state — `server_victory_threeway.sqf:70`: `(!(alive _hq) && _factories == 0) || (_towns == _total)`. It fires the instant units *actually* destroy the HQ and all factories (now possible after part 1+2). **No change needed to the win trigger itself** — it already awards on true destruction. The only thing manufacturing a fake state is the raze block.

**Gut the scripted raze in `AI_Commander_Strategy.sqf:686-711`:**
- Wrap the entire overrun block behind a new master flag `WFBE_C_AICOM_OVERRUN_RAZE_ENABLE`, **default 0** (OFF). With it OFF, lines 706-707 (`_enemyHQ setDamage 1;` + structures `setDamage 1`) never run → the win can only come from real weapon destruction.
- Keep the block as a **soft fallback**: when the flag is ON *and* the new real-combat path is enabled, only allow the `"siege"` timer sub-path (L705 `_ovrSiege >= _ovrSiegeNeed`) — and raise its default so it's a last-ditch anti-stall, not the primary win. Concretely: gate the siege sub-condition on a separate `WFBE_C_AICOM_OVERRUN_SIEGE_ENABLE` (default 0), and if kept, bump `WFBE_C_AICOM_OVERRUN_SIEGE_TICKS` (Init_CommonConstants.sqf:499) from 5 to something like 20 (~20 min) so it can only bail a truly hung round. The "clear"/"ratio" instant-raze paths (L704-705) become OFF by default too.
- Keep the `BASE_OVERRUN` `diag_log` telemetry line (L708) but split it: log an `ASSAULT_STRUCT_KILL` line from the new part-2 phase each time a real structure dies (so the soak proves units earned it), and only log `BASE_OVERRUN_FALLBACK` if the timer path ever fires.

Net: with the recommended defaults (raze OFF, siege-fallback OFF), the round ends **only** because AI weapons killed the HQ and every factory — exactly Ray's mandate.

---

## (4) A2-OA-1.64 safety, gating, rollback

**A2-OA safety (verified against this codebase's own idioms):**
- Side comparisons use `==`/`!=` (allowed for Side); the memory hazard is `==`/`!=` on **Bool** and A3-only `isEqualType`/`isEqualTo` — none used here. The existing gate at `Server_BuildingHandleDamages.sqf:12` already uses `in`/side compares.
- `doTarget`, `doFire`, `commandFire`, `selectWeapon`, `reveal` (2-operand only) are all confirmed present and working in this file (`Common_RunCommanderTeam.sqf:203-205, 1017, 1088, 1105`). Use the **2-operand `reveal`** form only (array form is A3-only — noted at L1017/L1088).
- No `allMapMarkers`, no `findIf`/`selectRandom`, no array-`reveal` — use `forEach` + `WFBE_CO_FNC_GetClosestEntity` (codebase-standard).
- `getVariable ["name", default]` on **groups** is unreliable in A2 — this file already uses `getVariable "x"; if (isNil ...)` on groups (L629, L771, L804, L943). New group reads must follow that; `missionNamespace`/object reads may use the `[name,default]` form (as L688-701 do).
- Guard every structure/HQ read with `!isNull` and `alive` (helpers already alive-filter; `_eHQ` can be `objNull` mid-mobilize per `Common_GetSideHQ.sqf`).
- All changes are **server/HC-local** (handleDamage EH is server-side; the assault phase runs HC-local exactly like the existing capture phase per the L153-156 locality note) — no publicVariable of group objects, no client edits, so **no pbo-filename bump needed** (client-cache trap avoided; this is a server-logic change only).

**Flags (all default to preserve current live behaviour except where we want the new default):**
| Flag | Default | Effect |
|---|---|---|
| `WFBE_C_STRUCTURES_ENEMY_DESTROYABLE` | `1` (ON — this is the whole point) | Unblocks enemy `handleDamage` in `Server_BuildingHandleDamages.sqf` |
| `WFBE_C_STRUCTURES_ENEMY_REDU` | `2` | Enemy-path damage divisor (vs live 5/6) so an AT/armour assault kills in a realistic window |
| `WFBE_C_AICOM_ASSAULT_STRUCTURES` | `1` (ON) | Enables the part-2 doTarget/doFire-on-structures phase for `"goto"` strike teams |
| `WFBE_C_AICOM_OVERRUN_RAZE_ENABLE` | `0` (OFF) | Master kill-switch for the scripted `setDamage 1` raze (L686-711) |
| `WFBE_C_AICOM_OVERRUN_SIEGE_ENABLE` | `0` (OFF) | If raze re-enabled, gate the pure timer sub-path only |

Declare all in `Common\Init\Init_CommonConstants.sqf` alongside the existing OVERRUN block (L494-500) using the `if (isNil ...) then {...}` idiom.

**Rollback (one flip each, no code revert needed):**
- Restore old base invulnerability: `WFBE_C_STRUCTURES_ENEMY_DESTROYABLE = 0` (falls to the legacy `_side in [_sideBuilding, sideEnemy]` branch, byte-identical to live).
- Restore scripted win: `WFBE_C_AICOM_OVERRUN_RAZE_ENABLE = 1` (+ `WFBE_C_AICOM_OVERRUN_SIEGE_ENABLE = 1`, `SIEGE_TICKS = 5`) → exact current live behaviour.
- Disable AI structure fire: `WFBE_C_AICOM_ASSAULT_STRUCTURES = 0` → strike teams revert to the plain SAD (L903).
- Full revert path: since every edit is additive behind a flag, setting the three flags back reproduces build-84 live exactly; git revert only needed if a flag-gated branch is itself buggy.

---

## Files to edit (all under `Missions\[55-2hc]warfarev2_073v48co.chernarus`, then `dotnet run` in `Tools\LoadoutManager` to mirror to Takistan)
1. `Server\Functions\Server_BuildingHandleDamages.sqf:12` — friendly-only damage drop behind `WFBE_C_STRUCTURES_ENEMY_DESTROYABLE` (part 1).
2. `Server\Functions\Server_HandleBuildingDamage.sqf:6` and `Server\Functions\Server_BuildingDamaged.sqf:6` — flag-gated `_redu` override (`WFBE_C_STRUCTURES_ENEMY_REDU`) (part 1).
3. `Common\Functions\Common_RunCommanderTeam.sqf` — add `_mode == "goto"` assault-structures phase near the arrival branch (after L905 / paralleling L934-1105), reusing the L1099-1105 reveal/doTarget/doFire idiom + `WFBE_CO_FNC_GetClosestEntity` structure selection (part 2a).
4. `Server\AI\Commander\AI_Commander_Strategy.sqf` — (a) optional launcher bonus in the striker picker L644-649; (b) wrap the overrun raze block L686-711 in `WFBE_C_AICOM_OVERRUN_RAZE_ENABLE` (default 0) and gate the siege sub-path (part 2b + part 3). Keep `_mode` token `"goto"` (L660) as-is.
5. `Common\Init\Init_CommonConstants.sqf` — declare the 5 new flags near L494-500 / L1106 (parts 1-4).
6. **No edit** to `server_victory_threeway.sqf` — its L70 real-state check already awards on genuine destruction (part 3).

**Verification for the morning soak:** watch the HC `ArmA2OA.RPT` (per memory: team-driver logs go to the HC RPT, not the server RPT) for the new `ASSAULT_STRUCT_KILL` lines and an eventual `ROUNDEND` in `server_victory_threeway.sqf` with **no** preceding `BASE_OVERRUN` line — that proves the win was earned by weapons, not the timer. Boot-smoke both maps before live."

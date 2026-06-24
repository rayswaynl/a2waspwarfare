# Structure Damage Reduction and Friendly-Fire handleDamage Mechanic (the per-hit HP-loss rule for base structures)

> Source-verified 2026-06-23 against master f8a76de3. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

## 2026-06-24 PR #66 Debug Anti-TK Branch Addendum

PR [#66](https://github.com/rayswaynl/a2waspwarfare/pull/66) / `origin/claude/trello-debug-antitk@98440121c0468e13676c4de5fd2838edaab75167` is open draft branch-only evidence, not current stable behavior. GitHub reports `mergeable=true` / `clean`, but the PR base and local merge-base remain `f8a76de349da6f8b871d079c828436c10afb221c`; current master is `origin/master@f39665d7950ddf14cb0bbfacb7ee1e40121e93b4`, and local `origin/master...origin/claude/trello-debug-antitk` counts are `80 1`. Base-relative payload is four maintained-root files / +10 / -0, clean under `git diff --check f8a76de34..origin/claude/trello-debug-antitk`, with no `Modded_Missions`, `Tools` or `Extension` payload.

In source Chernarus and maintained Vanilla, the branch adds `if (WF_Debug) exitWith {};` inside `WFBE_CL_FNC_OnFiredSatchel` before the existing friendly-structure scan, deletion and `StructureTK` message path (`Client_FNC_OnFired.sqf:12,16,35,41` on the branch). It also adds `if (WF_Debug) exitWith {_dammages};` inside `Server_BuildingHandleDamages.sqf` before the own-side/`sideEnemy` nulling gate and enemy-hit `HandleBuildingDamage` call (`Server_BuildingHandleDamages.sqf:4,9,11-17` on the branch). Current master keeps the same functions without the debug bypass (`Client_FNC_OnFired.sqf:12,32,38`; `Server_BuildingHandleDamages.sqf:4,9-15`), and `WF_Debug` defaults false in both maintained roots at `initJIPCompatible.sqf:110`, only becoming true under the existing debug condition at `:112`.

Before promotion, rebase or recheck the branch against post-B751b master and smoke both roots with `WF_Debug=false` and `WF_Debug=true`: normal mode should still delete same-side PipeBomb attempts near friendly structures, emit the existing `StructureTK` client message and null own-side base-structure damage; debug mode should bypass that client satchel guard and return the raw incoming damage from `Server_BuildingHandleDamages` without changing production defaults. Treat this as a debug/tester bypass only, not a general friendly-fire authority fix or a replacement for the `WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE` production semantics below.

## Overview

Every constructed base structure (CoIn site, headquarters, deployed/mobile HQ) carries a server-side `handleDamage` event handler. Unlike a `hit`/`killed` EH, an Arma 2 `handleDamage` closure is a **rule**: its return value *is* the new damage state the engine applies for that hit-selection. WASP uses this to do two things at once:

1. **Friendly-fire gate** — if the shooter is on the same side as the building, or is `sideEnemy`, the hit is nulled (`false`) and the structure takes no HP loss.
2. **Damage reduction** — for a legitimate enemy hit, the incoming damage delta is divided by a reduction factor (default `6`, or `5` for an unfolded HQ, or `20` for two specific cannon rounds), so bases soak far more fire than their raw armor would allow.

This is distinct from the `BuildingDamaged` "IsUnderAttack" notifier and the `BuildingKilled` scoring path, both of which are documented in [Server Composition Spawner Function Reference](Server-Composition-Spawner-Function-Reference) — that page explicitly dead-ends at *"Actual structure HP is governed by the `handleDamage` EH registered separately"* (`Server-Composition-Spawner-Function-Reference.md:296`). This page is that separately-registered EH.

## Arma 2 `handleDamage` parameter order

The closure receives the engine's standard 5-element array:

| Index | Element | Used by WASP closures |
|---|---|---|
| `select 0` | unit (the structure) | yes — the building object |
| `select 1` | selection (hit-point name) | no |
| `select 2` | damage (incoming total for that selection) | yes — the new damage value |
| `select 3` | source (the firer) | yes — for the side gate |
| `select 4` | ammo (class string) | only the deployed-HQ closure passes it |

Param order confirmed in-repo at `Common/Functions/Common_JetAADamage.sqf:12` (`HandleDamage params: [unit, selection, damage, source, ammo]`). The closure's return value is the damage the engine writes back.

## The friendly-fire-aware function: `Server_BuildingHandleDamages.sqf`

Compiled to the global `BuildingHandleDamages` at `Server/Init/Init_Server.sqf:27`.

```sqf
_building     = _this select 0;             // :3
_dammages     = _this select 1;             // :4
_origin       = _this select 2;             // :5
_ammo         = _this select 3;             // :6
_sideBuilding = _building getVariable "wfbe_side";   // :9
_side         = side _origin;               // :10
if (_side in [_sideBuilding, sideEnemy]) then {      // :12
    _dammages = false;                      // :13
} else {
    _dammages = [_building, _dammages, _ammo] Call HandleBuildingDamage;  // :15
};
_dammages                                   // :18 — returned to the engine
```

`Server/Functions/Server_BuildingHandleDamages.sqf:1-18`.

### The side gate (the "why can't I damage my own base" rule)

The structure's side is read from the object variable `wfbe_side` (`:9`). `_origin` is whichever element the wrapper closure put in `_this select 2` (see the arg-mapping table below — in every real attachment this is the firer/source, *not* the engine's `select 2`).

The gate at line 12 nulls damage to `false` when `_side in [_sideBuilding, sideEnemy]`. Two cases pass:

| `_side` of firer | Result | Meaning |
|---|---|---|
| equals `_sideBuilding` | `_dammages = false` | own-side fire — base is invulnerable to friendlies |
| `sideEnemy` | `_dammages = false` | the engine's neutral "renegade/no-side" placeholder (`west`/`east`/`resistance`/`civilian` are the four real sides; `sideEnemy` is the catch-all returned for objects with no resolved side) — these hits are also nulled |

Any other side (a genuine opposing faction) falls through to the `else` branch and goes to the divisor math. A `nil`/null `_origin` resolves `side _origin` to `sideEnemy`, so unattributed environmental damage is also nulled.

> Note: `Server_BuildingHandleDamages.sqf:1` declares `'_side'` twice in its `Private` list and never declares `_ammo`. Both are cosmetic (the duplicate is harmless; `_ammo` works because it is assigned, not just read). No behavioral effect under A2.

## The divisor math + per-ammo overrides: `Server_HandleBuildingDamage.sqf`

Compiled to the global `HandleBuildingDamage` at `Server/Init/Init_Server.sqf:36`.

```sqf
_building = _this select 0;                  // :2
_ammo     = _this select 2;                  // :3
_redu = if (_building isKindOf "Warfare_HQ_base_unfolded")
        then {5}                             // :6 — hardcoded HQ divisor
        else {missionNamespace getVariable "WFBE_C_STRUCTURES_DAMAGES_REDUCTION"};
switch (_ammo) do {                          // :8
    case "B_30mm_HE" :{_redu = 20};          // :9
    case "B_23mm_AA" :{_redu = 20};          // :10
};
_difference = ((_this select 1) - (getDammage (_this select 0)))/(_redu);  // :14
((getDammage (_this select 0))+_difference)  // :15 — returned
```

`Server/Functions/Server_HandleBuildingDamage.sqf:1-15`.

### The formula

Let `dmg_in = _this select 1` (the proposed new damage from the wrapper) and `dmg_now = getDammage building`. The function returns:

```
new_damage = dmg_now + (dmg_in - dmg_now) / _redu
```

i.e. the structure only moves `1/_redu` of the way toward the engine's proposed damage on each hit. With the default `_redu = 6`, a hit that would have brought the building to full destruction instead advances it 1/6 of the remaining gap — bases bleed HP roughly six times slower than their raw armor.

### Divisor (`_redu`) selection

| Condition | `_redu` | Source |
|---|---|---|
| building `isKindOf "Warfare_HQ_base_unfolded"` | `5` (hardcoded) | `Server_HandleBuildingDamage.sqf:6` |
| `_ammo == "B_30mm_HE"` | `20` (override) | `Server_HandleBuildingDamage.sqf:9` |
| `_ammo == "B_23mm_AA"` | `20` (override) | `Server_HandleBuildingDamage.sqf:10` |
| any other structure / ammo | `WFBE_C_STRUCTURES_DAMAGES_REDUCTION` (= `6`) | `Server_HandleBuildingDamage.sqf:6` |

The ammo `switch` runs **after** the HQ check, so a `B_30mm_HE`/`B_23mm_AA` round against an unfolded HQ overrides the `5` to `20`. A higher `_redu` means *more* reduction (less damage applied), so the two cannon overrides actually make those rounds **less** effective against structures, not more — a deliberate balance choice for autocannon spam (the BMP-2's `B_30mm_HE` and the ZU-23 / Tunguska `B_23mm_AA`).

## The `WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE` toggle (two-closure switch)

`WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE` (`Common/Init/Init_CommonConstants.sqf:613`, default `1`) decides which closure the construction code attaches:

```sqf
if ((missionNamespace getVariable "WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE") > 0) then {
    _site addEventHandler ['handleDamage',{[_this select 0,_this select 2,_this select 3] Call BuildingHandleDamages}];
} else {
    _site addEventHandler ['handleDamage',{[_this select 0, _this select 2] Call HandleBuildingDamage}];
};
```

- **FF on (default):** attaches the FF-aware wrapper that calls `BuildingHandleDamages` (side gate → divisor).
- **FF off (raw fallback):** attaches a closure that calls `HandleBuildingDamage` **directly**, bypassing the side gate entirely — every side (including friendlies) can damage the base, but the divisor reduction still applies.

### Wrapper-closure arg mapping (and the dropped-`_ammo` consequence)

The FF-on wrapper passes the engine's `[unit, damage, source]` as `[select 0, select 2, select 3]`. Inside `Server_BuildingHandleDamages` these become `_building (select 0)`, `_dammages (select 1)`, `_origin (select 2)` — so `_origin` correctly receives the **source**, and `_ammo (select 3)` receives whatever the wrapper put at index 3.

| Attachment site | Args passed to `BuildingHandleDamages` | `_ammo` inside the fn | Per-ammo override reachable? |
|---|---|---|---|
| `Construction_SmallSite.sqf:143` | `[sel 0, sel 2, sel 3]` (3 elements) | `nil` (index 3 out of range) | **No** |
| `Construction_MediumSite.sqf:183` | `[sel 0, sel 2, sel 3]` | `nil` | **No** |
| `Construction_HQSite.sqf:106` (mobile HQ) | `[sel 0, sel 2, sel 3]` | `nil` | **No** |
| `Construction_HQSite.sqf:38` (deployed HQ) | `[sel 0, sel 2, sel 3, sel 4]` (4 elements) | the real ammo string | **Yes** |
| `Server_HandleBuildingRepair.sqf:64` (re-attach) | `[sel 0, sel 2, sel 3]` | `nil` | **No** |

Because four of the five attachments pass only three elements, the wrapper's `_this select 3` (which becomes the function's `_ammo`) is out of range and resolves to `nil`. The `B_30mm_HE` / `B_23mm_AA` overrides in `Server_HandleBuildingDamage.sqf:8-11` therefore **only ever match for the deployed-HQ structure** (`Construction_HQSite.sqf:38`, which alone forwards `_this select 4`). For CoIn sites and the mobile HQ, those rounds fall through to the default `_redu`. This is a latent inconsistency, not a crash — `switch (nil)` simply matches no case under A2.

## Where the EH is attached

| File:line | Structure | Toggle-gated? | Closure target |
|---|---|---|---|
| `Server/Construction/Construction_SmallSite.sqf:142-146` | small CoIn site | yes (`>0`) | `BuildingHandleDamages` / else `HandleBuildingDamage` |
| `Server/Construction/Construction_MediumSite.sqf:182-186` | medium CoIn site | yes | `BuildingHandleDamages` / else `HandleBuildingDamage` |
| `Server/Construction/Construction_HQSite.sqf:38` | deployed HQ | **no** (unconditional) | `BuildingHandleDamages` (4-arg, passes ammo) |
| `Server/Construction/Construction_HQSite.sqf:106` | mobilized MHQ | **no** (unconditional) | `BuildingHandleDamages` (3-arg) |
| `Server/Functions/Server_HandleBuildingRepair.sqf:63-65` | rebuilt site (repair path) | yes | `BuildingHandleDamages` / else inline raw closure |

### HQ structures are unconditional

`Construction_HQSite.sqf:38` and `:106` attach the FF-aware `BuildingHandleDamages` closure with **no** `WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE` guard — so the headquarters always uses the side gate regardless of the toggle. (A toggle-gated HQ variant exists but is commented out at `Server/Init/Init_Server.sqf:568` and `Server/Functions/Server_MHQRepair.sqf:42`; neither runs.)

### Re-attachment on repair

When a destroyed structure is rebuilt, `Server_HandleBuildingRepair.sqf` re-spawns the object and must re-register the EH (event handlers do not survive the object being replaced). Its FF-off fallback is a **different** raw closure than the construction sites use:

```sqf
_site addEventHandler ['handleDamage',{getDammage (_this select 0)+((_this select 2)/(_redu))}];  // :66
```

`Server/Functions/Server_HandleBuildingRepair.sqf:66`. This inline closure captures `_redu` from the enclosing repair scope, where it is declared in the function's `Private` list (`:1`) and set at `:9` (`5` for an unfolded HQ, else `WFBE_C_STRUCTURES_DAMAGES_REDUCTION`). So the FF-off repair path applies the divisor but has no per-ammo override and no side gate — it adds `damage/_redu` to current damage directly. The FF-on repair path (`:64`) is identical to the construction-site wrappers.

## Constants

| Constant | Default | Meaning | Source |
|---|---|---|---|
| `WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE` | `1` (on) | `>0` selects the FF-aware closure; `0` selects the raw fallback | `Common/Init/Init_CommonConstants.sqf:613` |
| `WFBE_C_STRUCTURES_DAMAGES_REDUCTION` | `6` | divisor for non-HQ structures (current damage given / x; `1` = normal) | `Common/Init/Init_CommonConstants.sqf:690` |
| HQ divisor | `5` | hardcoded for `Warfare_HQ_base_unfolded`; not a tunable | `Server/Functions/Server_HandleBuildingDamage.sqf:6` |
| `B_30mm_HE` / `B_23mm_AA` divisor | `20` | hardcoded per-ammo override (deployed HQ only, see arg-mapping table) | `Server/Functions/Server_HandleBuildingDamage.sqf:9-10` |

## Relationship to the hit/kill paths

| EH | Fires on | Effect | Documented in |
|---|---|---|---|
| `handleDamage` (this page) | every damage selection | returns the actual new HP/damage value | here |
| `hit` → `BuildingDamaged` | each registered hit | only raises the "IsUnderAttack" side alert (throttled by `wfbe_structure_lasthit`); applies **no** HP | [Server Composition Spawner Function Reference](Server-Composition-Spawner-Function-Reference) (`:300`) |
| `killed` → `BuildingKilled` | structure destroyed | scoring / bounty / HeadHunter | [Server Composition Spawner Function Reference](Server-Composition-Spawner-Function-Reference) (`:311` ff.) |

All three EHs are attached side-by-side in each construction site (e.g. `Construction_SmallSite.sqf:141` `hit`, `:142-146` `handleDamage`, `:147` `killed`). The `hit` notifier reads a *post-reduction* damage delta but never writes it; the `handleDamage` rule on this page is the only one of the three that changes structure HP.

## Continue Reading

- [Server Composition Spawner Function Reference](Server-Composition-Spawner-Function-Reference) — the `BuildingDamaged` "IsUnderAttack" notifier and `BuildingKilled` scoring; dead-ends at the `handleDamage` EH documented here
- [Commander HQ Lifecycle Atlas](Commander-HQ-Lifecycle-Atlas) — HQ deploy/mobilize, `Warfare_HQ_base_unfolded`, and the HQ-killed path that this damage rule feeds
- [Construction And CoIn Systems Atlas](Construction-And-CoIn-Systems-Atlas) — how CoIn sites are constructed and where their EHs are wired
- [Kill And Score Pipeline](Kill-And-Score-Pipeline) — the unit/vehicle damage and kill-credit chain that parallels this structure rule
- [Mission Tunable Constants Catalog](Mission-Tunable-Constants-Catalog) — `WFBE_C_STRUCTURES_DAMAGES_REDUCTION`, `WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE`, and the rest of the gameplay-tuning constants

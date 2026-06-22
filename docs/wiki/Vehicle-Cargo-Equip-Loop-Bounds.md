# Vehicle Cargo Equip Loop Bounds

This page documents a confirmed cargo-application loop-bound bug in vehicle and backpack gear helpers. It replaces the older vague scout note in [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas).

All mission paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Current Flow

```mermaid
flowchart TD
    BuyGear["Client/GUI/GUI_BuyGearMenu.sqf"] --> GetVehicle["Client_GetVehicleContent.sqf"]
    GetVehicle --> VehicleContent["_gear_sel_vehicle / _gear_vehicle_content"]
    BuyGear --> EquipVehicle["Common_EquipVehicle.sqf"]
    BuildUnit["Client_BuildUnit.sqf soldier gear path"] --> EquipBackpack["Common_EquipBackpack.sqf"]
    EquipUnit["Common_EquipUnit.sqf"] --> EquipBackpack
```

## Source Evidence

| Source | Evidence |
| --- | --- |
| `Common/Init/Init_Common.sqf:108,110` | Compiles `WFBE_CO_FNC_EquipBackpack` and `WFBE_CO_FNC_EquipVehicle` when not running the A2 vanilla fallback. |
| `Client/GUI/GUI_BuyGearMenu.sqf:94,102,108` | Reads current vehicle cargo through `Client_GetVehicleContent.sqf` and stores selected cargo arrays. |
| `Client/GUI/GUI_BuyGearMenu.sqf:439` | Applies selected vehicle cargo with `[vehicle _target, _gear_sel_vehicle] Call WFBE_CO_FNC_EquipVehicle`. |
| `Client/Functions/Client_GetVehicleContent.sqf:20-22` | Reads cargo with safe `for '_i' from 0 to count(_items)-1` loops. The collector is not the bug. |
| `Common/Functions/Common_EquipVehicle.sqf:27,33,39` | Applies weapon, magazine and backpack cargo. Docs branch `b2544207`, historical Miksuu `b8389e74` and historical EASA QoL `a66d4691` still use inclusive `count(_items)` loops; current stable `origin/master@0139a346` and current Miksuu `d9506078` use corrected `(count(_items) - 1)` loops in both maintained roots. |
| `Common/Functions/Common_EquipBackpack.sqf:35,41` | Applies backpack weapon and magazine contents. The same branch split applies: old-shape docs/EASA/perf-Vanilla targets still overrun by one, while current stable and current Miksuu are already fixed in both maintained roots. |
| `Client/Functions/Client_BuildUnit.sqf:229` | Calls `WFBE_CO_FNC_EquipBackpack` for soldier purchases when a backpack is present. |
| `Common/Functions/Common_EquipUnit.sqf:38` | Calls `WFBE_CO_FNC_EquipBackpack` for unit loadout application. |

## Current Branch Matrix

| Root / branch | `Common_EquipVehicle.sqf` | `Common_EquipBackpack.sqf` | Practical meaning |
| --- | --- | --- | --- |
| Docs branch `docs/developer-wiki-index@b2544207` | Inclusive weapon, magazine and backpack loops at `:27`, `:33`, `:39` in Chernarus and maintained Vanilla. | Inclusive weapon and magazine loops at `:35`, `:41` in Chernarus and maintained Vanilla. | Patch-ready on the docs branch and any target derived from it. |
| Current stable `origin/master@0139a346` | Fixed to `(count(_items) - 1)` in both maintained roots at `:27`, `:33`, `:39`. | Fixed to `(count(_items) - 1)` in both maintained roots at `:35`, `:41`. | Do not reopen this defect on current stable; preserve the fix when merging older branches. |
| Current Miksuu upstream `miksuu/master@d9506078` | Fixed to `(count(_items) - 1)` in both maintained roots at `:27`, `:33`, `:39`. Older checkpoint `b8389e74` was still inclusive. | Fixed to `(count(_items) - 1)` in both maintained roots at `:35`, `:41`. Older checkpoint `b8389e74` was still inclusive. | Upstream now carries the loop-bound rescue; use the current fetched head, not the older `b8389e74` checkpoint, for merge guidance. |
| `origin/perf/quick-wins` `0076040f` | Chernarus fixes all three loops to `count(_items)-1`; maintained Vanilla still carries inclusive loops. | Chernarus fixes both loops to `count(_items)-1`; maintained Vanilla still carries inclusive loops. | Perf branch is Chernarus-only for this fix; Vanilla propagation remains open there. |
| Historical release commit `a96fdda2` | Fixed to `(count(_items) - 1)` in both maintained roots at `:27`, `:33`, `:39`. | Fixed to `(count(_items) - 1)` in both maintained roots at `:35`, `:41`. | Historical fixed checkpoint only; current origin exposes no `release/*` head on 2026-06-22. |
| Historical EASA QoL commit `a66d4691` | Same inclusive loops in both maintained roots. | Same inclusive loops in both maintained roots. | Historical old-shape checkpoint only; current origin exposes no `feat/buymenu-easa-qol` head on 2026-06-22. |

## Bug Shape

SQF arrays are zero-indexed. These equip helpers iterate one slot past the last valid item:

```sqf
for '_i' from 0 to count(_items) do {_vehicle addWeaponCargoGlobal [_items select _i, _counts select _i]};
```

For an array with `N` entries, valid indexes are `0` through `N - 1`. Index `N` is out of range.

Confirmed old-shape locations:

| Helper | Loops |
| --- | --- |
| `Common_EquipVehicle.sqf` | weapon cargo `:27`, magazine cargo `:33`, backpack cargo `:39` on docs branch `b2544207`, historical EASA QoL `a66d4691` and perf Vanilla |
| `Common_EquipBackpack.sqf` | backpack weapon cargo `:35`, backpack magazine cargo `:41` on docs branch `b2544207`, historical EASA QoL `a66d4691` and perf Vanilla |

Likely impact:

- Each non-empty cargo application can attempt one out-of-range `_items select _i` / `_counts select _i` at the end of the loop.
- Depending on Arma 2 OA runtime behavior and logging settings, this may create RPT noise, abort the loop tail or fail silently after applying valid entries.
- Empty arrays may also enter the loop at index `0` unless the surrounding content guard exits first; `Common_EquipVehicle.sqf` checks only the top-level vehicle-content array, not each sub-array.
- This is a correctness and reliability bug in local gear/cargo application, not a public-server authority fix.

## Patch Shape

Recommended first patch for old-shape targets:

```sqf
for '_i' from 0 to count(_items)-1 do {
    _vehicle addWeaponCargoGlobal [_items select _i, _counts select _i];
};
```

Apply the `count(_items)-1` bound to all five confirmed old-shape loops. Current stable, current Miksuu and historical `a96fdda2` already carry this shape in both maintained roots.

Optional guard if the code owner wants clearer empty-array behavior:

```sqf
if (count _items > 0) then {
    for '_i' from 0 to count(_items)-1 do {
        _vehicle addWeaponCargoGlobal [_items select _i, _counts select _i];
    };
};
```

Keep the patch scoped:

- Do not redesign the buy-gear UI.
- Do not treat this as gear-purchase authority hardening.
- Do not combine with [Gear template profile filter](Gear-Template-Profile-Filter), even though both live in the gear UI area.

## Validation Plan

Source checks:

1. `Common_EquipVehicle.sqf` has no `for '_i' from 0 to count(_items) do` loops.
2. `Common_EquipBackpack.sqf` has no `for '_i' from 0 to count(_items) do` loops.
3. `Client_GetVehicleContent.sqf` still uses `count(_items)-1` and does not regress.
4. Source Chernarus is patched first; Vanilla Takistan is propagated by LoadoutManager from a correctly named `a2waspwarfare` checkout.

Arma smoke:

1. Add one weapon cargo item to a vehicle through Buy Gear and confirm exactly one appears.
2. Add one magazine cargo item to a vehicle and confirm exactly one appears.
3. Add one backpack cargo item to a vehicle and confirm exactly one appears.
4. Add backpack weapon/magazine contents to a unit backpack and confirm contents apply without RPT out-of-range errors.
5. Try empty cargo groups and confirm no RPT out-of-range errors.

## Generated And Modded Missions

On docs branch `b2544207`, `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` carries the same inclusive loops in `Common_EquipVehicle.sqf` and `Common_EquipBackpack.sqf`. Current stable `origin/master@0139a346`, current Miksuu `d9506078` and historical release `a96fdda2` already fix both maintained roots; perf `0076040f` fixes Chernarus only.

Per project rules:

- Patch source Chernarus first.
- Use `Tools/LoadoutManager` for Vanilla propagation.
- Treat Napf/Eden/Lingor as divergent forks and other modded folders as stubs unless the owner chooses a maintenance model.

## Agent Notes

- This is a small, patch-ready reliability bug.
- It should be safe to patch independently from the server-authority/economy redesign because it only fixes loop bounds in cargo-application helpers.
- Keep this page paired with [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas) and [Feature status](Feature-Status-Register).
- Branch check refreshed 2026-06-22: docs branch `b2544207`, older Miksuu checkpoint `b8389e74` and historical EASA QoL `a66d4691` still carry the five inclusive loops in both maintained roots. Current stable `origin/master@0139a346`, current Miksuu `d9506078` and historical release `a96fdda2` fix both maintained roots; perf `0076040f` fixes Chernarus only. Current origin exposes no live `release/*` or `feat/buymenu-easa-qol` heads.

## Continue Reading

Previous: [Gear template profile filter](Gear-Template-Profile-Filter) | Next: [UI IDD collision repair](UI-IDD-Collision-Repair)

Main map: [Home](Home) | Agent file: [`agent-feature-status.jsonl`](agent-feature-status.jsonl) | Backlog: [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)

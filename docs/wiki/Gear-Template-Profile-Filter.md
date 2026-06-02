# Gear Template Profile Filter

This page documents the profile-template save filter bug in the buy-gear system. It is a focused implementation note for the row in [Feature status](Feature-Status-Register) and the gear atlas.

All mission paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Current Flow

```mermaid
flowchart TD
    InitClient["Client/Init/Init_Client.sqf"] --> CompileGear["Compile gear UI helpers"]
    InitClient --> ProfileGate["OA version gate compiles SaveTemplateProfile"]
    ProfileVars["Client/Init/Init_ProfileVariables.sqf"] --> ProfileGear["Client/Init/Init_ProfileGear.sqf"]
    ProfileGear --> MissionTemplates["WFBE_%SIDE_Template in missionNamespace"]
    BuyGear["GUI_BuyGearMenu.sqf"] --> AddTemplate["Client_UI_Gear_AddTemplate.sqf"]
    AddTemplate --> MissionTemplates
    BuyGear --> SaveNeeded["_need_save when template changes"]
    SaveNeeded --> SaveProfile["Client_UI_Gear_SaveTemplateProfile.sqf"]
    SaveProfile --> ProfileNamespace["profileNamespace WFBE_PERSISTENT_%SIDE_GEAR_TEMPLATE"]
```

## Source Evidence

| Source | Evidence |
| --- | --- |
| `Client/Init/Init_Client.sqf:116-126` | Compiles gear UI helpers including add/delete/fill/template functions. |
| `Client/Init/Init_Client.sqf:169-172` | Under the OA version gate, compiles `WFBE_CL_FNC_UI_Gear_SaveTemplateProfile` and runs profile variable loading. |
| `Client/Init/Init_ProfileVariables.sqf:37-42` | Reads `WFBE_PERSISTENT_%SIDE_GEAR_TEMPLATE` from `profileNamespace` and validates through `Init_ProfileGear.sqf`. |
| `Client/Init/Init_ProfileGear.sqf:25-136` | Re-validates stored profile templates for shape, side membership, price and max upgrade before replacing mission templates. |
| `Client/Functions/Client_UI_Gear_AddTemplate.sqf:15,37,83,110,136-148` | Builds `_u_upgrade` as the maximum required upgrade in the new template, then appends the template and sets `_need_save = true`. |
| `Client/GUI/GUI_BuyGearMenu.sqf:509` | Spawns `WFBE_CL_FNC_UI_Gear_SaveTemplateProfile` after the dialog closes when `_need_save` is true. |
| `Client/Functions/Client_UI_Gear_SaveTemplateProfile.sqf:17-19` | Privates and sets `_template_upgrade = _x select 3`. |
| `Client/Functions/Client_UI_Gear_SaveTemplateProfile.sqf:33,52,75` | Uses `_u_upgrade`, which is not private or assigned in this function. |
| `Client/Functions/Client_UI_Gear_SaveTemplateProfile.sqf:94-95` | Writes the filtered array to `profileNamespace` and calls `saveProfileNamespace`. |

## Bug Shape

`Client_UI_Gear_SaveTemplateProfile.sqf` intends to filter templates so only side-valid and currently unlocked items are saved to the player's profile. The function has a correctly named `_template_upgrade` value, but the three per-item upgrade checks reference `_u_upgrade` instead:

```sqf
if ((_get select 3) > _upgrade_barracks && _u_upgrade > _upgrade_gear) then {_can_save = false};
```

`_u_upgrade` exists in `Client_UI_Gear_AddTemplate.sqf`, where it is the computed max upgrade for a newly created template. It does not exist in `Client_UI_Gear_SaveTemplateProfile.sqf`.

Practical impact:

- The save pass can hit an undefined-variable script error when a template item's upgrade exceeds the current barracks upgrade and the expression evaluates the second operand.
- Even when no error is hit, saved-template upgrade filtering cannot be trusted as written because the intended second comparison reads the wrong variable.
- `Init_ProfileGear.sqf` still validates profile templates on load, so this is mainly a persistence/filter correctness bug, not proof that the live buy-gear UI lets locked gear equip by itself.
- The broader gear/EASA/service authority issue remains separate: purchases and effects are still client-authoritative legacy flows, covered by [Server authority migration map](Server-Authority-Migration-Map) and [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas).

## Patch Options

| Option | Shape | Tradeoff |
| --- | --- | --- |
| Use item upgrade directly | Replace `_u_upgrade > _upgrade_gear` with `(_get select 3) > _upgrade_gear` in all three checks. | Most local and easiest to reason about: reject each item if its own upgrade exceeds both barracks and gear. |
| Use template max upgrade | Replace `_u_upgrade` with `_template_upgrade`. | Matches the already-read template field, but rejects based on the template max when checking each item. This is close to `AddTemplate` behavior. |
| Recompute local max | Initialize `_u_upgrade = _template_upgrade` or recompute max before per-item checks. | More churn than needed unless the owner wants to normalize stale profile data during save. |

Recommended first patch:

```sqf
if ((_get select 3) > _upgrade_barracks && (_get select 3) > _upgrade_gear) then {_can_save = false};
```

Apply that replacement at the weapon, magazine and backpack-content checks. Keep `Init_ProfileGear.sqf` load validation unchanged unless a smoke test proves it filters too aggressively or too loosely.

## Validation Plan

Source checks:

1. `Client_UI_Gear_SaveTemplateProfile.sqf` has no `_u_upgrade` reference.
2. The function still writes `WFBE_PERSISTENT_%SIDE_GEAR_TEMPLATE`.
3. `Client_UI_Gear_AddTemplate.sqf` still computes and stores template max upgrade in field 3.
4. `Init_ProfileGear.sqf` still recalculates stored profile price and max upgrade on load.

Arma smoke:

1. Create a gear template with currently allowed gear; close the menu and confirm it persists after restart/rejoin.
2. Try to save a template containing gear above both barracks and gear upgrade levels; confirm it is not written and no RPT undefined-variable error appears.
3. Upgrade barracks/gear and confirm the same template becomes saveable when the relevant level is unlocked.
4. Confirm templates still disappear from the visible list when `Client_UI_Gear_FillTemplates.sqf` filters them above current `WFBE_UP_GEAR`.

Generated mission:

- Patch source Chernarus first.
- Propagate Vanilla Takistan with `Tools/LoadoutManager` from a checkout whose ancestor folder is literally named `a2waspwarfare`.
- Do not hand-edit divergent/stubbed `Modded_Missions` unless the owner picks a maintenance model.

## Agent Notes

- This is a correctness and persistence bug in profile-template filtering.
- It is not the same as full gear purchase authority. Do not claim public-server gear hardening after this patch.
- Keep this page paired with [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas) and [Feature status](Feature-Status-Register).

## Continue Reading

Previous: [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) | Next: [UI IDD collision repair](UI-IDD-Collision-Repair)

Main map: [Home](Home) | Agent file: [`agent-feature-status.jsonl`](agent-feature-status.jsonl) | Backlog: [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)

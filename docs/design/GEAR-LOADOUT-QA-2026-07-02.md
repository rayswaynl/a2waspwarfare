# Gear / Loadout Save-Load QA - 2026-07-02

Scope: lane 65 QA sweep for player gear presets, respawn gear restore, and EASA interplay on the live lane `claude/build84-cmdcon36`.

Out of scope: `GUI_Menu*.sqf` in-flight work, the shelved lane-34 price-cleanup framing, AI respawn loadout PR #206, EASA-for-AI behavior, economy retunes, and live-server/package actions.

## Source Map

| Area | Live source anchor | Current behavior |
| --- | --- | --- |
| Profile import | `Client/Init/Init_ProfileVariables.sqf:47-52` -> `Client/Init/Init_ProfileGear.sqf` | Reads `profileNamespace` key `WFBE_PERSISTENT_%SIDE_GEAR_TEMPLATE`, sanitizes rows, and replaces `WFBE_%SIDE_Template` only when at least one valid row survives. |
| Template create/save | `Client/GUI/GUI_BuyGearMenu.sqf:467-525`, `Client_UI_Gear_AddTemplate.sqf`, `Client_UI_Gear_SaveTemplateProfile.sqf:106-108` | Template edits mark `_need_save`; dialog close spawns save; save writes the filtered template list back to `profileNamespace`. |
| Hostile/captured gear policy | `Client/Init/Init_Client.sqf:47`, `Client_UI_Gear_AddTemplate.sqf:34,74,106`, `Client_UI_Gear_SaveTemplateProfile.sqf:46,67,92` | The live default allows hostile gear saving, and add/save paths only enforce side membership when `WFBE_Allow_HostileGearSaving` is false. |
| Purchased custom gear | `GUI_BuyGearMenu.sqf:438-445`, `Client_OnRespawnHandler.sqf:134-178` | Purchase stores `wfbe_custom_gear` and `wfbe_custom_gear_cost`; respawn re-equips it when custom gear is allowed and the penalty mode/funds checks pass. |
| Default respawn gear | `Client_OnRespawnHandler.sqf:180-215`, `Init_Client.sqf:1083-1110` | Role default gear falls back to side-wide `WFBE_%SIDE_DefaultGear`; missing fallback only logs and keeps config gear instead of stripping the unit. |
| EASA | `Client/Module/EASA/EASA_Init.sqf`, `GUI_Menu_EASA.sqf:73-132`, `EASA_Equip.sqf:15-37`, `Client_CanUseRepairPointEASA.sqf` | EASA is client-built data; loadout swaps remove old/default weapons, add the selected kit, broadcast `WFBE_EASA_Setup`, and repair-point EASA is Engineer + driver + cooldown gated. |

## Findings

| ID | Severity | Status | Evidence | Result |
| --- | --- | --- | --- | --- |
| GEAR-1 | P1 | Fixed in this PR | Add/save honor `WFBE_Allow_HostileGearSaving`, but `Init_ProfileGear.sqf` still rejected stored weapons not in the current side list. A captured/hostile weapon template could be created and saved on the default live policy, then disappear on next profile import. | `Init_ProfileGear.sqf` now applies the side-membership check only when hostile gear saving is disabled. |
| GEAR-2 | P2 | Fixed in this PR | `Init_ProfileGear.sqf` accepted rows with `count _x >= 6` and then read `_x select 6`; a malformed six-field profile row could trip a load-time script error. This exact row was already preserved in the wiki gear atlas. | The import guard now requires `count _x >= 7` before reading backpack data. |
| GEAR-3 | P2 | Shelved, not duplicated | `Client_UI_Gear_UpdatePrice.sqf:87-89` still carries the stray `forEach _gear_new` shape. PR #169 removed it, but Ray shelved that PR because the parsed behavior is likely a type-error/no-op rather than real wallet double-counting. | Left unchanged. Revive PR #169 or rebase a cleanup only after a gear-price smoke test decides the framing. |
| GEAR-4 | P2 | Follow-up only | Template creation passes weapons, magazines, and backpack content at `GUI_BuyGearMenu.sqf:470`; nearby update code still says `todo later, template for veh / bp` at `:498`. Price/purchase handles vehicle cargo, but profile templates are not a full snapshot of the visible vehicle/backpack cargo state. | Left unchanged because fixing this needs a deliberate template-schema extension and old-profile compatibility plan. |
| GEAR-5 | P3 | Smoke-only | Custom respawn gear depends on `wfbe_custom_gear` and `wfbe_custom_gear_cost` being present on the respawned unit (`Client_OnRespawnHandler.sqf:135-174`). The code is coherent, but it is an engine-lifecycle behavior that should be verified in-game across base, mobile, and leader respawn modes. | No source change without RPT or live repro evidence. |
| GEAR-6 | P3 | No issue found | EASA exact-funds purchase is already `>=` in `GUI_Menu_EASA.sqf:119`; default loadout restore strips the current setup before re-adding factory kit; turret airframes use turret add/remove paths. | No EASA source change in this lane. |

## Smoke Checklist

1. With default `WFBE_Allow_HostileGearSaving = true`, create a template containing a captured/enemy weapon, close the gear dialog, restart/rejoin, and confirm the template is still listed.
2. Temporarily test a malformed six-field `WFBE_PERSISTENT_%SIDE_GEAR_TEMPLATE` row and confirm profile import ignores it without a `select 6` RPT error.
3. Confirm a normal seven-field template with backpack content still imports, recalculates price/upgrade, and appears when the current gear tier allows it.
4. Buy a custom player loadout, respawn at base and at a mobile respawn with penalty modes 0, 2/3/4, and 5, and confirm default/custom gear toggles and charges match `Client_OnRespawnHandler.sqf`.
5. Equip an EASA loadout, restore `[DEFAULT]`, then use repair-point EASA as Engineer driver and as non-Engineer to confirm the driver/cooldown/role gates.

## Guardrails

- No `GUI_Menu*.sqf`, AI commander, HC architecture, enrollment/JIP flow, deploy script, package, or live-server work.
- Source fixes are limited to profile-template import and are mirrored through `Tools/LoadoutManager`.
- The lane-34 price cleanup stays shelved by owner decision; this report records it but does not reopen it.

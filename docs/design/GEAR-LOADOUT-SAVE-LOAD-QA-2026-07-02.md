# Gear/Loadout Save-Load QA - 2026-07-02

Lane: 65, gear/loadout save-load QA
Base checked: `origin/claude/build84-cmdcon36@24604e9f7`
Scope: saved gear presets, respawn gear restore, GUER gear-tier handling, inventory/cargo price math, and EASA interplay. Adjacent open PRs for gear-slot tooltips (#226) and AI respawn loadout guards (#204/#206) stay out of scope.

## Summary

The live target already has several important gear fixes: profile template save uses the item-level upgrade requirement instead of the old undefined variable, add/save now respect `WFBE_Allow_HostileGearSaving`, respawn gear falls back to side default gear instead of stripping players, and playable GUER bypasses the normal gear-tier filter because GUER has no side upgrade economy.

This lane fixes three small current-source issues in the same surface:

- Backpack/vehicle container additions in `Client_UI_Gear_UpdatePrice.sqf` were still repeated by a stray trailing `forEach _gear_new`, inflating displayed and charged gear prices.
- Profile template import accepted six-field rows and then read field 6, so a malformed old profile row could still throw during startup.
- Profile template import still rejected cross-side gear even though create/save allow hostile gear templates by default.

## Fixed Findings

| ID | Severity | Finding | Evidence | Fix |
| --- | --- | --- | --- | --- |
| GL-QA-01 | P2 | Backpack/vehicle cargo price additions were double-counted in non-vanilla gear price math. | `Client_UI_Gear_UpdatePrice.sqf` had a `for '_k' from 0 to count(_gear_new)-1 do` loop at lines 74-88, but the closing brace was also suffixed with `forEach _gear_new`, repeating the addition pass once per container. This was previously released as PR #169 but that PR is closed unmerged, and the target still carried the bug. | Removed the stale trailing `forEach _gear_new` so the existing `for` loop runs exactly once. |
| GL-QA-02 | P2 | Profile template import could accept a six-field row and then read index 6. | `Init_ProfileGear.sqf` checked `count _x >= 6` before assigning `_backpack = _x select 6`. Legit templates have seven fields, but a malformed old profile row could still trip the startup importer. | Tightened the row-shape guard to `count _x >= 7`. |
| GL-QA-03 | P2 | Hostile-gear templates could be created and saved but then dropped on the next profile import. | `Init_Client.sqf:47` defaults `WFBE_Allow_HostileGearSaving = true`; add/save honor that in `Client_UI_Gear_AddTemplate.sqf:34,74,106` and `Client_UI_Gear_SaveTemplateProfile.sqf:43-47,66-68,91-93`. `Init_ProfileGear.sqf:48-49` still rejected any weapon not in the side equipment list unconditionally. | Wrapped the import-side membership check in the same `if !(WFBE_Allow_HostileGearSaving)` policy used by add/save. |

## Verified Current Behavior

- Profile loading is type-gated before execution: `Init_ProfileVariables.sqf:47-52` reads `WFBE_PERSISTENT_<side>_GEAR_TEMPLATE` from `profileNamespace`, requires an array, then routes it through `Init_ProfileGear.sqf`.
- Profile import recalculates template upgrade and price from live item metadata before accepting a row: `Init_ProfileGear.sqf:30-44`, `70-73`, `105-112`, `128-134`.
- Template creation sanitizes unknown weapons, magazines and backpack contents before saving into the side template array: `Client_UI_Gear_AddTemplate.sqf:29-52`, `69-91`, `94-130`, `140-152`.
- Template deletion removes the row from the side template array and marks the profile dirty: `Client_UI_Gear_DeleteTemplate.sqf:9-14`.
- The gear menu only writes the profile when the dialog exits and `_need_save` is set: `GUI_BuyGearMenu.sqf:522-525`.
- Purchasing gear stores `wfbe_custom_gear` and `wfbe_custom_gear_cost` on man targets after a paid loadout update: `GUI_BuyGearMenu.sqf:438-445`.
- Respawn custom gear charges according to `WFBE_C_RESPAWN_PENALTY`, skips only when the player cannot pay a charged respawn, and applies the stored weapons/magazines/backpack tuple through `EquipUnit`: `Client_OnRespawnHandler.sqf:135-175`.
- Default respawn gear now has the GUER fallback guard: if the role-specific default is missing or empty, it falls back to `WFBE_<side>_DefaultGear` and logs a warning instead of stripping the player: `Client_OnRespawnHandler.sqf:180-214`.
- Playable GUER gear list, visible templates, template creation, and profile save all bypass the normal gear-tier economy because resistance has no real upgrade array: `Client_UI_Gear_FillList.sqf:14-19`, `Client_UI_Gear_FillTemplates.sqf:15-17`, `Client_UI_Gear_AddTemplate.sqf:135-139`, `Client_UI_Gear_SaveTemplateProfile.sqf:16-18`.
- EASA access at ordinary repair-truck service points is engineer, driver, cooldown, vehicle-class and service-point gated: `Client_CanUseRepairPointEASA.sqf:9-17`.
- Playable GUER EASA access is intentionally routed through friendly or neutral town centers because GUER is base-less: `Client_CanUseTownCenterEASA.sqf:13-28`.
- EASA purchase restores/changes loadouts with a default sentinel row, exact-funds allowed, and active setup publication: `GUI_Menu_EASA.sqf:14-17`, `73-99`, `118-126`.
- EASA equip/remove uses turret paths for `AW159_Lynx_BAF` and `Ka137_MG_PMC`, and hull paths for the rest: `EASA_Equip.sqf:26-37`, `EASA_RemoveLoadout.sqf:6-12`.
- AICOM EASA/rich-gear is separate from player EASA setup state: `Common_RunCommanderTeam.sqf:328-333` explicitly does not set `WFBE_EASA_Setup` on AI hulls, avoiding player rearm index confusion.

## Remaining Risks

| ID | Severity | Risk | Evidence | Recommended follow-up |
| --- | --- | --- | --- | --- |
| GL-QA-04 | P3 | Profile template import still drops rows with unknown item classnames silently. | `Init_ProfileGear.sqf` sets `_can_load = false` for unknown weapon, magazine or backpack content and only imports rows that remain valid. This is safer than loading broken gear but gives the player no direct UI hint. | Runtime-smoke with an intentionally stale profile template and decide whether an RPT `WARNING` should be added for dropped rows. Keep any UX work separate from PR #226. |
| GL-QA-05 | P3 | Vehicle cargo profile templates are still not supported. | `GUI_BuyGearMenu.sqf:497-501` still carries the local comment `todo later, template for veh / bp`; the template data model saved by `Client_UI_Gear_AddTemplate.sqf` covers man loadout plus backpack content, not vehicle cargo. | Treat vehicle-cargo presets as a future feature. Do not mix with save/load bugfixes unless the UI/data model is explicitly designed. |
| GL-QA-06 | P3 | Player gear and EASA purchases remain client-money-authoritative. | `GUI_BuyGearMenu.sqf:422-452` and `GUI_Menu_EASA.sqf:118-126` change client funds from client UI paths. This is existing Warfare architecture and larger than this QA lane. | Leave to a future server-authority/economy hardening lane; smoke this PR only for price/profile correctness. |

## Smoke Checklist

1. On WEST or EAST, create a gear template containing normal side gear, close/reopen the gear dialog, reconnect or restart the mission, and confirm the template survives in the template tab.
2. With `WFBE_Allow_HostileGearSaving` at its default true, create a template containing valid captured/foreign gear, reconnect, and confirm the template survives profile import.
3. Create or buy a loadout with backpack contents and vehicle cargo contents, then confirm the displayed price is not multiplied by the number of backpack/vehicle container sections.
4. Buy custom gear, respawn with enough funds, and confirm the stored `wfbe_custom_gear` is re-equipped and the configured respawn penalty is charged.
5. Respawn without enough funds for a charged custom-gear respawn and confirm the mission falls back to default gear rather than applying unpaid custom gear.
6. Join as playable GUER and confirm rifles/templates remain visible despite resistance having no normal gear-upgrade progression.
7. Use EASA at a base service point as an eligible engineer driver, then confirm the selected loadout applies once and rearm keeps the selected setup.
8. Use GUER town-center EASA in a friendly or neutral town and confirm WEST/EAST cannot use the GUER-only town-center predicate.

## Verification Notes

- Chernarus source was edited first; Takistan mirror is generated through `Tools/LoadoutManager`.
- No gear-slot tooltip UI work, AI respawn loadout guard work, service menu rewrite, live deploy, or package artifact is part of this lane.

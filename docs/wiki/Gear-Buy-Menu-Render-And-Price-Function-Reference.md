# Gear Buy-Menu Render And Price Function Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The gear buy dialog (`Rsc/Dialogs.hpp`, IDC family 503xxx) is driven by a single long-lived loop in `Client/GUI/GUI_BuyGearMenu.sqf`. That loop owns all state; the `WFBE_CL_FNC_UI_Gear_*` functions documented here are the stateless *view layer* it calls to repaint listboxes, comboboxes, the price label, and to normalize the data it feeds them. This page is the per-function contract for that view layer. It is deliberately distinct from the gear **content** catalogs (the per-faction class lists and the EASA mutation concept) — see [Gear Loadout And EASA Atlas](Gear-Loadout-And-EASA-Atlas) and [Gear Store Catalog Per Faction](Gear-Store-Catalog-Per-Faction). All eight functions are compiled at client init alongside the other gear UI helpers in `Client/Init/Init_Client.sqf:143-151`. (That block is not exactly these eight: line 146 compiles a sibling, `WFBE_CL_FNC_UI_Gear_FillTemplates`, which is not covered on this page.)

## The gear-class tuple contract

Every render function below resolves a class name to a global tuple stored in `missionNamespace`. Weapon/item classes are stored under their own name; magazine classes are stored under a `Mag_` prefix. The tuple field layout is fixed at catalog-build time and read positionally everywhere in this family:

| Index | Weapon tuple (`Config_Weapons.sqf`) | Magazine tuple (`Mag_*`, `Config_Magazines.sqf`) |
| --- | --- | --- |
| 0 | picture path (`Config_Weapons.sqf:34`) | picture path (`Config_Magazines.sqf:24`) |
| 1 | displayName (`Config_Weapons.sqf:35`) | displayName (`Config_Magazines.sqf:25`) |
| 2 | price (`Config_Weapons.sqf:36`) | price (`Config_Magazines.sqf:26`) |
| 3 | required gear upgrade level (`Config_Weapons.sqf:37`) | required gear upgrade level (`Config_Magazines.sqf:27`) |
| 4 | "belong" / slot type (`Config_Weapons.sqf:38`) | pool type (`Config_Magazines.sqf:28`) |
| 5 | inventory size span (`Config_Weapons.sqf:39`) | mag slot count = `type/_div` (`Config_Magazines.sqf:29`) |
| 6 | magazines array (`Config_Weapons.sqf:40`) | own class name (`Config_Magazines.sqf:30`) |

Slot-type (index 4) values for weapons: `0` primary, `1` pistol, `2` launcher, `4` equipment, `5` item (`Config_Weapons.sqf:21-26`). Pool-type for magazines: `101` main pool, `100` secondary/hand pool (`Config_Magazines.sqf:19-20`). These literals are the switch keys the render layer branches on below.

## Function reference

### WFBE_CL_FNC_UI_Gear_DisplayInventory

Selectively repaints the equipped-loadout picture slots (the left-hand "what the unit is wearing" panel), section by section, so the loop never has to repaint the whole panel on every click.

| Aspect | Detail |
| --- | --- |
| Params | `[_weapons, _magazines, _refresh]` (`Client_UI_Gear_DisplayInventory.sqf:11-13`) |
| Returns | nothing (side-effect: `ctrlSetText` on picture controls) |
| Refresh selector | `_refresh` is a string array; `"all"` lights every section flag, else granular `"items"`, `"magazines_main"`, `"magazines_hand"`, `"weapons"`, `"special"` each set one flag (`:21-26`) |
| Weapon section | IDCs primary 503401 / secondary 503402 / sidearm 503403; switch on tuple index 4 routes each weapon to its slot, case `3` hides the secondary slot, cases `200/201` push to secondary (`:28-46`) |
| Empty-slot fallback | unfilled weapon IDCs get placeholder paas `ui_gear_gun_gs` / `ui_gear_sec_gs` / `ui_gear_hgun_gs` (`:48-50`) |
| Special section | up to 2 slots at IDC 503533-503534 for tuple type `4` (`:53-72`) |
| Items section | up to 12 slots from base IDC 503521, tuple type `5` (`:73-90`) |
| Main magazines | up to 12 slots from base IDC 503501, tuple type `101`; a mag consumes `_size-1` extra blanked cells per its index-5 span (`:92-115`) |
| Hand magazines | up to 8 slots from base IDC 503513, tuple type `100`, same span logic (`:117-140`) |
| Magazine lookup | magazines are resolved via `Format["Mag_%1",_x]` (`:97`, `:122`) |
| Call site | `GUI_BuyGearMenu.sqf:508`, only when `_view == "gear"` |

### WFBE_CL_FNC_UI_Gear_UpdatePrice

Computes the net buy/sell cost of the pending loadout change as a single integer delta, used to drive the "Gear Cost" label. Compares an old loadout against a new one for weapons, magazines, and (non-vanilla) backpack/vehicle cargo.

| Aspect | Detail |
| --- | --- |
| Params | `[_gear, _gear_mags, _gear_bp, _gear_veh]`, each a `[old, new]` pair; deep-copied with `+` (`Client_UI_Gear_UpdatePrice.sqf:7-10`) |
| Returns | `[_price]` — a one-element array holding the signed cost (`:92`); caller reads `select 0` (`GUI_BuyGearMenu.sqf:501`) |
| Sell coefficient | refunds are scaled by `_div`; `0` when the active view is `"vehicle"` (no sell-back), otherwise `WFBE_C_PLAYERS_GEAR_SELL_COEF` (`:13`, default `0.6` at `Common/Init/Init_CommonConstants.sqf:422`) |
| View source | reads the current view from combobox 503003 via `lbData` (`:11`) |
| Diff algorithm | for weapons then magazines (`Mag_` prefix added on the second pass, `:34`): items present in both old and new are cancelled (`set [_find, false]`), removed items refund `price*_div`, surviving new items add full price (`:16-35`) |
| Cargo branch | only when `!WF_A2_Vanilla`: walks backpack and vehicle cargo as `[[mags],[counts]]` per slot, charging/refunding the per-unit count difference (`:37-90`) |
| Constant | `WFBE_C_PLAYERS_GEAR_SELL_COEF` (`Common/Init/Init_CommonConstants.sqf:422`) |
| Call sites | `GUI_BuyGearMenu.sqf:443` (total gear-cost stamp on equip — weapons+magazines+backpack with the vehicle pair passed empty; result stored as `wfbe_custom_gear_cost` at `:444`) and `:500` (full pending-change price) |

### WFBE_CL_FNC_UI_Gear_UpdateView

Rebuilds the **view** combobox (IDC 503003) — the dropdown that switches the right-hand panel between Gear, Backpack, and Vehicle. Content is conditional on what the selected target can carry.

| Aspect | Detail |
| --- | --- |
| Params | `[_backpack, _target]` (`Client_UI_Gear_UpdateView.sqf:10-11`) |
| Returns | nothing (side-effect: rebuilds combobox 503003) |
| Combobox | clears 503003, then `lbAdd`/`lbSetData` per entry (`:13`, `:26`) |
| Man target | offers "Backpack" only if `_backpack` resolves to a tuple of type `200` (`:17`), always offers "Gear", and offers "Vehicle" when non-vanilla and the unit is in a vehicle (`:18-19`) |
| Non-man target | a single "Vehicle" entry, pre-selected (`:20-23`) |
| Default selection | re-selects "gear" (or "vehicle" for non-man) by matching data string (`:14`, `:26`) |
| Call sites | `GUI_BuyGearMenu.sqf:104`, `:164`, `:326`, plus `:58` on backpack removal |

### WFBE_CL_FNC_UI_Gear_UpdateTarget

Rebuilds the **target** combobox (IDC 503004) — which friendly unit/vehicle the loadout edits apply to — gated by proximity to a barracks factory or a camp/depot, depending on the server's gear-buy mode.

| Aspect | Detail |
| --- | --- |
| Params | `_this` is the currently-selected target object (`Client_UI_Gear_UpdateTarget.sqf:6`) |
| Returns | the eligible-targets array `_temp` (`:54`); caller stores it as `_targets` (`GUI_BuyGearMenu.sqf:25`) |
| Combobox | clears 503004, repopulates with `lbAdd`, restores selection (`:8`, `:46-53`) |
| Candidate set | leader gets all live units via `WFBE_CO_FNC_GetLiveUnits`, otherwise just `[player]` (`:9`) |
| Factory gate | nearest side barracks factories via `GetFactories`; a unit qualifies if within `WFBE_C_UNITS_PURCHASE_GEAR_RANGE` (`:16`, `:24-26`) |
| Camp/depot gate | active when `WFBE_C_TOWNS_GEAR` is `1/2/3` (`:18-19`); mode 1 = closest camp, 2 = closest depot, 3 = either, via `WFBE_CL_FNC_GetClosestCamp`/`GetClosestDepot` and the player-vs-AI mobile ranges (`:27-36`) |
| Vehicle add | non-vanilla also lists nearby local vehicles within `WFBE_C_PLAYERS_GEAR_VEHICLE_RANGE` (`:40-42`) |
| Locality guard | a unit/vehicle is only added when `local` (`:37`, `:41`) |
| Labels | men labelled `[AIID] name`, vehicles by `displayName` (`:48`) |
| Constant | `WFBE_C_TOWNS_GEAR` modes 0/1/2/3 (`Common/Init/Init_CommonConstants.sqf:485`) |
| Call sites | `GUI_BuyGearMenu.sqf:25`, `:74`, `:492` |

### WFBE_CL_FNC_UI_Gear_FillList

Populates the purchasable-gear store listbox (an `lnb`/list-n-box) with one row per buyable class, applying the per-side gear upgrade-level visibility gate.

| Aspect | Detail |
| --- | --- |
| Params | `[_lb, _gear]` where `_gear` is an array of `[classNames, optionalPrefix]` groups (`Client_UI_Gear_FillList.sqf:9-11`) |
| Returns | nothing (populates `_lb`) |
| Upgrade gate | reads the side's gear upgrade tier via `(GetSideUpgrades) select WFBE_UP_GEAR` and skips any class whose tuple index 3 exceeds it (`:12`, `:21`) |
| Row content | column 0 = `$price.`, column 1 = displayName; picture set from tuple index 0; row data = the (prefixed) class name (`:22-24`) |
| Prefix | per group; the magazine group passes `"Mag_"` so lookups hit the `Mag_` namespace (`:17`, `:19`) |
| Error path | an unresolved class logs an `ERROR` naming Team_x.sqf as the fix site (`:27-28`) |
| Constant | `WFBE_UP_GEAR = 13` (`Common/Init/Init_CommonConstants.sqf:50`) |
| Call sites | `GUI_BuyGearMenu.sqf:125-129` (tab dispatch: All / Primary / Secondary / Pistols / Equipment) and `:409` (per-weapon compatible-magazine list) |

### WFBE_CL_FNC_UI_Gear_FillCargoList

Populates the cargo-style listbox (IDC 503005) used for the Backpack and Vehicle views, where rows are `[items, counts]` rather than upgrade-gated store entries.

| Aspect | Detail |
| --- | --- |
| Params | `[_lb, _gear, _clear]` (`Client_UI_Gear_FillCargoList.sqf:9-12`) |
| Returns | nothing (populates `_lb`) |
| Clear | optionally `lnbClear` first (`:14`) |
| Structure | `_gear` is grouped slots; each slot is `[items, counts]`; sub-index 1 uses the `"Mag_"` prefix (`:17-22`) |
| Row content | column 0 = `x{count}`, column 1 = displayName; picture from tuple index 0; row data = prefixed class (`:26-28`) |
| No upgrade gate | unlike FillList, this resolves and shows whatever is in cargo without checking upgrade level |
| Call sites | `GUI_BuyGearMenu.sqf:144`, `:146`, `:197`, `:199`, `:216`, `:223`, `:269`, `:287`, `:357`, `:367` (backpack/vehicle repaints) |

### WFBE_CL_FNC_UI_Gear_ParseTemplateContent

Expands a compact `[items, counts]` magazine spec into a flat per-unit list, so a saved template's "3x of mag X" becomes three discrete entries the inventory pipeline can place individually.

| Aspect | Detail |
| --- | --- |
| Params | `_this` is `[items, counts]` (`Client_UI_Gear_ParseTemplateContent.sqf:8`) |
| Returns | flat magazine array `_magazines` (`:22`); empty array when input is empty (`:18-20`) |
| Behavior | for each item, pushes it `count` times via `WFBE_CO_FNC_ArrayPush` (`:14-17`) |
| Call site | `GUI_BuyGearMenu.sqf:306` (template apply) |

### WFBE_CL_FNC_UI_Gear_Sanitize

Drops classes that have no registered gear tuple, so a stale or cross-faction loadout (e.g. from a profile saved on another side) cannot poison the render/price passes with undefined lookups.

| Aspect | Detail |
| --- | --- |
| Params | `[_content, _type]` where `_type` is `"magazines"` or `"weapons"` (`Client_UI_Gear_Sanitize.sqf:10-11`) |
| Returns | a deep-copied, filtered list `_sanitized` (`:13`, `:23`) |
| Magazines | removes any class with no `Mag_`-prefixed tuple (`:15-17`) |
| Weapons | removes any class with no root-namespace tuple (`:18-20`) |
| Call sites | `GUI_BuyGearMenu.sqf:79-80` (sanitize the target's current weapons and magazines before they enter the edit loop) |

## Loop interaction summary

The view functions are not self-triggering; they fire in response to `WFBE_MenuAction` codes the dialog controls set. Relevant bindings, all in `GUI_BuyGearMenu.sqf`: combobox 503003 `onLBSelChanged` sets action `301` → `_update_view` (`Rsc/Dialogs.hpp:663`, `GUI_BuyGearMenu.sqf:50`); combobox 503004 sets `302` → `_update_target` (`Rsc/Dialogs.hpp:668`, `GUI_BuyGearMenu.sqf:51`). On each loop iteration the dirty flags drive, in order: UpdatePrice into the Gear Cost label (`:496-503`) then DisplayInventory when the gear view is active (`:506-509`). `WF_A2_Vanilla` (set in `initJIPCompatible.sqf:95-97`) is the master branch that turns off the vehicle/backpack cargo paths in UpdatePrice, UpdateView, and UpdateTarget for plain Arma 2.

## Continue Reading

- [Gear Loadout And EASA Atlas](Gear-Loadout-And-EASA-Atlas)
- [Gear Store Price And Upgrade Catalog](Gear-Store-Price-And-Upgrade-Catalog)
- [Gear Template Profile Filter](Gear-Template-Profile-Filter)
- [Client UI Systems Atlas](Client-UI-Systems-Atlas)
- [BuyMenu EASA QoL Branch Audit](BuyMenu-EASA-QoL-Branch-Audit)

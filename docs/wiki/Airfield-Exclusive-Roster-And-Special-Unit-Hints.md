# Airfield-Exclusive Roster And Special-Unit Hints

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

When a side captures an airfield, the hangar buy menu stops showing that side's normal `WFBE_<side>AIRPORTUNITS` list and shows a **cross-faction, airfield-exclusive aircraft roster** instead. This page documents the small self-contained subsystem that drives that swap: three global lists published at boot by `Init_Common.sqf` (the tail of the post-load mutation layer, after the block that the [Assets/Config atlas](Assets-Config-Localization-And-Parameters-Atlas) stops at), and the `GUI_Menu_BuyUnits.sqf` "Airport" case that consumes them. It also covers the parallel data-driven **special-unit info popup** table (`WFBE_SPECIAL_UNIT_HINTS`) that fires a `hintSilent` when the player selects a flagged classname.

This is distinct from the standard faction hangar list (owned by [Factory and purchase systems](Factory-And-Purchase-Systems-Atlas)) and from how an airfield is captured / its hangar object spawned (owned by [Towns, camps and capture](Towns-Camps-And-Capture-Atlas)). This page owns only the roster-swap and hint mechanism.

## Boot-time globals (Init_Common.sqf)

These three globals are written near the very end of common initialization, just before `commonInitComplete = true` (`Common/Init/Init_Common.sqf:419`). They are plain `missionNamespace`-scoped globals set on **every** machine (no `setVariable [..., true]` broadcast and no server round-trip), so the buy menu can read them locally at menu-fill time. The roster block is gated on `WFBE_C_AIRFIELDS > 0` (`Init_Common.sqf:386`); the hint table is unconditional.

| Global | Built at | Shape | Notes |
| --- | --- | --- | --- |
| `WFBE_AIRFIELD_UNITS` | `Init_Common.sqf:387-401` | `[classname, ...]` | Generic cross-faction list shared by ALL captured airfields on BOTH sides. Map-forked on `IS_chernarus_map_dependent` (`Init_Common.sqf:387`). |
| `WFBE_AIRFIELD_UNITS_SPECIAL` | `Init_Common.sqf:403-405` | `[[townName, [classname, ...]], ...]` | Per-airfield extras appended only at the named airfield. Resolved by town name at menu-fill time. |
| `WFBE_SPECIAL_UNIT_HINTS` | `Init_Common.sqf:412-415` | `[[classname, stringtable-key], ...]` | Drives a selection-time info popup in the buy menu. Independent of the roster swap (applies to any unit, not just airfield ones). |

The header comment block (`Init_Common.sqf:379-385`) labels this "Task 12: Airfield-exclusive aircraft roster" and states the design intent: append a pair to `WFBE_AIRFIELD_UNITS_SPECIAL` to add a per-airfield special "no other file changes needed."

### Generic roster, map fork

The Chernarus branch (`Init_Common.sqf:387-396`) publishes a five-entry list; the Takistan branch (`Init_Common.sqf:397-400`) publishes a two-entry list:

| Map condition | `WFBE_AIRFIELD_UNITS` value | Source |
| --- | --- | --- |
| `IS_chernarus_map_dependent` true | `["An2_TK_EP1","Mi17_Ins","Mi171Sh_rockets_CZ_EP1","Su25_Ins","L159_ACR"]` | `Init_Common.sqf:394` |
| otherwise (Takistan) | `["An2_TK_EP1","Mi17_TK_EP1"]` | `Init_Common.sqf:397` |

In-source comments (`Init_Common.sqf:388-395`) record the content rulings: the L-39C was removed from the generic Chernarus list and moved to a Balota-only special; the rocket-armed Mi-171Sh was added for early-game support; and a 2026-06-12 amendment added two light jets, `Su25_Ins` (EAST) and `L159_ACR` (WEST), priced between the Mi-171Sh and the cheapest factory jet. The comments also flag that `Su25_Ins` and `L159_ACR` deliberately appear in **both** the airfield pool and a faction factory list — confirmed at `Common/Config/Core_Units/Units_CO_US.sqf:284` and `:297` for `L159_ACR`. The cross-faction listing (Takistani/Insurgent airframes available to any captor) is called out as intentional, citing "soft-faction-walls precedent."

`Mi171Sh_rockets_CZ_EP1` was explicitly relocated out of the US factory roster into this list — see the leftover marker comment at `Units_CO_US.sqf:279` ("moved to WFBE_AIRFIELD_UNITS ... buy it at any captured airfield"), which sits right after the still-listed `Mi171Sh_CZ_EP1` at `Units_CO_US.sqf:278`.

### Per-airfield specials

Only one special is defined in source (`Init_Common.sqf:403-405`):

| Town key | Appended classes | Map | Source |
| --- | --- | --- | --- |
| `Balota` | `["L39_TK_EP1"]` | Chernarus only | `Init_Common.sqf:404` |

Takistan defines no specials (empty array on that branch is implied — the whole `WFBE_AIRFIELD_UNITS_SPECIAL` assignment lives inside the `WFBE_C_AIRFIELDS > 0` block but the literal at `:403-405` is map-independent, so Takistan also gets the Balota entry; it simply never matches a Takistan town name). The comment at `Init_Common.sqf:401-402` states Takistan has "no clean equivalent for L-39C."

### Special-unit hint table

One entry is defined (`Init_Common.sqf:412-415`):

| Classname | Stringtable key | Source |
| --- | --- | --- |
| `Mi17_medevac_CDF` | `STR_WF_HINT_SalvageHeli` | `Init_Common.sqf:414` |

The key resolves at `stringtable.xml:9566`. A comment at `Init_Common.sqf:413` records that a WEST salvage heli (`UH1H_EP1`) entry was removed as an invalid class on the live box, to be re-added with a validated airframe (claude-inbox#2 item 1).

## Buy-menu consumer (GUI_Menu_BuyUnits.sqf)

### Roster swap — Airport case

The swap lives in the `case 'Airport'` branch of the menu's update-list switch (`Client/GUI/GUI_Menu_BuyUnits.sqf:329-360`). The normal path computes the nearest hangar via `WFBE_CL_FNC_GetClosestAirport`; the override triggers only when that hangar is a captured-airfield hangar.

| Step | Behaviour | Source |
| --- | --- | --- |
| Detect | Trigger only if `WFBE_C_AIRFIELDS > 0`, the closest airport is non-null, and its `wfbe_hangar` object has `wfbe_is_airfield_hangar == true`. | `GUI_Menu_BuyUnits.sqf:334` |
| Base list | `_listUnits` becomes `WFBE_AIRFIELD_UNITS`, OR `WFBE_GUERAIRPORTUNITS` when `sideJoined == resistance`. | `GUI_Menu_BuyUnits.sqf:335` |
| Resolve town | `_airfTownObj = [_closest, towns] Call WFBE_CO_FNC_GetClosestEntity`, then read its `name` variable (empty string if null). | `GUI_Menu_BuyUnits.sqf:340-341` |
| Append special | Linear-scan `WFBE_AIRFIELD_UNITS_SPECIAL` for a `(_x select 0) == _airfTownName` match; if found, `_listUnits = _listUnits + (entry select 1)`. | `GUI_Menu_BuyUnits.sqf:342-352` |
| Filter override 1 | Reset the saved faction filter to index `0` ("All") via `setVariable [Format["WFBE_%1%2CURRENTFACTIONSELECTED",sideJoinedText,_type], 0]` — otherwise the cross-faction rows are all dropped. | `GUI_Menu_BuyUnits.sqf:353,358` |
| Filter override 2 | Call `UIFillListBuyUnits` with upgrade-gate sentinel `999` instead of the real upgrade index — the capture itself is the unlock, and out-of-range is treated as "no gate." | `GUI_Menu_BuyUnits.sqf:354-357,359` |

The `wfbe_is_airfield_hangar` flag the detection reads is set server-side at capture time: `server_town.sqf:496` spawns a new hangar on the airfield logic object and tags it `["wfbe_is_airfield_hangar", true, true]` (broadcast), then records it as the logic's `wfbe_hangar` (`server_town.sqf:497`). `WFBE_C_AIRFIELDS` itself defaults to `1` (`Common/Init/Init_CommonConstants.sqf:598`). `WFBE_CO_FNC_GetClosestEntity` is compiled at `Init_Common.sqf:126` from `Common/Functions/Common_GetClosestEntity.sqf`.

The sentinel-999 pattern mirrors the unconditional GUER tab path elsewhere in the same file: the generic tab-update call at `GUI_Menu_BuyUnits.sqf:308` already passes `999` when `sideJoined == resistance` to bypass the upgrade gate (GUER has no upgrades, only funds + time-tier gating).

### GUER roster has no setter (source finding)

`WFBE_GUERAIRPORTUNITS` is **read** at `GUI_Menu_BuyUnits.sqf:335` with a default of `[]`, but a repo-wide grep finds **no `setVariable`/assignment for it anywhere in the source mission**. Practical consequence: a resistance-side captor of an airfield gets an **empty** exclusive roster (plus any town special, which is also keyed off the same `_listUnits` and so would still append). The GUER airfield roster is therefore effectively non-functional unless populated by a generated or branch file outside this checkout. This is a real gap worth flagging before assuming GUER players can buy airfield aircraft.

GUER airfield ownership is otherwise wired: `server_town.sqf:497` tags the logic with `wfbe_airfield_side`, and `Client/Functions/Client_GetClosestAirport.sqf:14` filters so a resistance player only sees a hangar whose `wfbe_airfield_side == resistance` ("C-1: GUER airfield ownership gate").

### Special-unit hint consumer

On unit selection the menu runs a chain of `hintSilent parseText` info popups (VBIED, lift-helicopter, etc.); the data-driven special-hint lookup is the last general one (`GUI_Menu_BuyUnits.sqf:623-635`):

| Step | Behaviour | Source |
| --- | --- | --- |
| Read table | `_wfbeSpecialHints = missionNamespace getVariable ["WFBE_SPECIAL_UNIT_HINTS", []]`. | `GUI_Menu_BuyUnits.sqf:626` |
| Match | Linear-scan for `(_x select 0) == _unit` (the selected classname). | `GUI_Menu_BuyUnits.sqf:628-631` |
| Show | On match, `hintSilent parseText (localize (entry select 1))`. | `GUI_Menu_BuyUnits.sqf:632-635` |

So selecting `Mi17_medevac_CDF` anywhere in the buy menu (not only at an airfield) shows the `STR_WF_HINT_SalvageHeli` popup. The hint table and the roster swap are independent subsystems that happen to be initialized adjacently.

## Extending the subsystem

| To add | Edit | Effect |
| --- | --- | --- |
| A new aircraft to all captured airfields | Append a classname to the relevant map branch of `WFBE_AIRFIELD_UNITS` (`Init_Common.sqf:394`/`:397`). | Available at every captured airfield on that map for both sides. |
| A new per-airfield exclusive | Append `[townName, [classes]]` to `WFBE_AIRFIELD_UNITS_SPECIAL` (`Init_Common.sqf:403-405`). | Town name must match the airfield's nearest-town `name`. |
| A new selection popup | Append `[classname, "STR_WF_HINT_..."]` to `WFBE_SPECIAL_UNIT_HINTS` (`Init_Common.sqf:412-415`) and add the stringtable key. | Fires the hint whenever that class is selected in the buy menu. |

No FSM, server router, or `description.ext` change is needed for any of the above — the design is deliberately one-array-edit per addition.

## Continue Reading

- [Factory And Purchase Systems Atlas](Factory-And-Purchase-Systems-Atlas) — the standard faction `WFBE_<side>AIRPORTUNITS` hangar list this roster replaces, plus `UIFillListBuyUnits` and hangar purchase range.
- [Towns Camps And Capture Atlas](Towns-Camps-And-Capture-Atlas) — how an airfield is captured and its `wfbe_is_airfield_hangar` hangar object is spawned (`server_town.sqf`).
- [Assets Config Localization And Parameters Atlas](Assets-Config-Localization-And-Parameters-Atlas) — the earlier `Init_Common.sqf` post-load mutation layer (pricing, currency, repair-truck aggregation) that precedes this block.
- [Auxiliary And Special Forces Unit Catalog](Auxiliary-And-Special-Forces-Unit-Catalog) — the individual airframes that populate the roster (e.g. the airfield-exclusive gunship).
- [Server Init Deadspawn And Airfield Probe](Server-Init-Deadspawn-And-Airfield-Probe) — airfield-logic setup at server init.

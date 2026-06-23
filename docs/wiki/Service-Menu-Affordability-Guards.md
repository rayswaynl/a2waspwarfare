# Service Menu Affordability Guards

This page is a focused implementation guide for the vehicle/person service menu debit checks. It is a local correctness patch, not a replacement for the broader server-authority redesign documented in [Server authority migration map](Server-Authority-Migration-Map).

All source paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Why This Matters

The service menu controls rearm, repair, refuel, crew heal and EASA entry. The menu displays prices and disables buttons when the current client thinks the player cannot afford an action, but the action branches do not consistently re-check price, funds and usable vehicle state before debiting money and starting the support script.

That creates a normal-client correctness bug: a stale `MenuAction`, stale price, or quickly changed funds/context can debit an unaffordable action. It also explains why this is not real anti-cheat: the whole flow remains client-side, so public-server hardening still needs a server ledger or BattlEye posture decision.

## Current Branch Matrix

Refreshed 2026-06-23. Docs/source service/EASA paths were checked through `docs/developer-wiki-index@b798fd66` and remain source-unchanged from `e9dd7f37`, `8906ee89`, `9b3fc38e` and `8b71e2a1` for the paths below. Current stable/B74.1 is `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34`; current B74.2 is `origin/claude/b74.2-aicom@21b62b04`; current B69 is `origin/claude/b69@8d465fce`; adjacent B74 is `origin/claude/b74-aicom-spend@b23f557f`. Targeted path diffs `0139a3468609..origin/master`, `origin/master..origin/claude/b74.2-aicom`, `d472da6a..21b62b04` and `origin/claude/b69..origin/claude/b74-aicom-spend` are empty for checked service/EASA menu/module/stringtable paths except the old-stable-to-current Chernarus/Vanilla `GUI_Menu_EASA.sqf` exact-funds/categorization drift. Miksuu upstream is `miksuu/master@b8389e748243`; `origin/perf/quick-wins@0076040f` is still old-shape. Current origin exposes no live `release/*` service/EASA rescue head, but it does expose two current-stable-based Trello branches that are branch-only UI/wiring evidence: `origin/claude/trello-service-ammo-count@9159f935874e` and `origin/claude/trello-easa-weapon-categories@0881911849da`.

| Root / branch | Service menu status | EASA status | Practical meaning |
| --- | --- | --- | --- |
| Current docs/source Chernarus `HEAD@e9dd7f37` | Source-unchanged from `8906ee89` / `9b3fc38e` / `8b71e2a1`: buttons still use cached prices before recalculation (`GUI_Menu_Service.sqf:126`, `:141-148`); rearm/refuel debit without action-time funds/context guards (`:198`, `:219`), while repair/heal only check positive price (`:208-209`, `:229-230`). | Purchase still uses strict `_funds > price` and client-side `ChangePlayerFunds` (`GUI_Menu_EASA.sqf:40,47-49`). | Patch-ready and source-unpatched. Fix Chernarus first if this lane becomes code work. |
| Maintained Vanilla Takistan `HEAD@e9dd7f37` | Same source shape as Chernarus for service and EASA; checked paths remain source-unchanged from `8906ee89` / `9b3fc38e` / `8b71e2a1`. | Same strict exact-funds rejection and client-side debit as Chernarus. | Must be propagated deliberately; do not call a Chernarus-only fix complete. |
| Current stable/B74.1 `origin/master@f8a76de34` / B74.2 `origin/claude/b74.2-aicom@21b62b04` | Newer controller/debit helper exists in both maintained roots (`GUI_Menu_Service.sqf:167,207`), button enable checks require positive prices and funds (`:421`, `:448-455`), and legacy action branches partially guard rearm/refuel with `_funds >= _price` (`:484`, `:507`). Repair/heal still only check positive price at the debit point (`:496-497`, `:519-520`). Current B74.2 has no checked service/EASA delta over current stable or over the older `d472da6a` B74.2 snapshot for the checked service/EASA paths. | Chernarus now allows exact-funds purchase with `_funds >= price` (`GUI_Menu_EASA.sqf:118-120`), but maintained Vanilla still rejects exact funds with `_funds > price` at the same lines. Current stable also has the guarded category call site (`GUI_Menu_EASA.sqf:34-36`) and default-on `WFBE_C_EASA_CATEGORIES` constant (Chernarus `Init_CommonConstants.sqf:821`, Vanilla `:623`) but does not compile `WFBE_EASA_FNC_LoadoutCat`. | Current stable/B74.1/B74.2 narrow stale-button and rearm/refuel behavior and fix Chernarus exact-funds EASA only. Repair/heal, action-time context and server authority remain open; Vanilla exact-funds remains open. |
| Current Miksuu upstream `master@b8389e748243` and `origin/perf/quick-wins@0076040f` | Service action branches still debit from client state: rearm/refuel debit directly and repair/heal only check positive price (`GUI_Menu_Service.sqf:326-358` in checked roots). | Exact-funds rejection remains at old EASA lines (`GUI_Menu_EASA.sqf:47-49`). | No stable-style service guard rescue exists on these refs. |
| Historical release commit `a96fdda2` | Matches the current-stable partial shape with line drift in both maintained roots: helper debits at `:157`, `:197`; rearm/refuel guard with `_funds >= _price` at `:466`, `:489`; repair/heal still only positive-price guarded at `:478`, `:501`. | Release Chernarus and Vanilla still use strict `_funds > price` for EASA (`GUI_Menu_EASA.sqf:76-78`). | Historical fixed checkpoint only; current origin exposes no live `release/*`, `feat/*service*`, `feat/*easa*` or `feat/buymenu-easa-qol` heads on 2026-06-22. |
| Historical EASA QoL commit `a66d4691` | Keeps the old direct service debit shape in both maintained roots (`GUI_Menu_Service.sqf:326-358`). | Chernarus shifts the same strict purchase/debit to `GUI_Menu_EASA.sqf:58-60`; Vanilla remains at `:47-49`. | QoL only changes Chernarus EASA orientation; it does not fix service guards, exact-funds purchase or maintained Vanilla. |
| Local/origin checkpoint `origin/claude/a2a3-execute-nullguard@d9506078` | Matches the current-stable partial service shape with line drift (`GUI_Menu_Service.sqf:476,488-489,499,511-512`). | Still uses strict `_funds > price` in both maintained roots (`GUI_Menu_EASA.sqf:118-120`). | Useful comparison checkpoint, but not Miksuu upstream evidence. |
| Current B69/B74 `origin/claude/b69@8d465fce` / `origin/claude/b74-aicom-spend@b23f557f` | B74 is unchanged from B69 for checked service/EASA paths, and B69 is unchanged from finalpieces `80d3267c`. Service matches current-stable behavior in both maintained roots (`GUI_Menu_Service.sqf:484,496-497,507,519-520`). | Chernarus keeps `_funds >= price` at `GUI_Menu_EASA.sqf:118-120`, but maintained Vanilla remains strict `_funds > price` at the same lines. | Current B69/B74 head evidence; still a Chernarus-only exact-funds candidate until Vanilla propagation and smoke exist. |
| Trello service ammo-count branch `origin/claude/trello-service-ammo-count@9159f935874e` | Current-stable-based one-commit UI branch (merge-base `f8a76de34`; two maintained-root service files, +6/-4, `git diff --check` clean). It adds vehicle ammo percentage to service-list rows (`GUI_Menu_Service.sqf:333`) and the status strip (`:474,:477`) in both roots, while preserving stable-shaped affordability lines (`:485,:497,:508,:520`). | No EASA menu/module changes. | Branch-only service UI evidence, not repair/heal affordability closure, action-time context hardening or server authority work. |
| Trello EASA category branch `origin/claude/trello-easa-weapon-categories@0881911849da` | No checked service-menu changes. | Current-stable-based one-commit wiring branch (merge-base `f8a76de34`; four maintained-root EASA module files, +116/-2, `git diff --check` clean). Stable already has the guarded menu call site (`GUI_Menu_EASA.sqf:34-36`); the branch compiles `WFBE_EASA_FNC_LoadoutCat` from `EASA_Init.sqf:2` and adds `EASA_LoadoutCat.sqf:1-57`, classifying weapon-slot rows into `[MR]`, `[AA]` or `[AG]` at `:54-56`. Chernarus exact-funds remains `>=`; Vanilla remains strict `>`. | Branch-only category-tag wiring completion. It is not an EASA exact-funds, stale-context or authority closure. |

The small local fix is still useful, but it is only a correctness patch. Full public-server hardening belongs to [Server authority migration map](Server-Authority-Migration-Map) and [Economy authority first cut](Economy-Authority-First-Cut).

## Source Flow

| Step | Source | Behavior |
| --- | --- | --- |
| Service dialog loads controller | `Rsc/Dialogs.hpp:2873` | `RscMenu_Service` runs `Client/GUI/GUI_Menu_Service.sqf`. |
| Support functions are compiled | `Client/Init/Init_Client.sqf:71-74` | Compiles `SupportHeal`, `SupportRearm`, `SupportRefuel` and `SupportRepair`. |
| Menu reads current funds | `Client/GUI/GUI_Menu_Service.sqf:126` | `_funds = Call GetPlayerFunds`. |
| Vehicle action buttons use cached prices | `GUI_Menu_Service.sqf:140-148` | Buttons require `_canBeUsed` and `_funds >= _price`, but prices are recalculated later in the same loop. |
| Prices are recalculated | `GUI_Menu_Service.sqf:155-190` | Repair, rearm and refuel prices are updated after the enable checks. |
| Rearm action | `GUI_Menu_Service.sqf:196-201` | Debits `_rearmPrice` and spawns `SupportRearm` with no action-time price/funds/context check. |
| Repair action | `GUI_Menu_Service.sqf:205-212` | Checks `_repairPrice > 0`, then debits/spawns; no action-time affordability check. |
| Refuel action | `GUI_Menu_Service.sqf:217-222` | Debits `_refuelPrice` and spawns `SupportRefuel` with no action-time price/funds/context check. |
| Heal action | `GUI_Menu_Service.sqf:226-233` | Checks `_healPrice > 0`, then debits/spawns; no action-time affordability check. |
| Support scripts re-check world context | `Client_SupportRearm.sqf:56-72`, `Client_SupportRefuel.sqf:61-77`, `Client_SupportRepair.sqf:56-72`, `Client_SupportHeal.sqf:56-76` | Timed scripts re-check support distance, vehicle alive state and airborne state before applying effects, but they do not know whether the player could afford the already-debited action. |

The person heal branch has the same stale-price shape: `GUI_Menu_Service.sqf:130-133` enables the heal button before recomputing `_healPrice`.

## Current Action Matrix (docs/source `HEAD@e9dd7f37`, service paths unchanged from `8906ee89`, `9b3fc38e` and `8b71e2a1`)

| Action | Current debit guard | Missing local guard |
| --- | --- | --- |
| Rearm | None before `-_rearmPrice Call ChangePlayerFunds`. | `_rearmPrice > 0`, fresh `_funds >= _rearmPrice`, current `_canBeUsed`, valid selection/support context. |
| Repair | `_repairPrice > 0`. | Fresh `_funds >= _repairPrice`, current `_canBeUsed`, valid selection/support context. |
| Refuel | None before `-_refuelPrice Call ChangePlayerFunds`. | `_refuelPrice > 0`, fresh `_funds >= _refuelPrice`, current `_canBeUsed`, valid selection/support context. |
| Heal | `_healPrice > 0`. | Fresh `_funds >= _healPrice`, current usable context for vehicles, valid selection/support context. |
| EASA entry | Button is enabled by service/EASA context and driver/upgrade checks, then `MenuAction == 7` opens EASA from the same loop snapshot. | Re-check current vehicle/support context before opening EASA; action-time EASA purchase/equip still belongs with the broader gear/EASA authority work. |

## Patch Shape

Keep the first patch deliberately small:

1. Recompute prices before `ctrlEnable` and before the action branches, or add a fresh action-time `_funds = Call GetPlayerFunds` and use the currently displayed price after recalculation.
2. Guard each debit/spawn branch with price, affordability and usable-context checks.
3. Apply the guard before `ChangePlayerFunds`.
4. If the action is rejected, reset `MenuAction = -1` and show a short hint; do not start the support thread.
5. Patch source Chernarus first, then propagate Vanilla with LoadoutManager from a correctly named `a2waspwarfare` checkout.

Minimal action branch pattern:

```sqf
if (MenuAction == 1) then {
	MenuAction = -1;
	_funds = Call GetPlayerFunds;
	if (_canBeUsed && _rearmPrice > 0 && _funds >= _rearmPrice) then {
		-_rearmPrice Call ChangePlayerFunds;
		[_veh,_nearSupport select _curSel,_typeRepair,_spType] Spawn SupportRearm;
	} else {
		hint "Unable to rearm: insufficient funds or invalid service state.";
	};
};
```

Use the same shape for refuel, repair and heal. For `Man` healing, `_canBeUsed` is defined in scope (assigned at line 414, before the `isKindOf "Man"` split at line 416), but it is not referenced in the Man button-enable check or the heal action branch. Include it in the Man action guard the same way as for vehicle actions.

## What Not To Claim

- Do not mark gear/EASA/service as server-authoritative after this patch.
- Do not claim a public-server exploit class is closed; clients still own service effects and money mutation.
- Do not combine this with a full server ledger migration unless that larger design is explicitly claimed.
- Do not hand-edit generated Takistan or modded folders as a substitute for LoadoutManager propagation.

## Validation

| Scenario | Expected result |
| --- | --- |
| Player has enough funds and valid service context | Rearm, repair, refuel and heal still debit once and start their support scripts. |
| Player cannot afford rearm/refuel | No debit, no support thread, short rejection feedback. |
| Player cannot afford repair/heal | No debit, no support thread, short rejection feedback. |
| Vehicle is airborne or moving too fast at action time | No debit and no support thread for vehicle actions. |
| Price is zero because the action is unnecessary | No debit and no support thread. |
| Support object moves/dies during timed work | Existing support scripts still fail the action without applying the final effect. |
| Arma smoke/RPT | No undefined-variable or out-of-range errors from the new guards. |

## Relationship To Authority Work

This page is the small local guard for DR-28's service-menu inconsistency. The larger economy authority class still lives in:

- [Server authority migration map](Server-Authority-Migration-Map)
- [Economy authority first cut](Economy-Authority-First-Cut)
- [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas)
- [Feature status register](Feature-Status-Register)

## Agent Index Facts

```json
[
  {"fact":"service_menu_stale_enable_prices","source":"GUI_Menu_Service.sqf:140-190","summary":"Service action buttons are enabled from funds and cached price variables before the loop recalculates repair/rearm/refuel prices."},
  {"fact":"service_rearm_refuel_partial_guard","source":"GUI_Menu_Service.sqf:196-222 (docs HEAD@b798fd66, source-unchanged from e9dd7f37, 8906ee89, 9b3fc38e and 8b71e2a1); GUI_Menu_Service.sqf:482-520 (origin/master@f8a76de34, origin/claude/b74.2-aicom@21b62b04, origin/claude/b69@8d465fce and origin/claude/b74-aicom-spend@b23f557f); d472da6a..21b62b04 empty for checked service/EASA paths","summary":"On docs/source HEAD@b798fd66, rearm and refuel action branches debit money and spawn support threads without price, affordability or action-time usable-state guards. On current stable/B74.1, B74.2, current B69/B74 and historical release a96fdda2, rearm/refuel guard the debit with `_funds >= _price`, but repair/heal still only check positive price and none of the four action branches adds a fresh `_canBeUsed` or action-time context recheck at the debit point."},
  {"fact":"service_support_scripts_no_funds_check","source":"Client_SupportRearm.sqf:56-72; Client_SupportRefuel.sqf:61-77; Client_SupportRepair.sqf:56-72; Client_SupportHeal.sqf:56-76","summary":"Support scripts re-check distance/alive/airborne state during timed work, but funds were already debited by the menu."},
  {"fact":"service_easa_branch_matrix_2026_06_23","source":"docs HEAD@b798fd66 GUI_Menu_Service.sqf:198,208-209,219,229-230; origin/master@f8a76de34 / origin/claude/b74.1-aicom@f8a76de34 and origin/claude/b74.2-aicom@21b62b04 GUI_Menu_Service.sqf:484,496-497,507,519-520 and GUI_Menu_EASA.sqf:34-36,118-120; d472da6a..21b62b04 empty for checked service/EASA menu/module/stringtable paths; origin/claude/trello-service-ammo-count@9159f935 GUI_Menu_Service.sqf:333,474,477,485,497,508,520; origin/claude/trello-easa-weapon-categories@08819118 EASA_Init.sqf:2 and EASA_LoadoutCat.sqf:1-57","summary":"Docs/current Miksuu/perf/QoL keep old direct service debits. Current stable/B74.1, B74.2, B69/B74 and historical release partially guard service rearm/refuel but leave repair/heal and action-time context open. Chernarus exact-funds EASA is fixed on stable-shaped refs, but maintained Vanilla remains strict `>`. The Trello service ammo branch is service UI-only; the Trello EASA category branch supplies the missing LoadoutCat helper for an already-guarded menu call site. Neither closes service/EASA authority."}
]
```

## Continue Reading

Previous: [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds) | Next: [Tools/build workflow](Tools-And-Build-Workflow)

Main map: [Home](Home) | Gear map: [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) | Authority map: [Server authority migration map](Server-Authority-Migration-Map)

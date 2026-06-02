# Service Menu Affordability Guards

This page is a focused implementation guide for the vehicle/person service menu debit checks. It is a local correctness patch, not a replacement for the broader server-authority redesign documented in [Server authority migration map](Server-Authority-Migration-Map).

All source paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Why This Matters

The service menu controls rearm, repair, refuel, crew heal and EASA entry. The menu displays prices and disables buttons when the current client thinks the player cannot afford an action, but the action branches do not consistently re-check price, funds and usable vehicle state before debiting money and starting the support script.

That creates a normal-client correctness bug: a stale `MenuAction`, stale price, or quickly changed funds/context can debit an unaffordable action. It also explains why this is not real anti-cheat: the whole flow remains client-side, so public-server hardening still needs a server ledger or BattlEye posture decision.

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

## Current Action Matrix

| Action | Current debit guard | Missing local guard |
| --- | --- | --- |
| Rearm | None before `-_rearmPrice Call ChangePlayerFunds`. | `_rearmPrice > 0`, fresh `_funds >= _rearmPrice`, current `_canBeUsed`, valid selection/support context. |
| Repair | `_repairPrice > 0`. | Fresh `_funds >= _repairPrice`, current `_canBeUsed`, valid selection/support context. |
| Refuel | None before `-_refuelPrice Call ChangePlayerFunds`. | `_refuelPrice > 0`, fresh `_funds >= _refuelPrice`, current `_canBeUsed`, valid selection/support context. |
| Heal | `_healPrice > 0`. | Fresh `_funds >= _healPrice`, current usable context for vehicles, valid selection/support context. |
| EASA entry | Button is enabled by service/EASA context and driver/upgrade checks. | If EASA flow is hardened later, patch it with the broader gear/EASA authority work rather than this small guard. |

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

Use the same shape for refuel, repair and heal. For `Man` healing, `_canBeUsed` is not defined in the current branch, so either use a separate `_canHealMan` boolean or make the action guard branch-specific.

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
  {"fact":"service_rearm_refuel_unconditional_debit","source":"GUI_Menu_Service.sqf:196-222","summary":"Rearm and refuel action branches debit money and spawn support threads without price, affordability or action-time usable-state guards."},
  {"fact":"service_support_scripts_no_funds_check","source":"Client_SupportRearm.sqf:56-72; Client_SupportRefuel.sqf:61-77; Client_SupportRepair.sqf:56-72; Client_SupportHeal.sqf:56-76","summary":"Support scripts re-check distance/alive/airborne state during timed work, but funds were already debited by the menu."}
]
```

## Continue Reading

Previous: [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds) | Next: [Tools/build workflow](Tools-And-Build-Workflow)

Main map: [Home](Home) | Gear map: [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) | Authority map: [Server authority migration map](Server-Authority-Migration-Map)

# Factory Queue Cancel and Refund Action (Action_CancelQueue)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The unit-factory build queue lets a player order more units than spawn at once; orders wait in a per-building `queu` token list until their build slot resolves. This page documents the **queue-cancel** feature layered on top of that queue: a player can cancel their own most-recently-queued unit and get a refund, either via an in-world scroll action on the factory building (`Action_CancelQueue.sqf`) or via the buy-menu's cancel button (`GUI_Menu_BuyUnits.sqf` MenuAction 501). Both paths share the same four lock-step parallel arrays (`queu`, `queu_costs`, `queu_cpts`, `queu_labels`) populated by `Client_BuildUnit.sqf`.

This corrects the stale Factory-And-Purchase-Systems-Atlas claim that "'cancel' is not a current UI operation... until an actual cancel command exists" (`Factory-And-Purchase-Systems-Atlas.md:248`). The feature exists in source.

## The parallel-array queue contract

Every queued order appends one element to **four** building variables, all written with the broadcast flag so the queue state replicates. The arrays are index-aligned: element `i` of each describes the same order.

| Variable | Element value | Written by | Citation |
|---|---|---|---|
| `queu` | Unique token `"<UID>_<diag_tickTime>"` | `Client_BuildUnit.sqf:168-173` | the order's identity (UID-prefixed) |
| `queu_costs` | `_currentCost` (price actually paid) | `Client_BuildUnit.sqf:176-178` | drives the refund amount |
| `queu_cpts` | `_cpt` (queue "count" weight of the order) | `Client_BuildUnit.sqf:179-181` | drives `unitQueu` decrement |
| `queu_labels` | Unit display label (`select QUERYUNITLABEL`) | `Client_BuildUnit.sqf:182-186` | buy-menu queue readout (Task 33) |

The token format is the keystone: `varQueu = Format["%1_%2", getPlayerUID player, diag_tickTime]` (`Client_BuildUnit.sqf:168`). Because every token **begins with the buyer's UID**, the cancel logic can find a player's own orders by prefix-matching the UID against each token. `QUERYUNITLABEL` is the constant `0` (`Common/Init/Init_CommonConstants.sqf:6`); the label is read from the unit's config-gear array via `_currentUnit select QUERYUNITLABEL` (`Client_BuildUnit.sqf:183`).

## Action_CancelQueue.sqf — the in-world cancel action

`Client/Action/Action_CancelQueue.sqf` (99 lines) is the script attached as an `addAction` on the factory building. It runs locally on the cancelling player's machine.

| Aspect | Detail | Citation |
|---|---|---|
| Params | `_this select 1` = the factory building object; `(_this select 3) select 0` = factory type string (e.g. `"Barracks"`), the action's argument array | `Action_CancelQueue.sqf:17-18` |
| Reads | `getPlayerUID player`, then the four parallel arrays off the building (defaulting to `[]`) | `Action_CancelQueue.sqf:20-24` |
| Target order | The **last** array entry whose token prefix-matches the player's UID (most recent = safest to cancel) | `Action_CancelQueue.sqf:43-47` |
| No-queue guard | If no matching index, `exitWith` with an orange hint "You have no unit in this factory's queue." | `Action_CancelQueue.sqf:49-51` |
| Refund base | `_paidCost = queu_costs select _idx` (default `0`); `_cpt = queu_cpts select _idx` (default `1`) | `Action_CancelQueue.sqf:54-55` |
| Refund cap | Attack-wave defensive ceiling (see below) | `Action_CancelQueue.sqf:57-63` |
| Array removal | Removes index `_idx` from all four arrays, re-broadcasts each | `Action_CancelQueue.sqf:65-80` |
| Counter decrement | `unitQueu -= _cpt` (floored at 0); `WFBE_C_QUEUE_<factory> -= 1` (floored at 0) | `Action_CancelQueue.sqf:82-88` |
| Refund payout | `if (_refund > 0) then {(_refund) Call ChangePlayerFunds}` | `Action_CancelQueue.sqf:90-91` |
| Feedback | Green "Queue cancelled." hint with refunded amount, plus a "(capped...)" note if `_paidCost != _refund` | `Action_CancelQueue.sqf:93-98` |

### The A2-safe UID-prefix matcher

The function's distinguishing feature is the hand-rolled prefix test `_uidPrefix` (`Action_CancelQueue.sqf:29-41`). It converts both the token and the UID with `toArray` and compares leading byte-codes:

```
_tokA = toArray (_this select 0);   // token bytes
_uidA = toArray (_this select 1);   // UID bytes
_ok = (_ul > 0) && (_ul <= count _tokA);
if (_ok) then { for "_j" from 0 to (_ul - 1) do {
    if ((_tokA select _j) != (_uidA select _j)) exitWith {_ok = false};
}};
```

The header comment records *why* (`Action_CancelQueue.sqf:26-28`): `string find string` is Arma-3-only and threw `"find: Type String, expected Array"` on A2 OA — it fired every time a player cancelled a queue item. The `toArray` byte comparison is the same A2-safe idiom used in the buy-menu cancel block (`GUI_Menu_BuyUnits.sqf:220-232`). **A2 note:** `toArray` and capitalized `Private` are valid A2 OA; do not "modernize" this to `find` or `isEqualTo`.

### Index-based array removal (not value removal)

The token array is removed by value because tokens are unique: `_queu = _queu - [_queu select _idx]` (`Action_CancelQueue.sqf:66`). But `queu_costs`/`queu_cpts`/`queu_labels` can hold **duplicate** values (two identical units cost the same), so they are removed by **index** with an explicit rebuild loop that skips only `_idx` (`Action_CancelQueue.sqf:67-76`). The comment at `:65` calls this out: "costs/cpts may share values, must use index." Conflating these would desync the parallel arrays.

## The attack-wave refund cap

Normally the refund equals the price paid (`_refund = _paidCost`, `Action_CancelQueue.sqf:58`). A defensive ceiling applies only during an active attack-wave discount:

| Element | Value / behavior | Citation |
|---|---|---|
| Trigger | `ATTACK_WAVE_PRICE_MODIFIER < 1.0 && UNIT_COST_MODIFIER > 0` | `Action_CancelQueue.sqf:59` |
| Base price recovery | `_basePrice = _paidCost / (ATTACK_WAVE_PRICE_MODIFIER * UNIT_COST_MODIFIER)` | `Action_CancelQueue.sqf:60` |
| Cap | `_maxRefund = round (_basePrice * 0.5)`; clamp `_refund` to it | `Action_CancelQueue.sqf:61-62` |
| `ATTACK_WAVE_PRICE_MODIFIER` default | `1` (no discount; cap inert) | `Common/Init/Init_CommonConstants.sqf:367` |
| `UNIT_COST_MODIFIER` default | `1`; becomes `0.75`/`0.5` per cost-reduction upgrade | `Common/Init/Init_CommonConstants.sqf:373`; `Client/Functions/Client_UIFillListBuyUnits.sqf:11,14` |

`ATTACK_WAVE_PRICE_MODIFIER` is set by the attack-wave system (`Server/Functions/Server_AttackWave.sqf:19,34`) and applied to client price displays (`Client_UIFillListBuyUnits.sqf:90`, `GUI_Menu_BuyUnits.sqf:99,416`). The header comment (`Action_CancelQueue.sqf:6-12`) states the cap is a **DEFENSIVE CEILING that does not trigger in standard config**: the refund never exceeds the amount paid, so no arbitrage exists at normal modifier values; it is kept against future config edge cases.

## Client_BuildUnit.sqf — wiring, sync, and the cancelled-mid-build guard

`Client_BuildUnit.sqf` (`BuildUnit`, compiled at `Client/Init/Init_Client.sqf:71`) is the per-order worker that the buy menu spawns. Its params are `[_building, _unit, _vehi, _factory, _cpt, _currentCost]` (`Client_BuildUnit.sqf:2-7`); `_currentCost` defaults to `0` if absent. The buy menu supplies all six and debits at order time: `_params Spawn BuildUnit; -(_currentCost) Call ChangePlayerFunds` (`GUI_Menu_BuyUnits.sqf:163-165`).

| Stage | What it does | Citation |
|---|---|---|
| Enqueue | Builds the token, appends to `queu` + the three cost/cpt/label arrays; adds `unitQueu += _cpt` | `Client_BuildUnit.sqf:11,168-186` |
| Add cancel action | `addAction ["Cancel last queued unit", "Client\Action\Action_CancelQueue.sqf", [_factory], 50, false, true, "", "cursorObject == _target && player distance _target < 25"]`; the action id is stored as `wfbe_cancel_action_<UID>` | `Client_BuildUnit.sqf:187-199` |
| Normal-completion sync | On actual spawn, finds `_qIdx = _queu find _unique` and removes that index from `queu_costs/cpts/labels` to keep them aligned | `Client_BuildUnit.sqf:232-259` |
| Remove cancel action | Removes the per-player `wfbe_cancel_action_<UID>` action once the slot resolves | `Client_BuildUnit.sqf:260-267` |
| Cancelled-mid-build guard (E1) | If `_qIdx < 0` (the token is gone — `Action_CancelQueue` already removed it, decremented counters, and refunded), `exitWith {}` **without spawning** so the player can't keep both the refund and the unit | `Client_BuildUnit.sqf:269-273` |
| Destroyed-factory refund (FC2) | Distinct path: if the building dies mid-build, decrement counters and `if (_currentCost > 0) then {(_currentCost) Call ChangePlayerFunds}` | `Client_BuildUnit.sqf:276-281` |

The cancel-action condition `cursorObject == _target && player distance _target < 25` means the buyer must be looking at the factory within 25 m. The action is scoped per-player via the `wfbe_cancel_action_<UID>` key (`Client_BuildUnit.sqf:199,262`), so each buyer only ever removes their own action handle.

The **E1 guard is the safety hinge**: because `Action_CancelQueue` already balanced `unitQueu` and `WFBE_C_QUEUE_<factory>` and issued the refund, the worker must bail without re-touching those counters or spawning (`Client_BuildUnit.sqf:269-273`). Missing this would double-decrement or hand out a free unit.

## GUI_Menu_BuyUnits.sqf — the in-dialog cancel (MenuAction 501)

The buy menu has a second, equivalent cancel path bound to MenuAction `501` (`GUI_Menu_BuyUnits.sqf:213-272`, "Task 33"). It operates on `_closest` (the currently selected factory building) and mirrors `Action_CancelQueue` line-for-line: the same `toArray` UID-prefix matcher (`:220-232`), the same four parallel-array reads (`:233-236`), last-owned-index pick (`:238-239`), no-queue guard (`:240`), attack-wave cap (`:243-248`), index removal + rebroadcast (`:249-257`), `unitQueu`/`WFBE_C_QUEUE_<type>` decrement (`:258-263`), and `ChangePlayerFunds` refund with the same hint (`:264-272`). It is the menu-button equivalent of the in-world scroll action; both produce the identical "Queue cancelled." green hint.

## Counters and the refund sink

| Symbol | Role | Citation |
|---|---|---|
| `unitQueu` | Global running count of queued order weight; both cancel paths subtract `_cpt` (floored at 0) | `Action_CancelQueue.sqf:83-84`; `GUI_Menu_BuyUnits.sqf:259` |
| `WFBE_C_QUEUE_<factory>` | Per-factory-type queued count; incremented at buy (`GUI_Menu_BuyUnits.sqf:154-155`), decremented by 1 on cancel (floored at 0) | `Action_CancelQueue.sqf:85-88`; `GUI_Menu_BuyUnits.sqf:260-263` |
| `ChangePlayerFunds` | The refund/debit sink; compiled from `Client_ChangePlayerFunds.sqf`, which forwards to `ChangeTeamFunds` for `clientTeam`. Positive arg credits, negative debits | `Client/Init/Init_Client.sqf:72`; `Client/Functions/Client_ChangePlayerFunds.sqf:1` |

The cap on `WFBE_C_QUEUE_<factory>` enforcement happens at buy time (`< WFBE_C_QUEUE_<type>_MAX`, `GUI_Menu_BuyUnits.sqf:154`); cancel only ever decrements it, never below 0.

## Continue Reading

- [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) — buy/abort/destroyed-factory flow (note: its "no cancel command exists" claim is superseded by this page)
- [Factory-Queue-Counter-Token-Cleanup](Factory-Queue-Counter-Token-Cleanup) — the `unitQueu`/`WFBE_C_QUEUE_*` token-counter lifecycle this cancel path decrements
- [Attack-Wave-Authority-Playbook](Attack-Wave-Authority-Playbook) — how `ATTACK_WAVE_PRICE_MODIFIER` is set, which drives the refund cap
- [BuyMenu-EASA-QoL-Branch-Audit](BuyMenu-EASA-QoL-Branch-Audit) — the QoL buy-menu branch where the cancel button and parallel arrays were introduced
- [Side-Team-State-Function-Reference](Side-Team-State-Function-Reference) — `ChangePlayerFunds`/`ChangeTeamFunds`, the refund sink

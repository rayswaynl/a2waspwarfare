# Client Funds & Income HUD Readout

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The player's on-screen money line is rendered twice, by two independent loops, from the same three client-local accessors. This page documents the **render side** of the client economy: the thin funds accessors (`Client_GetPlayerFunds` / `Client_ChangePlayerFunds`), the per-income-system display split (`Client_GetIncome`), and the two surfaces that consume them — the legacy in-game-map info line written by `updateavailableactions.fsm` (engine map display 12, control IDC 116) and the newer right-side RHUD money panel written by `Client_UpdateRHUD.sqf` (RscTitles `OptionsAvailable`, IDC 1353). Economy *authority* (who is allowed to debit, the income-system-4 balance bug) is owned by the economy pages and is only cross-referenced here.

## Client funds accessors

Both accessors are one-liners that delegate to the shared team-funds family keyed on the client's own group. `clientTeam` is set once at `Client/Init/Init_Client.sqf:258` to `group player`.

| Function | Source | Body (verbatim) | Behavior |
|---|---|---|---|
| `GetPlayerFunds` | `Client/Functions/Client_GetPlayerFunds.sqf:1` | `(clientTeam) Call GetTeamFunds` | Reads `wfbe_funds` off the player's group via `Common_GetTeamFunds.sqf`; returns 0 if the group is null or the var is nil (`Common/Functions/Common_GetTeamFunds.sqf:3,6`). |
| `ChangePlayerFunds` | `Client/Functions/Client_ChangePlayerFunds.sqf:1` | `[clientTeam, _this] Call ChangeTeamFunds;` | Adds `_this` to the group's `wfbe_funds` and re-broadcasts it (`Common/Functions/Common_ChangeTeamFunds.sqf:8` writes with the `true` networked flag). |

### Dual aliasing — same files, two names

`Init_Client.sqf` compiles each of these source files **twice**, under both a bare legacy name and a `WFBE_CL_FNC_*` name. There is no separate `Client_GetClientFunds.sqf` / `Client_ChangeClientFunds.sqf` file — the `*ClientFunds` aliases point back at the `*PlayerFunds` sources.

| Alias | Compiled from | Init_Client line |
|---|---|---|
| `ChangePlayerFunds` | `Client\Functions\Client_ChangePlayerFunds.sqf` | `Client/Init/Init_Client.sqf:72` |
| `GetPlayerFunds` | `Client\Functions\Client_GetPlayerFunds.sqf` | `Client/Init/Init_Client.sqf:76` |
| `WFBE_CL_FNC_ChangeClientFunds` | `Client\Functions\Client_ChangePlayerFunds.sqf` | `Client/Init/Init_Client.sqf:110` |
| `WFBE_CL_FNC_GetClientFunds` | `Client\Functions\Client_GetPlayerFunds.sqf` | `Client/Init/Init_Client.sqf:118` |

Because `ChangeTeamFunds` broadcasts (`true` flag), a client `ChangePlayerFunds` write is **not** a local-only optimistic debit at the variable level — it sets the shared group var globally. The balance-authority concerns around this live in the economy pages, not here.

## Client income split — `Client_GetIncome`

`Client/Functions/Client_GetIncome.sqf` computes the **per-player display income** the readout shows after `Income:`. It takes the side (`_this`) and reads the gross town income, then applies the active income system. `_side` is the parameter; `GetTownsIncome` is the gross basis (`Client/Functions/Client_GetIncome.sqf:3,5`).

| Param / read | Where | Notes |
|---|---|---|
| `_side` = `_this` | `:3` | Caller passes `sideJoined` in both render surfaces. |
| `_income` = `_side Call GetTownsIncome` | `:5` | Gross town income (compiled `Common/Init/Init_Common.sqf:65`). |
| `_incomeSystem` = `WFBE_C_ECONOMY_INCOME_SYSTEM` | `:4` | Selects the branch. |

Income-system branches (`switch (_incomeSystem)`, `:7`):

| System | Source lines | Display formula |
|---|---|---|
| 2 | `:8` | `round(_income / 2)` — flat halving, no commander split. |
| 3 | `:9-19` | `_ply = round(_income * ((100 - wfbe_commander_percent)/100) / WFBE_Client_Teams_Count)`; if this group **is** the commander team, add `round(_income * (wfbe_commander_percent/100) / WFBE_C_ECONOMY_INCOME_DIVIDED)` on top of `_ply`; otherwise just `_ply`. |
| 4 | `:20-29` | `_ply = round(_income * (100 - wfbe_commander_percent)/100)`; if commander team, `_ply + round((_income - _ply) * WFBE_Client_Teams_Count)`; otherwise `_ply`. |
| (default) | — | No case → `_income` returned unchanged (`:33`). |

`_commanderTeam` is resolved via `WFBE_CO_FNC_GetCommanderTeam` and compared against `group player` (`:11,14` and `:22,25`). `WFBE_Client_Teams_Count` and `WFBE_Client_Logic` are client globals set at `Client/Init/Init_Client.sqf:315,310`.

> **Income-system-4 display-vs-payout mismatch.** The server pays system 4 with a `* 1.5` multiplier (`Server/FSM/updateresources.sqf:56-57`), but the client `Client_GetIncome` case 4 has **no** `1.5` factor (`:23-28`). So the `Income:` number a player sees under system 4 understates the funds the server actually credits each tick. This is a known balance/display defect; the fix is owned by the economy authority pages, not this readout page.

## Surface 1 — legacy map info line (display 12, IDC 116)

`Client/FSM/updateavailableactions.fsm` rebuilds a single text line and writes it to the **engine's** in-game map info control whenever the map is visible. The control is `findDisplay 12 displayCtrl 116` — display 12 is the stock A2/OA map display and IDC 116 is its built-in resource title text (not a mission-defined HPP control).

Assembly block (`Client/FSM/updateavailableactions.fsm:145-149`), only entered inside `if (visibleMap)`:

| FSM line | Builds | Detail |
|---|---|---|
| `:145` | Commander name | `format [localize 'STR_WF_Commander', name (leader commanderTeam)]`, or `STR_WF_Commander` + `STR_WF_AI` when no commander. `STR_WF_Commander` = `"Commander: %1"`, `STR_WF_AI` = `"No Commander"` (`stringtable.xml:4651,4644`). |
| `:146` | Funds + income | `Format [localize "STR_WF_Income", Call GetPlayerFunds, (sideJoined) Call GetIncome]`. `STR_WF_Income` = `"Income: $%1 ($%2/Min)"` (`stringtable.xml:4239`) — `%1` is current funds, `%2` is the per-min income from `GetIncome`. |
| `:147` | Commander-% suffix | Only when `_is in [3,4]` (`_is` = `WFBE_C_ECONOMY_INCOME_SYSTEM`, set `:40`): appends `" (%1%)"` with `WFBE_Client_Logic getVariable "wfbe_commander_percent"`. |
| `:148` | Supply suffix | Only when `_currency_system == 0` (`_currency_system` = `WFBE_C_ECONOMY_CURRENCY_SYSTEM`, set `:43`): appends `STR_WF_UPGRADE_Supply` + `: ` + `str((sideJoined) Call GetSideSupply)`. |
| `:149` | Commit | `(findDisplay 12 displayCtrl 116) ctrlSetText _txt;` |

Note the supply suffix on this surface is gated on `currency_system == 0`; the RHUD surface below shows supply unconditionally.

## Surface 2 — RHUD money panel (RscTitles `OptionsAvailable`)

`Client/Client_UpdateRHUD.sqf` drives the right-side heads-up panel defined as RscTitles class `OptionsAvailable` (idd 10200) in `Rsc/Titles.hpp:169`. The script never calls `displayCtrl` with literal IDCs; instead it builds a `_controls` array by walking the fixed IDC list `_rhudIDC = [1345,1346,…,1371]` (`Client/Client_UpdateRHUD.sqf:26`), and the `_RHUDSetText`/`_RHUDSetColor` helpers index into that array (`:68-85`). **Index N therefore maps to IDC `1345 + N`.**

The label/value pairing is `[[1,2],[3,4],[5,6],[7,8],[9,10],[11,12],[13,14],…]` (`Client/Client_UpdateRHUD.sqf:242`); odd indices hold the static label set once per show (`Client/Client_UpdateRHUD.sqf:309-315`), even indices hold the live value.

> **IDC-vs-class-name caveat.** The Marty RHUD reuses the original RscText classes out of order, so the HPP class *name* does not match what the slot now shows. The money **value** lands on index 8 → IDC **1353**, whose HPP class is literally named `RUBHUD_AICOUNT_Value` (`Rsc/Titles.hpp:269`). Trust the index→IDC math, not the class name.

| Field | RHUD index → IDC | Built at | Text format |
|---|---|---|---|
| Money + income | `[8]` → 1353 (`RUBHUD_AICOUNT_Value`, `Rsc/Titles.hpp:269`) | `Client/Client_UpdateRHUD.sqf:403-405` | `Format ["%1 $ | %2", Call GetPlayerFunds, _incomeText]`, color `[0,0.825294,0.449803,1]` |
| Income (folded into money text) | — | `:379` | `_incomeText = Format ["+ %1 $", sideJoined Call GetIncome]` |
| Supply | `[10]` → 1355 (`RUBHUD_Money_Value`, `Rsc/Titles.hpp:291`) | `:380,406-407` | `_supplyText = Format ["%1", (sideJoined) Call GetSideSupply]`, color `[1,0.8831,0,1]` |

The income value is **not** written to its own control — it is concatenated into the money slot's text (`:403`), so the `RUBHUD_Income*` IDCs (1356/1357) carry only their static label and are otherwise unused on this surface. The town/economy aggregates (`_incomeText`, `_supplyText`) are refreshed at most every 3s (`if (time - _lastTownRefresh > 3)`, `:378-401`) because they walk the towns array, while the money slot itself is rewritten every panel pass from the already-cached `_incomeText`.

Both surfaces ultimately read the same `GetPlayerFunds` / `GetIncome` pair; they differ only in formatting, refresh cadence, and which control they write. The RHUD lifecycle (display-handle acquisition, `currentCutDisplay`, label-apply-once gating) is owned by the UI atlas page.

## Continue Reading

- [Town-Economy-Getter-Reference](Town-Economy-Getter-Reference) — `GetTownsIncome` / `GetSideSupply` gross-income and supply basis these readouts consume.
- [Side-Team-State-Function-Reference](Side-Team-State-Function-Reference) — `GetTeamFunds` / `ChangeTeamFunds` writer contracts behind the client accessors.
- [Economy-Authority-First-Cut](Economy-Authority-First-Cut) — funds authority and the income-system-4 balance defect this page only cross-references.
- [Client-UI-Systems-Atlas](Client-UI-Systems-Atlas) — RHUD display-handle / `currentCutDisplay` lifecycle owning `Client_UpdateRHUD`'s render plumbing.
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — supply-cap and town-supply correctness debts adjacent to the supply suffix.

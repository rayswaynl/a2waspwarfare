# AI Commander Treasury Fund Accessors

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`ChangeAICommanderFunds` and `GetAICommanderFunds` are the read/write pair for the AI commander's private money pool, `wfbe_aicom_funds`. They are the AI-side mirror of the player team's `ChangeTeamFunds`/`GetTeamFunds` pair, with one load-bearing difference: the AI write is **server-local** (no broadcast flag), so the value never reaches clients. This page documents the accessor contract, the storage object, the locality gotcha, and the full producer/consumer catalog.

Both functions are compiled in `Server\Init\Init_Server.sqf:29` (`ChangeAICommanderFunds`) and `:34` (`GetAICommanderFunds`), so they exist on the server only — there is no client alias. The treasury variable is seeded once per side at side-logic init in `Server\Init\Init_Server.sqf:443`.

## The accessor pair

| Function | File:line | Signature | Behavior |
|---|---|---|---|
| `GetAICommanderFunds` | `Server\Functions\Server_GetAICommanderFunds.sqf:1` | `_side` -> Number | `(_this Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_aicom_funds"`. Resolves the side's logic object, reads the funds variable off it. No nil-guard — see the gotcha below. |
| `ChangeAICommanderFunds` | `Server\Functions\Server_ChangeAICommanderFunds.sqf:1-5` | `[_side, _amount]` -> (none) | Resolves `_logik = _side Call WFBE_CO_FNC_GetSideLogic`, then `_logik setVariable ["wfbe_aicom_funds", (_side Call GetAICommanderFunds) + _amount]`. Read-current-plus-amount write; `_amount` may be negative (debits) or positive (credits). |

The mutator declares its locals capitalized (`Private ["_amount","_logik","_side"]`, `Server_ChangeAICommanderFunds.sqf:1`), the A2-valid form. It composes the two getter-style reads (`GetAICommanderFunds` inside the write) rather than caching, so each `ChangeAICommanderFunds` call performs two `GetSideLogic` resolutions.

### Storage object: the side logic

The funds live on the side's logic object (`WFBE_L_BLU` / `WFBE_L_OPF` / `WFBE_L_GUE`), resolved through `WFBE_CO_FNC_GetSideLogic` (`Common\Functions\Common_GetSideLogic.sqf`). That resolver returns `objNull` when the requested side's logic global is undefined (its A2 OA nil-guard against the resistance-logic RPT flood). The side logic holds `wfbe_aicom_funds`, the AI-only slot. This is a **different** storage object from the player-team funds: `wfbe_funds` is always written on the team/group object, never on the side logic (`Common_ChangeTeamFunds.sqf:8` `_team setVariable`, `Init_Server.sqf:553`/`:596` `_group setVariable`, `Server_OnPlayerConnected.sqf:83`/`:103` `_team setVariable`, `AI_Commander_Teams.sqf:350` `_g setVariable`). See `Side-Team-State-Function-Reference` for that player-funds counterpart.

## Locality contract (the key gotcha)

| Aspect | Player funds (`ChangeTeamFunds`) | AI funds (`ChangeAICommanderFunds`) |
|---|---|---|
| Storage | `wfbe_funds` on the team group | `wfbe_aicom_funds` on the side logic |
| Write | `setVariable [..., +amount, true]` — **broadcast** (`Common\Functions\Common_ChangeTeamFunds.sqf:8`) | `setVariable [..., +amount]` — **no flag, server-local** (`Server\Functions\Server_ChangeAICommanderFunds.sqf:5`) |
| Visibility | replicated to clients (drives the funds HUD) | server-only; clients never see it |

Because the AI write omits the broadcast `true` flag, the treasury is pure server-side state. No client (and therefore no HUD readout) ever observes `wfbe_aicom_funds`; the only public surface for the AI's wealth is the diagnostic `AICOMSTAT` RPT lines that print it (`AI_Commander.sqf:455`, `:457`). This is correct by design — the AI commander has no UI — but it means the value cannot be inspected live except through the RPT.

A second gotcha: `GetAICommanderFunds` has no nil-guard. If `GetSideLogic` returns `objNull` (logic not placed) or the side was never seeded, `getVariable "wfbe_aicom_funds"` yields `nil`, not `0`. Callers that arithmetic-compare the result (e.g. `_funds < _price`) rely on the seed at `Init_Server.sqf:443` having run for the side. Only **EAST and WEST** are seeded with `wfbe_aicom_funds`: the seed loop iterates `[[_present_east, east, _startE],[_present_west, west, _startW]]` (`Init_Server.sqf:582`), so GUER never gets an AI-commander treasury. Resistance runs a separate player-team stipend instead (`Server_GuerStipend.sqf`, spawned at `Init_Server.sqf:612`), which writes `wfbe_funds` on the player groups — not `wfbe_aicom_funds`. There are exactly two `wfbe_aicom_funds` writes in the whole source (the mutator at `Server_ChangeAICommanderFunds.sqf:5` and the seed at `Init_Server.sqf:443`), and neither touches resistance. Consequently `GetAICommanderFunds` called for resistance returns `nil`, and `ChangeAICommanderFunds` for resistance — e.g. the heli fly-off refund at `HandleSpecial.sqf:341`, which whitelists `resistance` in `[east,west,resistance]` — would evaluate `nil + _amount` and throw. That is a latent risk, not the safe "all three sides have a numeric balance" an earlier draft asserted.

## Producers (credits, positive `_amount`)

| Producer | File:line | Amount | Note |
|---|---|---|---|
| Income tick (under cap) | `Server\FSM\updateresources.sqf:82` | `round(_income * _pcMult)` | Per-interval treasury credit; only when the side has no human commander (`isNull GetCommanderTeam`) and `_commander_enabled`. Gated by `_supply < _supply_max_limit`. |
| Income stipend (under cap) | `Server\FSM\updateresources.sqf:90` | `WFBE_C_AI_COMMANDER_INCOME_STIPEND` (default 25) | Synthetic per-tick money drip so PvE on a near-empty server keeps the AI fielding armies. Never synthesizes supply. |
| Funds-famine credit | `Server\FSM\updateresources.sqf:106` | `round(_income * _pcMult)` | TOWN-STALL fix: keeps funds flowing when `_supply >= _supply_max_limit` (the supply-cap gate would otherwise starve the AI's wallet to \$0 and stall the war). |
| Funds-famine stipend | `Server\FSM\updateresources.sqf:108` | `WFBE_C_AI_COMMANDER_INCOME_STIPEND` (25) | Stipend half of the famine branch. |
| Bootstrap stipend | `Server\AI\Commander\AI_Commander.sqf:228` | `round(_stipendFunds * (_tickS/60))` | Once-per-60s bootstrap grant scaled by elapsed time (`WFBE_C_AICOM_BOOTSTRAP_FUNDS`, default 100), capped at 3x. The supervisor-loop owner is `AI-Commander-Execution-Loop-Reference`. |
| Heli fly-off refund | `Server\Functions\Server_HandleSpecial.sqf:341` | `_rCost` | Refunds a commander team's empty AIR transport build cost when it flew off-map alive and was reaped. Validates `_rSide in [east,west,resistance]` and `_rCost > 0`. Documented in `Server-HandleSpecial-Request-Router-Reference`. |
| Wildcard salvage / bonus | `Server\Functions\AI_Commander_Wildcard.sqf:530`, `:823`, `:1003` | `_bonus` / `_wkTotal` / `5000` | W-series wildcard payouts (losing-side catch-up bonus, salvage payback, flat grant). |
| Kill bounty (W12 Spoils) | `Server\PVFunctions\RequestOnUnitKilled.sqf:239` | `_bounty` | Double-bounty into the AI war chest while the W12 "Spoils of War" flag is active for that side. |
| AICOM donate | `Server\PVFunctions\RequestAIComDonate.sqf:76` | `_amount` | Player-initiated donation into the AI commander treasury (read-back logged at `:73`/`:78`). |

## Consumers (debits, negative `_amount`)

| Consumer | File:line | Amount | What it buys |
|---|---|---|---|
| Team founding | `Server\AI\Commander\AI_Commander_Teams.sqf:311` | `-_price` | Founds a new commander team (skipped under the W11 free-refound flag at `:286-290`). Funds gate checked at `:292`. |
| Upgrade purchase | `Server\Functions\Server_AI_Com_Upgrade.sqf:125` | `-(_cost select 1)` | Research/upgrade unlock. `_cost select 1` is the funds price (TR12 fix — was `select 0`, the supply price). |
| Upgrade funds-surcharge | `Server\Functions\Server_AI_Com_Upgrade.sqf:132` | `-_fundsSurcharge` | Task-6 fallback: pays a dry side's supply price as a funds surcharge instead of spending shared supply. |
| Base defense build | `Server\AI\Commander\AI_Commander_Base.sqf:453`, `:499` | `-_defPrice` | Stationary-defense construction debits. |
| Unit production | `Server\AI\Commander\AI_Commander_Produce.sqf:161` | `-_priceCharged` | Per-unit factory production charge. |

Read-only consumers (affordability checks via `GetAICommanderFunds`, no write) include `AI_Commander.sqf:172`/`:264`, `AI_Commander_Teams.sqf:61`/`:280`, `AI_Commander_Base.sqf:451`/`:497`, `AI_Commander_Produce.sqf:153`, `AI_Commander_Wildcard.sqf:320`/`:529`, and `Server_AI_Com_Upgrade.sqf:42`.

## Seeding

At side-logic init the treasury is set to a flat start balance: `_logik setVariable ["wfbe_aicom_funds", (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_START_FUNDS", 200000])]` (`Server\Init\Init_Server.sqf:443`). The B36 hotfix comment records this as a flat 200k (formerly `FUNDS_START x FUNDS_MULT`). The surrounding V0.4.1 note codifies the design rule the whole producer set obeys: synthetic **money** is acceptable for PvE pacing, synthetic **supply** is not. Supply spending stays 100% real; only the funds pool is topped up artificially (stipend, bootstrap, famine branch).

## Continue Reading

- [Side Team State Function Reference](Side-Team-State-Function-Reference) — the player-funds counterpart (`ChangeTeamFunds`/`GetTeamFunds`) and the side-logic seed list.
- [AI Commander Execution Loop Reference](AI-Commander-Execution-Loop-Reference) — the supervisor loop that owns the bootstrap stipend and the spend side.
- [Commander Team Driver Reference](Commander-Team-Driver-Reference) — the heli fly-off reaping that triggers the refund credit.
- [AI Commander Tunable Constants Reference](AI-Commander-Tunable-Constants-Reference) — values for `INCOME_STIPEND`, `START_FUNDS`, `BOOTSTRAP_FUNDS`, and the income multiplier.
- [Town Economy Getter Reference](Town-Economy-Getter-Reference) — the town-supply basis the income tick reads.

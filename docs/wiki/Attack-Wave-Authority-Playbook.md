# Attack Wave Authority Playbook

Implementation playbook for Claude DR-41: `ATTACK_WAVE_INIT` is a forgeable direct publicVariable channel that can make side-wide unit prices free or negative.

Scope: `Missions/[55-2hc]warfarev2_073v48co.chernarus`. Apply gameplay patches there first, then propagate generated missions with `Tools/LoadoutManager`.

## Status

| Field | Value |
| --- | --- |
| Finding | Confirmed high-risk authority bug |
| Finding id | DR-41 |
| Backlog id | `attack-wave-authority` |
| Primary files | `Common/Functions/Common_AttackWaveActivate.sqf`, `Server/Functions/Server_AttackWave.sqf`, `Server/PVFunctions/AttackWave.sqf` |
| Risk | Forged client `_supply` / `_side` can apply a side-wide `ATTACK_WAVE_PRICE_MODIFIER` of `0` or negative. |
| Patch type | Server-authoritative direct-PV handler rewrite |

## Source Chain

| File | Evidence |
| --- | --- |
| `Client/FSM/updateclient.sqf:240` | Adds the `HEAVY ATTACK MODE` action on the side HQ. The action condition is client-side only: `((sideJoined) Call GetSideSupply) >= 25000` and nearby cursor target. |
| `Common/Functions/Common_AttackWaveActivate.sqf:3-8` | Reads `_supply` and `_side` from action arguments, assigns `ATTACK_WAVE_INIT = [_supply, _side]`, then broadcasts `publicVariableServer "ATTACK_WAVE_INIT"`. |
| `Server/Functions/Server_AttackWave.sqf:1-15` | Direct PVEH receives `ATTACK_WAVE_INIT`, trusts payload `_supply` / `_side`, and computes `_discountPercentage` from client `_supply`. |
| `Server/Functions/Server_AttackWave.sqf:19-27` | Writes global `ATTACK_WAVE_PRICE_MODIFIER`, publishes `ATTACK_WAVE_DETAILS`, then sleeps for the computed attack-wave length. |
| `Server/PVFunctions/AttackWave.sqf:19-60` | Handles `ATTACK_WAVE_DETAILS`, stores per-side active/modifier state, spends side supply, sends client `HandleSpecial` / `LocalizeMessage`, then resets state when length reaches `0`. |
| `Client/GUI/GUI_Menu_BuyUnits.sqf:90,261` | Multiplies unit cost by `ATTACK_WAVE_PRICE_MODIFIER`. |
| `Client/Functions/Client_UIFillListBuyUnits.sqf:60` | Displays buy-list price using `ATTACK_WAVE_PRICE_MODIFIER`. |
| `Common/Init/Init_CommonConstants.sqf:166,197-199` | Sets `WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT = 50000`, default `ATTACK_WAVE_PRICE_MODIFIER = 1`, and active flags false. |
| `BattlEyeFilter/publicvariable.txt` | Does not include `ATTACK_WAVE_INIT`; the repo filter only carries the AFK feature rule. |

## Failure Condition

The unsafe path exists when all of these are true:

| Condition | Source-backed reason |
| --- | --- |
| A client can broadcast `ATTACK_WAVE_INIT` | The channel is a direct publicVariable, not a registered PVF command. |
| Payload contains forged `_supply` | `Server_AttackWave.sqf:5` uses `_this select 1 select 0` directly. |
| Payload contains forged `_side` | `Server_AttackWave.sqf:6` uses `_this select 1 select 1` directly. |
| Client-side gate is bypassed | The `GetSideSupply >= 25000` check is only the addAction condition in `updateclient.sqf:240`. |
| Modifier math accepts impossible supply | Formula is `0.7 * (0.4 + ((50000 - _supply) * (1 / 50000)))`. At `_supply = 70000`, modifier becomes `0`; larger values become negative. |
| Buy menus consume the modifier | Unit purchase UI multiplies costs by `ATTACK_WAVE_PRICE_MODIFIER`, so a forged side modifier affects all buyers for that side. |

This is not fixed by PVF dispatcher hardening. `ATTACK_WAVE_INIT` bypasses `WFBE_PVF_*` command dispatch entirely.

## Current Behavior To Preserve Deliberately

The intended spend model is not a fixed 25,000 supply cost in current source.

| Behavior | Source |
| --- | --- |
| 25,000 supply is only the minimum action gate. | `updateclient.sqf:240` |
| The discount is based on the side supply value sent into the wave. | `Server_AttackWave.sqf:15-17` |
| The side spends all current side supply when the wave starts. | `AttackWave.sqf:40`, `[_side, -(_side call GetSideSupply), ...] Call ChangeSideSupply` |

Default patch stance: preserve this model server-side. Server should re-derive current side supply, require at least `25000`, compute the modifier from that real value, then spend the same real value or explicitly document any owner-approved change to fixed-cost attack waves.

## Safe Patch Shape

Preferred shape:

1. Keep `Common_AttackWaveActivate.sqf` as a request sender, but stop sending economic truth. Payload should include requester context if useful, not `_supply`.
2. In `Server_AttackWave.sqf`, treat the payload as untrusted request data.
3. Server derives `_side` from the requester when possible, or validates the requested side against server-known player/group state.
4. Server computes `_supply = _side Call GetSideSupply`.
5. Reject if `_supply < 25000`.
6. Reject if an attack wave is already active for that side.
7. Compute the modifier from server `_supply`.
8. Clamp modifier and duration even after server recomputation.
9. Publish `ATTACK_WAVE_DETAILS` only after acceptance.
10. Ensure side-supply debit is based on server-derived `_supply` and happens once.

Pseudo-SQF outline:

```sqf
"ATTACK_WAVE_INIT" addPublicVariableEventHandler {
	private ["_request", "_requester", "_side", "_supply", "_modifier", "_length"];

	_request = _this select 1;
	_requester = if (count _request > 0) then {_request select 0} else {objNull};

	// Arma 2 OA PVEH does not provide a clean sender identity. Treat requester as a hint and validate it.
	if (isNull _requester || !isPlayer _requester) exitWith {
		["WARNING", "Server_AttackWave.sqf: rejected attack wave request with invalid requester."] Call WFBE_CO_FNC_LogContent;
	};

	_side = side _requester;
	if (!(_side in [west, east])) exitWith {};

	if ((_side == west && ATTACK_WAVE_ACTIVE_WEST) || (_side == east && ATTACK_WAVE_ACTIVE_EAST)) exitWith {
		["WARNING", Format ["Server_AttackWave.sqf: rejected duplicate attack wave request for [%1].", _side]] Call WFBE_CO_FNC_LogContent;
	};

	_supply = _side Call GetSideSupply;
	if (_supply < 25000) exitWith {
		["WARNING", Format ["Server_AttackWave.sqf: rejected attack wave for [%1], supply [%2] below threshold.", _side, _supply]] Call WFBE_CO_FNC_LogContent;
	};

	_modifier = 0.7 * (0.4 + ((WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT - _supply) * (1 / 50000)));
	_modifier = (_modifier max 0.28) min 0.98;
	_length = ((1 - _modifier) * 1500) max 0;

	ATTACK_WAVE_DETAILS = [_side, _modifier, _length, _supply];
	publicVariableServer "ATTACK_WAVE_DETAILS";
};
```

The exact requester validation may need adjustment after a live Arma 2 OA smoke test. Because PVEH does not give a trustworthy sender identity, this patch is stronger than the current source but still benefits from BattlEye defense-in-depth on public servers.

## Debit And Idempotency

`AttackWave.sqf` currently recomputes `(_side call GetSideSupply)` when debiting. After the authority patch, prefer one of these explicit choices:

| Option | Shape | Tradeoff |
| --- | --- | --- |
| Preserve all-supply spend | Add server-derived `_supplyToSpend` to `ATTACK_WAVE_DETAILS` and debit exactly that once. | Best preserves current design while avoiding a race between modifier compute and debit. |
| Recompute on debit | Keep `[_side, -(_side call GetSideSupply)] Call ChangeSideSupply`. | Simpler but can desync the displayed modifier from the amount spent if supply changes between init and details handling. |
| Fixed cost | Debit `25000` or a named constant. | Design change; update UI text, roadmap, docs and validation expectations. |

Whichever option is chosen, add an active-side guard before accepting a new wave. Duplicate `ATTACK_WAVE_INIT` events should not stack multiple sleeps, multiple debits or overlapping price modifiers.

## Edge Cases To Check

| Edge case | Expected result |
| --- | --- |
| Legit side with supply >= 25000 | Attack wave starts, side supply is debited once, clients receive attack-wave modifier and message. |
| Side supply below 25000 | Request rejected with compact warning; no modifier, no debit. |
| Forged `_supply = 70000` | Ignored; server uses real supply and cannot produce a zero/negative modifier. |
| Forged `_side = enemy side` | Rejected or re-derived from requester; cannot start wave for the other side. |
| Duplicate requests while active | Rejected; no duplicate debit and no overlapping reset thread. |
| JIP during active wave | `CLIENT_INIT_READY` path still informs player for their side with current modifier. |
| Wave end | Modifier resets to `1`, side active flag false, clients receive end message. |
| Hosted/listen server | No busy-loop or locality regression; server-side PVEH path still runs. |

## Validation

| Gate | Check |
| --- | --- |
| Static source check | `Server_AttackWave.sqf` no longer uses client `_supply` for modifier math and no longer trusts client `_side` without validation/re-derivation. |
| Static direct-PV check | `ATTACK_WAVE_INIT` remains documented as a direct channel outside PVF, or the channel is explicitly migrated to a registered PVF with matching docs. |
| Dedicated smoke | Valid west/east attack waves work, debit supply once and reset prices after the wave. |
| Forgery smoke | Forged `_supply >= 70000` and wrong-side payloads cannot set `ATTACK_WAVE_PRICE_MODIFIER` to `0`, negative, or the wrong side. |
| JIP smoke | Late joiner during active wave receives correct modifier/message through `CLIENT_INIT_READY`; late joiner after end sees normal price. |
| RPT | Rejections log useful `WARNING`s without hot-loop spam; no undefined variables or scheduler errors. |
| Generated missions | Run `dotnet run` from `Tools/LoadoutManager` in a correctly named `a2waspwarfare` checkout; missing `7za` is packaging-only unless deployment packaging is required. |
| Test evidence | Record planned or actual evidence with [`agent-test-plan.schema.json`](agent-test-plan.schema.json). |

## Implementation Notes For Agents

- Use Bohemia Interactive Arma 2 OA scripting semantics; do not assume Arma 3 remote execution or owner-sender APIs.
- Use `-LiteralPath` in PowerShell when reading or editing `[55-2hc]` paths.
- Keep gameplay changes in the Chernarus source mission first.
- Treat `BattlEyeFilter/publicvariable.txt` as defense in depth, not mission authority.
- Do not call the PVF dispatcher fix sufficient for this channel; direct PVEHs need their own validation.
- Keep logs compact and outside hot loops.

## Related Pages

- [Networking and public variables](Networking-And-Public-Variables)
- [Hardening implementation roadmap](Hardening-Implementation-Roadmap)
- [Server authority migration map](Server-Authority-Migration-Map)
- [Economy, towns and supply](Economy-Towns-And-Supply)
- [Deep-review findings](Deep-Review-Findings)
- [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)

## Continue Reading

Previous: [Server authority migration map](Server-Authority-Migration-Map) | Next: [Testing workflow](Testing-Debugging-And-Release-Workflow)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

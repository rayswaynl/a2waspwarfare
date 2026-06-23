# Attack Wave Authority Playbook

Implementation playbook for Claude DR-41: `ATTACK_WAVE_INIT` is a forgeable direct publicVariable channel that can make side-wide unit prices free or negative.

Scope: current source `Missions/[55-2hc]warfarev2_073v48co.chernarus` plus maintained Vanilla `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`. Apply gameplay patches in Chernarus first, then propagate maintained Vanilla and generated missions with `Tools/LoadoutManager`.

## Status

| Field | Value |
| --- | --- |
| Finding | Confirmed high-risk authority bug |
| Finding id | DR-41 |
| Backlog id | `attack-wave-authority` |
| Primary files | `Common/Functions/Common_AttackWaveActivate.sqf`, `Server/Functions/Server_AttackWave.sqf`, `Server/PVFunctions/AttackWave.sqf` |
| Risk | Forged client `_supply` / `_side` can apply a side-wide `ATTACK_WAVE_PRICE_MODIFIER` of `0` or negative; forged `ATTACK_WAVE_DETAILS` can bypass the init calculation and directly mutate active wave state. |
| Patch type | Server-authoritative direct-PV handler rewrite |

## Source Chain

| File | Evidence |
| --- | --- |
| `Client/FSM/updateclient.sqf:240` | Adds the `HEAVY ATTACK MODE` action on the side HQ. The action condition is client-side only: `((sideJoined) Call GetSideSupply) >= 25000` and nearby cursor target. |
| `Common/Functions/Common_AttackWaveActivate.sqf:3-8` | Reads `_supply` and `_side` from action arguments, assigns `ATTACK_WAVE_INIT = [_supply, _side]`, then broadcasts `publicVariableServer "ATTACK_WAVE_INIT"`. |
| `Server/Functions/Server_AttackWave.sqf:1-15` | Direct PVEH receives `ATTACK_WAVE_INIT`, trusts payload `_supply` / `_side`, and computes `_discountPercentage` from client `_supply`. |
| `Server/Functions/Server_AttackWave.sqf:19-27` | Writes global `ATTACK_WAVE_PRICE_MODIFIER`, publishes `ATTACK_WAVE_DETAILS`, then sleeps for the computed attack-wave length. |
| `Server/PVFunctions/AttackWave.sqf:19-62` | Handles `ATTACK_WAVE_DETAILS`, trusts `_side`, `_priceModifier` and `_attackLength`, stores per-side active/modifier state, spends side supply, sends client `HandleSpecial` / `LocalizeMessage`, then resets state when length reaches `0`. |
| `Client/GUI/GUI_Menu_BuyUnits.sqf:90,261` | Multiplies unit cost by `ATTACK_WAVE_PRICE_MODIFIER`. |
| `Client/Functions/Client_UIFillListBuyUnits.sqf:60` | Displays buy-list price using `ATTACK_WAVE_PRICE_MODIFIER`. |
| `Common/Init/Init_CommonConstants.sqf:166,197-199` | Sets `WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT = 50000`, default `ATTACK_WAVE_PRICE_MODIFIER = 1`, and active flags false. |
| `BattlEyeFilter/publicvariable.txt` | Does not include `ATTACK_WAVE_INIT`; the repo filter only carries the AFK feature rule. |

## Branch / Root Matrix

Checked on 2026-06-23 after `git fetch --all --prune`. No checked branch or maintained root fixes the direct-PV authority issue. Docs/source `HEAD@6d263dc21093` is unchanged from `1c1ea55970dc` and the older `f3e157f2` line-anchor proof for checked Chernarus/Vanilla attack-wave request/detail/client-price paths. Current origin exposes no live `release/*`, attack-wave or support rescue heads on 2026-06-23, so `a96fdda2`, `c20ce153` and `994150da` remain historical evidence. Adjacent `origin/claude/b74-aicom-spend@b23f557fc912` changes only Chernarus constants among checked attack-wave paths and is not an authority rescue.

| Ref | Chernarus source | Maintained Vanilla | Result |
| --- | --- | --- | --- |
| Docs/source `HEAD@6d263dc21093` | `updateclient.sqf:240` gates the action client-side; `Common_AttackWaveActivate.sqf:6,8` sends `ATTACK_WAVE_INIT`; `Server_AttackWave.sqf:5-6,15,23,27,36,38` trusts payload `_supply` / `_side` and publishes details; `AttackWave.sqf:19,23-25,40` trusts detail payload and debits side supply; buy-price consumers are `Client_UIFillListBuyUnits.sqf:60` and `GUI_Menu_BuyUnits.sqf:90,261`; constants are at `Init_CommonConstants.sqf:166,197-199`. | Same maintained-root line shape. | Patch-ready, current-docs-source-unpatched. |
| Current stable `origin/master` `0139a3468609` | Same trust shape with line drift: action `updateclient.sqf:260`, buy-price display `Client_UIFillListBuyUnits.sqf:90`, purchase costs `GUI_Menu_BuyUnits.sqf:99,416`, constants `Init_CommonConstants.sqf:323,367-369`; request/detail lines stay `Common_AttackWaveActivate.sqf:6,8`, `Server_AttackWave.sqf:5-6,15,23,27,36,38` and `AttackWave.sqf:19,23-25,40`. | Same maintained-root line shape. | Patch-ready, current-stable-unpatched. |
| Current B69 `origin/claude/b69` `8d465fcede7f` | Same trust shape as current stable for the request/detail/client paths. Chernarus constants drift to `Init_CommonConstants.sqf:515,559-561`; B69 path deltas `0a1ccb4d..8d465fce` and `b8530477..8d465fce` are empty for checked attack-wave request/detail/client-price paths. | Same request/detail/client-price shape; Vanilla constants drift to `Init_CommonConstants.sqf:349,393-395`. | B69 does not rescue this lane; only unrelated constants/AICOM movement causes line drift. |
| Adjacent B74 AICOM spend `origin/claude/b74-aicom-spend` `b23f557fc912` | Same request/detail/client trust shape as B69. `origin/claude/b69..origin/claude/b74-aicom-spend` touches only `Common/Init/Init_CommonConstants.sqf` among checked Chernarus attack-wave paths; constants drift to `:528,572-574`. | Same request/detail/client-price shape as B69; constants stay at `Init_CommonConstants.sqf:349,393-395`. | No attack-wave authority rescue; adjacent AICOM-spend constants drift only. |
| Miksuu upstream `miksuu/master` `b8389e74` | Same trust shape; action line `updateclient.sqf:260`; constants at `Init_CommonConstants.sqf:166,197-199`. | Same maintained-root shape. | No upstream rescue in current Miksuu head. |
| `origin/perf/quick-wins` `0076040f` | Same trust shape; action line `updateclient.sqf:223`; constants at `Init_CommonConstants.sqf:166,197-199`. | Same maintained-root shape. | Perf branch side-supply/factory fixes do not touch attack-wave authority. |
| Historical AI-commander commit `c20ce153` (current origin exposes no `feat/ai-commander` head on 2026-06-22) | Same trust shape; action line `updateclient.sqf:223`; Chernarus constants drift to `Init_CommonConstants.sqf:174,205-207`. | Same maintained-root attack-wave shape; Vanilla constants remain `:166,197-199`. | Treat as branch-scoped historical AI-commander evidence, not a live head. |
| Historical release commit `a96fdda2` (current origin exposes no `release/*` heads on 2026-06-22) | Same trust shape; action line `updateclient.sqf:260`; constants at `Init_CommonConstants.sqf:166,210-212`. | Same maintained-root shape. | Branch-scoped historical release evidence; no live release head rescues this lane. |
| Historical Miksuu `upstream/AttackWave` commit `994150da` | Same trust shape; action line `updateclient.sqf:203`; constants at `Init_CommonConstants.sqf:145,174-176`. | Same maintained-root shape. | Treat as inherited feature debt, not a fix branch. |

Fixed-string grep also found no `ATTACK_WAVE` entry in `BattlEyeFilter/publicvariable.txt` for the checked refs. Treat this as still patch-ready current-source debt, not a propagated fix.

## Failure Condition

The unsafe path exists when all of these are true:

| Condition | Source-backed reason |
| --- | --- |
| A client can broadcast `ATTACK_WAVE_INIT` | The channel is a direct publicVariable, not a registered PVF command. |
| Payload contains forged `_supply` | `Server_AttackWave.sqf:5` uses `_this select 1 select 0` directly. |
| Payload contains forged `_side` | `Server_AttackWave.sqf:6` uses `_this select 1 select 1` directly. |
| Client-side gate is bypassed | The `GetSideSupply >= 25000` check is only the addAction condition in `updateclient.sqf:260` on current stable. |
| Modifier math accepts impossible supply | Formula is `0.7 * (0.4 + ((50000 - _supply) * (1 / 50000)))`. At `_supply = 70000`, modifier becomes `0`; larger values become negative. |
| Buy menus consume the modifier | Unit purchase UI multiplies costs by `ATTACK_WAVE_PRICE_MODIFIER`, so a forged side modifier affects all buyers for that side. |

This is not fixed by PVF dispatcher hardening. `ATTACK_WAVE_INIT` bypasses `WFBE_PVF_*` command dispatch entirely.

Wave R direct-PV review also confirmed that `ATTACK_WAVE_DETAILS` should not be treated as a safe server-internal detail. The intended sender is `Server_AttackWave.sqf`, but the event handler accepts the direct PV payload and uses it to set active state, pricing and duration. A public-server hardening patch therefore needs either a BattlEye rule that prevents clients from sending this channel or a handler-side acceptance guard that proves the detail was generated by the accepted server request path.

## Current Behavior To Preserve Deliberately

The intended spend model is not a fixed 25,000 supply cost in current source.

| Behavior | Source |
| --- | --- |
| 25,000 supply is only the minimum action gate. | `updateclient.sqf:260` |
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
10. Ensure the `ATTACK_WAVE_DETAILS` handler accepts only server-derived detail state, not arbitrary client detail payloads.
11. Ensure side-supply debit is based on server-derived `_supply` and happens once.

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
| Forged `ATTACK_WAVE_DETAILS` | Rejected or ignored; cannot set price modifier, active flag, wave length or side-supply debit directly. |
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

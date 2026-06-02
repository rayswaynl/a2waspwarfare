# Headless Delegation And Failover Playbook

This is the implementation guide for hardening headless-client AI delegation. It ties together DR-21 and DR-42 so future code owners can patch HC behavior without confusing three different delegation models.

## Scope

Use this page before editing:

| Area | Source files |
| --- | --- |
| HC bootstrap | `Headless/Init/Init_HC.sqf`, `initJIPCompatible.sqf` |
| Server HC registry | `Server/Functions/Server_HandleSpecial.sqf`, `Server/Functions/Server_OnPlayerDisconnected.sqf` |
| Town AI HC delegation | `Server/Functions/Server_DelegateAITownHeadless.sqf`, `Client/Functions/Client_DelegateTownAI.sqf`, `Server/FSM/server_town_ai.sqf` |
| Static-defense HC delegation | `Server/Functions/Server_DelegateAIStaticDefenceHeadless.sqf`, `Client/Functions/Client_DelegateAIStaticDefence.sqf`, `Server/Functions/Server_OperateTownDefensesUnits.sqf`, `Server/Functions/Server_HandleDefense.sqf` |
| Client-FPS delegation mode | `Server/Functions/Server_FNC_Delegation.sqf`, `Client/FSM/updateavailableactions.fsm`, `Server/Functions/Server_OnPlayerConnected.sqf` |

## Current Behavior

`WFBE_C_AI_DELEGATION` has three meanings:

| Value | Meaning | Notes |
| --- | --- | --- |
| `0` | No delegation. | Server creates AI. |
| `1` | Client-FPS delegation. | Players report FPS; server picks player clients as delegators. |
| `2` | Headless-client delegation. | HC creates delegated units locally after server sends `HandleSpecial` messages. |

`initJIPCompatible.sqf:164-171` downgrades HC mode to disabled when the OA build does not support headless clients. `Headless/Init/Init_HC.sqf:11-15` waits 20 seconds, then sends `["RequestSpecial", ["connected-hc", player]]` to the server.

The server registers a connected HC in `Server_HandleSpecial.sqf:117-131` by storing:

- `WFBE_HEADLESS_<uid>` = `group _hc`
- `WFBE_HEADLESSCLIENTS_ID` += `[group _hc]`

On HC disconnect, `Server_OnPlayerDisconnected.sqf:22-29` removes that group from `WFBE_HEADLESSCLIENTS_ID` and clears `WFBE_HEADLESS_<uid>`. It does not reclaim, re-track, or re-delegate units that were already created by the HC.

## Delegation Paths

### Town AI Through HC

When town AI wakes in HC mode, `server_town_ai.sqf:164-170` checks whether `WFBE_HEADLESSCLIENTS_ID` is non-empty. If an HC exists, the server calls `Server_DelegateAITownHeadless.sqf`; otherwise it falls back to server-side `CreateTownUnits`.

`Server_DelegateAITownHeadless.sqf:22-30` picks random HC groups and sends `['delegate-townai', ...]` to the HC leader. The HC/client receiver is `Client_DelegateTownAI.sqf`:

- creates town units locally at `:26`;
- records created vehicles in `_town_vehicles` at `:27`;
- sends `["RequestSpecial", ["update-town-delegation", _town, _town_vehicles]]` back to the server at `:35`.

The server handles that update in `Server_HandleSpecial.sqf:86-96`: it appends vehicles to `wfbe_active_vehicles`, starts empty-vehicle cleanup, and marks taxi prohibition. This is the most complete HC path, but still lacks disconnect failover.

### Static Defense Through HC

Static-defense delegation is triggered from two server paths:

| Caller | Source behavior |
| --- | --- |
| `Server_OperateTownDefensesUnits.sqf:41-57` | Town defense spawn delegates gunners to HC when HC mode is enabled and a HC candidate exists. |
| `Server_HandleDefense.sqf:19-24` | Base/structure defense remanning delegates a replacement gunner to HC when candidates exist. |

`Server_DelegateAIStaticDefenceHeadless.sqf:21-27` sends `['delegate-ai-static-defence', ...]` to an HC leader. The receiver `Client_DelegateAIStaticDefence.sqf:25-28` creates units locally, but the intended server update-back is commented:

```sqf
//["RequestSpecial", ["update-delegation-static_defence", _teams]] Call WFBE_CO_FNC_SendToServer;
```

Unlike town AI, static-defense HC creation does not tell the server what was created. DR-42 confirms the server has no current record of HC-created static-defense units for cleanup, accounting, or re-delegation.

### Client-FPS Delegation Mode

Client delegation mode (`WFBE_C_AI_DELEGATION == 1`) is separate from HC mode. `Server_FNC_Delegation.sqf` selects player clients using `WFBE_AI_DELEGATION_<uid>` data:

- `Server_OnPlayerConnected.sqf:68-71` initializes `[fps, groups, sessionId]`.
- `Client/FSM/updateavailableactions.fsm` periodically sends client FPS.
- `Server_FNC_Delegation.sqf:139-178` selects delegators by FPS and group count.
- `Server_FNC_Delegation.sqf:104-115` tracks delegated groups until null, then decrements the delegator count if the session ID still matches.

Do not copy this player-client session-counting model directly into HC mode without adapting it; HC mode currently stores HC groups, not per-HC delegated work records.

## Risks

| Risk | Evidence | Impact |
| --- | --- | --- |
| HC disconnect has no mission-level re-delegation. | `Server_OnPlayerDisconnected.sqf:22-29` only removes the HC from the candidate pool. | Already-created HC-local groups may fall back to engine locality behavior, but the mission does not redistribute them to another HC. |
| Static-defense HC units are untracked server-side. | `Client_DelegateAIStaticDefence.sqf:28` comments out update-back; `Server_HandleSpecial.sqf` has `update-town-delegation` but no `update-delegation-static_defence` case. | Cleanup/accounting/re-delegation cannot reason about HC-created static-defense units. |
| Late HC join does not automatically re-enable mode. | `initJIPCompatible.sqf:164-171` can downgrade unsupported HC mode once; the server initializes `WFBE_HEADLESSCLIENTS_ID` only when mode is `2`. | If HC mode was disabled or no candidate was present during spawn decisions, later HC presence does not retroactively move existing AI. |
| Static-defense removal may miss original operators. | `Server_OperateTownDefensesUnits.sqf:62-69` stores `wfbe_defense_operator` only for server-created gunners; HC-created static gunners do not pass through that assignment. | Removal path deletes current gunner when it is not a player/funded group, but the original-operator bookkeeping differs between server and HC paths. |

## Patch Shape

### Phase 1: Make Static Defense Update-Back Explicit

Choose one of two designs:

| Option | Implementation |
| --- | --- |
| Restore tracking | Re-enable a `RequestSpecial` update from `Client_DelegateAIStaticDefence.sqf` and add a server `update-delegation-static_defence` case. Store enough data to clean/reassign units later: defense object, created team/group, created units, side, and whether `moveInGunner` was used. |
| Declare fire-and-forget | Leave the one-way behavior, but remove or annotate the commented send-back and document that static HC units are only locally lifecycle-managed by the HC. |

Prefer restore tracking if the mission will support public dedicated servers with HCs.

### Phase 2: Add HC Work Records

For each delegated HC batch, create a server-side record keyed by HC UID or group:

| Field | Why |
| --- | --- |
| owner HC UID/group | Remove work record on disconnect. |
| work type | Town AI, static defense, player-client delegation, future AI work. |
| town/defense object | Recreate or clean context. |
| groups/vehicles/units known to server | Cleanup and re-delegation candidates. |
| timestamp/session id | Ignore stale update-backs after reconnect. |

Town AI already returns vehicles via `update-town-delegation`; static defense needs an equivalent. Unit/group records may be incomplete if only vehicle lists are stored.

### Phase 3: Disconnect Policy

When `Server_OnPlayerDisconnected.sqf` detects a HC:

1. Remove the HC from `WFBE_HEADLESSCLIENTS_ID` as it does now.
2. Look up work records for that HC.
3. For each record, choose one policy:
   - re-delegate to another active HC;
   - recreate on server;
   - mark for normal town/static cleanup;
   - intentionally leave engine-local units alone but log the state.
4. Clear stale records.

Do not blindly delete all HC-created units on disconnect; town combat and static defenses can be active while players are nearby.

### Phase 4: Late-HC Behavior

If a HC joins after server init:

- keep current behavior for new wake/spawn decisions;
- optionally add a safe rebalance action later, but do not move active combat groups without a separate design;
- log HC registration and candidate count so testers can see whether the server is actually using the HC.

## Validation

| Scenario | Expected result |
| --- | --- |
| HC joins before town activation. | `WFBE_HEADLESSCLIENTS_ID` gains the HC group; town AI delegates to HC; town vehicles still enter `wfbe_active_vehicles`. |
| No HC available when town activates. | `server_town_ai.sqf` uses server-side fallback and records vehicles normally. |
| Static defense delegates to HC. | Either server receives explicit static-defense update-back, or docs/logs clearly mark it fire-and-forget. |
| HC disconnects during active town AI. | HC is removed from candidate pool; work records are cleaned/reassigned/logged according to the chosen policy. |
| HC disconnects during static defense. | Static-defense work record does not remain stale; gunner cleanup/remanning still works. |
| Late HC joins. | New delegation can use the HC; existing AI is not silently rebalanced unless a specific rebalance feature is implemented. |

## Implementation Notes

- Arma 2 OA does not need an Arma 3-style `setGroupOwner` plan here; this mission's HC model is remote creation on the HC/client, not server-created group ownership transfer.
- Keep server fallback behavior for no-HC cases. It is the safety net that prevents empty towns/defenses when HC is unavailable.
- Add `WF_Debug` or concise always-on logs around HC registration, delegation count, update-back receipt, and disconnect policy decisions.
- If this patch touches generated target missions, edit Chernarus first and run LoadoutManager propagation from a checkout whose ancestor folder is named `a2waspwarfare`.

## Agent Index Facts

```json
{
  "page": "Headless-Delegation-And-Failover-Playbook",
  "status": "implementation_playbook",
  "drFindings": ["DR-21", "DR-42"],
  "primaryRisk": "HC-created work is not fully tracked for disconnect/redelegation; static-defense HC update-back is commented out.",
  "codeOwners": ["future-ai-owner", "future-performance-owner"]
}
```

## Continue Reading

Previous: [AI/headless and performance](AI-Headless-And-Performance) | Next: [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

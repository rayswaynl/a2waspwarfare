# Headless Delegation And Failover Playbook

This is the implementation guide for hardening headless-client AI delegation. It ties together DR-21 and DR-42 so future code owners can patch HC behavior without confusing three different delegation models.

Page ownership: use [AI, headless and performance](AI-Headless-And-Performance) for runtime orientation and source routing, [Lifecycle wait-chain](Lifecycle-Wait-Chain) for HC boot timing, and [HC upstream history and lessons](HC-Upstream-History-And-Lessons) for older branch/comment-message evidence. This playbook owns the DR-21/DR-42 implementation decisions: update-back policy, work records, disconnect handling, failover and late-HC behavior.

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

Docs source downgrades HC mode to disabled at `initJIPCompatible.sqf:168-170` when the OA build does not support headless clients. Its `Headless/Init/Init_HC.sqf` remains simple-shaped: `:12` waits 20 seconds and `:15` sends `["RequestSpecial", ["connected-hc", player]]`. Current stable/B74.1 and current B74.2 line-drift the HC-support gate to `initJIPCompatible.sqf:206-207` and use the newer HC bootstrap: `Headless/Init/Init_HC.sqf:14` waits 20 seconds, `:28` waits for the player object, `:35-101` runs bounded reseat/deadspawn setup, a persistent 15-second watcher can reannounce at `:122`, and initial setup sends `connected-hc` at `:129`.

The docs-source server registers a connected HC in `Server_HandleSpecial.sqf:117-128`. Current stable line-drifts and hardens that case at `Server_HandleSpecial.sqf:406-431` by storing:

- `WFBE_HEADLESS_<uid>` = `group _hc`
- `WFBE_HEADLESSCLIENTS_ID` = pruned live candidates plus `[group _hc]`

Registration edge: current stable still only appends when `owner _hc` is not `0` (`Server_HandleSpecial.sqf:415-431`). If the owner id is `0`, the server logs a warning at `:432-434`; the HC-side persistent watcher may re-announce after reseat, but no server-side delayed registration queue is visible. In HC mode, a missed registration means later town-AI HC selection sees no HC groups and falls back to server-side creation (`server_town_ai.sqf:242-254` on current stable).

On HC disconnect, `Server_OnPlayerDisconnected.sqf:22-29` removes that group from `WFBE_HEADLESSCLIENTS_ID` and clears `WFBE_HEADLESS_<uid>`. It does not reclaim, re-track, or re-delegate units that were already created by the HC.

## Delegation Paths

### Town AI Through HC

When town AI wakes in HC mode, current stable `server_town_ai.sqf:242-248` checks whether `WFBE_HEADLESSCLIENTS_ID` is non-empty. If an HC exists, the server calls `Server_DelegateAITownHeadless.sqf`; otherwise it falls back to server-side `CreateTownUnits` at `:252-258`.

`Server_DelegateAITownHeadless.sqf:22-56` calls `WFBE_CO_FNC_PickLeastLoadedHC` once to find the lightest HC, then distributes this town's groups across all live HCs via a round-robin anchored at that lightest HC, and sends each group's `['delegate-townai', ...]` to the selected HC leader. The HC/client receiver is `Client_DelegateTownAI.sqf`:

- creates town units locally at `:29`;
- records created groups and vehicles at `:31-32`;
- sends `["RequestSpecial", ["update-town-delegation", _town, _town_teams, _town_vehicles]]` back to the server at `:44`.

The server handles that update in `Server_HandleSpecial.sqf:86-115`: it appends received groups to `wfbe_town_teams` (with a dedupe guard), appends vehicles to `wfbe_active_vehicles`, starts empty-vehicle cleanup, and marks taxi prohibition. This is the most complete HC path, but still lacks disconnect failover.

The round-robin anchored at the least-loaded HC is load-spreading only, not work tracking. There is no visible server-side record tying a delegated town batch to the selected HC, and disconnect cleanup only removes the HC from the candidate list. A future failover patch needs work records before it can safely redistribute or clean orphaned groups.

### Static Defense Through HC

Static-defense delegation is triggered from two server paths:

| Caller | Source behavior |
| --- | --- |
| `Server_OperateTownDefensesUnits.sqf:55-67` on current stable | Town defense spawn delegates active-side gunners to HC when HC mode is enabled and a HC candidate exists. There is no west/east/resistance side gate in that delegate branch. |
| `Server_HandleDefense.sqf:19-24` | Base/structure defense remanning delegates a replacement gunner to HC when candidates exist. |

`Server_DelegateAIStaticDefenceHeadless.sqf:21-28` routes each group to the least-loaded live HC via WFBE_CO_FNC_PickLeastLoadedHC (evaluated once per group), then sends `['delegate-ai-static-defence', ...]` to that HC leader. The receiver `Client_DelegateAIStaticDefence.sqf:25-39` creates units locally and tags created units, but the intended server update-back is commented:

```sqf
//["RequestSpecial", ["update-delegation-static_defence", _teams]] Call WFBE_CO_FNC_SendToServer;
```

Unlike town AI, static-defense HC creation does not tell the server what was created. DR-42 confirms the server has no current record of HC-created static-defense units for cleanup, accounting, or re-delegation.

Do not restore this by uncommenting it alone. `Client_DelegateAIStaticDefence.sqf:30-31` assigns `_teams` from `_retVal select 0`, and current stable `Common_CreateUnitForStaticDefence.sqf:205` returns only `[_teams]`. That payload can identify created groups, but it does not carry the defense object, side, move-in mode or cleanup/accounting context, and `Server_HandleSpecial.sqf:86-115` only implements the town `update-town-delegation` receiver. A real restore needs a deliberate payload and a new server branch.

### Client-FPS Delegation Mode

Client delegation mode (`WFBE_C_AI_DELEGATION == 1`) is separate from HC mode. `Server_FNC_Delegation.sqf` selects player clients using `WFBE_AI_DELEGATION_<uid>` data:

- `Server_OnPlayerConnected.sqf:68-71` initializes `[fps, groups, sessionId]`.
- `Client/FSM/updateavailableactions.fsm:121-125` periodically sends client FPS with `["update-clientfps", getPlayerUID(player), avgFps]`.
- `Server_FNC_Delegation.sqf:139-178` selects delegators by FPS and group count.
- `Server_FNC_Delegation.sqf:104-115` tracks delegated groups until null, then decrements the delegator count if the session ID still matches.

Authority edge: `Server_HandleSpecial.sqf:75-83` trusts the UID and FPS values from the `RequestSpecial` payload when updating `WFBE_AI_DELEGATION_<uid>`. That means client-FPS delegation is a client-asserted performance signal, then the server uses the stored values to choose delegators in `Server_FNC_Delegation.sqf:153-158`. If this mode is revived for public play, derive sender UID from the request context where possible or add strict shape/rate validation plus diagnostics.

Do not copy this player-client session-counting model directly into HC mode without adapting it; HC mode currently stores HC groups, not per-HC delegated work records.

### Historical Release-Line Locality Guard Delta

Historical/local release-line commit `7ff18c49` has a narrow delegated-AI locality hardening delta in both maintained release roots, but current origin exposes no live `release/*` head on 2026-06-22. In that historical commit, `Client_DelegateAIStaticDefence.sqf:27` and `Client_DelegateTownAI.sqf:27` create a fallback group only when the passed group is null or empty. `Common_CreateUnit.sqf:34-36` and `Common_CreateUnitForStaticDefence.sqf:68-69` still protect non-local populated groups, but they key the fallback on the group leader's locality rather than replacing every non-local group before checking contents.

Treat this as historical PR8 release-line evidence, not as closure for DR-42 or current-release proof. The static-defense update-back is still commented, no server `update-delegation-static_defence` receiver exists, and HC disconnect/failover work records are still design work. Add HC/town/static delegation smoke to any restored `7ff18c49`-shaped release test window before calling the branch safe.

## Mode Split Quick Reference

| Runtime meaning | Mode / symbols | Live source path | Main risk |
| --- | --- | --- | --- |
| Headless-client registration | `WFBE_C_AI_DELEGATION == 2`, `WFBE_HEADLESS_<uid>`, `WFBE_HEADLESSCLIENTS_ID` | Current stable `Init_HC.sqf:94-129`; `Server_HandleSpecial.sqf:406-431`; town/static delegation call sites in `server_town_ai.sqf:242-248`, `Server_OperateTownDefensesUnits.sqf:55-67`, `Server_HandleDefense.sqf:19-23` | Owner-id `0` miss can still happen; registration is now idempotent/pruned, but there is no work-record failover. |
| Player-client FPS delegation | `WFBE_C_AI_DELEGATION == 1`, `WFBE_AI_DELEGATION_<uid>` | `updateavailableactions.fsm:121-129`; `Server_HandleSpecial.sqf:75-84`; `Server_GetDelegators.sqf:20-27`; `Server_FNC_Delegation.sqf:30-47,82-95,104-115` | Client-stated UID/FPS and group counts influence delegation selection. |
| Arma High Command UI | `_hc_enabled`, `HCSetGroup`, `HCRemoveAllGroups` | `_hc_enabled = false` at `updateavailableactions.fsm:47`; `HCSetGroup` gated at `:115-119`; cleanup at `updateclient.sqf:204,228` | Add path is inert by default while removal still runs; do not confuse this with headless-client delegation. |

## Risks

| Risk | Evidence | Impact |
| --- | --- | --- |
| HC disconnect has no mission-level re-delegation. | `Server_OnPlayerDisconnected.sqf:22-29` only removes the HC from the candidate pool. | Already-created HC-local groups may fall back to engine locality behavior, but the mission does not redistribute them to another HC. |
| HC registration can miss the candidate pool. | Current stable `Headless/Init/Init_HC.sqf:94-129` sends `connected-hc` after initial setup and after re-reseat; `Server_HandleSpecial.sqf:432-434` still rejects owner id `0` with only a warning. | Add server-side delayed registration/reconciliation before relying on HC availability, or prove the HC-side re-announce is enough with telemetry. |
| HC re-registration is now idempotent. | `Server_HandleSpecial.sqf` connected-hc case (lines 416-431): drops the previous group for this UID (`_hcList - [_hcOld]`), prunes all dead/null entries, then appends the new group via `missionNamespace setVariable ["WFBE_HEADLESSCLIENTS_ID", _hcValid + [group _hc]]`. Disconnect cleanup in `Server_OnPlayerDisconnected.sqf:22-29` still removes the group from the candidate pool. | Remaining risk: the persistent-watcher re-announce in `Init_HC.sqf` may fire while the HC is mid-reseat; the new civ group may not yet be visible to the server, briefly producing a prune-then-miss window. Verify registration telemetry (`HCSIDE|v1|connect`) in production after each re-announce. |
| Client-FPS delegation trusts payload UID/FPS. | `updateavailableactions.fsm:121-125`; `Server_HandleSpecial.sqf:75-83`; `Server_FNC_Delegation.sqf:153-158`. | Treat mode `1` as authority-light; validate sender/UID/rate before using it on a hostile public server. |
| Static-defense HC units are untracked server-side. | Current stable `Client_DelegateAIStaticDefence.sqf:39` comments out update-back; `Server_HandleSpecial.sqf:86-115` has `update-town-delegation` but no `update-delegation-static_defence` case. | Cleanup/accounting/re-delegation cannot reason about HC-created static-defense units. |
| Delegated group cleanup is local and unbounded. | Current stable `Client_DelegateTownAI.sqf:52-53`, `Client_DelegateAI.sqf:29-30` and `Client_DelegateAIStaticDefence.sqf:57-58` wait until the created group has no units, then delete the group. | A leaked or engine-stuck unit can leave a long-running cleanup poll on the HC/client. Add timeout/diagnostics when building work records. |
| Late HC join does not automatically re-enable mode. | Docs source `initJIPCompatible.sqf:164-171` / current stable `:202-209` can downgrade unsupported HC mode once; the server initializes `WFBE_HEADLESSCLIENTS_ID` only when mode is `2`. | If HC mode was disabled or no candidate was present during spawn decisions, later HC presence does not retroactively move existing AI. |
| Static-defense removal may miss original operators. | Current stable `Server_OperateTownDefensesUnits.sqf:83` stores `wfbe_defense_operator` only for server-created gunners; HC-created static gunners do not pass through that assignment. Removal clears that variable at `:116-118`. | Removal path deletes current gunner when it is not a player/funded group, but the original-operator bookkeeping differs between server and HC paths. |

## Patch Shape

### Phase 1: Make Static Defense Update-Back Explicit

Choose one of two designs:

| Option | Implementation |
| --- | --- |
| Restore tracking | Add a deliberate `RequestSpecial` update from `Client_DelegateAIStaticDefence.sqf` and add a server `update-delegation-static_defence` case. Do not merely uncomment the current line: the current helper returns only `[_teams]` (`Common_CreateUnitForStaticDefence.sqf:205` on current stable), while the server will need enough data to clean/reassign units later: defense object, created team/group, created units, side, and whether `moveInGunner` was used. |
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

# Player Squad / Group Join Protocol

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The squad system lets players move between groups mid-mission. All client-side logic lives in `Client/Functions/Client_FNC_Groups.sqf`. Server arbitration runs through `Server/Functions/Server_HandleSpecial.sqf`. Client-to-client notifications travel via `Client/PVFunctions/HandleSpecial.sqf`.

---

## Constants

All constants are defined in `Common/Init/Init_CommonConstants.sqf` and overridden by mission parameters at start.

| Constant | Default | Description | Source |
|---|---|---|---|
| `WFBE_C_PLAYERS_SQUADS_MAX_PLAYERS` | `4` | Maximum player count per squad (player leader included). | `Init_CommonConstants.sqf:281` |
| `WFBE_C_PLAYERS_SQUADS_REQUEST_TIMEOUT` | `100` | Seconds before an unanswered incoming request auto-expires from `WFBE_Client_PendingRequests`. | `Init_CommonConstants.sqf:282` |
| `WFBE_C_PLAYERS_SQUADS_REQUEST_DELAY` | `120` | Per-client cooldown (seconds) between successive join attempts. | `Init_CommonConstants.sqf:283` |
| `WFBE_C_AI_TEAMS_ENABLED` | `1` (fallback default) | Enables joining AI-led groups. Parameter default is `0` (disabled). Fallback `isNil` guard sets `1`. | `Init_CommonConstants.sqf:98`, `Rsc/Parameters.hpp:81` |

The parameter UI default for `WFBE_C_AI_TEAMS_ENABLED` is **0 (Disabled)**; the `isNil` fallback in `Init_CommonConstants.sqf:98` applies only when the parameter is absent entirely.

---

## Client-Side State Variables

Initialised in `Client/Init/Init_Client.sqf:286-292` on every client connect/JIP.

| Variable | Type | Purpose |
|---|---|---|
| `WFBE_Client_Team` | Group | The player's **original** spawn group (`clientTeam`); join-back target. |
| `WFBE_Client_LastGroupJoinRequest` | Number | Mission `time` of last join attempt. Starts at `-5000` so the first attempt is always allowed. |
| `WFBE_Client_PendingRequests` | Array of `[uid, name]` | Incoming join requests visible in the Groups Menu. Leader's machine only. |
| `WFBE_Client_PendingRequests_Accepted` | Array of UIDs | UIDs accepted within the last 6 seconds; prevents duplicate `ChangeUnitGroup` calls on lag. |

---

## Three Join Paths

`WFBE_CL_FNC_UI_Groups_Join` (`Client_FNC_Groups.sqf:102`) is called when the player selects a group in the Groups Menu. It enforces the cooldown and player-cap before branching on group type.

### Path 1 — Re-join Original Team

**Condition:** the selected group `== WFBE_Client_Team` (`Client_FNC_Groups.sqf:115`).

The client calls `WFBE_CO_FNC_ChangeUnitGroup` locally (`Client_FNC_Groups.sqf:116`) — no server round-trip. The player is set as squad leader of the returned group (`Client_FNC_Groups.sqf:117`). Note: the source uses `_unit` (uninitialized at this scope, resolving to nil/objNull in A2) rather than `player`; this is a known latent source issue — in practice the selectLeader call may silently no-op.

### Path 2 — Join Player-Led Group

**Condition:** `isPlayer leader _group` is true and `alive leader _group` (`Client_FNC_Groups.sqf:125`).

1. Client sends `["RequestSpecial", ["group-query", _group, player, WFBE_Client_SideJoined]]` to the server (`Client_FNC_Groups.sqf:126`).
2. Server (`Server_HandleSpecial.sqf:13-27`) forwards `["group-join-request", _player]` to the group leader via `HandleSpecial`.
3. Leader's client receives `WFBE_CL_FNC_Groups_ReceiveRequest` (`HandleSpecial.sqf:23`) — adds `[uid, name]` to `WFBE_Client_PendingRequests` and spawns the timeout watcher.
4. Leader acts via the Groups Menu (Accept or Deny).
   - **Accept** (`WFBE_CL_FNC_UI_Groups_RequestAccept`, `Client_FNC_Groups.sqf:167-211`): checks the player cap again against `WFBE_Client_PendingRequests_Accepted + current players <= WFBE_C_PLAYERS_SQUADS_MAX_PLAYERS`; calls `WFBE_CO_FNC_ChangeUnitGroup` on the joining player, adds the UID to `WFBE_Client_PendingRequests_Accepted` for 6 seconds (`Client_FNC_Groups.sqf:191`), then sends `["group-join-accept", group player]` to the requester.
   - **Deny** (`WFBE_CL_FNC_UI_Groups_RequestDeny`, `Client_FNC_Groups.sqf:215-246`): removes the request from `WFBE_Client_PendingRequests` and sends `["group-join-deny", group player]` to the requester.
5. Requester receives accept/deny via `HandleSpecial.sqf:20-21`, which calls `WFBE_CL_FNC_Groups_JoinAccepted` or `WFBE_CL_FNC_Groups_JoinDenied` — both show a hint and, on accept, flush `WFBE_Client_PendingRequests` (`Client_FNC_Groups.sqf:11`).

### Path 3 — Join AI-Led Group

**Condition:** `isPlayer leader _group` is false (`Client_FNC_Groups.sqf:128-136`).

Gated on `WFBE_C_AI_TEAMS_ENABLED > 0`. If the gate passes, the client sends the same `"group-query"` packet to the server. The server (`Server_HandleSpecial.sqf:29-38`) checks `isNil {_group getVariable "wfbe_uid"}` to confirm the group is genuinely AI-controlled (not a player group whose leader just died), then calls `WFBE_CO_FNC_ChangeUnitGroup` server-side and sends `"group-join-accept"` directly to the requester.

If AI Teams are disabled the client shows a warning hint and resets `WFBE_Client_LastGroupJoinRequest = -5000` to **waive** the cooldown (`Client_FNC_Groups.sqf:135`) — the player can retry immediately.

---

## Gate Checks (join attempt entry, `Client_FNC_Groups.sqf:110-151`)

Evaluated in order; checks are nested; each failure short-circuits via its else branch and shows a hint, so only the first failing condition fires:

| # | Check | Failure hint |
|---|---|---|
| 1 | `group player != _group` | "You are already in this squad." |
| 2 | `_players < WFBE_C_PLAYERS_SQUADS_MAX_PLAYERS` | "The player limit on this group has been reached (`<N>`)." |
| 3 | `time - WFBE_Client_LastGroupJoinRequest > WFBE_C_PLAYERS_SQUADS_REQUEST_DELAY` | "You cannot change groups that often, please wait `<N>` seconds." |
| 4 | `alive leader _group` | "The group you've attempted to join has no leader or the leader is dead." |

---

## Kick Flow

Any player who is the **group leader** can kick a squad member. `WFBE_CL_FNC_UI_Groups_Kick` (`Client_FNC_Groups.sqf:155-164`) fires when the leader selects a member in list `508003` and clicks Kick.

1. Verifies `isPlayer _selected && group _selected == group player` (`Client_FNC_Groups.sqf:159`).
2. Removes the row from the UI list with `lnbDeleteRow [508003, _ui_lnb_sel]` (`Client_FNC_Groups.sqf:160`).
3. Sends `[uid, "HandleSpecial", ["group-kick", group player]]` to the target client (`Client_FNC_Groups.sqf:161`).
4. Target client receives `WFBE_CL_FNC_Groups_KickedOff` (`HandleSpecial.sqf:22`), which:
   - Calls `[player, WFBE_Client_Team, WFBE_Client_SideJoined] Call WFBE_CO_FNC_ChangeUnitGroup` (`Client_FNC_Groups.sqf:27`) — returns the player to their original team.
   - Calls `WFBE_Client_Team selectLeader player` if the player is not already the leader (`Client_FNC_Groups.sqf:28`).
   - Shows a hint: "You were kicked from the group `<name>`, you have been transferred back to your Original group."

The kicked player is routed back to `WFBE_Client_Team` — not to a freshly-created group.

---

## `WFBE_CO_FNC_ChangeUnitGroup` (Common)

`Common/Functions/Common_ChangeUnitGroup.sqf`. Called by all three join paths and the kick flow.

Signature: `[_unit, _group, _side] Call WFBE_CO_FNC_ChangeUnitGroup`

If `_unit` is the last live member of its current group, a temporary filler AI of class `WFBE_<SIDE>SOLDIER` is created in that group before the `join` call to prevent engine group deletion (`Common_ChangeUnitGroup.sqf:9`). The filler is deleted after the join (`Common_ChangeUnitGroup.sqf:11`).

---

## LB Filler (`WFBE_CL_FNC_UI_Groups_FillUnits`, `Client_FNC_Groups.sqf:81-99`)

Populates any `lnbControl` with one row per unit. Called with `[_units_or_group, _lb_idc]`. If passed a `GROUP`, expands via `units _group`. Each row contains:

- Column 0 text: `"*(name) [vehicleDisplayName]"` — prefix `*` marks players, name is in parentheses, display name in square brackets.
- Column 0 picture: `portrait` when on foot, `picture` when in a vehicle (from `configFile >> "CfgVehicles" >> typeOf(vehicle _unit)`).

The Groups Menu uses IDD **508003** for the current-squad member list and **508007** for the pending-requests list (`Client_FNC_Groups.sqf:160, 173, 176, 218-221`).

---

## Known Bug

`WFBE_CL_FNC_Groups_JoinAccepted` (`Client_FNC_Groups.sqf:12`) and `WFBE_CL_FNC_Groups_JoinDenied` (`Client_FNC_Groups.sqf:19`) both contain the typo `"the the group"` in their hint strings. This is a cosmetic UX defect noted in the Audit Findings Queue (UX4); it does not affect runtime behavior.

---

## Message Reference

| Message key | Direction | Handler | Source |
|---|---|---|---|
| `"group-query"` | Client → Server | `Server_HandleSpecial.sqf:13` | `Client_FNC_Groups.sqf:126,131` |
| `"group-join-request"` | Server → Leader's client | `HandleSpecial.sqf:23` → `WFBE_CL_FNC_Groups_ReceiveRequest` | `Server_HandleSpecial.sqf:24,26` |
| `"group-join-accept"` | Leader's client → Requester | `HandleSpecial.sqf:20` → `WFBE_CL_FNC_Groups_JoinAccepted` | `Client_FNC_Groups.sqf:206` |
| `"group-join-deny"` | Leader's client → Requester | `HandleSpecial.sqf:21` → `WFBE_CL_FNC_Groups_JoinDenied` | `Client_FNC_Groups.sqf:244` (send via `WFBE_CO_FNC_SendToClients`) |
| `"group-kick"` | Leader's client → Target | `HandleSpecial.sqf:22` → `WFBE_CL_FNC_Groups_KickedOff` | `Client_FNC_Groups.sqf:161` |
| `"group-join-accept"` (AI path) | Server → Requester | `HandleSpecial.sqf:20` → `WFBE_CL_FNC_Groups_JoinAccepted` | `Server_HandleSpecial.sqf:34,36` |

`WF_A2_Vanilla` mode uses `WFBE_CO_FNC_SendToClients` (broadcast-filtered-by-UID) for all targeted sends; non-vanilla uses `WFBE_CO_FNC_SendToClient` (direct). Both modes reach the same handler on the recipient. `Common/Init/Init_Common.sqf:149`.

---

## Continue Reading

- [Player-AI-Caps-And-Role-Balance](Player-AI-Caps-And-Role-Balance) — per-side player and AI unit caps that interact with squad formation choices.
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_C_*` / `WFBE_Client_*` / `WFBE_CO_FNC_*` naming conventions.
- [Client-UI-Systems-Atlas](Client-UI-Systems-Atlas) — full IDD map and UI subsystem inventory including the Groups Menu.
- [Networking-And-Public-Variables](Networking-And-Public-Variables) — `RequestSpecial`, `HandleSpecial`, and `SendToClients` channel mechanics.
- [AI-Squad-Team-Templates-Catalog](AI-Squad-Team-Templates-Catalog) — AI team compositions players can join when `WFBE_C_AI_TEAMS_ENABLED` is active.

# RequestTeamUpdate Squad-Discipline Handler

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`RequestTeamUpdate` is the server PVF that lets a **human commander** push manual squad-discipline state — behaviour, combat mode, formation, and speed mode — onto AI teams from the Command menu. The commander opens the team-properties tab of the Command dialog (`GUI_Menu_Command.sqf`), picks one value from each of four list boxes, chooses a target scope (selected teams vs the whole side), and clicks apply. That fires `MenuAction == 303`, which builds the payload and ships it to the server through `WFBE_CO_FNC_SendToServer`. The server handler then applies four engine commands (`setBehaviour`/`setCombatMode`/`setFormation`/`setSpeedMode`) to the targeted groups.

This is the **manual** discipline-push path. It is distinct from the AI commander's *autonomous* orders, which call the same four engine commands but from a separate code path inside `Server\AI\Orders\*` — see [Legacy-AI-Order-Primitive-Reference](Legacy-AI-Order-Primitive-Reference) and the contrast section below.

## Payload contract

The payload is a five-element array `[_team, _behaviour, _combatMode, _formation, _speedMode]`, read positionally by `RequestTeamUpdate.sqf` (`_team = _args select 0` at `Server\PVFunctions\RequestTeamUpdate.sqf:4`; properties at `select 1`..`select 4`, `:9-12`/`:20-23`). Element 0 is overloaded — its `typeName` is the branch discriminator (ARRAY vs SIDE, see below). Elements 1-4 are the four discipline strings, drawn verbatim from the client list boxes.

| Index | Field | Type | Engine command applied | Source |
|---|---|---|---|---|
| 0 | `_team` | ARRAY of groups **or** SIDE | (branch selector) | `RequestTeamUpdate.sqf:4,7,18` |
| 1 | `_behaviour` | String e.g. `"AWARE"` | `setBehaviour` | `RequestTeamUpdate.sqf:9,20` |
| 2 | `_combatMode` | String e.g. `"RED"` | `setCombatMode` | `RequestTeamUpdate.sqf:10,21` |
| 3 | `_formation` | String e.g. `"WEDGE"` | `setFormation` | `RequestTeamUpdate.sqf:11,22` |
| 4 | `_speedMode` | String e.g. `"NORMAL"` | `setSpeedMode` | `RequestTeamUpdate.sqf:12,23` |

The four value vocabularies are fixed client-side lists (`GUI_Menu_Command.sqf:81-84`) and are passed through to the engine commands without any server-side allow-listing:

| Field | Allowed values | Source |
|---|---|---|
| Behaviour | `AWARE`, `CARELESS`, `COMBAT`, `SAFE`, `STEALTH` | `GUI_Menu_Command.sqf:81` |
| Combat mode | `BLUE`, `GREEN`, `RED`, `WHITE`, `YELLOW` | `GUI_Menu_Command.sqf:82` |
| Formation | `COLUMN`, `DIAMOND`, `ECH LEFT`, `ECH  RIGHT`, `FILE`, `LINE`, `STAG COLUMN`, `VEE`, `WEDGE` | `GUI_Menu_Command.sqf:83` |
| Speed | `LIMITED`, `FULL`, `NORMAL` | `GUI_Menu_Command.sqf:84` |

## Client caller — Command menu, MenuAction 303

The team-properties tab populates the four list boxes (IDC 14017/14018/14019/14020) by `lbAdd`-ing the vocabularies above (`GUI_Menu_Command.sqf:86-89`). While the dialog is open, the property tab also *reads back* the current state of the selected team's leader and pre-selects the matching list-box rows, so the menu reflects live discipline (`behaviour`/`combatMode`/`formation`/`speedMode` of `leader _team` → `find` → `lbSetCurSel`, `:510-526`). The `_updateProperties` one-shot flag (`:508-509`) makes that read-back happen on tab entry rather than every loop tick.

When the commander clicks apply, `MenuAction` is set to `303` and the handler block runs once (it immediately resets `MenuAction = -1`):

| Step | Action | Source |
|---|---|---|
| Read selections | `_behavior/_combat/_formation/_speed = <list> select (lbCurSel <IDC>)` for IDC 14017/14018/14019/14020 | `GUI_Menu_Command.sqf:413-416` |
| Default scope | `_to = sideJoined` (whole-side branch) | `GUI_Menu_Command.sqf:419` |
| Selected-teams scope | If `!_isAll`, rebuild `_to` as an array of `clientTeams select (_x - 1)` over the selected list rows `_teams` | `GUI_Menu_Command.sqf:420-426` |
| Dispatch | `["RequestTeamUpdate", [_to,_behavior,_combat,_formation,_speed]] Call WFBE_CO_FNC_SendToServer` | `GUI_Menu_Command.sqf:431` |

`_isAll` is true when the team list-box selection is the synthetic "All" row (`_curSel == 0`) or when row `0` is among the multi-selected rows (`GUI_Menu_Command.sqf:117`). `_teams = lbSelection _listbox_teams` (the 14012 list box) is the set of currently selected rows (`:119`); each row index `_x` maps to `clientTeams select (_x - 1)` because row 0 is the "All" pseudo-entry prepended at `:29`. The commented-out `WFBE_RequestTeamUpdate`/`publicVariable`/`HandleSPVF` lines at `:428-430` are the legacy raw-PV form, superseded by the `SendToServer` helper call.

The send helper wraps the name into the server convention: `WFBE_CO_FNC_SendToServer` (defined in `Common\Functions\Common_SendToServer.sqf`) rewrites payload slot 0 to `SRVFNCREQUESTTEAMUPDATE` (`Common_SendToServer.sqf:12`), then either broadcasts `WFBE_PVF_RequestTeamUpdate` to the server (`:14-15`) or, on a hosted server, spawns `WFBE_SE_FNC_HandlePVF` directly (`:17`). See [PVF-Send-Helper-Contract-Reference](PVF-Send-Helper-Contract-Reference).

## Server dispatch and registration

`RequestTeamUpdate` is registered as a server-bound PVF in the command list at `Common\Init\Init_PublicVariables.sqf:19` (it is element 11 of `_serverCommandPV`). The registration loop compiles the handler into a global named `SRVFNCREQUESTTEAMUPDATE` from `Server\PVFunctions\RequestTeamUpdate.sqf` and attaches a public-variable event handler that spawns `WFBE_SE_FNC_HandlePVF` on receipt (`Init_PublicVariables.sqf:60-61`). The dispatcher (`Server\Functions\Server_HandlePVF.sqf`) resolves the handler by name — `_code = missionNamespace getVariable _script` where `_script` is the `SRVFNC...` token — and spawns it with the parameter array (`Server_HandlePVF.sqf:11-15`). See [Public-Variable-Channel-Index](Public-Variable-Channel-Index) and [PVF-Dispatch-Implementation-Playbook](PVF-Dispatch-Implementation-Playbook).

## The two target-scope branches

The handler body branches on `typeName _team` — the same slot-0 value carries the scope semantics. Both branches apply the identical four engine commands; they differ only in which groups they iterate.

| Branch | Condition | Iterates | Per-group commands | Logging | Source |
|---|---|---|---|---|---|
| Selected teams | `typeName _team == "ARRAY"` | `forEach _team` (the group array built client-side) | `setBehaviour`/`setCombatMode`/`setFormation`/`setSpeedMode` on `_x` | one `LogContent` line **per group** | `RequestTeamUpdate.sqf:7-15` |
| Whole side | `typeName _team == "SIDE"` | `forEach (missionNamespace getVariable Format["WFBE_%1TEAMS",str _team])` | same four commands on `_x` | one `LogContent` line for the side | `RequestTeamUpdate.sqf:18-26` |

The whole-side branch resolves the side's group registry through the `WFBE_<SIDE>TEAMS` namespace variable. That variable is populated at mission init from each side's logic object (`initJIPCompatible.sqf:267`, copying `wfbe_teams` off the side logic), and is the same registry that `Common_GetClientTeam.sqf:6` indexes for client-team lookups. Because the two branches are independent `if` blocks (not `else`-chained, `:7` and `:18`), the discriminator must be exactly ARRAY or SIDE; any other type silently no-ops.

Both branches emit `WFBE_CO_FNC_LogContent` `INFORMATION` lines — the ARRAY branch logs each updated group (`RequestTeamUpdate.sqf:13`), the SIDE branch logs once naming the side (`:25`).

## Authority note

The handler performs **no requester validation**: it does not check that the sender is the side's commander, and it does not allow-list the four discipline values before passing them to the engine commands. The values arrive verbatim from the client list boxes. This is tracked as a security gap in [Server-Authority-Migration-Map](Server-Authority-Migration-Map) (the "validate requester is commander / allowlist behaviour-combat-formation-speed values" rows). A spoofed `WFBE_PVF_RequestTeamUpdate` could retarget any side's whole team registry via the SIDE branch.

## Contrast — not the AI-commander order path

The autonomous AI commander issues movement and posture orders through a *different* code path: the order primitives under `Server\AI\Orders\` (e.g. `AI_MoveTo.sqf`, `AI_Patrol.sqf`) call the same `setBehaviour`/`setCombatMode`/`setFormation`/`setSpeedMode` engine commands as part of executing the AI commander's own decisions. Those are not driven by `RequestTeamUpdate` and carry no command-menu payload. `RequestTeamUpdate` is exclusively the human commander's manual override; the AI-order primitives are the machine commander acting on its own. See [Legacy-AI-Order-Primitive-Reference](Legacy-AI-Order-Primitive-Reference).

## Continue Reading

- [Legacy-AI-Order-Primitive-Reference](Legacy-AI-Order-Primitive-Reference)
- [PVF-Send-Helper-Contract-Reference](PVF-Send-Helper-Contract-Reference)
- [Server-Authority-Migration-Map](Server-Authority-Migration-Map)
- [Public-Variable-Channel-Index](Public-Variable-Channel-Index)
- [AI-Squad-Team-Templates-Catalog](AI-Squad-Team-Templates-Catalog)

# Command Verbs Reference

Fleet lane 164, source-checked against `origin/claude/build84-cmdcon36` on 2026-07-02.

This page documents the Build 86 command-menu verbs that are otherwise scattered through
SQF comments and RPT tokens. It is an operator/player reference, not a new design proposal.
`docs/design/SPREAD-AND-HOLD.md` remains the allocator/capture-behavior reference; this page
covers what the command UI sends and what the server/team driver does with those orders.

## Scope

The command-menu v2 additions are guarded by `WFBE_C_CMD_MENU_V2` (default `1`) at
`Common/Init/Init_CommonConstants.sqf:838`. The non-commander support nudge uses
`WFBE_C_CMD_NUDGE_COOLDOWN` (default `180`) and `WFBE_C_CMD_NUDGE_RANGE` (default `1500`) at
`Init_CommonConstants.sqf:839-840`.

The UI sends all command verbs through `RequestSpecial` from
`Client/GUI/GUI_Menu_Command.sqf`. The server revalidates side, human commander state,
selected team index, sender identity, funds, and cooldowns in
`Server/Functions/Server_HandleSpecial.sqf`. HC/server team execution then happens through
the normal AICOM order path in `Common/Functions/Common_RunCommanderTeam.sqf`.

## Menu States

There are two important command-menu states:

- **AI-commanded side / non-commander view:** players can read AI intent, send soft AI
  posture nudges (`PUSH` / `HOLD`), focus a town, and request nearby AI support. These are
  advisory and cooldowned; they do not make the player commander.
- **Human commander view:** the commander can select AI-led teams and issue direct team
  verbs (`RALLY`, `REFIT`, `HOLD`) plus existing direct move/defend/patrol orders and bulk
  `ALL PUSH` / `ALL HOLD`.

## Verb Summary

| Verb | Who can use it | UI send | Server action | RPT / telemetry |
| --- | --- | --- | --- | --- |
| `PUSH` / `HOLD` posture | Non-commander when the AI holds command | `aicom-posture` from `GUI_Menu_Command.sqf:206-224` | Stamps a side-level posture for the AI commander to consume under `WFBE_C_AICOM_POSTURE_TTL` (`Init_CommonConstants.sqf:659`). | `AICOM2\|v1\|ORDER\|aicom-posture` at `Server_HandleSpecial.sqf:427`. |
| `REQUEST AI SUPPORT` | Any live side player | `aicom-support` from `GUI_Menu_Command.sqf:277-290` | Server validates player/side/position, picks the nearest non-busy AI-led team within `WFBE_C_CMD_NUDGE_RANGE`, moves it to the request position, leaves it autonomous, and clears manual pinning so AssignTowns may retask it later. | `AICOM2\|v1\|ORDER\|CMD_NUDGE`, `CMD_NUDGE\|NONE`, or `CMD_NUDGE\|REJECT` at `Server_HandleSpecial.sqf:709-764`. |
| `RALLY` | Human commander, selected AI-led team | `aicom-rally` from `GUI_Menu_Command.sqf:700-729` | Server chooses the nearest own HQ or own town center, sets move mode `move`, sets move position there, disables autonomy briefly via manual pin, and lets the pin TTL expire for normal re-entry. | `AICOM2\|v1\|ORDER\|aicom-rally` at `Server_HandleSpecial.sqf:560-598`; executor emits `RALLY_FALLBACK` / `RALLY_ARRIVED` at `Common_RunCommanderTeam.sqf:1274-1401`. |
| `REFIT` | Human commander, selected AI-led team | `aicom-refit` from `GUI_Menu_Command.sqf:700-729` | Server tops the team toward 6 live soldiers, capped at 4 replacements, charges `WFBE_C_AICOM_TOPUP_UNIT_COST` per missing unit from AI commander funds, rate-limits with `WFBE_C_AICOM_TOPUP_COOLDOWN`, and writes `wfbe_aicom_topup_req` for the team driver to consume. | `AICOM2\|v1\|ORDER\|aicom-refit`, `SKIP`, or `REJECT` at `Server_HandleSpecial.sqf:603-659`; consumer starts at `Common_RunCommanderTeam.sqf:2243`. |
| `HOLD` | Human commander, selected AI-led team | `aicom-hold` from `GUI_Menu_Command.sqf:700-729` | Server finds the nearest own-side town, sets the same hold latch used by auto capture-hold, orders the team to defend the town center, disables autonomy, and manual-pins the team for the hold window. | `AICOM2\|v1\|ORDER\|aicom-hold` or `REJECT` at `Server_HandleSpecial.sqf:664-704`; auto capture-hold logs `HOLD-CLAIM` at `Common_RunCommanderTeam.sqf:1978-1984`. |
| `ALL PUSH` / `ALL HOLD` | Human commander | Local command-menu action at `GUI_Menu_Command.sqf:588-622` | `ALL PUSH` releases all AI-led teams back to towns/autonomy and clears manual pins. `ALL HOLD` snaps each team to a nearby road point where possible, sets defense mode, disables autonomy, and stamps a manual pin. | Client-side hint only; no `RequestSpecial` token. |

## Execution Details

`Common_RunCommanderTeam.sqf:10-16` defines the shared order tuple:
`wfbe_aicom_order = [seq, mode, pos]`, with modes including `towns-target`,
`defense`, and `rally`. Normal town attacks lay assault behavior after arrival;
`defense` creates a tighter defensive SAD; `rally` is a bounding withdrawal that
returns fire en route, clears the rally flag on arrival, and re-enters town assignment.

Manual pins are intentional. RALLY and HOLD set `wfbe_aicom_manualpin` so
`AI_Commander_AssignTowns.sqf` does not immediately steal the team back. Support
requests deliberately clear the manual pin and keep autonomy on, because support is a
temporary nudge rather than a commander override.

REFIT does not teleport a full team. The server writes `wfbe_aicom_topup_req`; the
owning HC/server team loop consumes that request and spawns replacement infantry near the
team (`Common_RunCommanderTeam.sqf:2243-2277`).

## Operator Smoke Checks

- Open Command menu as a non-commander while AI holds command. Send `PUSH` or `HOLD` and
  confirm `AICOM2|v1|ORDER|aicom-posture` appears.
- As any live player, press `REQUEST AI SUPPORT`; confirm a `CMD_NUDGE` success, `NONE`,
  or `REJECT` token. A success should move one nearby non-busy AI team toward the player.
- As human commander, select an AI-led roster row and press `RALLY`, `REFIT`, or `HOLD`.
  Confirm the matching `AICOM2|v1|ORDER|aicom-*` token and watch the selected team's
  roster/order text change.
- For RALLY, look for `RALLY_FALLBACK` followed by `RALLY_ARRIVED` if the team reaches its
  rally point.
- For HOLD, verify the team defends an owned town center for roughly `WFBE_C_AICOM_HOLD_SECS`
  (default `180`) unless later command/retask logic releases it.

## Out Of Scope

This page does not change command behavior, command-menu layout, AI target selection,
team founding, AICOM economics, or HC delegation. It also does not replace
`SPREAD-AND-HOLD.md`; that page remains the reference for why the allocator spreads teams
and why first captors hold freshly captured towns.

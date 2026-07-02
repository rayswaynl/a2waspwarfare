# Spectator AI Teams Audit - 2026-07-02

Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`.

Scope: fleet lane 178, focused on whether the spectator/unit-camera flow can already view AI-led side teams. This pass is docs-only because the current target already exposes the expected route through the command-console roster.

## Summary

The standalone unit-camera dialog still lists only player-led teams in its leader list. That is intentional legacy behavior in `Client/GUI/GUI_Menu_UnitCamera.sqf:18-26`: the list filters `clientTeams` to `isPlayer (leader _x)` so empty lobby groups and AI-led runtime squads do not fill the normal player camera list.

AI-led team viewing is handled by the command-console roster instead:

- `Client/GUI/GUI_Menu_Command.sqf:334-345` reads the live side-logic `wfbe_teams` array when it is replicated, falling back to `clientTeams` only while the live registry is unavailable.
- `Client/GUI/GUI_Menu_Command.sqf:345` filters that roster to non-player-led, alive groups, so founded AI commander squads appear there instead of in the standalone player-led list.
- `Rsc/Dialogs.hpp:2222-2234` wires a double-click on the roster listbox to `MenuAction = 726`.
- `Client/GUI/GUI_Menu_Command.sqf:452-458` resolves the selected AI-led group, stores its live leader in `WFBE_CmdCon_CamUnit`, closes the command console, and opens `RscMenu_UnitCamera`.
- `Client/GUI/GUI_Menu_UnitCamera.sqf:43-51` consumes `WFBE_CmdCon_CamUnit` once, clears it, and starts the camera on that selected AI leader's vehicle.

## Findings

| ID | Severity | Finding | Evidence | Route |
| --- | --- | --- | --- | --- |
| SPECT-178-1 | None | The prompt concern is already covered on the current target. AI-led teams are visible through the command-console roster and can be opened in the existing unit camera by double-clicking the selected roster row. | `GUI_Menu_Command.sqf:334-345`, `:452-458`; `GUI_Menu_UnitCamera.sqf:43-51`; `Dialogs.hpp:2222-2234`. Chernarus and Takistan copies of both GUI files are byte-identical on the checked base. | No source change. Keep the AI-led route in the command console; do not broaden the standalone UnitCamera player-led list unless the owner explicitly wants a mixed player/AI spectator list. |

## Non-Findings

- The UnitCamera leader list omits AI-led groups by design. It is still a player/team camera list, and the code comments explicitly call out the filtered player-led list.
- The command-console roster uses the live `wfbe_teams` registry rather than the frozen `clientTeams` snapshot, which is the important part for runtime AI commander squads.
- The seed variable is one-shot. `GUI_Menu_UnitCamera.sqf` clears `WFBE_CmdCon_CamUnit` immediately after reading it, so normal Tactical menu camera opens are unaffected.
- No Chernarus/Takistan GUI drift was found for `GUI_Menu_UnitCamera.sqf` or `GUI_Menu_Command.sqf`.

## How To Smoke

1. Join as a commander or open the command console where the AI-team roster is visible.
2. Wait until the side has at least one live AI-led team in the roster.
3. Double-click an AI-led team row.
4. Confirm the command console closes, the UnitCamera dialog opens, and the camera starts on the selected team's leader or vehicle.
5. Reopen UnitCamera from the Tactical menu and confirm it starts normally on the player path, proving the one-shot seed was cleared.

Out of scope: changing GUI layout, adding a second AI-team list inside UnitCamera, touching command-order buttons, or changing mission source.

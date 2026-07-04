# Server FPS GUI Broadcast Audit - 2026-07-02

Fleet lane 112 asks for `serverFpsGUI.sqf` to stop broadcasting
`SERVER_FPS_GUI` unconditionally when there is no GUI consumer. The current
live target already carries a default-preserving guard, so this lane is a
status/evidence closure rather than another source patch.

## Verdict

Status: implemented on `claude/build84-cmdcon36@04b1ecf913f37b4826df451526388e1c44363928`.

Fixing commit: `2ba44534d` (`Lane 112: gate server FPS GUI broadcast`).

The current maintained roots both define:

```sqf
WFBE_C_SERVER_FPS_GUI_ACTIVE_PLAYERS_ONLY = 0
```

Flag `0` preserves legacy behavior: a dedicated server publishes
`SERVER_FPS_GUI` every 8 seconds.

Flag `1` changes the publisher to skip the broadcast unless
`BIS_fnc_listPlayers` contains at least one non-HC human player. Headless
clients listed in `WFBE_HEADLESSCLIENTS_ID` do not keep the feed alive by
themselves.

## Source Shape

Checked files:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/GUI/serverFpsGUI.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/GUI/serverFpsGUI.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Client_UpdateRHUD.sqf`

The server loop still exits immediately on non-dedicated hosts, preserving the
earlier busy-loop fix. On dedicated hosts it samples `diag_fps` on the same
8-second cadence, but the new flag can make publication conditional on a real
player being connected.

The RHUD consumer remains unchanged: `Client_UpdateRHUD.sqf` reads
`SERVER_FPS_GUI` and renders `...` while the value is missing. That means the
flagged mode degrades visibly but safely for clients that join before the next
publish.

## Boundaries

This does not add a per-client RHUD toggle subscription. It is a coarser
"active non-HC player online" opt-in mode, which removes idle-server / HC-only
network spam while avoiding new client-to-server chatter or HUD state races.

No defaults, RHUD layout, HUD profile toggle, FPS sampling cadence, live server
deployment, package artifact, or LoadoutManager output changed in this PR.

Future work should only reopen this lane if Ray wants a stricter per-client
subscription model instead of the already-shipped active-player gate.

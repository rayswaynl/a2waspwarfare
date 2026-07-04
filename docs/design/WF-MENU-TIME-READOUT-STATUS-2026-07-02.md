# WF Menu Time-Of-Day Readout Status - 2026-07-02

Base checked: `origin/claude/build84-cmdcon36@b5667bd0a`.

Scope: fleet lane 47, "WF-MENU TIME-OF-DAY READOUT" - verify whether the deferred QoL item still needs implementation.

## Summary

No source patch is needed for this lane on the current base. The WF menu already displays the in-game clock in its top strip:

`Uptime: <h>h <m>m | Time <HH>:<MM> | Players <n>/<slots> | Towns <held>/<total> | SV +<income>`

The implementation is present in both maintained mission roots and Chernarus/Takistan `Client/GUI/GUI_Menu.sqf` files are SHA-256 identical.

## Evidence

| Check | Result |
| --- | --- |
| Current implementation | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu.sqf:37-56` updates control `11015` every WF-menu loop. |
| UI control | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp:1221-1228` defines `WF_Menu` title control `11015`. |
| Clock source | `GUI_Menu.sqf:41-44` reads `date select 3` / `date select 4`, zero-pads both fields, then renders `Time HH:MM`. |
| Uptime source | `Client/Functions/Client_GetTime.sqf` returns mission uptime from `time`; the menu keeps uptime and in-game clock separate. |
| Existing commit | `c6aa8a096 feat(wf-menu): show the in-game accelerated day/night clock next to uptime` added this behavior. |
| Mirror parity | Chernarus and Takistan `Client/GUI/GUI_Menu.sqf` SHA-256 hashes matched on this pass. |

## Conclusion

Lane 47 is stale relative to the current source branch. The source already satisfies the requested player-facing behavior, including the accelerated day/night clock case because the readout uses the mission `date`, which is driven by the existing day/night synchronization paths.

No mission source, generated mission files, live server/deploy work, package artifacts, menu navigation, tooltip sweep, or parameter rows were changed in this PR.

## Follow-Up Note

The existing top strip is not default-off flag gated because it predates this fleet pass and is already live on the target branch. Do not add a default-off flag in this lane just to hide already-shipped status text; if the owner wants a toggle for the whole compact WF-menu status strip, treat that as a separate UX/defaults decision.

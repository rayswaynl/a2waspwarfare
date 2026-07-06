# GUER Mortar Feedback Status

Fleet lane 152 asks for better player feedback on the GUER improvised mortar action: an impact map marker and visible cooldown, instead of only a one-off `titleText`.

Status: already represented in the current `claude/build84-cmdcon36` target source. This note is docs-only; it does not change mission source, mirrors, package output, or live runtime state.

## Current Source Anchors

The maintained mission copies carry the same feedback path:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Action/Action_GuerMortarStrike.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Action/Action_GuerMortarStrike.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Action/Action_GuerMortarStrike.sqf`

Relevant anchors in all three copies:

- `:35` reports remaining cooldown and reminds the caller that the last impact is marked.
- `:78` creates a caller-local impact marker with `createMarkerLocal`.
- `:82` labels the marker as `Mortar impact - ready in %1s`.
- `:98` refreshes the marker text during the cooldown countdown.
- `:102-103` deletes the marker and shows `Mortar crew ready.` when the cooldown expires.
- `:107` reports the accepted strike as inbound and shows the reload time.

The marker is intentionally local to the caller. The source comment notes that the server already creates the short global incoming marker after accepting/debiting the strike, while this client marker is the caller's impact/cooldown breadcrumb.

## Status Call

No source patch is recommended for lane 152 from this branch. The current source has the requested impact marker and visible cooldown feedback across Chernarus, Takistan, and Zargabad.

## Follow-Up

The remaining useful proof is a player-action smoke: as a GUER driver with the mortar-truck action, click a valid map target, confirm the local impact marker appears with a countdown, wait for expiry, and confirm the marker clears with the `Mortar crew ready.` title text.

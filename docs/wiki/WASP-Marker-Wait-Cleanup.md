# WASP Marker Wait Cleanup

This page tracks the `wasp-marker-wait-cleanup` opportunity. It is a small client-local performance cleanup for the WASP map marker helper, not a completed patch lane.

## Status

Not patched in the current source. Source Chernarus and Vanilla Takistan both still need a tiny sleep/backoff in `WASP/global_marking_monitor.sqf`, followed by in-game map-marker smoke.

## What To Read

Source:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/global_marking_monitor.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/WASP/global_marking_monitor.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf`

Wiki/docs:

- [Performance opportunity sweep](Performance-Opportunity-Sweep)
- [WASP overlay](WASP-Overlay)
- [Client UI systems atlas](Client-UI-Systems-Atlas)
- [Feature status register](Feature-Status-Register)
- [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)

## Current Behavior

`WASP/global_marking_monitor.sqf` is a client-local helper loaded from `Client/Init/Init_Client.sqf`. When a local player double-clicks the map, it temporarily disables user input, waits for Arma's marker text dialog (`findDisplay 54`) and attaches key handlers so pressing Enter prefixes the marker text with the player's name.

Current source still has the short polling window without a sleep:

- `global_marking_monitor.sqf`: `disableUserInput true`
- `global_marking_monitor.sqf`: `while {time < _this} do`
- `global_marking_monitor.sqf`: `_display = findDisplay 54`
- `global_marking_monitor.sqf`: `disableUserInput false`

The same file already uses a throttled style later for display 12: `waitUntil {sleep 0.1; !isNull (findDisplay 12)}`.

## Suggested Patch Shape

Keep the behavior local and narrow. Replace only the display-54 wait with a throttled wait, preserving the existing key handlers and timeout behavior:

```sqf
private ["_display"];
_display = displayNull;
waitUntil
{
    sleep 0.1;
    _display = findDisplay 54;
    (!isNull _display) || {time >= _this}
};

if (!isNull _display) then
{
    _display displayAddEventHandler ["keyUp", "_this call fnc_marker_keyUp_EH"];
    _display displayAddEventHandler ["keyDown", "_this call fnc_marker_keyDown_EH"];
};

disableUserInput false;
```

## Why It Matters

This is not a server-wide performance emergency; it is a short, local, player-triggered loop. It is still a worthwhile cleanup because it removes avoidable busy polling in visible UI code and follows an idiom already present in the same file.

## Validation Needed

Source-only:

- Source Chernarus no longer contains `while {time < _this}` in `WASP/global_marking_monitor.sqf`.
- Generated Vanilla propagation is inspected separately after LoadoutManager runs from a correctly named `a2waspwarfare` checkout.
- Both paths still wire the marker dialog keyUp/keyDown handlers.

In-game smoke:

- Local player double-clicks map, enters marker text and presses Enter; marker text is prefixed with player name.
- Empty marker text still becomes the player name.
- Escape still clears the dialog key handlers without leaving input disabled.
- Timeout/no-dialog case does not leave input disabled.
- JIP/headless behavior should be unchanged because this helper is local-player client wiring.

## Handoff

Do not expand this lane into broader WASP authority cleanup. `WASP/actions/Action_RepairMHQDepot.sqf` remains a separate authority-light legacy action.

## Continue Reading

Previous: [WASP overlay](WASP-Overlay) | Next: [Performance opportunity sweep](Performance-Opportunity-Sweep)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)

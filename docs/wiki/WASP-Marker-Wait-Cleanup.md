# WASP Marker Wait Cleanup

This page tracks the `wasp-marker-wait-cleanup` opportunity. It is a small client-local performance cleanup and propagation/smoke route for the WASP map marker helper, not a broad WASP authority lane.

## Status

Branch-split after the 2026-06-23 current-B74.1/B74.2 refresh. The docs/source checkout `HEAD@c9df2a8b7264` is unchanged from `46840f048bd4` for the checked WASP paths and still has the unslept display-54 loop in Chernarus and maintained Vanilla, so that branch remains patch-ready. Current stable/B74.1 `origin/master@f8a76de349da` / `origin/claude/b74.1-aicom@f8a76de349da`, B74.2 `origin/claude/b74.2-aicom@21b62b04fee3`, current B69 `origin/claude/b69@8d465fcede7f`, adjacent B74 `origin/claude/b74-aicom-spend@b23f557fc912` and live `origin/feat/client-fps@709258e7e6f8` already carry the tiny `sleep 0.1` throttle in both maintained roots; they still need marker-dialog smoke before "verified in-game" wording.

Current-head refresh 2026-06-23: docs/source Chernarus and maintained Vanilla load `WASP\global_marking_monitor.sqf` from `Client/Init/Init_Client.sqf:267`, then keep `disableUserInput true`, the unslept `while {time < _this}` polling window, `findDisplay 54` and marker keyUp/keyDown handler attach at `global_marking_monitor.sqf:57,62,64,68-69`; display-12 is already throttled at `:80`. Current stable/B74.1 launches the helper at `Init_Client.sqf:397` and has `sleep 0.1` at `global_marking_monitor.sqf:64` before `findDisplay 54` at `:65`, with handler attach at `:69-70`, input unlock at `:74` and display-12 at `:81`, in both Chernarus and maintained Vanilla. B74.2 keeps the same throttled helper in both maintained roots; only source Chernarus helper launch line-drifts to `Init_Client.sqf:403` because B74.2 changes unrelated vehicle-tint/join-ACK/intro-music client-init code, while maintained Vanilla remains at `:397`. Current B69 and adjacent B74 match the throttled helper shape at `Init_Client.sqf:397`; live `origin/feat/client-fps@709258e7e6f8` also carries the throttled helper, with launch lines Chernarus `Init_Client.sqf:308` and maintained Vanilla `:287`. The Chernarus source fix is commit `4805c778876d`; maintained Vanilla propagation is present through Takistan regeneration commit `9b49883cb936`. Current Miksuu upstream `b8389e748243`, `origin/perf/quick-wins@0076040f8a5e` and historical `a96fdda28087` still keep the old unslept shape in both maintained roots (`Init_Client.sqf:278` on Miksuu, `:279` on perf, `:282` on historical; display-54 wait at `global_marking_monitor.sqf:57,62,64,68-69`; display-12 at `:80`). Current origin exposes no live `release/*`, WASP or marker rescue head on 2026-06-23, so older release evidence is historical until a release ref is restored.

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

Unpatched refs use a `while {time < _this} do` loop with no sleep between display checks. Current stable/B74.1/B74.2/B69/B74/client-fps keep the same `while` shape but add `sleep 0.1` before `findDisplay 54`, which closes the hot-loop part while preserving behavior:

- `global_marking_monitor.sqf`: `disableUserInput true`
- `global_marking_monitor.sqf`: `while {time < _this} do`
- old-shape refs: no sleep inside the display-54 loop
- stable/B74.1/B74.2/B69/B74/client-fps refs: `sleep 0.1`
- `global_marking_monitor.sqf`: `_display = findDisplay 54`
- `global_marking_monitor.sqf`: `disableUserInput false`

The same file already uses a throttled `waitUntil` style later for display 12: `waitUntil {sleep 0.1; !isNull (findDisplay 12)}`.

## Suggested Patch Shape

Keep the behavior local and narrow. For old-shape targets, the minimum source fix is the stable/B69 one-line `sleep 0.1` before `findDisplay 54`. A fuller cleanup can replace only the display-54 wait with a throttled `waitUntil`, preserving the existing key handlers and timeout behavior:

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

This is not a server-wide performance emergency; it is a short, local, player-triggered loop. On old-shape targets, adding the throttle removes avoidable busy polling under `disableUserInput`. On stable/B74.1/B74.2/B69/B74/client-fps-shaped targets, the remaining work is smoke and, only if desired, a style refactor toward the display-12 idiom.

## Validation Needed

Source-only:

- The target ref's Chernarus `WASP/global_marking_monitor.sqf` either contains `sleep 0.1` inside the display-54 loop or deliberately refactors that wait to the throttled `waitUntil` shape.
- Maintained Vanilla propagation is inspected separately after the target source edit or regeneration.
- Both paths still wire the marker dialog keyUp/keyDown handlers.

In-game smoke:

- Local player double-clicks map, enters marker text and presses Enter; marker text is prefixed with player name.
- Empty marker text still becomes the player name.
- Escape still clears the dialog key handlers without leaving input disabled.
- Timeout/no-dialog case does not leave input disabled.
- JIP/headless behavior should be unchanged because this helper is local-player client wiring.

## Handoff

Do not expand this lane into broader WASP authority cleanup. `WASP/actions/Action_RepairMHQDepot.sqf` remains a separate authority-light legacy action. For current stable/B74.1/B74.2/B69/B74/client-fps, do not reopen the one-line sleep patch; record marker-dialog smoke or an intentional style refactor instead.

## Continue Reading

Previous: [WASP overlay](WASP-Overlay) | Next: [Performance opportunity sweep](Performance-Opportunity-Sweep)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)

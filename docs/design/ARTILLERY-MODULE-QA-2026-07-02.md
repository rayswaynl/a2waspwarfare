# Artillery Module QA - 2026-07-02

Lane: 58
Branch: `codex/lane58-artillery-module-qa`
Scope: player Tactical UI artillery flow, group gun discovery, fire execution cleanup, ammo selection, counter-battery routing, and AI commander boundaries. Source was checked in the Chernarus mission root and the same runtime fix was mirrored to Takistan through LoadoutManager.

## Verdict

The player artillery module is source-backed and mostly coherent in the current branch:

- The Tactical UI disables artillery controls when `WFBE_C_ARTILLERY` is off, displays effective range using the configured artillery divisor, refreshes player/group gun state, and stamps a local cooldown before spawning `RequestFireMission`.
- Gun discovery is intentionally narrow for ordinary players: group vehicles must match the selected artillery type, have a non-player gunner, and pass the optional ammo filter.
- Commander-area artillery is only added when pieces are tagged with `WFBE_CommanderArtillerySide` and found near the side base/HQ area.
- Marker cleanup is server-routed through `RequestSpecial ["ArtyMarkerCleanup", ...]`, so global fire-mission markers do not depend on the calling client staying connected.
- Ammo selection is bounds-checked by artillery type, upgrade-gated through `WFBE_UP_ARTYAMMO`, and forwarded to the server when the gun is not local.
- Counter-battery reporting is split cleanly: client/common fire handlers report fired positions, the server checks the counter-battery structure gate, and side-targeted contacts are sent back to clients.

One small runtime defect was found and fixed in this PR: if a gunner died after `ARTY_Prep` but before the mission reached its normal finish path, `Common_FireArtillery.sqf` removed fired event handlers but left the artillery vehicle restricted and its driver AI disabled. The dead-gunner exit now restores driver `MOVE`, `TARGET`, and `AUTOTARGET` AI when the artillery vehicle is still alive, then clears the `restricted` variable. This mirrors the cleanup intent already present in the out-of-range and normal completion paths without calling `ARTY_Finish` on a null/dead gunner path.

## Source Map

| Area | Current source evidence |
| --- | --- |
| Config gates | `Rsc/Parameters.hpp:65` and `:71` define artillery and artillery UI params. `Common/Init/Init_CommonConstants.sqf:1061-1071` supplies fallbacks, area max, and timeout intervals. |
| Tactical UI status | `Client/GUI/GUI_Menu_Tactical.sqf:43-62` shows effective range and disables controls when artillery is off. `:742-757` handles status, cooldown, group gun recheck, and fire-mission spawn. |
| Artillery list refresh | `Client/GUI/GUI_Menu_Tactical.sqf:835-840` calculates effective max range and asks `GetTeamArtillery` for current guns. `:910-916` refreshes the ranged list periodically. |
| Ammo UI | `Client/GUI/GUI_Menu_Tactical.sqf:139` fetches ammo options. `:869-874` applies selected ammo through `WFBE_CO_FNC_LoadArtilleryAmmo`. |
| Fire request | `Client/Functions/Client_RequestFireMission.sqf:9-15` rediscovers eligible guns, then spawns `WFBE_CO_FNC_FireArtillery` per gun. `:31-38` creates global markers and sends server cleanup. |
| Gun discovery | `Common/Functions/Common_GetTeamArtillery.sqf:18-35` bounds-checks the index and filters type, non-null gunner, non-player gunner, and ammo when requested. `:50-74` adds tagged commander-area artillery only inside the side base/HQ area. |
| Fire execution | `Common/Functions/Common_FireArtillery.sqf:7-44` restricts the vehicle, prepares artillery, and already cleans up the out-of-range exit. `:73-79` now also cleans up the dead-gunner exit. `:97-108` cleans up normal completion. |
| Ammo loading | `Common/Functions/Common_LoadArtilleryAmmo.sqf:13-28` validates gun state and forwards non-local loads. `:58-62` adds/loads the magazine and replicates `WFBE_A_ArtilleryAmmoSelection`. |
| Ammo options | `Common/Functions/Common_GetArtilleryAmmoOptions.sqf:23-25` bounds-checks side artillery ammo arrays. `:41-50` reads extended magazines and current upgrade level. `:52-72` resolves projectile-to-magazine options. |
| Server specials | `Server/Functions/Server_HandleSpecial.sqf:190-200` performs delayed global marker cleanup. `:208-218` handles server-local artillery ammo loads. |
| Counter-battery | `Server/PVFunctions/CounterBatteryFired.sqf:1-15` keeps the fired-position report server-side and delegates to `WFBE_SE_FNC_CounterBatteryCheck`. `Common/Init/Init_CommonConstants.sqf:1492` enables the counter-battery structure gate by default. |
| AI commander boundary | `Common/Init/Init_CommonConstants.sqf:488` hard-locks legacy AI commander artillery. `:670-675` leaves the newer player-artillery assist mode default-off. |

## Findings

| Status | Finding | Action |
| --- | --- | --- |
| Fixed in this PR | Dead-gunner early exit could strand a surviving artillery vehicle in `restricted=true` with driver AI still disabled. | Restored driver `MOVE`, `TARGET`, and `AUTOTARGET` AI and cleared `restricted` in both Chernarus and Takistan `Common_FireArtillery.sqf`. |
| Routed | `RequestSpecial` subcommands used by artillery marker cleanup and ammo loading rely on the shared `RequestSpecial` envelope and subcommand parsing. Broader PVF/RequestSpecial hardening is already covered by open hardening work, so lane 58 does not duplicate it. | Keep artillery-specific behavior unchanged here; validate after the shared hardening PR lands. |
| Follow-up | Player fire cooldown remains client-local (`fireMissionTime`) and the fire request remains client-spawned after a local group-gun recheck. A server-authoritative fire-token redesign would be larger than this lane. | Track as a future authority-hardening lane if abuse or race behavior is observed. |
| Smoke pending | Source review covers control flow and mirror generation, but no live OA server runtime smoke was run in this lane. | Use the checklist below before treating artillery as fully field-verified. |

## Runtime Smoke Checklist

1. Enable player artillery UI and confirm the Tactical UI disables all artillery controls when `WFBE_C_ARTILLERY` is set to 0.
2. Crew an eligible group artillery vehicle with AI, fire inside valid range, and confirm the gun fires and normal cleanup clears `restricted`.
3. Fire outside valid range and confirm the vehicle is reusable afterward.
4. Kill the gunner after fire mission prep starts and confirm the surviving artillery vehicle is reusable afterward.
5. Select each unlocked artillery ammo option and confirm the chosen magazine loads on a server-owned gun.
6. Disconnect the calling client during marker lifetime and confirm both artillery markers are deleted globally after the server delay.
7. With counter-battery structures present, fire enemy artillery and confirm side-targeted counter-battery contacts appear and expire.
8. Repeat the same Chernarus smoke on Takistan after LoadoutManager mirror generation.

## Out Of Scope

- No AI commander behavior changes. Legacy AI commander artillery remains disabled and player-artillery assist remains default-off.
- No change to shared PVF or `RequestSpecial` envelope hardening.
- No package artifacts were produced; LoadoutManager was run with `A2WASP_SKIP_ZIP=1`.

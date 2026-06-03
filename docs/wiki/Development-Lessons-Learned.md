# Development Lessons Learned

This page captures implementation lessons that future developers and agents should apply before editing the Arma 2 OA Warfare mission. It is source-backed and intentionally narrow: use it as a checklist, not a replacement for the owning atlas pages.

Source root: `Missions/[55-2hc]warfarev2_073v48co.chernarus`.

## Highest-Value Coverage Gaps

| Area | Current coverage state | Why it still deserves attention |
| --- | --- | --- |
| Config data model | The assets/config page covers parameters, media and high-level assets, but `Common/Config` is much deeper than media/config shell coverage. | Content changes propagate through root faction files, unit arrays, gear registries, squad derivation, loadouts, upgrades, factory timers and generated missions. |
| AI respawn/orders | Respawn atlas maps AI respawn; AI pages map HC/town AI. | Vanilla/non-vanilla respawn branches and commander-order team variables need a single maintainer checklist before AI feature work. |
| Cleanup/garbage/empty vehicles | Marker/cleanup atlas is strong, but patch handoffs are scattered. | Cleanup code has short polling loops, global replicated queues, inconsistent flags and nested-pair array traps. |
| Non-EASA modules | Modules atlas maps many modules. | Feature changes still need a "where to smoke" rule because modules are split across Common/Client/Server and often attach at unit creation. |

## Lesson 1: Smoke Both Vanilla Branches For AI Respawn

`Init_Server.sqf` compiles different AI respawn implementations depending on `WF_A2_Vanilla`: vanilla uses `AISquadRespawn`, non-vanilla uses `AIAdvancedRespawn` (`Server/Init/Init_Server.sqf:10-12`). The advanced path is an `MPRespawn` handler entrypoint (`Server/AI/AI_AddMultiplayerRespawnEH.sqf:1`), while the vanilla path is a long-running leader watch loop (`Server/AI/AI_SquadRespawn.sqf:14-21`).

Both paths share key semantics: wait by `WFBE_C_RESPAWN_DELAY`, equip from `WFBE_%SIDE_AI_Loadout_%level`, choose camp/mobile/base fallback, and reset movement mode after non-autonomous respawn (`Server/AI/AI_AdvancedRespawn.sqf:55-76`, `:80-125`; `Server/AI/AI_SquadRespawn.sqf:53-64`, `:68-110`). Any AI respawn change needs a source check and smoke plan for both branches, or the untested branch should be explicitly called out.

Concrete follow-up: `Server/AI/AI_SquadRespawn.sqf:1` has a private-list typo-like entry `_rcm'`. It does not stop `_rcm` assignment at line 10, but it is a low-risk cleanup candidate when vanilla AI respawn is next touched.

## Lesson 2: Team Orders Are Public Group Variables, Not A Proven Server Command Queue

The commander UI writes orders directly through shared setters: move mode/position (`Client/GUI/GUI_Menu_Command.sqf:295-306`), force respawn (`:348-360`), autonomy toggles (`:364-389`) and AI respawn target (`:431-443`). Those setters publish group variables globally: `wfbe_autonomous`, `wfbe_respawn`, `wfbe_teammode`, and `wfbe_teamgoto` (`Common/Functions/Common_SetTeamAutonomous.sqf:8`; `Common/Functions/Common_SetTeamRespawn.sqf:8`; `Common/Functions/Common_SetTeamMoveMode.sqf:8`; `Common/Functions/Common_SetTeamMovePos.sqf:8`).

Static source search found server-side reads mainly in respawn reset logic and support-spawn waypoint helpers, not a clearly owned general "server command queue." AI order helpers update group behavior and waypoints (`Server/AI/Orders/AI_MoveTo.sqf:6-21`; `AI_Patrol.sqf:7-37`; `AI_WPAdd.sqf:19-39`), while `CanUpdateTeam` suppresses automatic updates when a human commander exists (`Server/Functions/Server_CanUpdateTeam.sqf:13-17`).

Development rule: before hardening or extending commander AI orders, prove the live executor path for `wfbe_teammode` and `wfbe_teamgoto` in the target scenario. Do not assume these variables imply server-authoritative validation.

## Lesson 3: Cleanup Loops Are Server-Owned But Some Inputs Are Client-Replicated

The server starts the garbage collector, empty-vehicle collector, dropped-item cleaner, crater cleaner, ruins cleaner, building restorer and mine cleaner after init (`Server/Init/Init_Server.sqf:521-560`). Several loops run frequently or over broad areas:

- Garbage scans `allDead` every 0.5 seconds, skips HQ objects and objects carrying `wfbe_trashable`, then spawns `TrashObject` (`Server/FSM/server_collector_garbage.sqf:4-23`, `:32`).
- Empty-vehicle collection reads replicated `WF_Logic getVariable "emptyVehicles"` every 0.5 seconds and drains handled objects (`Server/FSM/emptyvehiclescollector.sqf:4-21`, `:30`).
- Client vehicle creation appends new vehicles into that replicated empty-vehicle list (`Client/Functions/Client_BuildUnit.sqf:249-253`).

Development rule: queue-processing fixes must be idempotent under repeated client publications and hosted/dedicated locality. Do not treat a server loop as fully server-owned just because it runs on the server.

## Lesson 4: Cleanup Flags And Nested Arrays Need Shape Checks

The garbage collector skips `wfbe_trashable`, but kill handling marks `wfbe_trashed` before spawning `TrashObject` (`Server/FSM/server_collector_garbage.sqf:17`; `Server/PVFunctions/RequestOnUnitKilled.sqf:50-54`). That is a flag-contract mismatch and a good example of why cleanup patches need source shape checks.

The mine cleaner initializes `mines = []`, expects `[mine, time]` pairs, and deletes expired mines, but removes with `mines = mines - _x` (`Server/FSM/cleaners/mines_cleaner.sqf:3-17`). Producers append nested pairs from RPG dropping and stationary defense (`WASP/rpg_dropping/DropRPG.sqf:65-68`; `Server/Construction/Construction_StationaryDefense.sqf:31-55`). For nested pairs, removal should preserve array shape, for example `mines = mines - [_x]`, or be rewritten as a filtered live-pair list.

Development rule: before changing cleanup arrays, cite both producer and consumer shapes.

## Lesson 5: Config Changes Propagate Through Derived Runtime Tables

`Common/Config/readme.txt` describes a modular core system: gear registers weapons/magazines/backpacks, group config defines town groups, loadout files define gear-menu templates, model/root files define side support assets and defaults (`Common/Config/readme.txt:7-26`, `:28-42`, `:50-65`). Runtime init then chooses faction roots from parameters and loads root, defense and group files (`Common/Init/Init_Common.sqf:263-308`).

The config layer is not static data only. `Init_Common` mutates derived values: it doubles some unit prices under `WFBE_C_UNITS_PRICING`, records longest build time per factory type, multiplies structure costs for money-only economy and builds aggregate repair-truck lists (`Common/Init/Init_Common.sqf:325-367`). Gear helpers validate engine config classes and set missionNamespace records (`Common/Config/Config_Weapons.sqf:12-44`; `Config_Magazines.sqf:11-34`; `Config_Backpack.sqf:11-65`), while templates compute price/upgrade from registered items (`Common/Config/Config_SetTemplates.sqf:33-123`).

Development rule: content changes are not complete when the class appears in one list. Verify the side root, factory list, gear registry, loadout template, AI loadout or squad data, upgrade level, pricing, and generated mission propagation.

## Lesson 6: Module Wiring Often Happens At Creation Or Init Time

Client init compiles supply/MASH/AntiStack/PV helpers and module gates near the main function registry (`Client/Init/Init_Client.sqf:127-135`), then later applies skill, WASP actions, AutoFlip, artillery UI, EASA and CM gates (`Client/Init/Init_Client.sqf:570-589`). Common init wires ICBM, IRS and CIPHER after config loading (`Common/Init/Init_Common.sqf:319-323`).

Some module effects attach when units or vehicles are built rather than when the module file is loaded. That means a module patch can require factory/purchase smoke even if the module file itself is small.

Development rule: for module edits, identify whether the runtime edge is "boot init", "player respawn reapply", "unit creation attach", "PV/PVF event", or "server loop". Smoke the edge, not just the edited file.

## Proposed Backlog Patches

| Priority | Patch | Owner page target | Validation |
| --- | --- | --- | --- |
| P1 | Add this page and `agent-development-lessons.jsonl` to navigation/agent context after orchestrator review. | `Home`, `_Sidebar`, `Agent-Context`, `agent-context.json` | Link check and JSON parse. |
| P1 | Add a config data-model checklist to the assets/config or a dedicated config atlas page. | `Assets-Config-Localization-And-Parameters-Atlas` or new `Config-Data-Model-Atlas` | Source-only plus one content-change smoke scenario. |
| P2 | Add AI respawn branch smoke to testing workflow. | `Testing-Debugging-And-Release-Workflow` | Vanilla and non-vanilla AI leader death/respawn smoke. |
| P2 | Promote cleanup flag/nested-pair shape rules into the marker/cleanup atlas patch-ready section if not already accepted. | `Marker-Cleanup-Restoration-Systems-Atlas` | Mine expiry and unit-kill garbage smoke. |
| P3 | Source-check whether commander `wfbe_teammode`/`wfbe_teamgoto` has a live general executor or is mostly UI/respawn/support state. | AI/order owner page | Dedicated commander AI order smoke. |

## Agent Handoff

This page is safe to integrate because it adds a new, source-cited lesson artifact and does not alter the DR-44-owned networking/server atlas/instructions pages. The matching machine-readable records live in `agent-development-lessons.jsonl`.

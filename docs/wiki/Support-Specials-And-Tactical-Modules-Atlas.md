# Support Specials And Tactical Modules Atlas

This atlas maps support calls, specials and tactical modules: paratroopers, paradrops, UAV, artillery, ICBM/Nuke, MASH, airlift/ZetaCargo, service actions and supply mission hooks.

## How To Use This Page

This page is the support/tactical gateway. Use it to identify which runtime family owns an effect, then follow the owner page before editing authority, economy, networking or smoke status.

| Need | Start here |
| --- | --- |
| Tactical menu entry points, button gates and local support flow | [Tactical Menu Entry Points](#tactical-menu-entry-points) below and [Client UI systems](Client-UI-Systems-Atlas) |
| `RequestSpecial` server authority and forged-payload risk | [Server Dispatch And PV Paths](#server-dispatch-and-pv-paths), [Server authority migration map](Server-Authority-Migration-Map) |
| ICBM/nuke hardening | [ICBM authority](ICBM-Authority-Playbook) |
| Artillery visibility, commander-built ARTY and fire-mission smoke | [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas), [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack) |
| Supply missions, service actions or client-side funds/debits | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Service menu affordability guards](Service-Menu-Affordability-Guards), [Economy authority first cut](Economy-Authority-First-Cut) |
| MASH, UAV, ZetaCargo, AAR or aircraft ordnance leaf behavior | [Module Deep Dives](#module-deep-dives) and [Aircraft Ordnance Guardrails](#aircraft-ordnance-guardrails) below |
| Branch/release readiness for support fixes | [Feature status register](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Testing workflow](Testing-Debugging-And-Release-Workflow) |

## Current Branch Scope

Checked 2026-06-23 for the `upgrade-sync` tuple lane against docs/source `HEAD@a7f383b6`, current stable/B74.1 `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34`, visible B74.2 `origin/claude/b74.2-aicom@d472da6a`, current B69 `origin/claude/b69@8d465fce`, adjacent B74 `origin/claude/b74-aicom-spend@b23f557f`, Miksuu `b8389e748243`, `origin/perf/quick-wins@0076040f` and historical release commit `a96fdda2`. Current origin exposes no live `release/*` heads for the checked pattern; the matching live upgrade heads are Trello UI/info branches already routed separately and not `upgrade-sync` parser fixes.

Targeted diffs over the checked maintained-root `Server_HandleSpecial.sqf`, `GUI_UpgradeMenu.sqf` and `Server_ProcessUpgrade.sqf` paths show no parser rescue: `origin/master..origin/claude/b74.2-aicom` is empty, `origin/claude/b69..origin/claude/b74-aicom-spend` is empty, and B74-to-current-stable drift does not normalize `upgrade-sync`. Current stable/B74.1/B74.2 did add authoritative upgrade end-time state in `Server_ProcessUpgrade.sqf:27,55` plus UI reads at `GUI_UpgradeMenu.sqf:82,86`, but the `RequestSpecial` tuple parser still mixes `_args` and `_this`.

This atlas carries support orientation and selected source anchors. Deep hardening status belongs on owner pages: [Server authority migration map](Server-Authority-Migration-Map) for `RequestSpecial`, [ICBM authority](ICBM-Authority-Playbook) for nuke, [Service menu affordability guards](Service-Menu-Affordability-Guards) for service actions, [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) for supply, [Feature status](Feature-Status-Register#partial--deferred--needs-review) for branch-only drone/recon support, and [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack) for branch-only smoke.

Trello base-integrity branch intel was added on 2026-06-23 for `origin/claude/trello-base-integrity-fixes@66d80160`, a two-commit branch on merge-base/current stable `origin/master@f8a76de34`. Its scoped payload is six files / +70 / -10 across source Chernarus plus maintained Vanilla ZetaCargo hook/unhook and Nuke damage files, with `git diff --check` clean. Treat it as branch-only evidence: #87 adds friendly-HQ lift filtering plus ground drop behavior, and #97 deletes in-progress construction logics inside the nuke blast. It does not close `RequestSpecial`/ICBM authority, and maintained Vanilla still lacks the source Chernarus Zeta detach-argument fix.

### Trello Artillery UI Branch Intel

Checked 2026-06-23 after fetch. These Trello artillery UI/UX candidates are branch-only and have `origin/master@f8a76de34` as their merge base, so the payloads are directly comparable to current stable and no older-base drift was found in these diffs. Current stable has the existing Tactical-menu artillery cooldown text in `GUI_Menu_Tactical.sqf:546-558` and initializes `fireMissionTime = -1000` at `Init_Client.sqf:422`, but it has no `RUBHUD_Arty`, `if (MenuAction == 50)` crew action or `STR_WF_TACTICAL_CrewArtillery*` string keys in the maintained roots. For PR #79 comparison, current stable still lists raw artillery display names at `GUI_Menu_Tactical.sqf:42`, deletes player-called artillery markers from the caller client at `Client_RequestFireMission.sqf:32-33` through `Client_Delete_Marker.sqf:24`, formats the team warning with two arguments at `Client_RequestFireMission.sqf:53`, and has no `ArtyMarkerCleanup` hits.

| Branch | Evidence | Status |
| --- | --- | --- |
| `origin/claude/trello-arty-cooldown-hud@471fc0580fd6` | Payload is four files / +134 / -8 and `git diff --check` clean against current stable. In source Chernarus plus maintained Vanilla, `Client_UpdateRHUD.sqf:27` extends the RHUD IDC cache with `1372/1373`, `:259-288` adds `_RHUDUpdateArty`, and `:452` calls it during the RHUD refresh. `Rsc/Titles.hpp:177` adds `RUBHUD_Arty` / `RUBHUD_Arty_Value` to `OptionsAvailable`, while `:478-490` defines those controls. | Branch-only UI candidate. It surfaces the existing local artillery timeout state on RHUD; it is not a server-authority change and needs visual/client smoke in source Chernarus plus maintained Vanilla before stable wording. |
| `origin/claude/trello-arty-to-gunner@2dc3e7403399` | Payload is six files / +217 / -8 and `git diff --check` clean against current stable. In source Chernarus plus maintained Vanilla, `GUI_Menu_Tactical.sqf:571-626` adds `MenuAction == 50`, flattens `WFBE_%1_ARTILLERY_CLASSNAMES`, selects player-group artillery with empty driver/gunner seats, and uses existing group AI with `moveInDriver` / `moveInGunner`. `Rsc/Dialogs.hpp:2364-2371` adds button idc `17040`; `stringtable.xml:3192-3213` adds the crew-artillery label, tooltip and result hints. | Branch-only Tactical UI candidate. It seats existing dismounted group AI and spawns no new units. Smoke must cover player-owned artillery, empty/no-AI/no-artillery cases, locality, and maintained Vanilla parity before promotion. |
| `origin/claude/trello-artillery-ux@c4459d4312ef` / draft PR #79 | Payload is eight maintained-root files / +100 / -20 and `git diff --check` clean against current stable. In source Chernarus plus maintained Vanilla, `GUI_Menu_Tactical.sqf:42-57` reads display names, min/max arrays and `WFBE_C_ARTILLERY` to append effective `min-max m` range text to each artillery row. `Client_RequestFireMission.sqf:31-38` keeps global `WF_createMarker` creation but sends `RequestSpecial ["ArtyMarkerCleanup", ...]` instead of caller-local deletion; `:58-60` passes `_gunCount` as `%3` to the localized warning. `Server_HandleSpecial.sqf` adds server-side delayed `deleteMarker` cleanup at Chernarus `:144-160` / Vanilla `:134-150`; `stringtable.xml` updates `STR_WF_INFO_Arty_called_message` for the third placeholder at Chernarus `:9304-9311` / Vanilla `:9304-9310`. | Branch-only artillery UX/cleanup candidate. It is not a fire-mission authority fix and the new `RequestSpecial` cleanup tag should get marker-name / forged-payload review before promotion. Smoke per-type range text, gun-count messaging, caller disconnect/leave cleanup, JIP marker visibility and maintained Vanilla parity. |

### Trello Audio Cue Branch Intel

Checked 2026-06-23 after fetch. `origin/claude/trello-audio-cues@a0e4fb458` is a one-commit branch on current stable merge-base `origin/master@f8a76de34`. Payload is four maintained-root files / +74 / -2 across source Chernarus plus maintained Vanilla, and `git diff --check f8a76de34..a0e4fb458` is clean. Treat it as branch-only player-feedback work, not support authority or marker-registration proof.

| Branch slice | Evidence | Status |
| --- | --- | --- |
| Trello #90 paradrop cue | In both maintained roots, branch `Client/PVFunctions/HandleParatrooperMarkerCreation.sqf:17-18` still gates the handler to the matching client side. Branch `:42-61` then adds a client-local one-shot `commanderNotification`, throttled by `WFBE_C_LastParatroopSound`, plus a `paraDZ_<time>` local `mil_objective` marker labeled `Paradrop` that deletes after 30 seconds. Current stable has no `WFBE_C_LastParatroopSound`, `paraDZ_` or hardcoded `Paradrop` marker text in this handler. | Branch-only support feedback candidate. Smoke needs friendly-side-only audience, multi-unit drop throttling, local marker cleanup, JIP/no-stale marker behavior and maintained Vanilla parity. The marker text is hardcoded English, so localization polish remains separate if the branch is promoted. |
| Trello #91 IR-smoke ready cue | In both maintained roots, branch `Common/Module/IRS/IRS_OnIncomingMissile.sqf:51-61` spawns a client-local delayed check after `WFBE_IRS_FLARE_DELAY`; if the vehicle is alive, the player is still crew, flares remain and `wfbe_irs_disabled` is false/default, it plays `ARTY_cooldown_over`. Current stable already plays `inboundMissileGround` / `inboundMissileGround_cont` at `IRS_OnIncomingMissile.sqf:37/:45`, but has no ready-again cue. | Branch-only IR-smoke feedback candidate. Smoke needs crew leave/death, no-flare, cooldown, level-1/level-2 sound-loop and PR #61 IR-smoke toggle interactions. It reuses existing sound classes, not new media. |

## Source Snapshot

Current docs checkout anchors for the maintained Chernarus root:

| Surface | Source anchors |
| --- | --- |
| Tactical UI | `Client/GUI/GUI_Menu_Tactical.sqf:58-61` defines support labels, fees and cooldowns; `:252-283` gates buttons; `:293-347` routes button actions; `:371-373`, `:463-527` send support/nuke requests; `:531-605` owns artillery status, fire requests and ammo loading. |
| PVF transport | `Common/Functions/Common_SendToServer.sqf:12-18` wraps client requests as `SRVFNC*`; `Server/Functions/Server_HandlePVF.sqf:9-14` compiles/dispatches the handler; `Server/PVFunctions/RequestSpecial.sqf:1` forwards into `HandleSpecial`. |
| Server special router | `Server/Functions/Server_HandleSpecial.sqf:13-31` handles `group-query`; `:43-64` handles paratroops/ammo/vehicle/UAV; docs/source and maintained Vanilla `:67-73` handle `upgrade-sync`, while current-stable source Chernarus drifts to `:77-83`; `:97-111` handles ICBM; `:133-170` covers `track-playerobject` and `repair-camp`. |
| Artillery path | `Common_GetTeamArtillery.sqf:10-32` discovers group-owned guns; `Client_RequestFireMission.sqf:8-13,50-72` starts local fire and cooldown; `Common_FireArtillery.sqf:9-23,37-72` validates gun/range/fire mechanics; `Common_GetArtilleryAmmoOptions.sqf:41-72` and `Common_LoadArtilleryAmmo.sqf:18-53` own ammo options/loading. |
| Adjacent support modules | `Client/Module/UAV/uav.sqf:27-52` creates/debits/tracks UAVs and `Server/Support/Support_UAV.sqf:6-20` monitors cleanup; `Client/Module/Nuke/nukeincoming.sqf:7-23` sends the ICBM request and `Client/Module/Nuke/damage.sqf:13-34` applies current-stable nuke damage; current source Chernarus `Client/Module/ZetaCargo/Zeta_Hook.sqf:34-35` passes the detach vehicle while maintained Vanilla `Zeta_Hook.sqf:34` does not; `Common/Config/Core_Root/Root_RU.sqf:36` still comments out `WFBE_%1PARAAMMO` on the starting-vehicles line. |

## Tactical Menu Entry Points

The main support UI is `Client/GUI/GUI_Menu_Tactical.sqf`. Use [Source Snapshot](#source-snapshot) for current line anchors, then follow the owner pages in [How To Use This Page](#how-to-use-this-page) before changing authority, economy or smoke status.

Key source refs:

- `GUI_Menu_Tactical.sqf:58-61` defines support list/fees/cooldowns.
- `:146-217` owns fast-travel destination discovery, fee-mode filtering and local fee marker text.
- `:252-282` gates support buttons by funds, upgrade level and local cooldown state.
- `:403-406` locally debits paid fast travel after destination click.
- `:371-373`, `:513-527` send `RequestSpecial` support requests.
- `:463-505` performs the ICBM local launch flow.
- `:532-605` requests artillery/fire mission behavior.

`RequestSpecial` scout route: source Chernarus still has active sends or server cases for `update-teamleader`, `group-query`, `Paratroops`, `ParaVehi`, `ParaAmmo`, `RespawnST`, `uav`, `upgrade-sync`, `update-clientfps`, `update-town-delegation`, `ICBM`, `process-killed-hq`, `connected-hc` and `repair-camp`. `track-playerobject` has a server case around `Server_HandleSpecial.sqf:133-145`, but no active Chernarus caller was found in the checked static search. Use [Server authority migration map](Server-Authority-Migration-Map#requestspecial-tag-triage) for the tag-by-tag trust-boundary matrix instead of repeating it here.

Local navigation cautions:

- Tactical menu gates are client-side first; do not treat them as server authority.
- Artillery is a local/group-gun path, not a `RequestSpecial` asset-spawn path.
- UAV creation/cost remain client-led, while old UAV cleanup is server-observed.
- Fast travel and service actions are local support families and should stay separate from `RequestSpecial` hardening.
- `upgrade-sync` remains tuple-parser cleanup debt; the compact branch matrix below keeps the current stable/B74.1/B74.2 inbound anchor used by Feature Status and Source Fix Queue.

### Upgrade-Sync Branch Matrix

`upgrade-sync` is consistency/cleanup debt rather than a proven current runtime break: `Server_HandleSpecial.sqf:3` sets `_args = _this`, so today's mixed `_args` / `_this` reads resolve to the same payload. The cleanup is still patch-ready because it makes the RequestSpecial tuple contract explicit before broader router hardening.

| Root / branch | Evidence | Status |
| --- | --- | --- |
| Docs/source `HEAD@a7f383b6` | Chernarus and maintained Vanilla still have `Server_HandleSpecial.sqf:3,67-73` assigning `_args = _this`, reading `_side` from `_args select 1`, then `_upgrade_id` / `_upgrade_level` from `_this select 2/3`; `GUI_UpgradeMenu.sqf:171` sends `["upgrade-sync", WFBE_Client_SideJoined, _this select 0, _this select 1]`; `Server_ProcessUpgrade.sqf:26,29,35` owns the sync variable and has no `wfbe_upgrading_end_time` hits. | Mixed-source reads remain; current behavior is equivalent but fragile. |
| Current stable/B74.1 `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34`; visible B74.2 `origin/claude/b74.2-aicom@d472da6a` | Both roots call from `GUI_UpgradeMenu.sqf:292`. Source Chernarus keeps `_args = _this` at `Server_HandleSpecial.sqf:3`, the case at `:77`, `_side = _args select 1` at `:79`, `_upgrade_id` / `_upgrade_level` from `_this select 2/3` at `:80-81`, and sync set at `:83`; maintained Vanilla keeps the same parser at `:3,67,69-73`. `Server_ProcessUpgrade.sqf:27,55` now publishes/clears `wfbe_upgrading_end_time`, while sync store/wait/release remain `:32,:35,:41`. `origin/master..origin/claude/b74.2-aicom` is empty for the checked handler/caller/process paths. | No current stable/B74.1/B74.2 parser rescue. Treat the tuple cleanup as still patch-ready, but do not roll it into the end-time UI work. |
| Current B69 `origin/claude/b69@8d465fce`; adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` | Checked `origin/claude/b69..origin/claude/b74-aicom-spend` path deltas are empty for the handler, caller and process-upgrade files. Prior B69/B74 anchors keep the same mixed parser, caller `GUI_UpgradeMenu.sqf:292`, and `Server_ProcessUpgrade.sqf:32,35,41` sync lifecycle. | No adjacent-branch rescue; use current stable/B74.1 anchors when patching now. |
| Historical release commit `a96fdda2`; prior historical upgrade-queue evidence `b061c905` | Rechecked release roots keep the same mixed parser at `Server_HandleSpecial.sqf:67-73`; release callers sit at `GUI_UpgradeMenu.sqf:254`. Prior upgrade-queue evidence put callers at `:268`, but no live queue head was exposed by current origin during this refresh. | Historical branch evidence only until those branches are restored or rechecked. |
| Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` | Both checked maintained roots keep the same mixed parser, caller line `GUI_UpgradeMenu.sqf:241`, and `Server_ProcessUpgrade.sqf:26,29,35` sync-variable ownership; neither has the B74.1 server end-time lifecycle. | No upstream/perf rescue. |

Patch order: normalize the branch to read side/id/level from `_args` only, add a short tuple comment or helper-local guard if editing the router, keep RequestUpgrade authority migration separate, propagate maintained Vanilla, then smoke normal commander upgrade completion, non-server client timer sync, malformed/short payload rejection and AI commander upgrade progress.

## Authority And Owner Routes

| Surface | Local signal | Canonical owner |
| --- | --- | --- |
| Non-ICBM `RequestSpecial` effects | `Paratroops`, `ParaVehi`, `ParaAmmo`, `uav`, `RespawnST`, `repair-camp` and `group-query` trust payload side/team/object data after client-side UI gates. No live `RequestSupport` symbol was found in source Chernarus; support/special effects route through `RequestSpecial`. | [Server authority migration map](Server-Authority-Migration-Map#requestspecial-tag-triage), [Feature status](Feature-Status-Register#networking--public-variable-hardening-lane-source-backed) |
| ICBM/nuke | Tactical UI and `NukeIncoming` send `RequestSpecial ["ICBM", ...]`; server damage uses client-supplied payload objects. | [ICBM authority](ICBM-Authority-Playbook) |
| Fast travel and Tactical UI fees | Fee-mode destination hiding and debits are local Tactical menu behavior, not `RequestSpecial` server authority. | [Client UI systems](Client-UI-Systems-Atlas#tactical-fast-travel-fee-branch-matrix) |
| Service/EASA support actions | Repair/refuel/rearm/heal and EASA affordability are local/client-authoritative economy paths. | [Service menu affordability guards](Service-Menu-Affordability-Guards), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) |
| Supply truck respawn and old AI logistics | Economy menu still sends `RespawnST`; current stable/release safe-disable old AI supply-truck logistics while older roots need the raw-spawn caveat. | [AI commander autonomy audit](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix), [Supply mission architecture](Supply-Mission-Architecture) |
| Commander-built ARTY visibility | Fire missions are local/group-gun flow; commander-built ARTY visibility depends on the target branch's construction/artillery ownership shape. | [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas), [Source fix propagation queue](Source-Fix-Propagation-Queue#current-propagated-fix-queue) |
| Branch-only drone/recon support | Drone saturation and recon UAV are separate branch-review support features with no maintained Vanilla propagation claim here. | [Feature status](Feature-Status-Register#partial--deferred--needs-review), [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack) |

Client-bound support feedback uses the sibling PVF path (`Common/Functions/Common_SendToClient.sqf:9-18`, `Client/Functions/Client_HandlePVF.sqf:19-22`); route transport hardening through [Networking and public variables](Networking-And-Public-Variables) and [Public variable channel index](Public-Variable-Channel-Index).

Adjacent server runtime surfaces: grouped base areas are enabled only when `WFBE_C_BASE_AREA > 0` (`Server/Init/Init_Server.sqf:565`). Side logic seeds `wfbe_basearea` at `Init_Server.sqf:380`; `Server/FSM/basearea.sqf:46-80` then polls every 20 seconds, prunes invalid/remote base-area logics, and schedules delayed orphan-defense cleanup through `_onAreaRemoved` (`basearea.sqf:12-43`). `Server/FSM/groupsMonitor.sqf:1-14` is a dormant debug monitor that logs `allGroups` counts every 30 seconds; its only source start point found in this pass is commented at `Init_Server.sqf:567`.

## Support Feature Matrix

| Feature | Status | Notes |
| --- | --- | --- |
| Tactical support menu | Partial | UI works, but most fee/cooldown/upgrade gates are client-side only. |
| Fast travel | Working/partial | Local Tactical flow. Fee mode hides unaffordable towns and debits locally; branch/root matrix and UX decision live in [Client UI systems](Client-UI-Systems-Atlas#tactical-fast-travel-fee-branch-matrix). |
| Paratroopers | Working/partial | `RequestSpecial -> HandleSpecial -> KAT_Paratroopers`; server creates transport/units and sends marker callback. Missing server-side fee/cooldown/upgrade validation. |
| Ammo paradrop | Working/partial | Client-gated by `WFBE_UP_SUPPLYPARADROP` and shared `lastSupplyCall`; server creates aircraft/crates. |
| Vehicle paradrop | Working/partial | Similar to ammo paradrop; server creates cargo vehicle and empty-vehicle cleanup. |
| UAV | Partial | Client creates UAV, deducts funds and sends tracking request; server mostly monitors cleanup and reveal broadcasts. |
| Paratrooper / IR-smoke audio cues | Branch-only feedback candidates | `trello-audio-cues` adds local paradrop and IR-smoke-ready sounds in both maintained roots. It reuses existing `commanderNotification` and `ARTY_cooldown_over` sound classes and does not change support authority. |
| Artillery | Working/partial | Local/client fire authority with upgrade-gated UI/ammo/timeout behavior. |
| Anti-air radar (AAR) | Working/partial | Base structure and client marker feature are live when enabled; upgrade levels change marker detail and refresh rate, but the per-aircraft marker loops are client-local and should be performance-smoked on busy air games. |
| ICBM/Nuke | Partial/high-risk | Client deducts funds and sends `RequestSpecial ["ICBM", ...]`; server applies nuke damage from payload. Stale adjunct paths remain. |
| MASH | Branch-split / removed on current stable | Current stable removed the officer MASH deploy skill action in the June bundle (`Skill_Apply.sqf:43`); no portable deploy path remains there. Old-shape docs/Miksuu/perf roots still carry local deploy plus orphaned marker relay/receiver stubs. The `WFBE_%1MASHES` config vars are commented out in all Core_Root/*.sqf files, and MASH as a buildable base defense structure in Core_Structures configs is a separate system. |
| ZetaCargo/airlift | Branch-split / partial | Source Chernarus current stable passes the lifted vehicle into manual detach; maintained Vanilla current stable still does not. Trello #87 branch adds friendly-HQ filtering and ground-drop behavior in both roots, but does not repair the Vanilla detach-argument gap. |
| Service menu | Working/partial | Repair/refuel/rearm/heal effects and deductions are client-side; local support scripts recheck world state but not full money authority. |
| Supply mission | Partial | Server validates return proximity but trusts client-set `SupplyFromTown` / `SupplyAmount`. |
| Supply truck respawn | Safe-disabled / authority gap if revived | Economy menu requests `RequestSpecial ["RespawnST", sideJoined]`; `Server_HandleSpecial.sqf:55-60` still trusts the payload side and damages the side logic's `wfbe_ai_supplytrucks` list. Current `origin/master` `cf2a6d6a` and release `a96fdda2` initialize that list and log-disable old AI supply-truck logistics at `Init_Server.sqf:382-384` in both maintained roots instead of raw-spawning `UpdateSupplyTruck`; the old worker still points at missing `Server\FSM\supplytruck.fsm` at `AI_UpdateSupplyTruck.sqf:17`. Canonical branch matrix: [AI commander autonomy audit](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix). |

## Server Dispatch And PV Paths

`RequestSpecial.sqf` is intentionally tiny and forwards payloads; see [Source Snapshot](#source-snapshot) for the current transport/router anchors. That makes `Server_HandleSpecial.sqf` the important hardening boundary. Today, several high-impact support effects rely on the client UI having already enforced role, upgrade, fee and cooldown.

Use [Server authority migration map](Server-Authority-Migration-Map) before adding public support features. Use [ICBM authority](ICBM-Authority-Playbook) for the nuke path specifically, because it has public-server blast radius.

## Economy Cooldown And Upgrade Gates

The tactical UI keeps support fees and intervals locally. Button enabling checks funds/upgrades/cooldowns client-side; future public-server patches should re-check the same facts on the server before spawning assets or applying map-wide effects.

Do not treat those UI checks as security boundaries. Public-server hardening should separate:

- `RequestSpecial` server validation for server-spawned assets and map-wide effects.
- local correctness guards for service/EASA/artillery UI paths.
- a broader economy ledger decision for client-side funds/effects.

## Module Deep Dives

### Anti-Air Radar

AAR is a live base-support system, not only a historical changelog item. The build/action layer recognizes `AARadar` structures (`RequestStructure.sqf:14`; `updateavailableactions.fsm:189-222`), and unit init starts `Common_AARadarMarkerUpdate.sqf` for opposite-side aircraft when `WFBE_C_STRUCTURES_ANTIAIRRADAR > 0` (`Init_Unit.sqf:111-114`). The marker loop hides work while the map is closed, requires an AAR in range, applies the configured detection altitude, and reads `WFBE_UP_AAR` to move from speed-only markers at 5 seconds to altitude at 3 seconds and aircraft type at 1 second (`Common_MarkerLoop.sqf`). `Common_AARadarMarkerUpdate.sqf` is now a registrar that records `PerformanceAuditAARMarkerScripts` and `aar_marker_start`; `aar_marker_update` samples are recorded by `Common_MarkerLoop.sqf`, so large-aircraft smoke should include map-open/map-closed performance.

### UAV

`Client/Module/UAV/*` owns creation/cost/PV behavior, interface toggles and reveal broadcasts. The server monitors/trashes the UAV when the leader leaves or the UAV dies. Current authority is client-led for spawn/cost and server-led for cleanup tracking.

### ICBM And Nuke

`Client/Module/Nuke/*` owns launch UI/marker/object flow and sends the special request. `Client/FSM/updateclient.sqf:19-20` still registers an `ICBM_launched` event handler, but no current publisher was found. `NukeIncoming` PVF exists but the current launch path uses `RequestSpecial`.

Branch-only integrity candidate: `origin/claude/trello-base-integrity-fixes@66d80160` adds Trello #97 logic in source Chernarus plus maintained Vanilla `Client/Module/Nuke/damage.sqf:33-42`, deleting nearby `LocationLogicStart` construction logics that carry `WFBE_B_Type` before radiation starts. This targets the stable behavior where `damage.sqf:17` excludes `LocationLogicStart` from normal damage and current `Construction_SmallSite.sqf` / `Construction_MediumSite.sqf` create those logics at `:34`, set `WFBE_B_Type` at `:47/:67`, wait on `WFBE_B_Completion` at `:75/:95` or `:75/:90/:110`, then create the real structure at `:104` / `:119`. It is not an ICBM authority fix.

### MASH

`Client/Module/Skill/*` owns officer MASH/supply actions on old-shape docs/Miksuu/perf roots. There, MASH deploy creates local tent state used by respawn lookup, while marker sync is stale: the server relay exists, the client receiver compile is commented, and no maintained Chernarus/Vanilla sender was found. Current stable `origin/master@0139a3468609`, historical `a96fdda28087` and B69-family refs remove the maintained-root deploy/module path and keep only `Skill_Apply.sqf:43` removal wording plus residues. Modded `eden`/`lingor` sender lines are drift, not maintained-marker proof. Use [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas) for the branch-sensitive respawn split.

### ZetaCargo Airlift

`Client/Module/ZetaCargo/*` defines lifters/types and hook/unhook behavior. Airlift action is gated by `WFBE_UP_AIRLIFT`. Current source Chernarus already passes the lifted vehicle in the detach action (`Zeta_Hook.sqf:34-35`; `Zeta_Unhook.sqf:3-7`), while maintained Vanilla still has the older no-argument detach action at `Zeta_Hook.sqf:34`.

Branch-only integrity candidate: `origin/claude/trello-base-integrity-fixes@66d80160` adds Trello #87 friendly-HQ filtering at branch `Zeta_Hook.sqf:17-19` and ground-level drop/HQ-offset behavior at branch `Zeta_Unhook.sqf:12-29` in both maintained roots. The branch keeps source Chernarus detach-argument behavior but leaves maintained Vanilla without the detach action argument, so do not call it a complete Zeta parity fix without an extra Vanilla patch and smoke.

## Logistics Supports

Paradrops, service actions and supply missions overlap with economy authority:

- Paradrops are server-created assets but client-gated requests.
- Service actions perform local timed repair/rearm/refuel/heal support and client-side debits.
- Supply mission completion adds side supply server-side but trusts truck variables set from client mission start.

Use [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Service menu affordability guards](Service-Menu-Affordability-Guards) and [Economy authority first cut](Economy-Authority-First-Cut) for implementation sequencing.

## Aircraft Ordnance Guardrails

Current source has live ordnance guardrails, but they are not all equally active:

- Bomb distance restriction is live for `Bo_FAB_250` and `Bo_Mk82`. Plane setup attaches `HandleShootBombs` (`Common/Init/Init_Unit.sqf:118-121`); the handler exits unless the ammo is one of those bomb classes, requires the local player as shooter, reads `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION`, checks `cursorTarget`, hints `STR_WF_MESSAGE_BombDistanceRestriction` and deletes the projectile when the target is beyond the configured distance (`Common/Functions/Common_HandleShootBombs.sqf:15-30`).
- Bomb altitude is config-present but runtime-dormant in that handler. `Rsc/Parameters.hpp:284-288` exposes `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE`, default 2000, but the altitude check/delete block in `Common_HandleShootBombs.sqf:32-44` is commented out.
- Incoming missile range limiting is live when `WFBE_C_GAMEPLAY_MISSILES_RANGE` is non-zero. Non-man units get an `incomingMissile` handler (`Common/Init/Init_Unit.sqf:125-128`); `Common_HandleIncomingMissile.sqf:9-21` deletes IR-lock missiles, with a dumb-bomb workaround, once they exceed the configured range.
- Terrain-masking missile blocking is live for tanks, cars and air units through a `Fired` handler (`Common/Init/Init_Unit.sqf:207-212`). `Common_HandleShootMissiles.sqf:95-140` detects guided missile-like ammo, uses `cursorTarget`, checks vehicle-to-target terrain intersection with ASL positions and deletes the projectile with `STR_WF_MESSAGE_MissileTerrainMaskingRestriction` plus `MissileLaunchBlocked`.
- The terrain-masking handler has a commented `_limit_distance` section (`Common_HandleShootMissiles.sqf:107-117`), so current enforcement is terrain-intersection based rather than "only under configured distance".
- Aircraft AA gating is partial/path-dependent. Build, buy, rearm and EASA paths remove/filter AA missiles through upgrade and parameter checks (`Client_BuildUnit.sqf:287-293`; `Server_BuyUnit.sqf:155-162`; `Common_RearmVehicle.sqf:53-60`; `GUI_Menu_EASA.sqf:15-20`), but start/pre-placed vehicles or unusual creation paths should be smoke-tested before claiming complete coverage.

The main risks are locality and player-facing false positives: bomb distance and missile masking lean on local `cursorTarget`, the unit init path exits for non-local player scope, and bomb altitude has a lobby parameter without active enforcement. Treat future aircraft-balance work as runtime-test-heavy, not just config editing.

## Wave N Dispatch Notes

Wave N rechecked leaf support assets and found two source-level traps worth keeping on this owner page:

- RU para-ammo config is effectively commented out in `Common/Config/Core_Root/Root_RU.sqf:36`: the `WFBE_%1PARAAMMO` assignment appears after `//--- Starting Vehicles` on the same physical line. `Server/Support/Support_ParaAmmo.sqf:59-60` exits unless `WFBE_%1PARAAMMO` is an array, so RU ammo paradrop support needs a config-line repair before it can be treated as feature-complete.
- `Client/PVFunctions/NukeIncoming.sqf:7` plays `airRaid`, while [Assets/config/localization/parameters atlas](Assets-Config-Localization-And-Parameters-Atlas) confirms no `class airRaid` in `Sounds/description.ext`. If `NukeIncoming` is revived, add or replace that sound reference.

## Patch-Ready Hardening

| Finding | Patch shape |
| --- | --- |
| `RequestSpecial` trusts client-side gates | Add server-side requester/side/role/funds/cooldown/upgrade validation before dispatching assets or map-wide effects. |
| Base-area cleanup private-list nit | If editing `basearea.sqf`, add `_unit` to the `_onAreaRemoved` private list before its static-gunner cleanup block. This is low-risk hygiene, not an urgent behavior bug. |
| Bomb altitude parameter is dormant | Either revive and smoke the commented altitude block in `Common_HandleShootBombs.sqf`, or rename/document the parameter as historical so admins do not expect it to enforce. |
| Ordnance guardrails depend on local target state | Test lock/no-lock, pilot/gunner, AI crew, JIP and remote locality cases before tightening bomb or missile restrictions. |
| AA missile gating is path-dependent | Verify start vehicles, purchased aircraft, client-built aircraft, rearmed aircraft, SAMs and EASA loadouts all pass the same `WFBE_C_GAMEPLAY_AIR_AA_MISSILES` / `WFBE_UP_AIRAAM` policy before calling AA restrictions complete. |
| RU ammo paradrop config is commented out | Split `Root_RU.sqf:36` so the starting-vehicle comment does not swallow `WFBE_%1PARAAMMO`; smoke RU para-ammo request after the fix. |
| Audio cue branch candidates | If porting Trello #90/#91, keep the new cues client-local, verify the `Paradrop` marker deletes, confirm no sound spam across multi-unit drops, and smoke `wfbe_irs_disabled` interaction if the IR-smoke toggle branch is also present. |
| `upgrade-sync` mixed argument source | Use the [upgrade-sync branch matrix](#upgrade-sync-branch-matrix). Normalize the `Server_HandleSpecial.sqf` case to read side/id/level from one payload shape, propagate maintained Vanilla, then smoke upgrade completion synchronization and malformed/short payload rejection. |
| Zeta Cargo branch split | Preserve source Chernarus detach-argument behavior, add maintained Vanilla parity before claiming manual detach fixed there, and smoke Trello #87 friendly-HQ filtering plus ground-drop behavior before promotion. |
| Nuke in-progress construction branch candidate | If porting Trello #97, delete only in-progress construction logics that carry `WFBE_B_Type`, keep completed-structure damage behavior intact, and do not present it as ICBM authority closure. |
| Stale ICBM adjuncts | Either wire the `ICBM_launched` / `NukeIncoming` paths intentionally or remove/document them as dead. If revived, fix the missing `airRaid` sound reference first. |
| MASH marker flow is split | Reconcile sender, server relay, client receiver, delete replay and JIP resend, or remove/archive the stale marker relay. |
| Supply mission cargo/source trust | Recompute cargo/source/reward server-side from trusted truck/town state. |
| UAV creation/cost client-owned | Move UAV spawn/cost validation server-side or validate requested type, side, funds and existing UAV before accepting tracking. |

## Validation Checklist

- Paratrooper, ammo and vehicle paradrops with valid/invalid upgrade levels and insufficient funds.
- If testing Trello #90, trigger paratrooper drops with several units and verify one friendly-side `commanderNotification`, a transient local `Paradrop` marker, no enemy-side cue and cleanup after 30 seconds.
- UAV spawn, reveal, leader disconnect and cleanup.
- Artillery request with each upgrade level and local/remote gunner state.
- ICBM request from valid commander and forged/non-commander payload; if testing Trello #97, include an in-progress SmallSite/MediumSite inside the blast and a completed structure as control.
- If testing Trello #91, spend IR smoke, wait `WFBE_IRS_FLARE_DELAY`, and verify `ARTY_cooldown_over` only plays for surviving crewed vehicles with remaining flares and no `wfbe_irs_disabled` flag.
- MASH deploy, respawn availability and marker sync.
- Zeta hook/unhook with vehicle attached, own-HQ proximity, normal-heli drop, C-130 drop, lifter-damage auto-detach and maintained Vanilla detach-argument parity.
- Service actions with changing funds/world state between button enable and click.
- Supply mission cargo reward and cooldown after truck reuse.

## Continue Reading

Previous: [Modules atlas](Modules-Atlas) | Next: [ICBM authority](ICBM-Authority-Playbook)

Main map: [Home](Home) | Feature triage: [Feature status](Feature-Status-Register) | Authority map: [Server authority migration map](Server-Authority-Migration-Map)

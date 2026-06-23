# Abandoned Feature Revival Review

This page classifies dormant, broken and orphaned feature paths by what the source actually does today. Use it before reviving old code: several candidates are live systems with one broken edge, while others are genuinely unsafe to re-enable without design work.

## Decision Matrix

| Candidate | What the code does now | Classification | Recommendation |
| --- | --- | --- | --- |
| MASH map markers | Docs/Miksuu/perf-shaped maintained roots create/undeploy local MASH tents client-side, but the marker receiver is commented out and no live maintained sender for `WFBE_CL_MASH_MARKER_CREATED` was found. Current stable `origin/master@0139a3468609`, current B69 `origin/claude/b69@8d465fce`, adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` and historical `a96fdda2` remove the maintained-root deploy/module path; older B69 refs `0a1ccb4d05c5` and `80d3267c1b2b` are provenance for that shape, and the checked B69..B74 MASH delta is empty. Modded `eden` and `lingor` emit the marker-created PV; `Napf` does not currently show that sender in tracked source. | Branch-split: broken marker edge on old-shape roots; current-stable/current-B69/B74-shaped roots have deploy path removed. Some modded forks have sender-only drift. | Revive only with server-held marker records, unique marker ids, delete cleanup and explicit JIP resend. Otherwise remove/annotate the dead marker relay and clean modded sender drift. |
| Paratrooper drop markers | Server paratrooper support ejects units and sends `HandleParatrooperMarkerCreation`; source Chernarus and maintained Vanilla Takistan now register the existing client handler. | Small broken edge patched and propagated; Arma smoke pending. | Use [Paratrooper marker revival](Paratrooper-Marker-Revival) for evidence and validation. Modded missions still need maintenance-model cleanup because they register the callback but lack the handler file. |
| AI commander supply trucks | `UpdateSupplyTruck` compile is commented and the update script references missing `Server\FSM\supplytruck.fsm`. Docs/source `HEAD@6d4b514c12fc`, Miksuu `b8389e748243` and `origin/perf/quick-wins@0076040f` still raw-spawn the missing worker in both maintained roots. Current stable/B74.1 `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34` log-disables the truck-supply + AI-commander branch at Chernarus `Init_Server.sqf:44,624-625` and maintained Vanilla `:44,618-619`; B74.2 `origin/claude/b74.2-aicom@d472da6a` keeps the same safe-disable shape. Historical release commit `a96fdda2` has the older safe-disable line shape, and historical `c20ce153` guards only Chernarus. | Broken/dormant logistics feature; current stable/B74-shaped branches are safe-disabled, not revived. Docs/Miksuu/perf raw-spawn branches still need the caveat. | Do not just uncomment. Use [AI commander autonomy audit](AI-Commander-Autonomy-Audit) before merging raw-spawn branches, changing the safe-disable, or redesigning autonomous logistics. |
| Task system | Docs/source `HEAD@86ab85b9d0b1`, Miksuu `b8389e748243` and perf `0076040f` keep the old town `TaskSystem` comments plus `Client_TaskSystem.sqf`; current stable `origin/master@0139a346` keeps only comment residue and removes the helper file in both maintained roots. Current stable, B69 `origin/claude/b69@8d465fce`, B74 `origin/claude/b74-aicom-spend@b23f557f` and `origin/feat/naval-hvt-objectives@2e1c59317186` separately use commander Objective Ping through `SetTask`; historical `a96fdda2` has the same ping shape but no live `release/*` head. None of that is a revival of the old town task loop. | Dormant legacy town UX path with branch-split residue. | Treat as owner decision. Re-enable only with task-spam, JIP and notification UX smoke; otherwise remove/annotate the stale comments/helper. Keep Objective Ping smoke on the commander UI path. |
| Old map-icon tracking loop | Docs checkout `3406ffa0`, Miksuu `b8389e74` and perf `0076040f` still carry old plural blink/track comments pointing at absent helpers. Current stable `origin/master@0139a346` and historical `a96fdda2` already removed those old comments in checked maintained roots; newer singular `Client_BlinkMapIcon` remains active. | Replaced/dormant client marker path on old-shape targets. | Do not restore the old loop without a performance review. Keep documentation clear that marker blinking is not wholly dead. |
| AT/bomb common hooks | `HandleATReloadVehicle` and `HandleBombs` compiles are commented; bomb helper is missing and AT reload has no active wiring found. | Cut-off hook family. | Leave dormant unless a gameplay owner designs the reload/bomb feature and its authority/locality model. |
| Air-vehicle modification hook | Vehicle creation comments out `Common_ModifyAirVehicle.sqf`; the hook is not active in source or modded forks. | Dormant post-create hook. | Do not assume active aircraft post-processing; revive only with aircraft smoke and generated/modded propagation policy. |
| UAV 007 branch | Tactical UAV deploy/destroy/remote-control is live. The OA UAV interface has a stale mouse-button branch checking `_button == 007` and toggling hidden controls. | Stale UI branch, not abandoned UAV. | Leave dormant or remove as cleanup. Do not treat core UAV as abandoned. |
| WASP startup and legacy actions | `WASP\actions\AddActions.sqf` waits for player and then leaves these addActions commented; `WASP\Init_Client.sqf` also comments killed-handler, OnArmor, timer/key/bootstrap paths. HQ recovery and marker monitoring are separate live WASP edges. | Mixed live/dormant WASP family. | Leave old armor/God-Slayer hooks dormant or remove them; do not conflate them with live HQ recovery and marker-monitor behavior. |
| Old upgrade dialog `RscMenu_Upgrade` | `Dialogs.hpp` still defines `RscMenu_Upgrade` with `GUI_Menu_Upgrade.sqf`, but that file is absent. The live menu opens `WFBE_UpgradeMenu` and `GUI_UpgradeMenu.sqf`. | Stale UI resource. | Remove or replace old resource class; do not revive missing script path. |
| Modded mission propagation | LoadoutManager can target `Modded_Missions`, but packaging currently includes only `Missions` and `Missions_Vanilla`; modded folders exist as divergent/stub mission sets. | Needs maintenance-model decision. | Pick regenerate-from-source vs maintained forks before applying gameplay fixes to modded missions. Do not patch stubs ad hoc. |

## Source Evidence

### MASH Markers

What was read:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Officer.sqf:7-27`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Actions/Officer_Undeploy_MASH.sqf:19-21`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf:128-132`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf:70`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/MASH/MASHMarker.sqf:1-13`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/MASH/receiverMASHmarker.sqf:1-29`

What the code does:

- On docs/Miksuu/perf-shaped roots, officer skill creates a MASH/FARP object from `WFBE_%1FARP`, stores it in `WFBE_Client_Logic` as `wfbe_mash`, and adds an undeploy action.
- Undeploy deletes the MASH object and resets `WFBE_SK_V_LastUse_MASH`.
- The server MASH marker PVEH is compiled, but it only reacts to `WFBE_CL_MASH_MARKER_CREATED`.
- The client receiver for `WFBE_SE_MASH_MARKER_SENT` is commented out in `Init_Client.sqf`.
- Search found the marker trigger/relay names only in the commented receiver reference and the marker relay files, not in the live MASH deployment path.
- Branch refresh 2026-06-23: docs/source `HEAD@443055cf` is unchanged from `2b5139219faa` and `db3015f18ea3` for checked MASH paths, and docs/source, Miksuu `b8389e748243` and `origin/perf/quick-wins@0076040f8a5e` keep that old deploy/relay shape. Current stable `origin/master@0139a3468609`, current B69 `origin/claude/b69@8d465fcede7f`, adjacent B74 `origin/claude/b74-aicom-spend@b23f557fc912` and historical `a96fdda28087` remove the maintained-root deploy/module path and keep only `Skill_Apply.sqf:43` removal wording plus residues; B69 diffs from `0a1ccb4d05c5` and `80d3267c1b2b` to current head contain no MASH-related hunks, and the checked B69..B74 MASH delta is empty.

Why it matters:

MASH respawn support should not be called dead on old-shape docs/Miksuu/perf targets. The dead part there is the map-marker synchronization edge; on current-stable/current-B69/B74-shaped targets the maintained-root deploy/module path is already source-removed. Reviving the old publicVariable relay as-is would still have JIP and uniqueness problems: one overwritten global, no server-held resend list and marker names based on `round random 50000`.

Safe implementation shape:

1. Decide whether MASH markers are wanted.
2. If yes, create a server-owned MASH marker registry keyed by object/net id or deployer UID/team, not a single overwritten public variable.
3. On deploy, server validates the MASH object and broadcasts a side-filtered marker creation payload.
4. On undeploy/death, broadcast marker deletion and remove the registry entry.
5. Replay current markers to JIP clients after side assignment.
6. If no, remove or clearly annotate the dead receiver and relay so future agents do not re-enable half of it.

Validation:

- Source-only: verify one live sender, one live receiver and one delete path exist.
- Hosted/dedicated smoke: officer deploys/undeploys MASH; same-side client sees marker appear/disappear; other side does not.
- JIP smoke: late same-side client receives existing marker state.

### Paratrooper Drop Markers

What was read:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Support/Support_Paratroopers.sqf:108-118`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/PVFunctions/HandleParatrooperMarkerCreation.sqf:1-47`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_PublicVariables.sqf:25-40`

What the code does:

- On greenlight, the server ejects paratrooper cargo and calls `WFBE_CO_FNC_SendToClient` with command `HandleParatrooperMarkerCreation`.
- The handler file exists and creates a side-filtered `MarkerUpdate` marker; it also grants east paratroopers NVGs if needed.
- Source Chernarus and maintained Vanilla Takistan now include the command in `_clientCommandPV`, so init compiles `CLTFNCHandleParatrooperMarkerCreation` and registers `WFBE_PVF_HandleParatrooperMarkerCreation`. This remains unproven in Arma smoke and still drifts in modded forks.

Why it matters:

This was a small, bounded repair with likely gameplay value. The support itself was not abandoned; only the client callback was unwired in source/Vanilla before propagation. It is still a useful smoke target for the PVF dispatch hardening playbook because it exercises a client-bound support callback.

Safe implementation shape:

1. Source/Vanilla already add `HandleParatrooperMarkerCreation` to `_clientCommandPV`; keep that registration during future refactors.
2. Keep the side filter in the handler.
3. Prefer one compact validation/logging path if the payload unit is null/dead or not an object.
4. If the feature is not wanted, remove the server send and handler file instead of leaving a ghost callback.

Validation:

- Source-only: init compiles the handler and registers the PVEH.
- Dedicated smoke: commander calls paratroopers, units eject, same-side client sees markers, other-side client does not.
- JIP note: this is a transient drop marker. No replay is necessary unless owner wants historical paratrooper markers.

### AI Commander Supply Trucks

What was read:

- Docs/source `HEAD@6d4b514c12fc`: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf:36,382-383`
- Current stable/B74.1 `origin/master@f8a76de34`: Chernarus `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf:44,624-625`; maintained Vanilla `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Init/Init_Server.sqf:44,618-619`
- B74.2 `origin/claude/b74.2-aicom@d472da6a`: same maintained-root safe-disable caller shape
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/AI_UpdateSupplyTruck.sqf:1-20`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:95,165`
- Missing path check: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/supplytruck.fsm`

What the code does:

- `UpdateSupplyTruck` is commented out at compile time.
- The per-side server init still has the truck-supply + AI-commander branch. Docs/source, Miksuu and perf still raw-spawn `UpdateSupplyTruck`; current stable/B74.1/B74.2 initialize `wfbe_ai_supplytrucks` and log that legacy AI supply-truck logistics are disabled instead of spawning it.
- Current stable/B74.1 Chernarus defaults AI commander on at `Rsc/Parameters.hpp:77-82` and falls back to automatic supply at `Common/Init/Init_CommonConstants.sqf:536`; docs/source still defaults AI commander off at `Rsc/Parameters.hpp:92-97` and uses the automatic supply fallback at `Init_CommonConstants.sqf:161`. The broken worker is avoided by automatic supply unless truck supply is selected while AI commanders are enabled.
- In current stable/B74-shaped branches the branch no longer hits undefined `UpdateSupplyTruck`; if someone restores the compile or reintroduces a raw spawn, the script later tries to `ExecFSM "Server\FSM\supplytruck.fsm"`, which is absent.

Why it matters:

This is the clearest "do not casually revive" feature. It is config-gated latent breakage, not a small missing registration. PR #1 correctly avoids building autonomous supply helicopters on this base.

Detailed AI commander state, upgrade-worker and production/logistics readiness are now canonical in [AI commander autonomy audit](AI-Commander-Autonomy-Audit).

Branch refresh 2026-06-23: docs/source `HEAD@6d4b514c12fc`, Miksuu upstream `b8389e748243` and `origin/perf/quick-wins@0076040f` still raw-spawn in both maintained roots. Current stable/B74.1 `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34` carries the warning/disabled branch in Chernarus and maintained Vanilla, and B74.2 `origin/claude/b74.2-aicom@d472da6a` keeps the same caller shape. Current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` also keep the safe-disable branch. Historical release commit `a96fdda2` has the older safe-disable line shape, but current origin exposes no `release/*` head. Historical `c20ce153` only guards Chernarus and leaves Vanilla raw, and current origin exposes no `feat/ai-commander` head. No checked branch restores `Server\FSM\supplytruck.fsm`; use [AI commander autonomy audit](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix) as the branch matrix.

Safe implementation shape:

- Short cleanup: preserve or port the current-master warning/disable shape so branches do not raw-spawn the missing worker.
- Full revival: design a new AI supply-truck loop or restore a verified FSM, define ownership/accounting for spawned vehicles, and test cleanup on HQ death, side loss and AI commander disable.

Validation:

- Source-only: default config remains safe; truck supply + AI commander branch cannot call nil code.
- Dedicated smoke if revived: AI commander creates at most `WFBE_C_AI_COMMANDER_SUPPLY_TRUCKS_MAX` supply trucks, tracks them in `wfbe_ai_supplytrucks`, and cleans them up after death/completion.

### UAV And The 007 Branch

What was read:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_Tactical.sqf:58-60`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_Tactical.sqf:274-282`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_Tactical.sqf:325-338`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/UAV/uav_interface_oa.sqf:95-108`

What the code does:

- Tactical menu exposes UAV deploy, destroy and remote control.
- UAV deploy checks upgrade/funds/client `playerUAV`, then executes `Client\Module\UAV\uav.sqf`.
- The OA interface registers a mousebuttondown handler whose `_button == 007` branch toggles controls `112401..112404` and contains `comment 'DISABLED';`.

Why it matters:

The core UAV feature is live and should stay out of the abandoned bucket. The stale 007 branch is UI cleanup only. It may be an unreachable/undocumented mouse-button branch, and the `comment` statement alone is not an exit.

Safe implementation shape:

- Leave the branch dormant if it is harmless.
- Or remove/comment it with an owner note after confirming those controls are not used by normal OA UAV operation.
- Do not change deploy/destroy/remote-control authority in this lane; UAV spend/effect authority belongs with the broader economy/server-authority work.

Validation:

- Source-only: confirm normal UAV menu path still points at `uav.sqf`.
- Hosted smoke if cleanup is applied: deploy UAV, enter/exit OA interface, remote-control and destroy still work.

### WASP Legacy Actions

What was read:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/actions/AddActions.sqf:1-15`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/Init_Client.sqf:5-21`

What the code does:

- Gear-your-unit, wheel-change and OnArmor addActions are commented.
- The old OnArmor timer/key/bootstrap comments are also inactive.
- The live action in this snippet is HQ recovery at `AddActions.sqf:15`.

Why it matters:

These comments are useful archaeology, but they are not ready-to-revive features. Player-on-vehicle and group mount/dismount behavior can create locality, animation and exploit problems if re-enabled without design.

Safe implementation shape:

- Preferred cleanup: document as intentionally dormant or remove old commented hooks.
- Revival path: create a small design note first, then implement with explicit locality/ownership checks and player feedback.

Validation:

- Source-only cleanup: no live action disappears except intentional removal of comments.
- If revived: hosted and dedicated smoke with player, AI squadmate and occupied vehicle edge cases.

### Old Upgrade Dialog

What was read:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp:4-7`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp:2425-2428`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu.sqf:161-165`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_UpgradeMenu.sqf:1-41`
- Missing path check: `Client/GUI/GUI_Menu_Upgrade.sqf`

What the code does:

- Live menu routing opens `WFBE_UpgradeMenu`.
- `WFBE_UpgradeMenu` runs `Client\GUI\GUI_UpgradeMenu.sqf`.
- Stale `RscMenu_Upgrade` still points to missing `Client\GUI\GUI_Menu_Upgrade.sqf`.

Why it matters:

This is not a gameplay feature to revive; it is stale UI resource debt. It can mislead maintainers or break if opened by an old action path.

Safe implementation shape:

- Remove `RscMenu_Upgrade` if no live caller exists, or replace it with a compatibility wrapper that opens the current upgrade UI.

Validation:

- Source-only: no live caller references `RscMenu_Upgrade`.
- UI smoke: main menu upgrade button still opens `WFBE_UpgradeMenu`.

### Modded Mission Propagation

What was read:

- `Tools/LoadoutManager/ZipManager.cs:7-10`
- `Tools/LoadoutManager/FileManagement/FileManager.cs:87-100`
- `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:136-146`
- `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:204-212`
- `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:246-256`
- `Modded_Missions/*`

What the code does:

- LoadoutManager has code paths that distinguish modded terrain targets.
- Packaging currently lists only `Missions` and `Missions_Vanilla`; `Modded_Missions` is commented out in the zip mission directory list.
- Existing `Modded_Missions` folders include Napf, eden, lingor and several stub terrain folders.

Why it matters:

This is a maintenance model problem, not a single missing function. Source fixes in Chernarus and generated Takistan should not be assumed to reach modded forks unless generation and packaging policy are made explicit.

Safe implementation shape:

1. Owner chooses: regenerate modded missions from source, maintain selected forks manually, or delete/archive stubs.
2. If regenerate, add a drift check and packaging policy before touching gameplay fixes.
3. If manual forks remain, list which source-backed hardening fixes must be ported to each fork.

Validation:

- Source-only: generation/packaging docs match actual LoadoutManager behavior.
- Local-tool: run LoadoutManager and inspect generated drift before packing.
- Release: confirm which mission folders are actually shipped.

## Handoff

For Codex:

- Keep this page linked from Feature Status, Pending Owner Decisions, Home and the hardening backlog.
- Use it as the decision matrix for `marker-support-cleanups` and abandoned-code cleanup.

For Claude:

- Best contradiction checks: confirm no hidden live sender for `WFBE_CL_MASH_MARKER_CREATED`; confirm source/Vanilla `HandleParatrooperMarkerCreation` still registers and modded forks still lack the handler file; verify whether `RscMenu_Upgrade` is truly uncalled outside static text search.

For a future code owner:

- Smallest already-landed patch: paratrooper markers are revived in source/Vanilla by registering `HandleParatrooperMarkerCreation`; remaining work is Arma smoke plus modded maintenance policy.
- Highest cleanup value: guard/remove AI supply truck config-gated nil/FSM path before anyone enables truck-based AI logistics.
- Highest owner decision: modded mission maintenance model before porting hardening fixes beyond Chernarus/Takistan.

## Continue Reading

Previous: [Pending owner decisions](Pending-Owner-Decisions) | Next: [Hardening roadmap](Hardening-Implementation-Roadmap)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)

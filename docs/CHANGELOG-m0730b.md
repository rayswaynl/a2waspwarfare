# WASP Warfare - build m0730b

This build heals a two-lineage split: everything the community has been playing live since build m0727 (07-27), merged with a full day of crash-fix, bugfix, and feature work that had been accumulating in parallel on a second branch. 57 commits, 64 mission files changed. Before shipping, the merged tree was completeness-gated against the live PBO - a full diff confirmed 0 files missing - after the previous attempt (m0730a) silently dropped content during assembly and was pulled.

## Server stability & crashes

**Fixed a crash that could take the whole server down mid-match**
This is the access-violation crash (engine code 014EFCF4) that hit the live 13.5h session and force-rebooted the server, dropping every connected player and losing that boot's match progress. It fired when AI cleanup deleted a dead soldier, an empty base gun, or a supply-squad vehicle at the exact moment other AI logic was still reading that object's position. AI rally orders for withdrawing teams, the base-defense gun-manning loop, the 60-second corpse/wreck cleanup timer, and the AI supply-squad tracker now all re-check that their target object still exists immediately before touching it, instead of trusting a check made a tick or a sleep earlier.

*Common_TrashObject.sqf, AI_Commander_Strategy.sqf (graceful-withdraw rally), Server_HandleDefense.sqf, Server_AicomSupplySquad.sqf: isNull/alive re-checks inserted immediately before every getPos/getPosATL/velocity call that follows a sleep or forEach, closing the concurrent-delete TOCTOU race behind crash 014EFCF4. Commits ddbddc0a19, 2d397bd66c.*

**Classic-launch nuke strikes now actually go off**
If a team built and fired an ICBM through the classic (non-TEL) launch path, the missile climbed into the sky and just stayed there - no explosion, ever. You paid the full build and launch cost for a strike that could never land. The cruise missile now force-detonates on its own after 180 seconds if nothing else has removed it, so a classic nuke launch always pays off.

*nukeincoming.sqf: the classic-path cruise missile spawns uncrewed with a permanent upward vector and nothing in the script tree ever kills it, so `waitUntil {!alive _cruise}` deadlocked both this client thread and the server's ICBM-detonation wait on the same object - NukeDammage never fired. Added a 180s deadline + isNull escape; on timeout the existing deleteVehicle triggers the server's isNull-based detonation, the same detonate-by-delete idiom the TEL launch path already relied on. Commit 777d05a6dd.*

**Closed off several ways an AI or menu action could hang forever**
A handful of everyday actions had waits with no way out if the thing they were waiting on never happened: a countermeasure-flare check that could wait on a missile forever, a heli-bomb/SCUD map-click designation that hard-spun the CPU with the map open, the commander vote popup, and the post-death respawn wait. None of these was a single dramatic crash on its own, but each one is a scheduler slot the server never got back - the same class of bug behind the nuke deadlock above, just spread across smaller everyday actions. All of them now give up after a bounded timeout instead of waiting indefinitely.

*CM_Spoofing.sqf, Action_GuerHeliBombCall.sqf, Client_BuildUnit.sqf (SCUD map-designate), Client_FNC_Special.sqf (vote popup + ICBM display wait), Client_OnKilled.sqf (respawn wait), AI_Commander_MHQReloc.sqf (contact-grace timer was being re-extended every 5s tick instead of once on the contact edge, so its own stuck/deadline monitor could never converge under sustained enemy contact): every bare waitUntil now sleeps inside its own condition and carries a bounded deadline. Commit 2e0c4366c7.*

**Closed more crash-risk gaps in AI landings, artillery, supply runs and ammo drops**
A transport helicopter landing an AI team, an illumination or SADARM artillery submunition falling toward its target, a player supply truck mid-delivery, and an ammo-crate paradrop from a helicopter could all hit the same crash pattern as above if the object they were tracking got deleted, destroyed, or cleaned up during a wait. None of these were confirmed as the exact crash seen in the live match, but they're the same class of bug, closed pre-emptively across the board rather than waiting for them to show up in an RPT.

*Common_AICOMAirLeg.sqf / Common_RunCommanderTeam.sqf (chopper land-and-unload wait), ARTY_HandleILLUM.sqf / ARTY_HandleSADARM.sqf (shell-fall and target-acquire waits, plus a TOCTOU on the acquired target during a random sleep), supplyMissionStarted.sqf (player supply-truck loop), Support_ParaAmmo.sqf (chopper TOCTOU before ammo-chute spawn): isNull/alive re-checked immediately before every getPos/getPosATL/distance call that follows a sleep. Commit 190362757b.*

## AI commander behaviour

**AI commanders stop flip-flopping between attack and defend when they're already winning**
In the 13.5h live match this delta was built from, WEST held a 4-7x strength advantage over the enemy for nearly 5 straight hours and captured nothing in that window - the commander kept alternating DEFEND and PRESS postures every couple of ticks (52 flips logged) instead of committing to the attack. Postures now hold for at least 3 minutes before the other trigger can flip them back, so a side that's clearly winning should start converting that edge into captures instead of dithering in place.

*AI_Commander_Strategy.sqf: shared DEFEND<->PRESS dwell (WFBE_C_AICOM_POSTURE_HYST_SEC=180) + LOSING_PRESS enter/exit hysteresis band (0.8 enter / 0.65 exit) replacing the single 0.8 threshold re-evaluated every tick. Flag: WFBE_C_AICOM_POSTURE_HYST_ENABLE default 1 (live-armed; set to 0 for byte-identical old thrash behaviour).*

**A collapsing side's mobile HQ can finally relocate instead of being stuck in the rear for the whole match**
In the same match, WEST's mobile headquarters never relocated once in 13.5 hours of play - 48 attempts, 48 aborts - leaving its entire logistics base pinned in a stale rear position while its territory shrank to 5-7 towns. The relocation check no longer auto-rejects a spot the AI already confirmed was safe just because it's closer than the normal minimum-advance distance, so a compressed side's HQ can now follow a collapsing front instead of getting stranded behind it.

*AI_Commander_MHQReloc.sqf: the MIN_ADVANCE gate (1500m) is now skipped when the candidate position came from the relaxed ring search (`_usedRing < 600+buffer`), instead of unconditionally discarding it and logging a misleading second abort line. Flag: WFBE_C_AICOM_MHQ_MINADV_RELAX_SKIP default 1 (live-armed).*

**AI teams don't freeze in place anymore when a headless client disconnects**
When a headless client (HC) drops, the game engine hands its AI units back to the server, but the mission kept believing those teams were still HC-driven - so the commander kept issuing orders to a channel nobody was listening to, and that side's affected teams sat idle until an unrelated background check happened to catch and recycle them a few minutes later. Those teams are now demoted to server control within seconds of the disconnect, so an HC drop no longer stalls out a chunk of that side's AI.

*Server_OnPlayerDisconnected.sqf demotes wfbe_aicom_hc on HC drop and clears any sticky town-HC ownership; AI_Commander_Execute.sqf/AI_Commander_AssignTowns.sqf add a defense-in-depth demote whenever a flagged team's leader is already server-local; server_hcreg_heal.sqf's identity-based (not group-based) registration heal is re-landed. Flag: unflagged demote fix; the re-landed registry heal rides the existing WFBE_C_HCREG_HEAL default 1 (live-armed).*

**Re-tasked AI teams actually move on their new orders instead of standing still**
Any AI team given a second set of orders - an AICOM re-dispatch to a new town, a human commander re-aiming a server-local team, a town-defense sortie getting re-tasked, or a patrol handed a fresh corridor - could have its new waypoints laid but never made active, so the team just stood at its old position looking idle even though its orders had changed underneath it. The new orders now take effect every time, not just on a team's very first assignment.

*AI_WPAdd.sqf: activation gate changed from `_WPCount == 0` (never true on a re-lay, since the previous order-clear leaves a residual index-0 waypoint) to `_forEachIndex == 0` (fires on the first node of every new order batch), matching the sibling fix already shipped in Common_WaypointsAdd.sqf.*

**A team pulled off an attack to save a town under threat no longer gets falsely punished for it**
When the commander diverts an attacking team to relieve a friendly town under attack, it used to leave that team's old attack order marked open - so the assault watcher kept counting down the abandoned order's timeout against the relieving team, logged a false stranded-attack warning, and fed a shared failure counter that can trigger a forced recycle of an otherwise healthy team. Diverted teams now have that stale order cleared the moment they're sent to relief, so responding to a threatened town no longer risks that team getting wrongly recycled later.

*AI_Commander_Strategy.sqf reactive-defense divert now clears wfbe_aicom_townorder/wfbe_aicom_dispatch_open at the divert site, matching the existing clear in AI_Commander_AssignTowns.sqf's FOOT_STAGE re-task.*

**Stalled attack fronts will be able to widen their target search once this is switched on**
In the same match, WEST's spearhead target picker cycled the identical 5 towns for roughly 370 ticks straight without ever considering anything farther out. The fix for this is built and shipped in the code, but the flag defaults off, so nothing changes for players yet - once armed, after 3 repeated stalls on the same pool the commander would widen its search radius and ease off the distance penalty so it can break out of a tight, looping front.

*AI_Commander_Strategy.sqf: once wfbe_aicom_spear_stall_hist reaches WFBE_C_AICOM_SPEARHEAD_POOL_EXPAND_AFTER (default 3), FRONTIER_RADIUS is raised to 6000m and FAR_PENALTY dropped to 200 for that side's repick. Flag: WFBE_C_AICOM_SPEARHEAD_POOL_EXPAND default 0 (dark - not active in the current build until armed).*

## Base economy & building

**Base buildings no longer get blocked red by an unrelated defense-slot shortage**
Opening the build menu to place a normal base structure (Barracks, Factory, Vehicle Service Point, etc.) could paint the placement ghost red and refuse to build - even on clear, flat, tree-free ground with funds available - simply because the separate defense-turret slot pool happened to be empty. That check now only applies to defense-category items, so base buildings turn red only for their own actual blockers (water, slope, nearby trees, collisions).

*Init_Client.sqf build-menu placement preview: the defense-slot (avail<=0) red-gate now requires _itemcategory != 0, so category-0 base structures skip it; defense categories keep the existing behavior.*

**Captured towns now flip marker color, garrison, and income correctly right away**
Right after capturing a town, the map marker could keep showing the old owner's color, the previous owner's garrison and vehicles could still be sitting there able to re-arm the town seconds later, and the town's income might not get credited to your side's supply. Capture now tears down the old owner's garrison on the flip, keys the marker to the correct town, and makes garrison AI, camp handling, and held-town/income counts all read the new owner consistently the moment ownership changes.

*TownCaptured.sqf: marker keyed off str _town (parity with Init_Markers), capture bounty prefers startingSupplyValue over a possibly-drained live supplyValue; server_town.sqf runs a full old-side garrison teardown (units/vehicles/sortie + lastspawn pointers) on the flip; server_town_ai.sqf, Common_GetTownsSupply/Held/Income.sqf, and Server_SetCampsToSide.sqf switch to 2-arg getVariable sideID reads (fallback WFBE_C_UNKNOWN_ID) so a nil/unset town never resolves to a phantom side.*

**AI commander base economy recovers a Command Center stranded after MHQ relocation**
When the mobile HQ relocates to a new base, the abandoned base's old Command Center used to be permanently protected from the automatic base-economy cleanup even after a working replacement existed near the new HQ - quietly eating into the Command Center cap and starving the new base's rebuild. The cleanup worker can now sell that stranded Command Center once a working one exists near the current HQ, refunding supply and freeing the slot for the new base.

*AI_Commander_BaseSell.sqf: Pass-1 stranded-structure sell now protects only Headquarters (not CommandCenter); Pass-2 duplicate-trigger sell still protects both. Runs under the already-armed WFBE_C_AICOM_BASE_SELL_ENABLE and WFBE_C_AICOM_SELL_STRANDED workers (both default 1 / live), so this takes effect immediately with no new flag.*

**Wider, randomized fallback when the game can't find open ground to place something**
The shared 'find an empty spot near this point' helper - used for AI-commander base/artillery placement, town garrison spawns, and patrol tasking - used to burn all 1000 tries at one fixed search radius and, on total failure, fall back to the exact same fixed offset every time, which could stack multiple things on top of each other in crowded spots like a base after repeated relocations. It now widens the search across four progressively larger radius bands, and even the last-resort fallback position is randomized instead of a fixed corner, cutting down on placement pileups.

*Common_GetEmptyPosition.sqf: single fixed-radius 1000-attempt loop replaced with four 250-attempt bands at 1x/1.5x/2x/2.5x the requested radius; every failed attempt now updates the returned candidate, so the eventual fallback is randomized rather than the old static (_object+5, +5, 0) point. Same 3-element return contract; all call sites (AI_Commander_Base.sqf, server_town.sqf/server_town_ai.sqf, Common_RunCommanderTeam.sqf, Common_RunSidePatrol.sqf, Init_IcbmTel.sqf, Common_CreateTownUnits.sqf) unaffected.*

**Stranded base-artillery recycle after MHQ relocate (ships off by default)**
Commander SPGs (mobile artillery) left behind at an abandoned base after an MHQ relocation could permanently freeze the side's 2/2 artillery cap for hours, since they live outside the normal structure-sell tracking and the base-economy cleanup never touched them. A new worker can sell one stranded piece per tick - preferring pieces clustered with other abandoned old-base structures, refunding commander funds, and clearing the crew - but it ships disabled by default, so nothing changes for players until this is turned on.

*AI_Commander_BaseSell.sqf Pass-3, new flag WFBE_C_AICOM_ARTY_SELL_STRANDED (default 0). Identifies WFBE_CommanderArtillery pieces farther than WFBE_C_AICOM_ARTY_SELL_STRANDED_DIST (default 1500m, floored at base radius) from the current HQ; sells the farthest qualifying piece, refunds via ChangeAICommanderFunds, deletes crew, and prunes wfbe_aicom_arty_reg.*

## GUER / insurgents

**GUER Quick Reaction Force gunships can now roll different airframes (opt-in, off by default)**
Every GUER "QRF gunship" and "QRF combo" contract used to spawn the exact same helicopter - a Mi-24P Hind, 174 times out of 174 sampled contracts in the RPT deep-dive, no exceptions. The commander panel now has a configurable pool that can roll a Ka-60 gunship or armed Ka-60 transport instead of the Hind, with gunners crewed correctly on whichever hull comes up. This build ships the mechanism but leaves it switched off, so QRF gunships will still look identical to before until the pool is armed.

*WFBE_C_GDIR_QRF_AIRFRAME_POOL (default 0) + WFBE_C_GDIR_QRF_GUNSHIP_POOL array; Server_GuerDirector.sqf QRF_FIRE/qrfCombo dispatch picks a CfgVehicles-validated class instead of hardcoded "Mi24_P", crews a gunner on any non-Ka137 hull, and logs the actual spawned class instead of always logging "Mi24_P". PR #1652.*

**Fix wired (but not yet turned on) for GUER reinforcement cells piling into the same two towns**
Analysis of a 13.5-hour live match found 35.5% of the insurgency's town-to-town reinforcement transfers (moveCell orders) were landing on just 2 of the map's 46 towns, while every other depleted GUER garrison went unreinforced. A shuffle-and-soft-cap mechanism is now in place: it randomizes which depleted town gets picked each tick and blocks a town from hogging more than 45% of its baseline strength in pending transfers, forcing surplus to spread. Like the gunship pool above, this ships dark in this build - GUER reinforcement will keep favoring the same towns until the flag is armed.

*WFBE_C_GDIR_CELL_SPREAD (default 0) + WFBE_C_GDIR_CELL_SPREAD_TRANSIT_FRAC (0.45); Server_GuerDirector.sqf Fisher-Yates shuffles the depleted/threatened/surplus/safe town lists and the source-order list each planning pass, and skips a destination for that tick once its pending inbound exceeds transitFrac x baseline strength. PR #1653.*

## New feature: spectator mode

**New: admin spectator camera for casting and match oversight**
An allowlisted admin (currently one owner Steam64 ID) can now take a "Spectator Camera" action from their own alive body - parking it invulnerable, non-hostile, and frozen in place - and switch to a free-flying camera to watch the match from anywhere on the map: mouse-look, WASD fly, wheel zoom, Shift boost / Alt precision, N/B to cycle through alive players as a watch target, F for an 8m chase/follow-cam on that target, V to see through their eyes, H to hide the on-screen hint for clean recording, and Backspace to exit instantly. For everyone else nothing changes - the action is invisible unless your Steam64 is on the allowlist, and the parked body just looks like an AFK player standing still (it cannot be shot or trigger AI aggro while spectating). This is a client-side visibility gate under normal Arma locality, not a real access-control boundary, so it's a caster/admin convenience tool, not a security feature - and it never touches respawn, JIP, or enrollment logic.

*Client_SpectatorEnter/Exit/Attach.sqf (mouse-look, follow/eyes modes, UID-gated addAction); flag WFBE_C_SPECTATOR default 1, allowlist WFBE_C_SPECTATOR_UIDS; PR #1594 baseline.*

**Fix: spectating right after a respawn no longer strips your invulnerability mid-flight**
If the admin opened spectator mode within the ~2-minute post-respawn grace window, the watchdog that turns off deadspawn invulnerability on a timer used to fire anyway and strip protection off the parked body while the admin was off flying the camera elsewhere - leaving their real body shootable without them watching it. The watchdog now checks whether spectator mode is still active and holds off restoring damage until they actually exit.

*Init_Client.sqf deadspawn-escaped watchdog (both live/HC-lock code paths) now skips `allowDamage true` while WFBE_C_VAR_SpectatorActive is true. Rides WFBE_C_SPECTATOR default 1 (PR #1594).*

**Fix: dying while spectating now hands the camera back cleanly instead of risking a stuck view**
No visible change for regular players. For the admin: if the parked spectating body ever died, the game used to build the normal death camera on top of the still-active spectator camera without tearing the spectator session down first, risking a stuck or conflicting view. Death now explicitly exits spectator mode before the death camera sets up, so control hands back the same clean way it does for a normal death.

*Client_OnKilled.sqf calls WFBE_CL_FNC_SpectatorExit before death-camera setup whenever WFBE_C_VAR_SpectatorActive is true. Rides WFBE_C_SPECTATOR default 1 (PR #1594).*

## UI & quality of life

**Command deck header no longer covers your funds and team roster**
Opening the Command menu used to draw the war-room header bar (the STRATEGY/zone title strip) right across the FUNDS readout and the YOUR TEAMS roster title, making both unreadable while the deck was up. The header now sits in the left footer strip instead, and the two decorative zone labels that were causing the overlap stay hidden - funds and your team list are legible every time you open the deck.

*WFBE_C_CMD_DECK header control 14700 repositioned to the left footer (y=0.951); labels 14701 ("SITUATION MAP") and 14703 ("FORCES") remain in the hidden set. GUI_Menu_Command.sqf + Dialogs.hpp, CH/TK/ZG mirrored. Flag: WFBE_C_CMD_DECK default 1 (Command Deck itself already live since 2026-07-28; this is a display-collision fix within it).*

**Backpack contents no longer leak between players when editing gear**
Adding or removing items from a backpack in the Buy Gear menu was writing straight into the shared source data instead of a private copy - the same array backed that backpack class's default contents, any saved gear template, and a unit's stored custom loadout. That meant one player's backpack edit could quietly bleed into what other players saw as the "default" contents of that backpack, or into a saved template, for the rest of the match. Backpack edits now stay isolated to your own purchase.

*Added a _bpCopy deep-copy helper applied at every load/store site in GUI_BuyGearMenu.sqf; case 200 (equip new backpack) previously took no copy at all. CH/TK/ZG mirrored.*

**Fixed TEL strikes that could land on the wrong target, and DISBAND that could hit the wrong team**
TEL FASCAM/Steel Rain/Bunker Buster fire used a shared confirmation key instead of one tied to your actual map click, so clicking one TEL strike type then quickly clicking another within the 6-second confirm window could fire the second strike under the first one's confirmation - landing somewhere you never aimed. Command Console's DISBAND SELECTED had the same problem: it only checked a timer, so reselecting a different team mid-confirm could disband a team you never actually confirmed. Both now require the same target/team on both clicks, so switching selections mid-window re-arms the confirmation instead of misfiring.

*TEL FASCAM/STEELRAIN/BUSTER now key ConfirmAction on _mapAimKey like ICBM/SCUD/SAT/RECON already did (GUI_Menu_Tactical.sqf); DISBAND SELECTED now checks roster-index identity (_disbandSelIdx) alongside the arm timestamp (GUI_Menu_Command.sqf). CH/TK/ZG.*

**Fixed a possible error buying certain naval carriers**
Buying some carrier-type vehicles rolls a random EASA equipment preset for the ship; if that ship class had no presets configured, the purchase could throw a script error instead of completing cleanly. Those carrier buys now just skip the random-preset step when the list is empty.

*Client_BuildUnit.sqf now requires a non-empty ARRAY before floor(random count) + EASA_Equip on the naval EASA preset pick. CH/TK/ZG.*

**AI town garrisons, patrols, and PMC defenders spawn more completely**
Several server-side AI spawn paths could quietly come up broken: some town garrison spawns could produce empty groups with no actual units, a HugeTown heavy-AA spawn was tagged as infantry instead of a vehicle (so it never acted like AA), leftover infantry that didn't fit a template could be dropped on the ground instead of riding in a vehicle's spare cargo seats, patrol routes could fail to resolve correctly when hosted on a Headless Client, and several PMC squad types were missing from the pool available to defending towns. Net effect: garrisons, patrols, and PMC defenses at towns spawn as intended more often - AA vehicles behave as AA, HC-hosted patrols actually patrol, and defended towns draw from the full PMC roster instead of a thinned one.

*Server_GetTownGroups.sqf/Server_GetTownGroupsDefender.sqf guard against malformed GROUP variants; HugeTown AA_Heavy kind changed 0->1; Common_CreateTeam.sqf seats leftover infantry into free cargo; server_side_patrols.sqf resolves PATROL string keys server-side before HC dispatch; Groups_PMC.sqf adds Team_MG/Squad_Advanced/Squad_Contractor to the defender pool. CH/TK/ZG.*

## Under the hood

**Fixed a false "off-map" kill along the map's center lines**
If you were moving directly along the map's north-south or east-west centerline, the boundary system could wrongly decide you were outside the play area and kill you even though you were well inside it. That false trigger is gone.

*Client_IsOnMap.sqf + Common_DeadspawnPenPos.sqf: replaced atan/cos edge-ray boundary math (div-by-zero on axis-aligned rays through map centre) with a simple square AABB [0..boundary]^2 test.*

**Town garrisons no longer get wiped as collateral during unrelated cleanup**
The check meant to skip AI groups belonging to a different town or side during headless-client cleanup never actually worked - it deleted whatever it was checking regardless of match. A town's defenders could vanish from a cleanup pass that had nothing to do with that town; now the guard actually protects them.

*Client_CleanupDelegatedTownAI.sqf: WFBE_TownAI_Town / WFBE_TownAI_Side mismatch checks used exitWith nested inside then{}, which only left the then-block and fell through to deleteVehicle; rewritten as top-scope exitWith per check.*

**Helicopter cargo-hook speed/height safety gate actually blocks unsafe hooks now**
The "too fast or too low to hook" rejection on the Zeta cargo hook wasn't actually stopping anything - you could hook a vehicle while flying over 20 speed or under 2m, conditions the game was supposed to refuse. The rejection now really aborts the attach.

*Zeta_Hook.sqf: speed/height exitWith checks were nested inside then{}/else{} (only exits that block, falls through); rewritten as top-scope exitWith conditions.*

**Multiple players caught in the same radiation zone all get the warning now**
When two or more players were irradiated in the same tick, the shared global variable used to trigger the radiation sound/effect could collide, so only the last player processed reliably got the cue. Now each irradiated player gets their own direct delivery.

*radzone.sqf: switched the global publicVariable "PLAYER_RADIATED" broadcast to a targeted (owner _x) publicVariableClient per irradiated player.*

**Salvaged wrecks near headless-client sectors are actually removed now**
Salvaging a vehicle wreck with a repair truck in an area managed by a headless client used to pay you and post the "Salvaged Unit" chat message, but the wreck itself silently stayed on the map forever since the delete never reached the machine that owned it. It's properly cleaned up now.

*updatesalvage.sqf: deleteVehicle on a non-local wreck was a silent no-op; now deletes locally when owned, or dispatches Server_HandleSpecial "salvage-delete-wreck" -> cleanup-trash-object to the owning machine.*

**UAV terminal requests fail cleanly instead of erroring**
Trying to launch a UAV with no valid command center to source it from used to fall through into the "assign UAV" logic on nothing, which could throw script errors or leave the terminal stuck. It now just does nothing, as intended, when there's no valid launch point.

*uav.sqf: bare exitWith inside an else{} branch fell through into crew/assignment logic on an unset _uav; restructured with a top-scope exitWith wrapping the whole request attempt.*

**Commander title no longer flickers from every client rewriting it**
Assigning a commander used to have every client on that side push their own copy of the commander onto the shared, networked value - a possible source of the commander name briefly flickering or showing wrong, plus needless network traffic every time it fired.

*Client_FNC_Special.sqf WFBE_CL_FNC_Commander_Assigned: dropped the public (broadcast) setVariable of wfbe_commander from clients; server remains sole public owner, clients set the value locally only for their own UI/chat text.*

**Server-triggered kills and artillery counter-fire stop going silent on dedicated servers**
Invisible but load-bearing: on a dedicated server, events the server itself originated (like registering a kill on a server-owned AI unit, or triggering artillery counter-battery) were silently dropped before reaching the server's own handling logic. They now actually go through.

*Common_SendToServer(Optimized).sqf: isHostedServer is false on dedicated, so publicVariable(Server) from the server never fired the server's own event handler; isServer now calls WFBE_SE_FNC_HandlePVF directly, clients/HC still use PVS.*

**AI-side supply income and charges are switched on by default**
Mostly invisible economy plumbing: supply changes that originate on the server rather than from a direct player action were dropped by default, so some AI-side income/expense updates never landed. That repair path is now on by default, so AI supply tracking should be more consistent over the course of a match.

*Init_CommonConstants.sqf: WFBE_C_SUPPLY_SERVER_FIX default flipped 0 (Off/no-op) -> 2 (Apply), routing server/AI-originated ChangeSideSupply calls through the already-proven direct-call repair.*

**Artillery range readout stops breaking when the range-scaling option is off**
Config-dependent edge case: if a server admin set the artillery range-scaling parameter to 0, the in-game artillery menu's range display and the AI's counter-battery range check could compute garbage instead of a real number. That's now clamped to a sane value.

*Common_FireArtillery.sqf / GUI_Menu_Tactical.sqf / AI_Commander_Strategy.sqf: range-max division by WFBE_C_ARTILLERY guarded with (WFBE_C_ARTILLERY max 1); FireArtillery also clean-exits when the value is <=0 (Disabled).*

**Shell placement math guarded against extreme or point-blank artillery ranges**
Edge case in artillery shell scatter: if a gun's max range or its distance to target computed out to zero, the impact-area math could go haywire. Landing-area and scatter calculations now fall back to a safe divisor instead.

*Common_HandleArtillery.sqf: guarded maxRange (Randomize Land Area distance calc) and distance (shell spawn-area percent calc) with a `max 1` floor before dividing.*

**Countermeasure flares won't silently fail to eject**
Rare edge case where a launched flare's direction math could zero out and produce a broken trajectory instead of a proper decoy launch. Flares now always get a valid velocity.

*CM_Flares.sqf: guarded the launcher-to-target direction vector sum before it's used as a divisor for flare velocity; near-zero sum now defaults instead of producing NaN.*

**Rejected supply-change payloads now actually get blocked**
Security-adjacent and invisible: when the optional payload-hardening check is enabled, a supply-change request flagged as suspect (bad, null, or wrong-side requester) was logged as rejected but applied anyway. A rejection now actually stops the write.

*Server_ChangeSideSupply.sqf: WFBE_C_SEC_HARDENING reject checks used exitWith nested in then{} (only aborts that check, falls through to apply); rewritten with a _rejected latch and a single top-scope exitWith.*

**AI oilfield targeting no longer stacks unbounded weight on the same town**
Invisible economy tuning: the AI commander's pull toward an oilfield town it was already targeting kept re-adding weight every tick instead of staying flat once set, which fed into the kind of fixated, lopsided AI targeting players have noticed in long matches.

*Server_Oilfields.sqf WFBE_FNC_OilfieldApplyPull: same-town no-op check was nested inside then{}, so exitWith only left that block and fell through to re-adding AICOM pull weight every tick; now a top-scope exitWith for the same-town case.*

## Known issues / not in this build

- **PR #1602 (reman refactor)** - deliberately held out of m0730b for its own dedicated soak; not merged.
- **Reforger port map/deploy-screen issues** - tracked in the separate Reforger-waspwarfare project, not part of this Chernarus Arma 2 build.
- **Scheduler audit, 9 medium findings** - not yet fixed in this build. This build addresses the deadlock/TOCTOU class the audit flagged (see Server stability & crashes), but the 9 medium-severity findings from that audit remain open.
- **Artillery finding** - landed as code, not as behavior. The stranded commander-SPG recycle (Base economy & building) required its own registry work (`wfbe_aicom_arty_reg` tracking in `AI_Commander_BaseSell.sqf` Pass-3), which is done and shipped, but the feature ships behind `WFBE_C_AICOM_ARTY_SELL_STRANDED` default 0 - dark until an admin arms it.

## For admins

New/changed flags in this build (defaults as shipped):

- `WFBE_C_SPECTATOR` = 1 (live-armed) + `WFBE_C_SPECTATOR_UIDS` allowlist (currently one owner Steam64 ID) - admin spectator camera.
- `WFBE_C_AICOM_MHQ_MINADV_RELAX_SKIP` = 1 (live-armed) - lets MHQ relocation skip the 1500m min-advance gate on relaxed-ring candidates.
- `WFBE_C_AICOM_POSTURE_HYST_ENABLE` = 1 (live-armed) - DEFEND/PRESS posture hysteresis (180s dwell, 0.8/0.65 LOSING_PRESS band).
- `WFBE_C_SUPPLY_SERVER_FIX` flipped 0 -> 2 (Apply, live) - routes server/AI-originated supply changes through the direct-call repair.
- `WFBE_C_AICOM_SPEARHEAD_POOL_EXPAND` = 0 (dark, not armed) - stalled-front target-pool widening.
- `WFBE_C_GDIR_QRF_AIRFRAME_POOL` = 0 (dark, not armed) - GUER QRF gunship airframe variety.
- `WFBE_C_GDIR_CELL_SPREAD` = 0 (dark, not armed) - GUER reinforcement-cell shuffle/soft-cap.
- `WFBE_C_AICOM_ARTY_SELL_STRANDED` = 0 (dark, not armed) - stranded commander-SPG recycle.

Unflagged fixes riding existing armed switches: `WFBE_C_HCREG_HEAL` (default 1, live) covers the re-landed HC registry heal; `WFBE_C_AICOM_BASE_SELL_ENABLE` / `WFBE_C_AICOM_SELL_STRANDED` (both default 1, live) cover the Command Center stranded-structure sell; `WFBE_C_CMD_DECK` (default 1, live since 2026-07-28) is unchanged - the header-overlap fix is a display change within it, not a new flag.

Rollback: previous PBO and config backup retained on the box.

TK/ZG rotations still run m0728i until their PBOs ride the next wave.
---

# Hotfix m0730c (2026-07-30, same day)

Two owner-reported regressions from the m0730b session, both root-caused rather than patched around.

**Spectator mode never appeared in the scroll menu**
The spectator action was in the build and the owner's UID was allowlisted, but the scroll entry never showed for anyone. Cause: `WFBE_gameover` is read in six places across the mission and **assigned nowhere** - so `Client_SpectatorAttach.sqf`'s very first statement (`while {!WFBE_gameover}`) threw an undefined-variable error and killed the attach thread before it could add a single action. Every spectator read now goes through `missionNamespace getVariable ["WFBE_gameover", false]`.

*Same latent bug silently kills the client name-tag loops and three AICOM guard loops (Common_AICOM_HeliTerrainGuard, Common_AICOM_SmallArmsAirEnvelope, server_heli_terrain_guard) - those are carded separately and deliberately untouched in this hotfix.*

**Command war room: overlapping, unreadable controls**
The Console Deck redesign (armed 07-28) *removes* the eight legacy order buttons from the show-set instead of hiding them - so `ctrlShow` is never called for those controls and they render in **both** commander and advisory states, stacked on top of the advisory layer. A same-day attempt to relocate the deck header out of the title band then landed it on top of the footer action buttons instead. The deck flag now defaults to 0, restoring the pre-deck war room (pixel-identical per the dialog's own contract). The tabbed Console Deck the owner asked for gets a proper rebuild in its own lane: explicit legacy-control hiding plus real tab groups, not overlay-on-overlay.

*Init_CommonConstants.sqf: WFBE_C_CMD_DECK default 1 -> 0. Set to 1 to see the half-built deck; not recommended until the rebuild lands.*

## For admins (m0730c)
- `WFBE_C_SPECTATOR` = 1, `WFBE_C_SPECTATOR_UIDS` = owner UID. Scroll menu -> "Spectator Camera". Controls: mouse look, wheel FOV, WASD/Space/Ctrl fly, Shift boost, Alt crawl, N/B cycle targets, F follow-cam, V through-their-eyes, H hide overlay, Backspace exit.
- `WFBE_C_CMD_DECK` = 0 (was 1).
- Rollback: `m0730b` PBO + `server-pr8.cfg.bak-m0730c` retained on the box.

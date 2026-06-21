# Mission Audio Catalog

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted (other roots: Server/, Common/, Client/). Arma 2 OA 1.64.

The mission ships its own audio outside the vanilla addons: a `CfgSounds` registry in `Sounds/description.ext` and a two-track `CfgMusic` registry in `Music/description.ext`. This page enumerates every defined class, its volume (the second element of `sound[]`), and the exact gameplay callsite that fires it via `playSound` / `playMusic` / `say`. The Assets-Config-Localization-And-Parameters-Atlas only counts these (26 sound classes, 2 music tracks) and notes the `airRaid` bug; it does not enumerate them per-class, so this is the catalog.

Two definition facts up front: the *BuildSound factory jingles are still defined in `Sounds/description.ext` but every one of their `playSound` callsites is commented out (`Client/Functions/Client_FNC_Special.sqf:149-173`, "factory build jingles too intrusive", owner 2026-06-11), so they never play. And two classes are referenced by code but missing from the registry: `airRaid` (`Client/PVFunctions/NukeIncoming.sqf:7`) and `upgradeStartedSound` (`Client/Functions/Client_FNC_Special.sqf:136`).

## CfgSounds (Sounds/description.ext)

The registry opens with `sounds[] = {}` (`Sounds/description.ext:4`); each class declares `name`, `sound[]={path, db, pitch}` and empty `titles[]`. The db column below is the literal second element of `sound[]`. Most callsites use the `playSound [name, true]` array form (the `true` = duplicate/3D-positional flag); a few use the bare-string form.

| CfgSounds class | file / db | trigger callsite (path:line) |
|---|---|---|
| `aaRadarBuildSound` | aaRadarBuildSound-7.ogg / 7 | `Client/Functions/Client_FNC_Special.sqf:173` — COMMENTED OUT (never plays) |
| `aircraftFactoryBuildSound` | aircraftFactoryBuildSound-7.ogg / 7 | `Client/Functions/Client_FNC_Special.sqf:165` — COMMENTED OUT (never plays) |
| `barracksBuildSound` | barracksBuildSound-7.ogg / 7 | `Client/Functions/Client_FNC_Special.sqf:149` — COMMENTED OUT (never plays) |
| `commandCenterBuildSound` | commandCenterBuildSound-7.ogg / 7 | `Client/Functions/Client_FNC_Special.sqf:157` — COMMENTED OUT (never plays) |
| `heavyFactoryBuildSound` | heavyFactoryBuildSound-7.ogg / 7 | `Client/Functions/Client_FNC_Special.sqf:161` — COMMENTED OUT (never plays) |
| `lightFactoryBuildSound` | lightFactoryBuildSound-7.ogg / 7 | `Client/Functions/Client_FNC_Special.sqf:153` — COMMENTED OUT (never plays) |
| `servicePointBuildSound` | servicePointBuildSound-7.ogg / 7 | `Client/Functions/Client_FNC_Special.sqf:169` — COMMENTED OUT (never plays) |
| `ARTY_cooldown_over` | ARTY_cooldown_over-8.ogg / 8 | `Client/Functions/Client_RequestFireMission.sqf:88` (arty ready again); `Client/Functions/Client_FNC_Special.sqf:242`; `Client/FSM/updatetownmarkers.sqf:31` (SpecOps supply cooldown expiry) |
| `ARTY_message_to_friendly_players_v2` | ARTY_message_to_friendly_players_v2-8.ogg / 8 | selected as `_audio_message` for American/west @ `Client/Functions/Client_RequestFireMission.sqf:55,58`, dispatched via `WF_sendMessage` → `Common/Functions/Common_SendMessage.sqf:31` |
| `ARTY_message_to_friendly_russian_v1` | ARTY_message_to_friendly_russian_v1-8.ogg / 8 | selected for Russian/east @ `Client/Functions/Client_RequestFireMission.sqf:57`, played via `Common/Functions/Common_SendMessage.sqf:31` |
| `ARTY_message_to_friendly_takistanish_v1` | ARTY_message_to_friendly_takistanish_v1-8.ogg / 8 | selected for Takistani/east @ `Client/Functions/Client_RequestFireMission.sqf:56`, played via `Common/Functions/Common_SendMessage.sqf:31` |
| `attackMode` | attackMode-7.ogg / 7 | `Client/PVFunctions/LocalizeMessage.sqf:12` (AttackModeActivated) and `:13` (AttackModeActiveJIP) |
| `autoViewDistanceToggledOff` | autoViewDistanceToggledOff-1.ogg / 1 | `Common/Functions/Common_AdjustViewDistance.sqf:23`; `Common/Functions/Common_AutoSendSpawnedUnitsToWaypoint.sqf:14` |
| `autoViewDistanceToggledOn` | autoViewDistanceToggledOn-1.ogg / 1 | `Common/Functions/Common_AdjustViewDistance.sqf:31`; `Common/Functions/Common_AutoSendSpawnedUnitsToWaypoint.sqf:18` |
| `Bipod_ON` | Bipod_ON-10.ogg / 10 | `Common/Functions/Common_Bipod.sqf:54` via `player say "Bipod_ON"` (note: `say`, not `playSound`) |
| `cashierSound` | cashierSound-7.ogg / 7 | `Client/PVFunctions/LocalizeMessage.sqf:68` (FundsTransfer) `playSound ["cashierSound", true]` |
| `commanderNotification` | commanderNotification-10.ogg / 10 | `Client/FSM/updateclient.sqf:243` (new commander); `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf:22` (supply run reward) |
| `newCommander` | newCommander-10.ogg / 10 | `Client/FSM/updateclient.sqf:244` (fired alongside `commanderNotification` when player becomes commander) |
| `ICBM_message_to_enemy_players` | ICBM_message_to_enemy_players-10.ogg / 10 | `Client/Module/Nuke/ICBM_EnemySide_Message.sqf:20` → `WF_sendMessage` → `Common/Functions/Common_SendMessage.sqf:31` |
| `ICBM_message_to_friendly_players` | ICBM_message_to_friendly_players-10.ogg / 10 | `Client/Module/Nuke/ICBM_friendlySide_Message.sqf:20` → `WF_sendMessage` → `Common/Functions/Common_SendMessage.sqf:31` |
| `inbound` | inbound-10.ogg / 10 | `Common/Functions/Common_HandleAlarm.sqf:11` (loop, 0.55s); `Common/Module/IRS/IRS_PlayWarningSound.sqf:9`; `Client/PVFunctions/CampCaptured.sqf:50` (repair case) |
| `inboundMissileGround` | inboundMissileGround-10.ogg / 10 | `Common/Module/IRS/IRS_OnIncomingMissile.sqf:37` |
| `inboundMissileGround_cont` | inboundMissileGround_cont-10.ogg / 10 | `Common/Module/IRS/IRS_OnIncomingMissile.sqf:45` |
| `MissileLaunchBlocked` | MissileLaunchBlocked-2.ogg / 2 | `Common/Functions/Common_HandleShootMissiles.sqf:140` (guided missile fired while terrain-masked) |
| `radiationSound` | radiationSound-5.ogg / 5 | `Client/Module/Nuke/OnEventHandler_player_radiated.sqf:18` |
| `SidewinderLock` | SidewinderLock-1.ogg / 1 | `Client/Init/Init_Client.sqf:1018` (missile lock authorized, throttled by `_lockSoundInterval`) |

### Referenced-but-undefined sound classes (bugs)

| Referenced class | callsite (path:line) | status |
|---|---|---|
| `airRaid` | `Client/PVFunctions/NukeIncoming.sqf:7` `playSound ["airRaid",true]` | NO `class airRaid` in `Sounds/description.ext` — warning sound silently fails. Also flagged in the Atlas (`:95`). |
| `upgradeStartedSound` | `Client/Functions/Client_FNC_Special.sqf:136` `playSound "upgradeStartedSound"` | NO `class upgradeStartedSound` in `Sounds/description.ext`. The inline comment (`:134`) describes it as a quiet alias of `commanderNotification`, but the class was never added — the upgrade-started cue is silent. |

## CfgMusic (Music/description.ext)

Two tracks are declared (`Music/description.ext`); `tracks[] = {}` opens the class (`:3`). Volume uses the `db + N` form. Note the class/file mismatch on `wf_outro`: the class is named for an outro but its file is `wf_intro_2_7.ogg`.

| CfgMusic track | display name | file / volume (path:line) | played at (path:line) |
|---|---|---|---|
| `wf_outro` | Warfare Victory OST | `\Music\wf_intro_2_7.ogg`, `db + 10` (`Music/description.ext:4-11`) | `Client/Client_EndGame.sqf:16` `playMusic _track` where `_track = "wf_outro"` (`:15`) — the victory/end-of-game music |
| `cherna_intro` | Cherna Intro OST | `\Music\cherna_intro_1.ogg`, `db + 1` (`Music/description.ext:13-20`) | DEFINED but no `playMusic "cherna_intro"` callsite found in Client/ Common/ Server/. The only other `playMusic` (`Client/Init/Init_Client.sqf:829`) is itself commented out and references the vanilla `Track11_Large_Scale_Assault`, not this track. |

Only `wf_outro` is actually played. `cherna_intro` is registered but never triggered by mission code (likely intended as a startup/intro cue that was disabled). The old end-game track selection at `Client/Client_EndGame.sqf:14` (commented out) referenced vanilla `Track21_Rise_Of_The_Fallen` / `EP1_Track15`; it was replaced by the custom `wf_outro` ("changed-MrNiceGuy", `:15`).

## Notes on dispatch plumbing

- The ARTY_message_* and ICBM_message_* classes are never named in a literal `playSound` line; they are passed as a `_messageSoundName` argument into `WF_sendMessage` (bound to `Common\Functions\Common_SendMessage.sqf` at `Common/Init/Init_Common.sqf:169`), which calls `playSound [_messageSoundName, true]` (`Common/Functions/Common_SendMessage.sqf:31`) only for clients whose `playerSide` matches the target side. A second copy of the same dispatcher exists at `Client/Functions/Client_onEventHandler_SEND_MESSAGE.sqf:33`.
- `inbound` is the most-reused class: missile-alarm loop, IRS warning loop, and the camp-captured repair cue all share it.

## Continue Reading

- [Assets-Config-Localization-And-Parameters-Atlas](Assets-Config-Localization-And-Parameters-Atlas) — the umbrella counts for sounds/music/titles and the `airRaid` bug entry.
- [LocalizeMessage-Chat-Notification-Router-Reference](LocalizeMessage-Chat-Notification-Router-Reference) — the message router that fires `cashierSound`/`attackMode`.
- [Victory-And-Endgame-Atlas](Victory-And-Endgame-Atlas) — the end-of-game flow that plays `wf_outro`.
- [ICBM-Nuke-Client-VFX-And-Radiation-Reference](ICBM-Nuke-Client-VFX-And-Radiation-Reference) — the nuke client path behind `radiationSound` and the missing `airRaid`.
- [Artillery-Firing-Function-Reference](Artillery-Firing-Function-Reference) — the fire-mission flow that selects the per-faction ARTY message audio.

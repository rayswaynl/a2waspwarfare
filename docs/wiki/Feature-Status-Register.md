# Feature Status Register

This register separates working systems from partial, deferred or risky systems found during indexing.

## Working / Active Systems

- Core Warfare loop: towns, commanders, bases, factories, upgrades, resources and victory checks.
- Client/server/common initialization split.
- Generic PVF request/response system.
- Player supply-truck missions on `master`.
- Enhanced day/night cycle with server authority and client smoothing.
- Server FPS publishing and RHUD/FPS HUD.
- Performance audit instrumentation plus analyzer.
- Anti-stack module with optional mission parameter.
- AFK kick through BattlEye publicVariable filter.
- MASH/ambulance respawn support; MASH marker synchronization is listed below as broken.
- ICBM/radiation module.
- EASA aircraft loadout module.
- Client marker blinking guarded by parameter.
- LoadoutManager mission copy/generation workflow.
- Discord bot status updates from exported game data.

## Partial / Deferred / Needs Review

| Area | Evidence | Status |
| --- | --- | --- |
| Autonomous AI supply trucks | `UpdateSupplyTruck` compile is commented at `Server/Init/Init_Server.sqf:36`, but the live call `[_side] Spawn UpdateSupplyTruck;` remains at `:383`, gated by `WFBE_C_ECONOMY_SUPPLY_SYSTEM == 0 && WFBE_C_AI_COMMANDER_ENABLED > 0`. `AI_UpdateSupplyTruck.sqf` also references missing `Server/FSM/supplytruck.fsm`. | Config-gated latent breakage. Default supply system 1 is safe; supply system 0 with AI commanders is broken until the compile and FSM are restored or redesigned. |
| AI commander automation | AI commander constants and side-logic state/funds exist, but the server runtime pass found no live AI commander FSM/loop that sets `wfbe_aicom_running = true`. | Partial/latent. Treat AI commander production and autonomous logistics as unimplemented until a runtime owner is restored. |
| Task system | `TaskSystem` compile and `TownAddComplete` spawn are commented in `Client/Init/Init_Client.sqf` though `Client_TaskSystem.sqf` still exists. | Disabled/partial. Re-enable only after checking task spam/JIP behavior. |
| MASH marker receiver | `receiverMASHmarker.sqf` (registers the `WFBE_SE_MASH_MARKER_SENT` client EH) is referenced **only** by the commented compile at `Client/Init/Init_Client.sqf:132`; the server re-broadcast (`Server/Module/MASH/MASHMarker.sqf`) is live. | **Confirmed broken (receiver never registered)** → MASH map markers never appear; MASH respawn itself is independent. See [Deep-review findings](Deep-Review-Findings) DR-3. |
| Paratrooper drop markers | `Server/Support/Support_Paratroopers.sqf:117` sends `HandleParatrooperMarkerCreation`, but it is absent from `_clientCommandPV` in `Init_PublicVariables.sqf` (no EH; `CLTFNC…` never compiled). | **Confirmed broken/dead** on all configs; receiver file exists but is unwired. See [Deep-review findings](Deep-Review-Findings) DR-2. |
| PV dispatch trust boundary | `Server_HandlePVF.sqf`/`Client_HandlePVF.sqf` run `Call Compile` on the sender-chosen command string with no validation; `BattlEyeFilter/publicvariable.txt` has only the `kickAFK` feature rule (no security filter). | **Live-server hardening gap (High).** Validate the command string before compile + add a real BE PV filter. See [Deep-review findings](Deep-Review-Findings) DR-1. |
| PV legitimate-command forgery | Hilbert's network pass confirmed high-trust handlers: `RequestChangeScore.sqf` overwrites score from payload, `RequestVehicleLock.sqf` locks payload vehicles, `RequestTeamUpdate.sqf` mutates team behavior, and `RequestUpgrade.sqf` forwards to upgrade processing without visible sender/cost validation in the handler. | **Live-server hardening gap (High).** Even after replacing dispatcher `Call Compile`, validate sender, role, side, funds, ownership and object locality inside high-impact handlers. |
| Direct publicVariable channels outside PVF | Direct PVEH/PV channels exist for attack waves, side supply, supply missions, MASH markers, HQ state, AntiStack compensation, server FPS, AFK, day/night and marker/message channels. | A PVF dispatcher fix or `WFBE_PVF_*` whitelist does not cover these. Review each channel's sender, lifecycle and JIP semantics before calling networking hardened. See [Networking and public variables](Networking-And-Public-Variables). |
| BattlEye mitigation as shipped | Claude DR-30 verified the repo's BattlEye footprint: `BattlEyeFilter/publicvariable.txt` contains only `5 "kickAFK"` and no `scripts.txt`, `server.cfg`, `basic.cfg` or broader filter bundle exists in-tree. | **High live-server hardening gap.** The "accept client authority and rely on BattlEye" option is not documented source truth unless production BEpath files exist outside the repo. Treat server-side authority as the only shipped remediation path until real filters/configs are supplied. |
| ICBM/Nuke `RequestSpecial` authority | Claude DR-27 traced the Tactical-menu ICBM path: client-side menu gates call `Client/Module/Nuke/nukeincoming.sqf`, which sends `RequestSpecial ["ICBM", ...]`; the server `HandleSpecial` ICBM case spawns `NukeDammage` from client payload without upgrade/commander/funds validation. | **Critical live-server hardening gap.** One forged `RequestSpecial` PV can trigger server-applied map-wide damage. Validate the `"ICBM"` branch server-side and restrict `RequestSpecial` through BattlEye/script filtering before public trust. |
| Construction request authority | `coin_interface.sqf` deducts funds and performs placement checks client-side, then sends `RequestStructure` / `RequestDefense`; server handlers mostly check class existence before creating objects. | Hardening gap. Add server-side checks for commander/repair authority, funds, radius, base-area availability and placement before object creation. See [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas). |
| Player purchase authority | `GUI_Menu_BuyUnits.sqf` calls local `BuildUnit` and deducts funds client-side; `Init_PublicVariables.sqf` has no `RequestBuyUnit`, and no `Server/PVFunctions/RequestBuyUnit.sqf` exists. | Legacy/client-local buy path. Add server validation before adding exploit-sensitive purchases. See [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas). |
| Server `AIBuyUnit` path | `Init_Server.sqf` compiles `AIBuyUnit = Server_BuyUnit.sqf`, but source search only finds the compile and `Server_BuyUnit.sqf` itself. | Latent/unused until a dynamic caller is proven. Decide whether to revive for AI commander production or retire. |
| Commander reassignment call shape | `Server_AssignNewCommander.sqf` assigns `_side = _this`, then `_commander = _this select 1`; `RequestNewCommander.sqf` calls it with `[_side, _assigned_commander]`. | Likely bug. `_side` should probably be `_this select 0`; verify before relying on manual commander reassignment. |
| Supply mission cooldown casing | Town init seeds `lastSupplyMissionRun`, but server supply mission code reads/writes `LastSupplyMissionRun`. | Likely cooldown bug or stale variable. Standardize casing and migrate carefully. |
| Supply mission reward authority | Client supply mission start sets truck `SupplyFromTown` and `SupplyAmount`; server completion trusts those truck variables. | Hardening gap. Recompute reward/cooldown server-side from trusted town/truck state. |
| Resistance side supply updates | `Common_ChangeSideSupply.sqf` formats `wfbe_supply_temp_<side>` generically, but server handlers exist only for west/east. | Resistance side supply not fully wired. |
| Hosted server FPS loops | `serverFpsGUI.sqf` and `monitorServerFPS.sqf` have `while {true}` loops with `sleep` only inside `if (isDedicated)`. | Hosted/non-dedicated server mode can busy-loop. Add sleep outside the dedicated guard if hosted mode matters. |
| Old map blink loop | `Client_BlinkMapIcons` and `AddUnitToTrack` compiles plus old exec are commented; newer singular `Client_BlinkMapIcon` and bookkeeping are active. | Legacy replacement. Avoid resurrecting old loop without perf review. |
| Server map blinking units | `Server_MapBlinkingUnits.sqf` exec is commented in `Init_Server.sqf`. | Disabled/legacy. |
| Old WASP init block | `initJIPCompatible.sqf` contains a commented WASP init block marked as old and resource-heavy. | Legacy/deferred removal. Individual WASP scripts still exist and may be called elsewhere. |
| Server FPS compile variable | `WFBE_CO_FNC_monitorServerFPS` compile lines are commented, but `Init_Server.sqf` later execVMs `Server/Module/serverFPS/monitorServerFPS.sqf`. | Not broken; document the direct exec path. |
| MASH marker duplicate compile | One MASH marker compile is active and a later duplicate is commented. | Likely cleanup artifact; do not re-enable both. |
| Volumetric clouds | Parameter exists but is forced disabled in constants and client init. | Intentional optimization. |
| Modded map generator path | `SqfFileGenerator.cs` has TODO to add modded maps back in one path. | Verify before assuming modded mission regeneration is complete. |
| Dangerous CRV7PG loadouts | LoadoutManager has `WARNING_GAME_CRASH_DO_NOT_USE_IN_LOADOUTS_*` weapon/ammunition classes, and `WILDCAT.cs` references one. | High-risk data. Keep these warnings visible when changing loadouts. |
| Gear menu cleanup | `GUI_BuyGearMenu.sqf` has TODOs about securing vanilla/removing unused code, refreshing targets, vehicle target content and vehicle/backpack templates. | Partial UI cleanup. See [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas). |
| Gear profile template filtering | `Client_UI_Gear_SaveTemplateProfile.sqf` references undefined `_u_upgrade` in upgrade checks. | Likely bug. Saved profile templates should not be trusted to enforce upgrade gates until the variable is fixed or replaced. |
| Gear/EASA/service purchase authority | `GUI_BuyGearMenu.sqf` applies gear and deducts funds client-side; `GUI_Menu_EASA.sqf` calls `EASA_Equip` and `ChangePlayerFunds` client-side; Claude DR-28 also traced `GUI_Menu_Service.sqf` rearm/refuel debits with no affordability guard. | Client-authoritative legacy path. DR-28 completes the economy authority class: build, buy, sell, supply, upgrade, ICBM and gear/service are all client-authoritative. Public-server hardening needs a server ledger/effect-validation design or BattlEye script filtering; service rearm/refuel also deserve local `if (_funds >= _price)` parity guards. |
| Generated EASA/balance output | `LoadoutManager` writes `Client/Module/EASA/EASA_Init.sqf` and `Common/Functions/Common_BalanceInit.sqf`; `Common_BalanceInit.sqf` exits on server while server buy code still calls `BalanceInit`. | Generated/locality risk. Change C# data first, inspect generated diffs, and test spawn versus rearm behavior separately. |
| Discord sample/config hygiene | `DiscordBot/preferences_sample.json` contains concrete sample IDs and a production-style `DataSourcePath`; `DiscordBot/FileConfiguration.cs` and `GameData.cs` have fallback paths to `C:\a2waspwarfare\Data`. | Governance cleanup. Replace real-looking sample IDs with placeholders and document one intended config source. No token is committed. |
| DiscordBot JSON deserialization | Claude DR-31 verified `DiscordBot/src/ExtensionData/GameData/GameData.cs` reads `database.json` with Newtonsoft `TypeNameHandling.All` on a 60-second status timer, at startup and from a command path. | **High local-write-gated RCE risk.** Use `TypeNameHandling.None` for the flat `GameData` DTO and remove the dead `.Auto` deserialization helper. Secret hygiene and command auth are otherwise documented as good. |
| In-repo stats extension vs AntiStack DB extension | `a2waspwarfare_Extension` only implements `GLOBALGAMESTATS`; AntiStack calls a separate `A2WaspDatabase` DLL that is absent from the repo. Claude DR-29 verified GLOBALGAMESTATS is not an SQF RCE path today because output is discarded, but it has dormant deserialization and async-write risks. | Deployment dependency split. Do not assume building `Extension` satisfies AntiStack. Add extension presence detection/circuit breaker before public deployment; remove/harden the dead `TypeNameHandling.Auto` load path and fix `async void` file writes before treating the extension as robust persistence. |
| Missing CI/reference validation | Only `.github/FUNDING.yml` exists; no build/reference/generated-drift checks were found. | Missing tooling. Add .NET builds, generated-mission drift, SQF reference scans and wiki JSON/JSONL validation when project automation is introduced. |
| Stale old upgrade dialog | `RscMenu_Upgrade` points to missing `Client/GUI/GUI_Menu_Upgrade.sqf`; the live main menu opens `WFBE_UpgradeMenu` / `GUI_UpgradeMenu.sqf` instead. | Confirmed stale UI path. Do not revive without deleting/replacing the old resource class. |
| Suspect clickable-text sound config | `Rsc/Ressources.hpp` defines `RscClickableText.soundPush[] = {, 0.2, 1};`. | Likely malformed resource config; verify in-game parser behavior before reusing this base control. |
| Buy gear partials | `GUI_BuyGearMenu.sqf` includes self-documented TODOs for target refresh, vehicle target content and template scope. | Partial UI cleanup; avoid expanding templates until gear/vehicle/backpack behavior is mapped. |
| Fast travel fee | `GUI_Menu_Tactical.sqf` TODO mentions travel fee/mod parameter work. | Missing/unfinished feature. |
| Base/town dynamic logic TODO | `Common/Init/Init_Common.sqf` has a TODO around dynamic logic presence. | Low-level init cleanup candidate. |
| CoIn border TODO | `Client/Module/CoIn/coin_interface.sqf` notes temporary border logic should move if logic position changes. | Construction UI risk. |
| AI attack radio/combat tuning | `Server_AI_SetTownAttackPath.sqf` TODOs mention combat mode, speed and radio on waypoint completion. | Enhancement backlog. |

## Broken Feature Candidate: AI Supply Logistics

This is the clearest broken/abandoned feature. `AI_UpdateSupplyTruck.sqf` is present and loops over `wfbe_ai_supplytrucks`, but it cannot run correctly because the compile is disabled and the referenced `supplytruck.fsm` is absent. PR #1 correctly defers autonomous supply helicopters because the AI logistics base is incomplete.

Claude sharpened the status on 2026-06-01: the feature is not cleanly inert. In `Server/Init/Init_Server.sqf`, the compile line is commented, but the per-side init still calls `[_side] Spawn UpdateSupplyTruck;` when supply system 0 and AI commanders are enabled. With current defaults, `WFBE_C_ECONOMY_SUPPLY_SYSTEM` is 1, so normal play does not hit the call. If an admin selects supply system 0 with AI commanders, the server can hit a nil-code spawn error, and restoring the compile would still fail later because `Server/FSM/supplytruck.fsm` is missing.

## Confirmed Defect: Stacked Supply-Vehicle Killed Handlers

PR #1 adds or extends `Server/Module/supplyMission/supplyMissionStarted.sqf` so supply vehicles can award interdiction cash when destroyed. The script adds a `Killed` event handler every time a supply mission starts, with no removal or already-tracked guard. Reusing one vehicle across many missions stacks handlers. Current double-payment risk is bounded because the first handler sets `SupplyAmount` to `0`, but the handler leak is real and future side effects would multiply.

## Missing Feature Candidates

- Autonomous AI supply trucks/helicopters.
- Formal generated docs from LoadoutManager data classes into mission docs.
- Automated validation that generated Takistan/modded missions match Chernarus source after docs/code changes.
- Automated SQF syntax or reference validation in CI.

## Continue Reading

Previous: [External integrations](External-Integrations) | Next: [AI assistant guide](AI-Assistant-Developer-Guide)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

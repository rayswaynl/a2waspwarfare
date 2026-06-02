# Source Inventory

Generated from `git ls-files` in the main repository checkout.

Snapshot: `2026-06-02T20:30:00+02:00` on `docs/developer-wiki-index`.

Total tracked files: **3432**.

Regenerate with:

```powershell
$files = git ls-files
$files.Count
$files | ForEach-Object { ($_ -split '[\\/]')[0] } | Group-Object | Sort-Object Count -Descending
$files | ForEach-Object { $ext = [IO.Path]::GetExtension($_).ToLowerInvariant(); if ([string]::IsNullOrEmpty($ext)) { '<none>' } else { $ext } } | Group-Object | Sort-Object Count -Descending
```

## Top-Level Inventory

| Count | Top-level path |
| ---: | --- |
| 1475 | `Modded_Missions` |
| 787 | `Missions` |
| 786 | `Missions_Vanilla` |
| 199 | `Tools` |
| 110 | `docs` |
| 42 | `DiscordBot` |
| 16 | `Extension` |
| 3 | `Guides` |
| 3 | `Mods` |
| 2 | `BattlEyeFilter` |
| 2 | `.github` |
| 1 | `.gitattributes` |
| 1 | `.gitignore` |
| 1 | `AGENTS.md` |
| 1 | `CLAUDE.md` |
| 1 | `LICENSE.md` |
| 1 | `README.md` |
| 1 | `mkdocs.yml` |

## Extension Inventory

| Count | Extension |
| ---: | --- |
| 2703 | `.sqf` |
| 242 | `.cs` |
| 196 | `.paa` |
| 104 | `.md` |
| 59 | `.ogg` |
| 37 | `.hpp` |
| 12 | `.fsm` |
| 9 | `.ext` |
| 9 | `.json` |
| 8 | `.txt` |
| 5 | `.bikb` |
| 5 | `.bin` |
| 5 | `.sqs` |
| 4 | `.sqm` |
| 4 | `.jsonl` |
| 4 | `.jpg` |
| 4 | `.gitignore` |
| 3 | `.ps1` |
| 3 | `.csproj` |
| 3 | `.yml` |
| 2 | `.html` |
| 2 | `.xml` |
| 2 | `.ogv` |
| 2 | `.png` |
| 1 | `.gitattributes` |
| 1 | `.docx` |
| 1 | `.cpp` |
| 1 | `.config` |
| 1 | `.cmd` |

## Source Mission Subsystems

### Client

| Count | Area |
| ---: | --- |
| 89 | `Functions` |
| 51 | `Module` |
| 46 | `Images` |
| 20 | `GUI` |
| 15 | `PVFunctions` |
| 12 | `Action` |
| 8 | `FSM` |
| 8 | `Init` |
| 3 | `kb` |
| 1 | `Client_EndGame.sqf` |
| 1 | `Client_UpdateRHUD.sqf` |

### Common

| Count | Area |
| ---: | --- |
| 154 | `Functions` |
| 136 | `Config` |
| 15 | `Module` |
| 11 | `Init` |
| 1 | `Common_AARadarMarkerUpdate.sqf` |
| 1 | `Common_InitArtillery.sqf` |
| 1 | `Common_MarkerUpdate.sqf` |
| 1 | `Common_ReturnAircraftNameFromItsType.sqf` |

### Server

| Count | Area |
| ---: | --- |
| 46 | `Functions` |
| 27 | `Module` |
| 16 | `FSM` |
| 15 | `PVFunctions` |
| 11 | `AI` |
| 4 | `Construction` |
| 4 | `Support` |
| 3 | `Init` |
| 1 | `CallExtensions` |
| 1 | `Config` |
| 1 | `GUI` |
| 1 | `MonitorPlayerCount.sqf` |

## Module Directories

### Client Modules

- `Client/Module/AFKkick`
- `Client/Module/AntiStack`
- `Client/Module/AutoFlip`
- `Client/Module/CM`
- `Client/Module/CoIn`
- `Client/Module/EASA`
- `Client/Module/Engines`
- `Client/Module/MASH`
- `Client/Module/Nuke`
- `Client/Module/Skill`
- `Client/Module/supplyMission`
- `Client/Module/UAV`
- `Client/Module/Valhalla`
- `Client/Module/ZetaCargo`

### Common Modules

- `Common/Module/Arty`
- `Common/Module/CIPHER`
- `Common/Module/IRS`
- `Common/Module/Reaktiv`

### Server Modules

- `Server/Module/afkKick`
- `Server/Module/AntiStack`
- `Server/Module/MASH`
- `Server/Module/NEURO`
- `Server/Module/serverFPS`
- `Server/Module/supplyMission`

## Static Reference Check

| File | Reference |
| --- | --- |
| Client/Init/Init_Client.sqf | ca\\modules\\ARTY\\data\\scripts\\init.sqf |
| Server/Construction/Construction_MediumSite.sqf | ca\\modules\\dyno\\data\\scripts\\objectMapper.sqf |
| Server/Construction/Construction_SmallSite.sqf | ca\\modules\\dyno\\data\\scripts\\objectMapper.sqf |
| Client/Module/UAV/uav_interface.sqf | ca\\modules\\uav\\data\\scripts\\uav_interface.sqf |
| Client/Init/Init_Client.sqf | Client\\Functions\\Client_AddUnitToTrack.sqf |
| Client/Init/Init_Client.sqf | Client\\Functions\\Client_BlinkMapIcons.sqf |
| Common/Config/Defenses/Defenses_CDF.sqf | Common\\Config\\Config_Defenses.sqf |
| Common/Config/Defenses/Defenses_GUE.sqf | Common\\Config\\Config_Defenses.sqf |
| Common/Config/Defenses/Defenses_INS.sqf | Common\\Config\\Config_Defenses.sqf |
| Common/Config/Defenses/Defenses_PMC.sqf | Common\\Config\\Config_Defenses.sqf |
| Common/Config/Defenses/Defenses_RU.sqf | Common\\Config\\Config_Defenses.sqf |
| Common/Config/Defenses/Defenses_TKA.sqf | Common\\Config\\Config_Defenses.sqf |
| Common/Config/Defenses/Defenses_TKGUE.sqf | Common\\Config\\Config_Defenses.sqf |
| Common/Config/Defenses/Defenses_US.sqf | Common\\Config\\Config_Defenses.sqf |
| Common/Config/Defenses/Defenses_USMC.sqf | Common\\Config\\Config_Defenses.sqf |
| Common/Init/Init_Common.sqf | Common\\Functions\\Common_HandleBombs.sqf |
| WASP/baserep/init.sqf | data.sqf |
| description.ext | scripts\\unitCaching\\description.ext |
| Server/Init/Init_Towns.sqf | Server\\FSM\\respatrol.fsm |
| Server/AI/AI_UpdateSupplyTruck.sqf | Server\\FSM\\supplytruck.fsm |
| Server/Init/Init_Server.sqf | Server\\Functions\\Server_MapBlinkingUnits.sqf |
| description.ext | version.sqf |
| initJIPCompatible.sqf | version.sqf |
| WASP/baserep/init.sqf | viem.sqf |
| WASP/Init_Client.sqf | WASP\\actions\\OnArmor\\timer.sqf |
| WASP/Init_Client.sqf | WASP\\actions\\SitsOnArmor\\init.sqf |
| WASP/Init_Client.sqf | WASP\\KeyDown.sqf |

## Read Existing Human Docs First

- `AGENTS.md`: coding-agent rules for this repo.
- `README.md`: server info and public links.
- `Guides/CommanderGuide/commanderGuide.md`: player-facing commander guide.
- `Tools/LoadoutManager/README.md`: .NET and 7-Zip workflow.
- `Tools/PerformanceAuditAnalyzer/README.md`: RPT audit parser/report workflow.
- `Tools/Arma2Warfare_GPT/CustomInstructions.md`: older assistant instructions.

## Continue Reading

Previous: [Lifecycle wait-chain](Lifecycle-Wait-Chain) | Next: [Content/maps](Content-Structure-And-Maps)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

# A2 Wasp Warfare Developer Wiki

This wiki indexes `rayswaynl/a2waspwarfare` for human developers and AI coding assistants. It focuses on the Arma 2: Operation Arrowhead 1.64 mission/server ecosystem, not Arma 3.

Use the Bohemia Interactive Arma 2 OA scripting command reference when checking engine behavior: <https://community.bistudio.com/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands>.

## Start Here

- [Architecture overview](Architecture-Overview)
- [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle)
- [Lifecycle wait-chain reference](Lifecycle-Wait-Chain)
- [Source inventory](Source-Inventory)
- [Core systems index](Core-Systems-Index)
- [Function and module index](Function-And-Module-Index)
- [Networking and public variables](Networking-And-Public-Variables)
- [Economy, towns and supply](Economy-Towns-And-Supply)
- [Supply mission architecture](Supply-Mission-Architecture)
- [AI, headless and performance](AI-Headless-And-Performance)
- [WASP overlay](WASP-Overlay)
- [Client UI, HUD and menus](Client-UI-HUD-And-Menus)
- [Tools and build workflow](Tools-And-Build-Workflow)
- [External integrations](External-Integrations)
- [Content structure and maps](Content-Structure-And-Maps)
- [Feature status register](Feature-Status-Register)
- [Deep-review findings](Deep-Review-Findings)
- [Current work: supply helicopters PR #1](Current-Work-Supply-Helicopters-PR1)
- [Documentation implementation plan](Documentation-Implementation-Plan)
- [Coordination board](Coordination-Board)
- [Claude goal](Claude-Goal)
- [Agent worklog](Agent-Worklog)
- [Agent context](Agent-Context)
- [AI assistant developer guide](AI-Assistant-Developer-Guide)

Machine-readable agent file: [`agent-context.json`](agent-context.json)

## Repo Shape

| Count | Top-level path |
| ---: | --- |
| 1475 | `Modded_Missions` |
| 787 | `Missions` |
| 786 | `Missions_Vanilla` |
| 199 | `Tools` |
| 42 | `DiscordBot` |
| 16 | `Extension` |
| 3 | `Guides` |
| 3 | `Mods` |
| 2 | `BattlEyeFilter` |
| 1 | `.gitattributes` |
| 1 | `.github` |
| 1 | `.gitignore` |
| 1 | `AGENTS.md` |
| 1 | `LICENSE.md` |
| 1 | `README.md` |

## Most Important Rule

For mission gameplay edits, treat `Missions/[55-2hc]warfarev2_073v48co.chernarus` as the source mission. `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` and modded mission folders are generated/copied targets managed by `Tools/LoadoutManager`.

## Current Documentation Scope

- Stable baseline: `master` at the time of indexing.
- Current work: PR #1, `feat/supply-helicopter`, documented separately.
- No gameplay code is changed by this documentation set.


# Server Runtime And Operations

This is a gateway for prompts and readers that ask for "server runtime" or "server operations" without knowing which owner page they need.

Do not put long source proof here. Runtime and operations are intentionally split so gameplay loops, deployment contracts and release evidence do not overwrite each other.

## Which Page Owns What

| Need | Open this | Why |
| --- | --- | --- |
| Long-running gameplay loops | [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) | Town capture, town AI, resources, victory, supply mission tracking, server FPS publishers, side radio and dormant server hooks. |
| Running or packaging a server | [Server ops runbook](Server-Ops-Runbook) | Mission generation, deploy inventory, BattlEye paths, extension paths, DiscordBot data paths, RPT/log collection and dedicated/listen smoke boundaries. |
| Public-server trust boundaries | [External integrations](External-Integrations), [Integration trust boundary audit](Integration-Trust-Boundary-Audit) | DiscordBot, in-repo extension, out-of-repo AntiStack DB extension, BattlEye filter posture and missing production config. |
| Authority hardening | [Server authority migration map](Server-Authority-Migration-Map), [Hardening roadmap](Hardening-Implementation-Roadmap) | Server-owned validation design, direct-PV/PVF risks and implementation order. |
| Headless/client delegation | [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map), [Headless delegation/failover](Headless-Delegation-And-Failover-Playbook) | HC ownership, client FPS delegation, town AI/static-defense update-back and disconnect/failover policy. |
| Performance testing | [Performance opportunity sweep](Performance-Opportunity-Sweep), [Testing workflow](Testing-Debugging-And-Release-Workflow) | Benchmark order, old BE comparison route, full-server FPS matrix and proof level naming. |
| Current branch truth | [Current source status snapshot](Current-Source-Status-Snapshot) | Whether a finding is stable-master, docs branch, release branch, generated Vanilla or upstream candidate truth. |

## Source Orientation

Use these source clusters only as orientation. The owner pages above carry the detailed evidence and next gates.

| Cluster | Source area | Owner page |
| --- | --- | --- |
| Init and worker startup | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf` | [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) |
| Town/camp runtime | `Server/FSM/server_town.sqf`, `server_town_ai.sqf`, `server_town_camp.sqf` | [Towns/camps/capture](Towns-Camps-And-Capture-Atlas), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) |
| Economy/resource runtime | `Server/FSM/updateresources.sqf`, supply mission server modules | [Economy/towns/supply](Economy-Towns-And-Supply), [Supply mission architecture](Supply-Mission-Architecture) |
| Integration and telemetry | `Server/CallExtensions/GlobalGameStats.sqf`, `DiscordBot`, `Extension`, `BattlEyeFilter/publicvariable.txt` | [External integrations](External-Integrations), [Server ops runbook](Server-Ops-Runbook) |
| Release proof | `Tools/LoadoutManager`, smoke scripts, RPT captures | [Tools/build workflow](Tools-And-Build-Workflow), [Testing workflow](Testing-Debugging-And-Release-Workflow) |

## Agent Rule

If a task asks for `Server-Runtime-And-Operations.md`, start here, then edit the owner page that matches the task. Keep this gateway short. Add new runtime facts to [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), new deployment facts to [Server ops runbook](Server-Ops-Runbook), and new proof gates to [Testing workflow](Testing-Debugging-And-Release-Workflow).

## Continue Reading

Runtime: [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) | Operations: [Server ops runbook](Server-Ops-Runbook) | Testing: [Testing workflow](Testing-Debugging-And-Release-Workflow)

Main map: [Home](Home) | Status: [Progress dashboard](Progress-Dashboard) | Agent index: [`agent-machine-index.json`](agent-machine-index.json)

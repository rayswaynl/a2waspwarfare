# Core Systems Index

This page is a route map, not an implementation atlas. Use it to choose the right owner page before changing gameplay behavior.

The detailed source evidence lives in the linked pages. Avoid treating the summaries below as proof of current runtime behavior without opening the owner page and source anchors.

## First Stops

| System | Open first | Why |
| --- | --- | --- |
| Towns, camps and capture | [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas) | Town logic initialization, camp loops, capture modes, side/SV state and town-defense lifecycle. |
| Economy and supply | [Economy, towns and supply](Economy-Towns-And-Supply), [Economy authority first cut](Economy-Authority-First-Cut) | Funds, side supply, income loops, supply missions, AntiStack interaction and economy authority risks. |
| Commander and HQ | [Commander/HQ lifecycle atlas](Commander-HQ-Lifecycle-Atlas), [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook) | Commander state, voting, reassignment, HQ deploy/mobilize/repair and known vote/call-shape hazards. |
| Construction and base | [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas) | CoIn preview, request handlers, construction workers, base-area logic, repairs, sale and structure authority. |
| Factories and purchases | [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) | Buy menus, spawn pads, queue state, player-local production, latent `AIBuyUnit` and purchase authority. |
| Upgrades | [Upgrades and research atlas](Upgrades-And-Research-Atlas) | Upgrade indices, request/process flow, artillery refresh, UI/debit risks and research dependencies. |
| Respawn | [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas) | Camp, leader, MASH and mobile respawn behavior, penalties and safe radius. |
| Supports | [Support specials and tactical modules](Support-Specials-And-Tactical-Modules-Atlas) | Artillery, tactical requests, ICBM, para drops, UAV, HALO, EASA and service systems. |
| AI and headless clients | [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map), [AI headless and performance](AI-Headless-And-Performance) | Town AI activation, delegation, AI commander context, HC failover and performance-sensitive loops. |
| Operations and integrations | [Server ops runbook](Server-Ops-Runbook), [External integrations](External-Integrations) | AntiStack, AFK/BattlEye filters, server FPS, DiscordBot and extension boundaries. |

## Representative Source Anchors

These anchors are a starting breadcrumb only. Prefer the owner page for current caveats and adjacent files.

| System | Source anchors |
| --- | --- |
| Towns/capture | `initJIPCompatible.sqf:215`; `Server/Init/Init_Server.sqf:510,514,519`; `Server/FSM/server_town.sqf:222,227,235,240,265`; `Server/FSM/server_town_ai.sqf:211-216,247` |
| Economy and resources | `Common/Init/Init_Common.sqf:19-20,42,53,61-63`; `Server/Init/Init_Server.sqf:531`; `Server/FSM/updateresources.sqf` |
| Factories/purchases | `Rsc/Dialogs.hpp:1448`; `Client/Init/Init_Client.sqf:52`; `Server/Init/Init_Server.sqf:10`; `Server/Functions/Server_BuyUnit.sqf:19` |
| Upgrades | `Common/Init/Init_CommonConstants.sqf:37,58`; `Server/Init/Init_Server.sqf:57`; `Common/Init/Init_Common.sqf:323` |
| Support/admin ops | `Server/Init/Init_Server.sqf:39-42,298,578`; `Client/FSM/updateclient.sqf:153-160`; `Common/Functions/Common_PerformanceAudit.sqf:4` |
| Discord integration boundary | Mission text mentions Discord at `briefing.sqf:17,19`, `Client/Init/Init_Client.sqf:958` and `stringtable.xml:416`; status publishing code lives in `DiscordBot/src/ProgramRuntime.cs:69-70`, `DiscordBot/src/GameStatusUpdater.cs:14,52` and `DiscordBot/src/ExtensionData/GameData/GameData.cs:36,159`. |

## Gateway Rules

- If a claim involves authority, money, ownership, locality or a broken feature, open the owner page and [Deep-review findings](Deep-Review-Findings) before editing.
- Do not assume "server-owned" or "client-owned" from this index alone. Several systems are split flows with client-side UI/debit and server-side creation or notification.
- Treat `Server_BuyUnit.sqf` / `AIBuyUnit` as latent on stable master unless a branch or source search proves a live caller.
- Route new findings to the owner page first, then update this index only if the navigation target changes.

## Continue Reading

Previous: [Server runtime atlas](Server-Gameplay-Runtime-Atlas) | Next: [Gameplay systems atlas](Gameplay-Systems-Atlas)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

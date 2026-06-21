# A2 Wasp Warfare Developer Wiki

Developer documentation for `rayswaynl/a2waspwarfare`, an Arma 2: Operation Arrowhead 1.64 Warfare / CTI mission and server ecosystem.

This page is the front door. It should help you choose the right owner page quickly, not repeat the whole wiki.

## Start Here

| If you are... | Open first | Then |
| --- | --- | --- |
| New human developer | [Quickstart](Quickstart-For-Humans-And-Agents) | [Architecture overview](Architecture-Overview), [Mission entrypoints](Mission-Entrypoints-And-Lifecycle), [SQF code atlas](SQF-Code-Atlas) |
| New player / commander | [Commander's Handbook](Commanders-Handbook) | [Upgrade costs](Upgrade-Research-Cross-Faction-Reference), [Unit/vehicle roster](Faction-Unit-And-Vehicle-Roster-Catalog) |
| AI assistant / LLM | [LLM agent entry pack](LLM-Agent-Entry-Pack) | [`llms.txt`](llms.txt), [`agent-entrypoint.json`](agent-entrypoint.json), [`agent-context.json`](agent-context.json), [AI assistant guide](AI-Assistant-Guide) |
| Current work reviewer | [Progress dashboard](Progress-Dashboard) | [`agent-status.json`](agent-status.json), [`agent-collaboration.json`](agent-collaboration.json), [Agent worklog](Agent-Worklog) |
| Feature or bug triager | [Feature status register](Feature-Status-Register) | [Dead/stale code register](Dead-Code-And-Stale-Code-Register), [Pending owner decisions](Pending-Owner-Decisions) |
| Gameplay implementer | [Gameplay systems atlas](Gameplay-Systems-Atlas) | [Construction/CoIn](Construction-And-CoIn-Systems-Atlas), [Factory/purchase](Factory-And-Purchase-Systems-Atlas), [Server runtime](Server-Runtime-And-Operations) |
| Public-server hardening owner | [Hardening roadmap](Hardening-Implementation-Roadmap) | [Server authority map](Server-Authority-Migration-Map), [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook), [Testing workflow](Testing-Debugging-And-Release-Workflow) |
| Upstream/community archaeologist | [Community & Dev](Community-And-Dev) | [Miksuu wiki import](Miksuu-Upstream-Wiki-Import), [Developer history](Developer-History-And-Upstream-Lessons), [Upstream commit intel](Upstream-Miksuu-Commit-Intel) |
| Docs/platform maintainer | [Navigation inventory](Navigation-Inventory-And-Page-Status) | [Wiki pruning ledger](Wiki-Pruning-And-Relevance-Ledger), [Knowledge platform roadmap](Knowledge-Platform-Roadmap), [Wiki mirror plan](Wiki-Mirror-Reconciliation-Plan) |

## Non-Negotiables

| Rule | Why it matters |
| --- | --- |
| Source gameplay edits start in `Missions/[55-2hc]warfarev2_073v48co.chernarus`. | This is the source mission. |
| Treat `Missions_Vanilla` as maintained generated/copy output. | Propagate with `Tools/LoadoutManager`; do not hand-edit drift unless a release owner says so. |
| Treat `Modded_Missions` as divergent/stubbed unless tooling proves otherwise. | Current generation/package paths do not actively maintain those folders. |
| Use Arma 2 OA 1.64 scripting references. | Arma 3 assumptions are a common source of bad fixes. |
| Check [Progress dashboard](Progress-Dashboard) before claiming work. | It prevents duplicate Codex/Claude/agent lanes. |
| Keep `docs/wiki` and the GitHub wiki mirror in sync. | Humans use the wiki; agents use the repo mirror. |

## Main Routes

| Need | Canonical route |
| --- | --- |
| Startup, lifecycle, includes | [Architecture overview](Architecture-Overview) -> [Mission entrypoints](Mission-Entrypoints-And-Lifecycle) -> [Mission config/version graph](Mission-Config-Version-Include-Graph) -> [Lifecycle wait-chain](Lifecycle-Wait-Chain) -> [Experimental feature-flag constants](Experimental-Feature-Flag-Constants-Reference) -> [Per-unit client init pipeline](Per-Unit-Client-Init-Pipeline-Reference) -> [Server-init deadspawn & airfield probe](Server-Init-Deadspawn-And-Airfield-Probe) -> [Mission tunable constants catalog](Mission-Tunable-Constants-Catalog) |
| SQF ownership and compile flow | [SQF code atlas](SQF-Code-Atlas) -> [Function and module index](Function-And-Module-Index) -> [Source inventory](Source-Inventory) |
| Networking and authority | [Networking/PV](Networking-And-Public-Variables) -> [Public variable channel index](Public-Variable-Channel-Index) -> [Server authority map](Server-Authority-Migration-Map) -> [Server HandleSpecial router](Server-HandleSpecial-Request-Router-Reference) -> [LocalizeMessage chat router](LocalizeMessage-Chat-Notification-Router-Reference) -> [PVF send-helper contracts](PVF-Send-Helper-Contract-Reference) -> [RequestTeamUpdate squad-discipline](Request-Team-Update-Squad-Discipline-Handler) |
| Economy, towns, supply | [Economy/towns/supply](Economy-Towns-And-Supply) -> [Towns/camps/capture](Towns-Camps-And-Capture-Atlas) -> [Side-patrol & convoy runtime](Side-Patrol-Runtime-And-Convoy-Mechanics) -> [Town-economy getters](Town-Economy-Getter-Reference) -> [Supply mission architecture](Supply-Mission-Architecture) -> [GUER insurgent economy](GUER-Insurgent-Player-Economy) -> [Income-tick engine](Resource-Income-Tick-Distribution-Engine) -> [Town tuning constants](Town-Runtime-Tuning-Constants) -> [Town-capture garrison & airfield rebuild](Town-Capture-Garrison-And-Airfield-Rebuild) |
| Commander, HQ, construction | [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) -> [Construction/CoIn](Construction-And-CoIn-Systems-Atlas) -> [Counter-battery radar](Counter-Battery-Radar-System) -> [Bank/Reserve/Artillery Radar](Bank-Reserve-And-Artillery-Radar-Structures) -> [Site clearance](Site-Clearance-Commander-Function-Reference) -> [Structure dressing](Server-Structure-Dressing-Function-Reference) -> [Defense category & budget](Defense-Category-And-Budget-Reference) -> [HQ radio kb catalog](HQ-Radio-Knowledge-Base-Conversation-Catalog) -> [WASP base-repair](WASP-Base-Repair-System-Reference) -> [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook) |
| Factories, purchases, upgrades | [Factory/purchase](Factory-And-Purchase-Systems-Atlas) -> [Upgrades/research](Upgrades-And-Research-Atlas) -> [Gear/loadout/EASA](Gear-Loadout-And-EASA-Atlas) -> [Factory queue cancel](Factory-Queue-Cancel-And-Refund-Action) -> [Vehicle weapon balance init](Vehicle-Weapon-Balance-Init-Reference) |
| AI, HC, performance | [AI/headless/performance](AI-Headless-And-Performance) -> [Headless client scaling](Headless-Client-Scaling-And-Topology) -> [Performance opportunity sweep](Performance-Opportunity-Sweep) -> [Performance audit writer](Performance-Audit-Writer-Function-Reference) -> [AI commander tunable constants](AI-Commander-Tunable-Constants-Reference) -> [Commander-team driver](Commander-Team-Driver-Reference) -> [Legacy AI order primitives](Legacy-AI-Order-Primitive-Reference) -> [Static-defense manning](Static-Defense-Manning-Reference) -> [AI commander execution loop](AI-Commander-Execution-Loop-Reference) -> [AICOM treasury accessors](AI-Commander-Treasury-Fund-Accessors) -> [AICOM logging & telemetry](AI-Commander-Logging-And-AICOMSTAT-Telemetry) -> [Group lifecycle & reaping](Group-Lifecycle-And-Entity-Reaping) -> [Batch AI spawner](Batch-AI-Spawner-Orchestrator) -> [Server group GC](Server-Group-GC-Cap-Warning-And-Zombie-Reaper) -> [HC delegation target selection](Headless-Client-Delegation-Target-Selection) -> [Client FPS & state telemetry](Client-FPS-And-State-Telemetry-Reference) -> [HC init & stat loop](Headless-Client-Init-And-Stat-Loop) -> [Town-garrison patrol/defense worker](Town-Garrison-Patrol-Defense-Worker) |
| UI, HUD, menus | [Client UI/HUD/menus](Client-UI-HUD-And-Menus) -> [Client UI systems atlas](Client-UI-Systems-Atlas) -> [UI IDD collision repair](UI-IDD-Collision-Repair) -> [Gear buy-menu functions](Gear-Buy-Menu-Render-And-Price-Function-Reference) -> [End-of-game stats screen](End-Of-Game-Stats-Victory-Screen) -> [Client funds/income HUD](Client-Funds-Income-HUD-Readout) -> [Client input/hotkey handler](Client-Input-Hotkey-Handler) -> [CoIn client engine](CoIn-Construction-Interface-Client-Engine-Reference) -> [Map-control & minimap templates](Map-Control-Template-And-Minimap-Embed-Reference) -> [Unit-camera spectator](Unit-Camera-Spectator-System-Reference) |
| Map markers | [Cleanup/restoration](Marker-Cleanup-Restoration-Systems-Atlas) -> [Loop engine & registries](Marker-Loop-Engine-And-Registries) -> [Marker families catalog](Map-Marker-Families-Content-Catalog) -> [FSM updater map](Client-Marker-FSM-Updater-Map) -> [Function reference](Marker-Subsystem-Function-Reference) |
| Support, specials, airlift | [Support specials](Support-Specials-And-Tactical-Modules-Atlas) -> [UAV terminal & spotter](UAV-Terminal-And-Spotter-System) -> [Vehicle countermeasure](Vehicle-Countermeasure-Flares-And-Spoofing) -> [Artillery firing functions](Artillery-Firing-Function-Reference) -> [Service Point pricing](Service-Point-Pricing-Model) -> [Paradrop delivery](Server-Paradrop-Delivery-Function-Reference) -> [ICBM nuke VFX](ICBM-Nuke-Client-VFX-And-Radiation-Reference) -> [GUER VBIED detonate](GUER-VBIED-Detonate-Action) -> [Zeta cargo sling-load](Zeta-Cargo-Sling-Load-Reference) -> [Modules atlas](Modules-Atlas) -> [NEURO AI-taxi module](NEURO-AI-Taxi-Module-Reference) |
| Player QoL / WASP UI actions | [WASP overlay](WASP-Overlay) -> [Skin selector/class swap](Skin-Selector-And-Class-Swap-Reference) -> [Earplugs audio toggle](Earplugs-Audio-Toggle-Reference) -> [QoL trio player hints](QoL-Trio-Player-Hints-Reference) -> [Player vehicle/travel actions](Player-Vehicle-And-Travel-Actions-Reference) -> [AutoFlip vehicle recovery](AutoFlip-Vehicle-Recovery-Reference) -> [Engine stealth fuel toggle](Engine-Stealth-Fuel-Toggle-Reference) -> [View distance auto-throttle](View-Distance-And-Target-FPS-Auto-Throttle) -> [WASP DropRPG launcher](WASP-DropRPG-Launcher-And-Ordnance-Handler) -> [Player UI workflow](Player-UI-Workflow-Map) |
| Tools, build, release | [Tools/build workflow](Tools-And-Build-Workflow) -> [Operator monitor/CPU affinity tools](Operator-Monitor-And-CPU-Affinity-Tools-Reference) -> [Source fix propagation queue](Source-Fix-Propagation-Queue) -> [Testing workflow](Testing-Debugging-And-Release-Workflow) |
| Integrations and ops | [External integrations](External-Integrations) -> [Integration trust boundary audit](Integration-Trust-Boundary-Audit) -> [Server runtime and operations](Server-Runtime-And-Operations) -> [Server broadcast & telemetry loops](Server-Broadcast-And-Telemetry-Loop-Reference) -> [Day/night cycle & weather](Day-Night-Cycle-And-Weather-System) |
| Faction content & catalogs | [Unit/vehicle roster](Faction-Unit-And-Vehicle-Roster-Catalog) -> [Gear loadout routes](Gear-Store-Loadout-Route-Catalog) -> [Gear store catalog (complete)](Gear-Store-Catalog-Per-Faction) -> [Gear store prices](Gear-Store-Price-And-Upgrade-Catalog) -> [Default gear templates](Default-Gear-Template-Content-Catalog) -> [Upgrade costs](Upgrade-Research-Cross-Faction-Reference) -> [Defenses](Defense-Structures-Catalog) -> [Artillery](Artillery-Reference-Per-Faction) -> [AI squad templates](AI-Squad-Team-Templates-Catalog) -> [Town AI groups](Town-AI-Group-Composition-Catalog) -> [Aux/SF/civilian units](Auxiliary-And-Special-Forces-Unit-Catalog) -> [Vehicle marking & texture](Vehicle-Marking-And-Texture-Pipeline) -> [Airfield-exclusive roster & hints](Airfield-Exclusive-Roster-And-Special-Unit-Hints) |
| Map content | [Chernarus](Chernarus-Map-Content-Reference) -> [Takistan](Takistan-Map-Content-Reference) -> [Ruleset model/object config](Map-Ruleset-Model-And-Object-Config) -> [Mission audio catalog](Mission-Audio-Catalog) |
| Player roles and class abilities | [Player skill abilities](Player-Skill-Abilities-Reference) -> [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas) -> [Medic redeploy truck](Medic-Redeployment-Truck-Forward-Spawn) -> [Deployable bipod / weapon resting](Deployable-Bipod-Weapon-Resting) -> [Gear/loadout/EASA](Gear-Loadout-And-EASA-Atlas) -> [Player AI caps](Player-AI-Caps-And-Role-Balance) |
| Core SQF function reference | [Spawn primitives](Spawn-Primitive-Function-Reference) -> [Kill/score pipeline](Kill-And-Score-Pipeline) -> [Waypoint helpers](Waypoint-Helper-Function-Reference) -> [Position/proximity helpers](Position-And-Proximity-Function-Reference) -> [Side/team state](Side-Team-State-Function-Reference) -> [CIPHER sort utilities](CIPHER-Sort-Utilities-Reference) -> [Camp getters](Camp-And-Respawn-Camp-Getter-Reference) -> [Gear parsing & cargo](Client-Gear-Parsing-And-Cargo-Capacity-Function-Reference) -> [Client service-proximity getters](Client-Service-Structure-Proximity-Getters) -> [Player-AI watchdog](Player-AI-Watchdog-And-Recovery) |

| Player feature guides | [Commander's Handbook](Commanders-Handbook) -> [Tactical support menu](Tactical-Support-Menu-Player-Guide) -> [Supply missions](Supply-Mission-Player-Guide) -> [Squad/group join](Player-Squad-Group-Join-Protocol) |
| Maps & modules | [Playable maps](Playable-Maps-Catalog) -> [Modded maps](Modded-Maps-Status-And-Content) -> [BattlEye filter](BattlEye-Filter-Setup-And-OA-Taxonomy) -> [Valhalla](Valhalla-Vehicle-Climbing-Assist) |

| Combat & vehicle function refs | [Player vehicle/travel actions](Player-Vehicle-And-Travel-Actions-Reference) -> [Missile/ordnance Fired-EH](Missile-And-Ordnance-Fired-EH-Reference) -> [Engine stealth fuel toggle](Engine-Stealth-Fuel-Toggle-Reference) -> [Vehicle equip/rearm](Vehicle-Equip-And-Rearm-Function-Reference) -> [Array utilities](Array-And-Collection-Utility-Reference) -> [Composition spawner](Server-Composition-Spawner-Function-Reference) -> [Namespace/profile utils](Namespace-Profile-And-Diagnostic-Utility-Reference) |
| Server internals | [Upgrade queue loop](Upgrade-Queue-Server-Loop-Reference) -> [Map boundaries & off-map](Map-Boundaries-And-Offmap-Enforcement) |

## Current Work

| Surface | Use it for |
| --- | --- |
| [Progress dashboard](Progress-Dashboard) | Human-readable current lanes, July update queue and recent published batches. |
| [`agent-status.json`](agent-status.json) | Compact machine snapshot of active/watchlist/code-owner lanes. |
| [`agent-collaboration.json`](agent-collaboration.json) | Current claim/ownership surface. Historical lanes live in the worklog and event stream. |
| [`agent-events.jsonl`](agent-events.jsonl) | Append-only coordination events. |
| [Agent worklog](Agent-Worklog) | Dated narrative notes and historical batch detail. |

## Validation

```powershell
powershell -ExecutionPolicy Bypass -File docs\validate-wiki.ps1
```

After meaningful docs or machine-file edits, also parse touched JSON/JSONL files, mirror touched wiki files, inspect diffs and keep gameplay source unchanged unless Steff explicitly asks for a code patch.

## Navigation Notes

- Persistent navigation is in [`_Sidebar.md`](_Sidebar).
- Shared footer navigation is in [`_Footer.md`](_Footer).
- Page-status and hidden/support-page classification lives in [Navigation inventory](Navigation-Inventory-And-Page-Status).
- Bloat, merge, archive and relevance decisions live in [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger).
- The long-term docs platform recommendation lives in [Knowledge platform roadmap](Knowledge-Platform-Roadmap).

## Continue Reading

Previous: [Claude long-term goal](Claude-Long-Term-Goal) | Next: [Quickstart](Quickstart-For-Humans-And-Agents)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent pack: [LLM agent entry pack](LLM-Agent-Entry-Pack)

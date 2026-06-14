# Economy, Towns And Supply

Town object initialization, capture/SV state, camp capture, marker visibility and town-AI activation are mapped in [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas). Keep this page focused on economy, supply, reward and resource interpretation, then route lifecycle implementation details to the owner pages below.

## How To Use This Page

| Need | Read |
| --- | --- |
| Town init, capture, camp and town-AI source flow | [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas) |
| Supply mission cooldowns, JIP, cargo vars and completion trust | [Supply mission architecture](Supply-Mission-Architecture) |
| Supply authority patch shape | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) |
| Side-supply clamp, reason strings, direct temp channels and first patch order | [Economy authority first cut](Economy-Authority-First-Cut) |
| AI commander upgrades and AI logistics | [AI commander autonomy audit](AI-Commander-Autonomy-Audit), [Upgrades and research](Upgrades-And-Research-Atlas) |
| Client-trusted economy surfaces outside towns/supply | [Server authority migration map](Server-Authority-Migration-Map), [Construction atlas](Construction-And-CoIn-Systems-Atlas), [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) |

## Current Branch Scope

Checked 2026-06-14 against docs checkout `8a6695b8` (maintained mission roots unchanged from `6d05cb5a`), stable `origin/master` `cf2a6d6a`, Miksuu upstream `b8389e74`, `origin/perf/quick-wins` `0076040f` and release `origin/release/2026-06-feature-bundle` `a96fdda2` in the maintained Chernarus and Vanilla mission roots unless noted.

| Ref | Economy/supply status |
| --- | --- |
| Docs checkout `8a6695b8` | Resource-income guard/display drift remains; supply missions are truck-only; AI commander upgrade debit is still swapped; side-supply arithmetic/reason validation remains open. |
| Stable `origin/master` `cf2a6d6a` | Resource-income guard/display drift remains; supply missions include heli/cash-run state; AI commander upgrade debit order is fixed; side-supply arithmetic/reason validation remains open. |
| Miksuu upstream `b8389e74` | Same resource-income drift as the docs checkout; truck-only supply mission flow; swapped AI commander upgrade debit; no upstream rescue for side-supply clamp/reason behavior. |
| `origin/perf/quick-wins` `0076040f` | Same resource-income drift; truck-only supply mission flow; swapped AI commander upgrade debit; Chernarus floors side-supply negatives to zero, but Vanilla keeps the old floor and authority remains open. |
| Release `a96fdda2` | Same resource-income drift; supply missions include heli/cash-run state; AI commander upgrade debit order is fixed; side-supply arithmetic/reason validation remains open. |

## Town Supply Model

Town supply value drives automatic income and supply missions. In the docs checkout, the maintained Chernarus constants sit in `Common/Init/Init_CommonConstants.sqf`: automatic supply mode at `:161`, timed supply delay at `:165`, the supply-mission multiplier `20` at `:167`, score coefficient at `:180`, stale delivery-funds coefficient at `:268`, and supply-level arrays at `:339-340`. Stable `origin/master` shifts those constants to `:165,169,171,173-181,285,358-359`; release `a96fdda2` shifts them to `:161,165,167,169-180,281,354-355`.

Keep the model split clear:

- `supplyValue` / SV is the town-side value used by income and supply cargo.
- Side supply is the team-level pool changed through `ChangeSideSupply` and direct temp PV channels.
- Funds are group/player money values changed through shared helpers and many client-trusted UI paths.

## Player Supply Mission Flow

Common route: a SpecOps skill action in `Client/Module/Skill/Skill_Apply.sqf` exposes the load action, `Client/Module/supplyMission/supplyMissionStart.sqf` checks cooldown and stamps vehicle vars, the client broadcasts `WFBE_Client_PV_SupplyMissionStarted`, the server tracks the vehicle/town, command-center proximity completes the mission, and `Server/Module/supplyMission/supplyMissionCompleted.sqf` trusts vehicle vars before mutating side supply and notifying the client reward path.

Branch split:

| Scope | Flow detail |
| --- | --- |
| Docs checkout `8a6695b8`, Miksuu `b8389e74`, perf `0076040f` | Truck-only flow. Cargo is computed in `supplyMissionStart.sqf:32` and stored as `SupplyAmount` at `:34`; server completion reads the vehicle var at `supplyMissionCompleted.sqf:9`, mutates side supply at `:26`, and client reward/score handling runs in `supplyMissionCompletedMessage.sqf:13-14,22`. |
| Stable `origin/master` `cf2a6d6a`, release `a96fdda2` | Heli/cash-run flow exists. Cargo still comes from `supplyMissionStart.sqf:61`, with `SupplyByHeli` and `SupplyAmount` stamped at `:80-81`; server completion sends the expanded message at `supplyMissionCompleted.sqf:31`, can award commander cash-run funds at `:37`, or side supply at `:40`; client reward and score run through `supplyMissionCompletedMessage.sqf:16-17,30-32`. |

Routing note: [Supply mission architecture](Supply-Mission-Architecture) owns the cooldown/JIP flow, [Deep-review findings](Deep-Review-Findings) DR-18 owns the `lastSupplyMissionRun` / `LastSupplyMissionRun` casing defect, and [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) owns the patch shape.

## Economy And Commander Funds

Funds and supply are separate systems unless the mission parameter switches currency behavior. The separation is conceptual, not proof that each payout path is independently server-gated.

`Server/FSM/updateresources.sqf:29-70` computes town supply income, then wraps side-supply growth, player paychecks and AI-commander funds in `if (_supply < _supply_max_limit)` at `:31`. Because `_supply` is the computed town-income value, not the current side-supply balance, this looks like an old supply-cap guard that can also suppress money payouts when the computed town supply reaches the cap. Treat income-loop changes as economy gameplay changes, not only supply UI changes.

Income system `4` has a display/runtime mismatch in every checked branch: server payout multiplies income by `1.5` before splitting commander/player shares (`updateresources.sqf:42-43`), while `Client/Functions/Client_GetIncome.sqf:24-28` displays the split without the `1.5` multiplier. Verify intended balance before changing either path; the docs point is that RHUD/menu income can differ from the actual paycheck.

### Resource Income Branch Matrix

| Scope | Source anchors | Development meaning |
| --- | --- | --- |
| Docs checkout `8a6695b8` | Maintained Chernarus and Vanilla both guard the whole payout block at `Server/FSM/updateresources.sqf:31`, apply income-system `4` multiplier at `:42-43`, change side supply at `:49`, pay groups at `:63`, credit AI commander funds at `:67`, and omit the display multiplier in `Client/Functions/Client_GetIncome.sqf:24-28`. | Patch-ready economy correctness debt. Treat as balance-sensitive, not a harmless UI refactor. |
| Stable `origin/master` `cf2a6d6a` and release `a96fdda2` | Same maintained-root guard/display shape and same line anchors for the checked files. | Stable/release have supply-heli and AI-debit fixes, but not this income/display correction. |
| Miksuu upstream `b8389e74` and perf `0076040f` | Same maintained-root guard/display shape and same line anchors for the checked files. | No upstream/perf rescue candidate for this income route. |

Smallest code-owner review: decide whether the cap guard should constrain only side-supply growth or also money payouts, then align actual paychecks, AI commander funds and `Client_GetIncome`/RHUD/menu display for income system `4`. Smoke a capped-supply side, a normal uncapped side, commander and non-commander teams, and AI commander funds before calling the behavior fixed.

AI commander upgrades are branch-split. All checked refs validate `_cost select 0` as side supply and `_cost select 1` as funds at `Server/Functions/Server_AI_Com_Upgrade.sqf:32-36`. The docs checkout, Miksuu and perf still deduct `_cost select 0` from AI commander funds and `_cost select 1` from side supply at `:47,50`; stable `origin/master` and release `a96fdda2` now debit funds with `_cost select 1` and side supply with `_cost select 0` at the same lines. Use [AI commander autonomy audit](AI-Commander-Autonomy-Audit#ai-upgrade-debit-branch-matrix) and [Upgrades and research](Upgrades-And-Research-Atlas#ai-commander-flow) before enabling or expanding autonomous AI commander upgrades.

Kill-bounty detail: player-facing bounty awards are client PVF/local-money paths, but AI-led kill bounty has a separate server branch. `RequestOnUnitKilled.sqf:83-100` sends `AwardBountyPlayer`/`AwardBounty` to players for player kills and, when `WFBE_C_AI_TEAMS_ENABLED > 0`, credits the AI killer group directly with `ChangeTeamFunds` (`RequestOnUnitKilled.sqf:97-100`). Treat score/bounty changes as both player-economy and AI-team-economy work.

### Supply Mission Reward Formula And Stale Copy

The runtime reward path is not the old "4 x actual value" player-help rule.

| Scope | Runtime reward |
| --- | --- |
| Docs checkout `8a6695b8`, Miksuu `b8389e74`, perf `0076040f` | Loaded cargo is `floor((town supplyValue) * WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER * supplyUpgradeModifier)` in `supplyMissionStart.sqf:32`; the multiplier is `20` at `Init_CommonConstants.sqf:167`. Completion sends the same `_supplyAmount` to the player message path, where `supplyMissionCompletedMessage.sqf:13-14` grants raw cash and `:22` requests score. |
| Stable `origin/master` `cf2a6d6a`, release `a96fdda2` | Cargo formula remains at `supplyMissionStart.sqf:61`. Player cash reward starts as `_supplyAmount`, then applies `WFBE_C_SUPPLY_HELI_REWARD_MULT` for heli delivery in `supplyMissionCompletedMessage.sqf:16-17`; score uses `_supplyAmount` at `:30-32`. The heli reward constant is `Init_CommonConstants.sqf:173` on stable and `:169` on release. |

The stale copy is in maintained `stringtable.xml:188-193`: `STR_Supplies_2` still tells players they receive "4 x the actual value as cash". The matching `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF = 4` remains defined (`Init_CommonConstants.sqf:268` in the docs checkout, `:285` on stable, `:281` on release), but this source pass found no maintained supply-completion consumer. Treat the stringtable text as player-facing docs debt, not runtime authority.

## Economy Authority Synthesis

The economy authority class is characterized by source review. Every confirmed spend or value-changing path is client-authoritative or trusts client-originated payload/state:

| Path | Finding | Evidence |
| --- | --- | --- |
| Construction/build | Client pays and sends `RequestStructure` / `RequestDefense`; server performs only light creation checks. | DR-6, [Construction atlas](Construction-And-CoIn-Systems-Atlas) |
| Player unit buy | Client spawns through `Client_BuildUnit` and deducts locally; no `RequestBuyUnit` PVF exists. | DR-14, [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas) |
| Structure sale | Economy UI refunds and destroys locally. | DR-16 |
| Side supply | Direct temp channels mutate keyed `wfbe_supply_%1` values; the generic `wfbe_supply` client init value is a legacy alias/cache. Branch check 2026-06-13: docs checkout `6d05cb5a`, stable `cf2a6d6a`, Miksuu `b8389e74` and release `a96fdda2` still use the overspend-as-credit floor and trust payload `_side`; `origin/perf/quick-wins` fixes only Chernarus arithmetic at `Common_ChangeSideSupply.sqf:25` and `Server_ChangeSideSupply.sqf:12,36`, not Vanilla or DR-44 authority. | DR-22, DR-44, [Economy authority first cut](Economy-Authority-First-Cut#side-supply-branch-matrix) |
| Score mutation/rewards | `RequestChangeScore` accepts a payload score, while `Common_AwardScorePlayer` and kill scoring show safer server-derived award patterns. | [Economy authority first cut](Economy-Authority-First-Cut), [Public variable channel index](Public-Variable-Channel-Index) |
| Player/group funds | No `RequestChangeFunds` PVF exists; funds are changed through replicated `wfbe_funds` group variables and shared helpers. | [Economy authority first cut](Economy-Authority-First-Cut) |
| Supply mission cargo/reward | Client stamps `SupplyFromTown` / `SupplyAmount` and, on stable/release, `SupplyByHeli` onto the vehicle; server completion trusts those vars after proximity checks. Personal cash/score reward presentation is still client-side after the completion broadcast. | [Supply mission architecture](Supply-Mission-Architecture) |
| Upgrades | `RequestUpgrade` passes raw payload into server process; no server-side cost/commander/dependency validation. | DR-23 |
| ICBM/special | Client can send `RequestSpecial ["ICBM", ...]`; server spawns `NukeDammage` from payload without authority checks. | DR-27, [Networking/PV](Networking-And-Public-Variables) |
| Gear/EASA/service | Gear, EASA and vehicle service effects/debits are client-side; service rearm/refuel skip even client affordability guards. | DR-28, [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) |
| Attack wave price modifier | `ATTACK_WAVE_INIT` is a direct client/common -> server publicVariable; server trusts `_supply` / `_side` and can apply a side-wide unit-price modifier from forged payload. | DR-41, [Networking/PV](Networking-And-Public-Variables), [Server authority map](Server-Authority-Migration-Map), [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) |

This should be treated as one owner decision, not separate patch tracks. Either introduce a server-side funds/effects ledger and validate each spend handler before applying effects, or explicitly accept the legacy client-trusted model and lean on BattlEye script filters for public-server hardening. DR-41 adds an important architecture rule: the forgery class has two surfaces, registered PVF handlers and direct `publicVariableServer` channels, so a PVF dispatcher fix alone does not harden direct economy/support channels. Small parity fixes, such as adding affordability guards to service rearm/refuel, are useful correctness work but do not close the architectural authority gap.

Side-supply logging caveat: `Common_ChangeSideSupply.sqf:8-13` only copies the human-readable `_reason` when `count _this > 3`. Use the branch-checked [Economy authority matrix](Economy-Authority-First-Cut#side-supply-reason-string-branch-matrix): checked current docs/source, stable, upstream, perf and release roots all drop the 3-argument `AttackWave.sqf:40` reason while preserving 4-argument supply-completion reasons. Patch this as diagnostics cleanup alongside side-supply clamp/validation work, not as authority closure.

## Supply-Related Partial Work

Do not use this page as the canonical AI logistics status page. [AI commander autonomy audit](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix) owns the AI supply-truck matrix: current stable/release safe-disable the incomplete worker, while Miksuu/perf still carry the raw-spawn trap. Treat autonomous AI logistics as incomplete/deferred until that owner page is refreshed and source-smoked.

## Supply Helicopter Branch Work

Stable `origin/master` `cf2a6d6a` and release `a96fdda2` carry the supply-heli/cash-run source shape; docs checkout `8a6695b8`, Miksuu `b8389e74` and perf `0076040f` do not. The branch with heli support adds class constants, upgrade gates, `SupplyByHeli`, air bonuses, commander-team cash runs and interdiction-related constants, but it does not change the fundamental client-started/server-completed trust model. See [Current work: supply helicopters PR #1](Current-Work-Supply-Helicopters-PR1) for the original feature route and [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix) for branch matrix ownership.

Implementation handoff: [Economy authority first cut](Economy-Authority-First-Cut) turns this economy-authority class into the smallest source-backed patch order.

## Continue Reading

Previous: [Core systems](Core-Systems-Index) | Next: [Supply mission architecture](Supply-Mission-Architecture)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)


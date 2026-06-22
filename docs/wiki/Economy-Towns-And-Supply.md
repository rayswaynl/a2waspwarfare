# Economy, Towns And Supply

Town object initialization, capture/SV state, camp capture, marker visibility and town-AI activation are mapped in [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas). Keep this page focused on economy, supply, reward and resource interpretation, then route lifecycle implementation details to the owner pages below.

## How To Use This Page

| Need | Read |
| --- | --- |
| Town init, capture, camp and town-AI source flow | [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas) |
| Resource-income tick algorithm, AI commander over-cap funds fallback and income-system `4` display mismatch | [Resource income tick distribution engine](Resource-Income-Tick-Distribution-Engine), [resource income branch matrix](#resource-income-branch-matrix) |
| Supply mission cooldowns, JIP, cargo vars and completion trust | [Supply mission architecture](Supply-Mission-Architecture) |
| Supply authority patch shape | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) |
| Side-supply clamp, reason strings, direct temp channels and first patch order | [Economy authority first cut](Economy-Authority-First-Cut), [Resistance supply scaffold](Resistance-Supply-Scaffold) |
| AI commander upgrades and AI logistics | [AI commander autonomy audit](AI-Commander-Autonomy-Audit), [Upgrades and research](Upgrades-And-Research-Atlas) |
| Client-trusted economy surfaces outside towns/supply | [Server authority migration map](Server-Authority-Migration-Map), [Construction atlas](Construction-And-CoIn-Systems-Atlas), [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) |

## Current Branch Scope

Current branch truth is owned by the row-specific matrices below and linked owner pages. Older 2026-06-14 baseline checks (`8cb43e4e`, `cf2a6d6a`, `b8389e74`, `0076040f`, `a96fdda2`) remain provenance for unchanged legacy anchors, but do not override newer current-stable refreshes. Targeted `git diff --name-only 8a6695b8..HEAD` and `6d05cb5a..HEAD` checks over the economy/supply constants, resource loop, income display, supply mission, side-supply helper, AI upgrade, kill-bounty and stringtable paths returned no source changes at that checkpoint, so the `8a6695b8` / `6d05cb5a` line anchors remain historical provenance where a row has not been refreshed.

Resource-income evidence was refreshed again on 2026-06-22 in [the branch matrix below](#resource-income-branch-matrix) against docs branch `d7a30e15`, current stable `origin/master@0139a346`, Miksuu `b8389e74`, `origin/perf/quick-wins@0076040f` and historical release commit `a96fdda2`. Supply-mission branch scope was refreshed again on 2026-06-22 in [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix): docs/source `15563691` remains truck-only with typed terminal scan, current stable `origin/master@0139a346` carries supply-heli/cash-run state in both maintained roots, and current Miksuu `b8389e748243` plus perf remain truck-only/broad-scan shaped. Current origin exposes no `release/*` or supply/heli feature heads, so release/PR evidence is historical until a live ref returns.

| Ref | Economy/supply status |
| --- | --- |
| Docs checkout `8cb43e4e` | Same source shape as `8a6695b8`: resource-income guard/display drift remains; supply missions are truck-only; AI commander upgrade debit is still swapped; side-supply arithmetic/reason validation remains open. |
| Current stable `origin/master@0139a346` | Resource-income cap/display drift is partially fixed only for AI commander over-cap funds; supply missions include heli/cash-run state, `SupplyByHeli`, guarded killed-handler setup and typed heli-aware command-center scan in both maintained roots; AI commander upgrade debit order is fixed; side-supply arithmetic/reason validation and supply player-list indexing remain open. |
| Current Miksuu `master@b8389e748243`, `origin/perf/quick-wins@0076040f` and current B69 `origin/claude/b69@8d465fce` | Miksuu/perf resource-income guard/display drift remains; supply missions are truck-only and still use the broad command-center scan on Miksuu/perf; AI commander upgrade debit remains swapped on Miksuu/perf. Perf floors side-supply negatives in Chernarus only. B69 is unchanged from `39eed5c0` for checked side-supply paths; it fixes Chernarus server-side side-supply arithmetic and wires a Chernarus resistance temp handler, but Vanilla propagation and authority validation remain open. |

Exact branch matrices live on owner pages: [Economy authority first cut](Economy-Authority-First-Cut#side-supply-branch-matrix) for side supply, [Resistance supply scaffold](Resistance-Supply-Scaffold#current-branch-matrix) for GUER/resistance owner/read/write scope, [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix) for truck/heli supply flow, and [AI commander autonomy](AI-Commander-Autonomy-Audit#ai-upgrade-debit-branch-matrix) for AI upgrade debit.

## Town Supply Model

Town supply value drives automatic income and supply missions. Current docs checkout `8cb43e4e` has the same maintained Chernarus constants as `8a6695b8`: automatic supply mode at `Common/Init/Init_CommonConstants.sqf:161`, timed supply delay at `:165`, the supply-mission multiplier `20` at `:167`, score coefficient at `:180`, stale delivery-funds coefficient at `:268`, and supply-level arrays at `:339-340`. Stable `origin/master` shifts those constants to `:165,169,171,173-181,285,358-359`; release `a96fdda2` shifts them to `:161,165,167,169-180,281,354-355`.

Keep the model split clear:

- `supplyValue` / SV is the town-side value used by income and supply cargo.
- Side supply is the team-level pool changed through `ChangeSideSupply` and direct temp PV channels.
- Funds are group/player money values changed through shared helpers and many client-trusted UI paths.

## Player Supply Mission Flow

Common route: a SpecOps skill action in `Client/Module/Skill/Skill_Apply.sqf` exposes the load action, `Client/Module/supplyMission/supplyMissionStart.sqf` checks cooldown and stamps vehicle vars, the client broadcasts `WFBE_Client_PV_SupplyMissionStarted`, the server tracks the vehicle/town, command-center proximity completes the mission, and `Server/Module/supplyMission/supplyMissionCompleted.sqf` trusts vehicle vars before mutating side supply and notifying the client reward path.

Branch split routes through [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix): docs/source `15563691`, current Miksuu `b8389e748243` and perf `0076040f` are truck-only, while current stable `origin/master@0139a346` adds supply-heli/cash-run state in both maintained roots. Old PR #1/release rows are historical branch-review evidence until a live ref returns. The economy implication is unchanged across both shapes: the server completion path still trusts client-stamped vehicle vars, and the client completion message path remains gameplay-relevant for personal cash/score reward presentation.

Routing note: [Supply mission architecture](Supply-Mission-Architecture) owns the cooldown/JIP flow, [Deep-review findings](Deep-Review-Findings) DR-18 owns the `lastSupplyMissionRun` / `LastSupplyMissionRun` casing defect, and [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) owns the patch shape.

## Economy And Commander Funds

Funds and supply are separate systems unless the mission parameter switches currency behavior. The separation is conceptual, not proof that each payout path is independently server-gated.

Old-shape refs still have the broadest cap-guard debt: docs branch `d7a30e15`, Miksuu `b8389e74`, `origin/perf/quick-wins@0076040f` and historical release commit `a96fdda2` compute town supply income in `Server/FSM/updateresources.sqf:29-70`, then wrap side-supply growth, team paychecks and AI-commander funds in `if (_supply < _supply_max_limit)` at `:31`. Because `_supply` is the computed town-income value, not the current side-supply balance, this is not simply "current side supply is full". Treat income-loop changes as economy gameplay changes, not only supply UI changes.

Current stable `origin/master@0139a346` is a partial fix, not the same old shape. In both maintained roots, the cap gate at `updateresources.sqf:45` still wraps side-supply growth (`:63`) and team paychecks (`:77`), but AI-commander cash has an over-cap fallback outside the guard at `:102-109`; under-cap AI commander income/stipend remain at `:82` and `:90`. Do not reopen the "AI commander gets no funds at cap" fix on current stable unless new source evidence changes; do keep the side-supply/team-paycheck cap decision and display mismatch on the economy review path.

Income system `4` has a display/runtime mismatch in every checked branch: old-shape refs multiply income by `1.5` before splitting commander/player shares at `updateresources.sqf:42-43`, and current stable does the same at `:56-57`; `Client/Functions/Client_GetIncome.sqf:24-28` displays the split without the `1.5` multiplier. Verify intended balance before changing either path; the docs point is that RHUD/menu income can differ from the actual paycheck.

### Resource Income Branch Matrix

| Scope | Source anchors | Development meaning |
| --- | --- | --- |
| Docs branch `d7a30e15` | Maintained Chernarus and Vanilla keep the old source shape: the whole payout block is guarded at `Server/FSM/updateresources.sqf:31`, income-system `4` multiplier applies at `:42-43`, side supply changes at `:49`, groups are paid at `:63`, AI commander funds are credited at `:67`, and `Client/Functions/Client_GetIncome.sqf:24-28` omits the display multiplier. | Patch-ready economy correctness debt. Treat as balance-sensitive, not a harmless UI refactor. |
| Current stable `origin/master@0139a346` | Maintained Chernarus and Vanilla keep the cap gate at `updateresources.sqf:45` over side-supply growth (`:63`) and team paychecks (`:77`), but add AI commander income/stipend fallback outside the gate at `:102-109`. Income-system `4` still uses `1.5` at `:56-57`, and `Client_GetIncome.sqf:24-28` still omits that multiplier. | Partial source-present fix. Do not ask current stable to redo the AI-commander funds-famine fallback; remaining review is cap intent for side supply/team paychecks plus actual-payout vs displayed-income alignment. |
| Miksuu upstream `b8389e74`, `origin/perf/quick-wins@0076040f` and historical release `a96fdda2` | Same old maintained-root guard/display shape as docs branch: cap guard at `updateresources.sqf:31`, system-4 multiplier at `:42-43`, side supply at `:49`, group funds at `:63`, AI commander funds at `:67`, and client display at `Client_GetIncome.sqf:24-28`. Perf Chernarus changes resource-loop wait cadence only. | Old-shape targets still need the AI-commander over-cap funds decision as well as the side-supply/team-paycheck and display-math review. Current origin exposes no `release/*` heads on 2026-06-22. |

Smallest code-owner review on current stable: decide whether the cap guard should constrain only side-supply growth or also team paychecks, then align actual paychecks and `Client_GetIncome`/RHUD/menu display for income system `4`. On old-shape branches, include the AI-commander over-cap funds/stipend fallback in the same review. Smoke a capped-supply side, a normal uncapped side, commander and non-commander teams, and AI commander funds before calling the behavior fixed.

AI commander upgrades are an economy consumer, not an owner-page responsibility here. Current docs checkout `8cb43e4e` has no checked source drift from the older AI upgrade anchor: docs/Miksuu/perf still carry the swapped debit; current stable fixes debit order and current-level lookup, while historical release evidence fixed debit only. Use [AI commander autonomy audit](AI-Commander-Autonomy-Audit#ai-upgrade-debit-branch-matrix) and [Upgrades and research](Upgrades-And-Research-Atlas#ai-commander-flow) before enabling or expanding autonomous AI commander upgrades.

Kill-bounty detail: player-facing bounty awards are client PVF/local-money paths, but AI-led kill bounty has a separate server branch. `RequestOnUnitKilled.sqf:83-100` sends `AwardBountyPlayer`/`AwardBounty` to players for player kills and, when `WFBE_C_AI_TEAMS_ENABLED > 0`, credits the AI killer group directly with `ChangeTeamFunds` (`RequestOnUnitKilled.sqf:97-100`). Treat score/bounty changes as both player-economy and AI-team-economy work.

### Supply Mission Reward Formula And Stale Copy

The runtime reward path is not the old "4 x actual value" player-help rule.

| Scope | Runtime reward |
| --- | --- |
| Docs checkout `8a6695b8`, Miksuu `b8389e74`, perf `0076040f` | Loaded cargo is `floor((town supplyValue) * WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER * supplyUpgradeModifier)` in `supplyMissionStart.sqf:32`; the multiplier is `20` at `Init_CommonConstants.sqf:167`. Completion sends the same `_supplyAmount` to the player message path, where `supplyMissionCompletedMessage.sqf:13-14` grants raw cash and `:22` requests score. |
| Current stable `origin/master@0139a346` | Heli/truck loading writes `SupplyByHeli` at `supplyMissionStart.sqf:80`, completion reads it at `supplyMissionCompleted.sqf:26`, computes cash-run state at `:29,33-37`, clears it at `:44`, and sends `_byHeli` / `_cashRun` in the completion message at `:31`. Player cash reward starts as `_supplyAmount`, then applies `WFBE_C_SUPPLY_HELI_REWARD_MULT` for heli delivery in `supplyMissionCompletedMessage.sqf:16-17`; score does the same at `:32-33`. The heli reward constant is `Init_CommonConstants.sqf:326`. |

The stale copy is in maintained `stringtable.xml:188-193`: `STR_Supplies_2` still tells players they receive "4 x the actual value as cash". The matching `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF = 4` remains defined (`Init_CommonConstants.sqf:268` in the docs checkout, `:285` on stable, `:281` on release), but this source pass found no maintained supply-completion consumer. Treat the stringtable text as player-facing docs debt, not runtime authority.

## Economy Authority Synthesis

The economy authority class is characterized by source review. Every confirmed spend or value-changing path is client-authoritative or trusts client-originated payload/state:

| Path | Finding | Evidence |
| --- | --- | --- |
| Construction/build | Client pays and sends `RequestStructure` / `RequestDefense`; server performs only light creation checks. | DR-6, [Construction atlas](Construction-And-CoIn-Systems-Atlas) |
| Player unit buy | Client spawns through `Client_BuildUnit` and deducts locally; no `RequestBuyUnit` PVF exists. | DR-14, [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas) |
| Structure sale | Economy UI refunds and destroys locally. | DR-16 |
| Side supply | Direct temp channels mutate keyed `wfbe_supply_%1` values; the generic `wfbe_supply` client init value is a legacy alias/cache. Current docs checkout `8cb43e4e` has no checked source drift from the `6d05cb5a` side-supply anchors. | DR-22, DR-44, [Economy authority first cut](Economy-Authority-First-Cut#side-supply-branch-matrix) |
| Score mutation/rewards | `RequestChangeScore` accepts a payload score, while `Common_AwardScorePlayer` and kill scoring show safer server-derived award patterns. | [Economy authority first cut](Economy-Authority-First-Cut), [Public variable channel index](Public-Variable-Channel-Index) |
| Player/group funds | No `RequestChangeFunds` PVF exists; funds are changed through replicated `wfbe_funds` group variables and shared helpers. | [Economy authority first cut](Economy-Authority-First-Cut) |
| Supply mission cargo/reward | Client stamps `SupplyFromTown` / `SupplyAmount` and, on current stable, `SupplyByHeli` onto the vehicle; server completion trusts those vars after proximity checks. Personal cash/score reward presentation is still client-side after the completion broadcast. | [Supply mission architecture](Supply-Mission-Architecture) |
| Upgrades | `RequestUpgrade` passes raw payload into server process; no server-side cost/commander/dependency validation. | DR-23 |
| ICBM/special | Client can send `RequestSpecial ["ICBM", ...]`; server spawns `NukeDammage` from payload without authority checks. | DR-27, [Networking/PV](Networking-And-Public-Variables) |
| Gear/EASA/service | Gear, EASA and vehicle service effects/debits are client-side; service rearm/refuel skip even client affordability guards. | DR-28, [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) |
| Attack wave price modifier | `ATTACK_WAVE_INIT` is a direct client/common -> server publicVariable; server trusts `_supply` / `_side` and can apply a side-wide unit-price modifier from forged payload. | DR-41, [Networking/PV](Networking-And-Public-Variables), [Server authority map](Server-Authority-Migration-Map), [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) |

This should be treated as one owner decision, not separate patch tracks. Either introduce a server-side funds/effects ledger and validate each spend handler before applying effects, or explicitly accept the legacy client-trusted model and lean on BattlEye script filters for public-server hardening. DR-41 adds an important architecture rule: the forgery class has two surfaces, registered PVF handlers and direct `publicVariableServer` channels, so a PVF dispatcher fix alone does not harden direct economy/support channels. Small parity fixes, such as adding affordability guards to service rearm/refuel, are useful correctness work but do not close the architectural authority gap.

Side-supply logging caveat: `Common_ChangeSideSupply.sqf:8-13` only copies the human-readable `_reason` when `count _this > 3`. Use the branch-checked [Economy authority matrix](Economy-Authority-First-Cut#side-supply-reason-string-branch-matrix): checked docs/source, stable, upstream, perf and release roots all drop the 3-argument `AttackWave.sqf:40` reason while preserving 4-argument supply-completion reasons. Patch this as diagnostics cleanup alongside side-supply clamp/validation work, not as authority closure.

## Supply-Related Partial Work

Do not use this page as the canonical AI logistics status page. [AI commander autonomy audit](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix) owns the AI supply-truck matrix: current stable and historical release evidence safe-disable the incomplete worker, while Miksuu/perf still carry the raw-spawn trap. Treat autonomous AI logistics as incomplete/deferred until a code-owner revival is source-smoked.

## Supply Helicopter Branch Work

Current stable `origin/master@0139a346` carries the supply-heli/cash-run source shape in both maintained roots; docs/source `15563691`, current Miksuu `b8389e748243` and perf `0076040f` remain truck-only. PR #1 is closed/unmerged and no live origin supply/heli feature head was found on 2026-06-22, so old PR/release rows are historical branch-review context. [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix) owns the exact matrix and line anchors. The economy takeaway is that heli support adds class constants, upgrade gates, `SupplyByHeli`, air bonuses, commander-team cash runs and interdiction-related constants, but it does not change the fundamental client-started/server-completed trust model.

Implementation handoff: [Economy authority first cut](Economy-Authority-First-Cut) turns this economy-authority class into the smallest source-backed patch order.

## Continue Reading

Previous: [Core systems](Core-Systems-Index) | Next: [Supply mission architecture](Supply-Mission-Architecture)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)


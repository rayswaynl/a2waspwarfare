# Pending Owner Decisions

> Claude-owned (2026-06-02). The single place a code owner can see every open decision the deep-review campaign surfaced, each with its finding(s) and the affected subsystem. The [Codebase coverage ledger](Codebase-Coverage-Ledger) is "green except Auth/PV cells"; **those residual cells are exactly the decisions below** — review work is complete, what remains is choosing and applying fixes. Severity uses the [Deep-review findings](Deep-Review-Findings) tiers.

## How To Use This Page

Read this as a decision register, not a bug list. A row belongs here when source evidence is already strong enough and the next step is choosing a policy: server authority, filter posture, revive/remove, smoke gate or branch ownership.

Quick path:

1. Start with the [Owner Decision Queue](Feature-Status-Register#owner-decision-queue) if you need the human-readable triage view.
2. Pick one decision class below and open its canonical page before editing code.
3. If you patch gameplay, update the Chernarus source mission first, run LoadoutManager propagation when needed, and record smoke status in [Source fix queue](Source-Fix-Propagation-Queue) / [`agent-release-readiness.json`](agent-release-readiness.json).

## Fast Decision Queue

| Queue | Decision type | Canonical implementation route |
| --- | --- | --- |
| P0 public-server safety | Choose server-side authority and dispatcher hardening before public hosting, or document a real BattlEye/filter deployment as defense in depth only. | [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook), [ICBM authority](ICBM-Authority-Playbook), [Economy authority first cut](Economy-Authority-First-Cut), [External integrations](External-Integrations). |
| P1 economy and direct-PV migration | Treat spend/effect/direct-PV payloads as requests and re-derive side/funds/supply/effects server-side. | [Server authority migration map](Server-Authority-Migration-Map), [Public variable channel index](Public-Variable-Channel-Index), [Attack-wave authority](Attack-Wave-Authority-Playbook). |
| P1/P2 match correctness | Patch default victory winner/double-fire behavior and choose whether threeway victory is real or unsupported. | [Victory/endgame atlas](Victory-And-Endgame-Atlas), [Hardening roadmap](Hardening-Implementation-Roadmap). |
| P1 logistics baseline | Decide PR #1 supply heli merge requirements separately from dormant autonomous AI logistics. | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Supply mission architecture](Supply-Mission-Architecture), [Current supply heli PR](Current-Work-Supply-Helicopters-PR1). |
| P2 revive/remove backlog | Decide whether to revive, hide or delete dormant UI/support/marker/mission paths. | [Abandoned feature revival](Abandoned-Feature-Revival-Review), [AI commander autonomy audit](AI-Commander-Autonomy-Audit), [Client UI systems atlas](Client-UI-Systems-Atlas). |
| P2/P3 scoped hardening | Patch ready local defects once a maintainer schedules smoke. | [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety), [Service guards](Service-Menu-Affordability-Guards), [Marker cleanup/restoration](Marker-Cleanup-Restoration-Systems-Atlas). |

## 1. The big one — economy/forgery authority (one decision, whole class)

**Decision:** add server-side authority to spend/effect paths, **or** accept client-authoritative economy and ship a real BattlEye filter set. The forgery class has **two surfaces** and the decision must cover both:
- **PVF dispatcher** — `Server_HandlePVF.sqf` / `Client_HandlePVF.sqf` `Call Compile` the sender's command string (DR-1). Fix: validate against the known `SRVFNC*`/`CLTFNC*` set + re-derive authority in each handler. (Same change removes a per-message recompile, DR-38.)
- **Direct `publicVariableServer` channels** — e.g. `ATTACK_WAVE_INIT` (DR-41); each needs its own server re-derivation. See [Public variable channel index](Public-Variable-Channel-Index).

| Path | Finding | Severity |
| --- | --- | --- |
| PVF dispatch RCE/forgery | DR-1 | High |
| Construction (`RequestStructure`/`RequestDefense`/MHQ) | DR-6 | High |
| Unit purchase | DR-14 | High (architectural) |
| Structure sale | DR-16 | High |
| Side-supply transfer (overspend floor) | DR-22 | High |
| Side-supply ledger directly client-writable (forged `wfbe_supply_temp_<side>`) | DR-44 | High |
| Upgrades | DR-23 | High |
| ICBM superweapon (forged `RequestSpecial`) | DR-27 | **Critical** |
| Gear/EASA + vehicle rearm/repair/refuel/heal | DR-28 | High |
| Attack-wave price modifier (direct PV) | DR-41 | High |
| BattlEye option is **not shipped** (22-byte `kickAFK` stub only, no `scripts.txt`) | DR-30 | informs the choice |

> Caveat (DR-30): BattlEye filter files normally live in the server's `BEpath` outside the mission PBO, so confirm the production posture with the server owner before assuming it is unprotected.

## 2. Other correctness fixes (owner-scoped, source-cited)

| Decision | Finding | Severity | Note |
| --- | --- | --- | --- |
| Victory winner-inversion + duplicate game-end | DR-11, DR-13 (mechanism DR-36) | High | one-line: parenthesize/guard both win clauses with `!WFBE_GameOver` + `exitWith` the side `forEach` on win |
| Threeway mode has no victory detection | DR-12 | Medium | enable detection when `WFBE_C_VICTORY_THREEWAY != 0` |
| Commander-assign call-shape bug | DR-15 | Medium | `_side = _this` → `_this select 0` |
| Supply-mission cooldown key casing | DR-18 | Medium | align `lastSupplyMissionRun` vs `LastSupplyMissionRun` (case-sensitive getVariable) |
| HQ-killed non-idempotent score exploit | DR-20 | Medium | idempotency guard on the killed-EH |
| Factory queue soft-lock + broadcast churn | DR-33 | Medium | decrement `WFBE_C_QUEUE` on all exit paths; unique token |
| HC static-defence update-back commented out | DR-42 | Low/Med | restore the update-back or document as fire-and-forget |
| DiscordBot `TypeNameHandling.All` insecure deser | DR-31 | High (latent) | `.All` → `.None` (data is a flat DTO) |
| GLOBALGAMESTATS extension dormant deser + async-void race | DR-29 | Med | delete dead `.Auto` load; fix `File.Replace` race |

## 3. Keep-or-remove / maintenance-model decisions

Use [Abandoned feature revival](Abandoned-Feature-Revival-Review) for the source-backed revive/remove matrix behind the MASH, WASP, AI supply truck, stale UI and modded-mission rows. Paratrooper markers have moved out of the revive/remove bucket for maintained source/Vanilla: see [Paratrooper marker revival](Paratrooper-Marker-Revival) and the smoke-pending row below.

| Decision | Finding | Note |
| --- | --- | --- |
| Modded missions: regenerate from source vs maintain as forks | DR-32 | Napf/eden/lingor are divergent hand-edited forks; source fixes don't reach them |
| 4 abandoned stub missions: complete or delete | DR-32 | sahrani/dingor/tavi/isladuala are non-runnable (1–20 files) |
| MASH map-marker feature: revive or remove | DR-34 | dead both ends; revive needs server-held list + JIP re-send |
| Paratrooper drop markers: smoke propagated fix / decide modded drift | DR-2 | source Chernarus + maintained Vanilla now register the callback and ship the handler; Arma smoke and divergent modded folders remain |
| Dead WASP actions (OnArmor, GearYourUnit) | DR-35 | commented in `AddActions.sqf` |
| `supplyMissionActive.sqf` dead twin | DR-39 | compiled but never called |
| Duplicate `Init_Server` function binds (6) | DR-43b | de-duplicate; `LogGameEnd` dup relates to DR-13 |
| `version.sqf` referenced by `description.ext:39` but absent from source | DR-43a | commit a source `version.sqf` or document pack-time generation |

## 4. Robustness / defense-in-depth (optional)

| Decision | Finding | Note |
| --- | --- | --- |
| Post-join `wfbe_*` `waitUntil` chain has no timeouts | DR-37 | a never-set synced var hangs the JIP client; add defensive timeouts |
| Server-FPS hosted/listen busy-loop | DR-19 | move `sleep` outside the `isDedicated` guard |
| WASP `global_marking_monitor.sqf:62` sleepless display-wait | DR-40 | use the throttled `waitUntil {sleep …; cond}` idiom |

## Agent Handoff Contract

- Do not open a gameplay branch from this page alone; follow the canonical implementation page for source paths, exact evidence and smoke gates.
- Treat "owner decision" as **not a remaining research gap** unless a page explicitly says "research-needed".
- If a decision is made, update this page, [Feature status](Feature-Status-Register), [Hardening roadmap](Hardening-Implementation-Roadmap), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) and [`agent-feature-status.jsonl`](agent-feature-status.jsonl).
- If a feature is removed instead of revived, preserve a short source-backed note explaining why so future agents do not rediscover it as "missing".

## Continue Reading

Scoreboard: [Codebase coverage ledger](Codebase-Coverage-Ledger) | Evidence: [Deep-review findings](Deep-Review-Findings) | Channels: [Public variable channel index](Public-Variable-Channel-Index)

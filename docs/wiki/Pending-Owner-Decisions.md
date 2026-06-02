# Pending Owner Decisions

> Claude-owned (2026-06-02). The single place a code owner can see every open decision the deep-review campaign surfaced, each with its finding(s) and the affected subsystem. The [Codebase coverage ledger](Codebase-Coverage-Ledger) is "green except Auth/PV cells"; **those residual cells are exactly the decisions below** — review work is complete, what remains is choosing and applying fixes. Severity uses the [Deep-review findings](Deep-Review-Findings) tiers.

## 1. The big one — economy/forgery authority (one decision, whole class)

**Decision:** add server-side authority to spend/effect paths, **or** accept client-authoritative economy and ship a real BattlEye filter set. The forgery class has **two surfaces** and the decision must cover both:
- **PVF dispatcher** — `Server/Client_HandlePVF.sqf` `Call Compile` the sender's command string (DR-1). Fix: validate against the known `SRVFNC*`/`CLTFNC*` set + re-derive authority in each handler. (Same change removes a per-message recompile, DR-38.)
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

Use [Abandoned feature revival](Abandoned-Feature-Revival-Review) for the source-backed revive/remove matrix behind the MASH, paratrooper, WASP, AI supply truck, stale UI and modded-mission rows.

| Decision | Finding | Note |
| --- | --- | --- |
| Modded missions: regenerate from source vs maintain as forks | DR-32 | Napf/eden/lingor are divergent hand-edited forks; source fixes don't reach them |
| 4 abandoned stub missions: complete or delete | DR-32 | sahrani/dingor/tavi/isladuala are non-runnable (1–20 files) |
| MASH map-marker feature: revive or remove | DR-34 | dead both ends; revive needs server-held list + JIP re-send |
| Paratrooper drop markers: revive or remove | DR-2 | dead receive path |
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

## Continue Reading

Scoreboard: [Codebase coverage ledger](Codebase-Coverage-Ledger) | Evidence: [Deep-review findings](Deep-Review-Findings) | Channels: [Public variable channel index](Public-Variable-Channel-Index)

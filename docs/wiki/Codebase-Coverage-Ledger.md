# Codebase Coverage Ledger

> Claude-owned campaign tracker (source-cited). This page operationalizes a standing long-term goal: **drive every subsystem of the Chernarus source mission to full, source-verified comprehension and implementation-hardening, until there are no dark corners.** It is the backbone that turns ad-hoc review passes into measurable coverage. Codex fills the *Mapped* column with atlases; Claude fills the hardening columns with source-verified [Deep-review findings](Deep-Review-Findings). Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Arma 2 OA 1.64 only.

## The long-term goal (Claude, self-authored 2026-06-01)

> Get to the bottom of the WASP Warfare mission. Over many bounded passes, take each subsystem from *unmapped* → *source-verified deep-reviewed* → *implementation-hardened*, recording every PV/publicVariable hazard, authority boundary, config-gated landmine, performance trap, JIP/headless edge case, abandoned/half-implemented feature, and generated-mission drift point with `path:line` evidence and a concrete implementation constraint. Each pass: pick the emptiest high-traffic cell in the matrix below, claim the lane in `agent-collaboration.json`, verify against source before claiming anything, publish a small focused commit, and leave Codex an integration-ready handoff. **Done = the matrix is green and the only open items are explicit, owned decisions for code owners.**

This complements [Claude long-term goal](Claude-Long-Term-Goal) (the role) by making the *scope and finish line* explicit.

## Coverage dimensions (the "done" bar per subsystem)

| Dim | Question | Owner emphasis |
| --- | --- | --- |
| **Map** | Is the flow + source map documented? | Codex atlases |
| **Auth** | Are authority/ownership/trust boundaries validated (esp. client→server PVF)? | Claude |
| **PV** | Are publicVariable/network hazards (forgery, RCE, JIP sync) checked? | Claude |
| **Perf** | Are hot loops / spawn-delete / marker churn / `Call Compile` checked? | Claude |
| **JIP/HC** | Are join-in-progress + dedicated + headless edge cases checked? | Claude |
| **Drift** | Are LoadoutManager skip-list / generated-mission divergences checked? | shared |

Legend: ✅ done (source-cited) · 🟡 partial · ⬜ gap. A ✅ cell means the dimension was **reviewed** — either *reviewed-clean* (no defect) or *reviewed-with-finding* (a source-cited DR filed); the row's anchor note says which. "Map ✅" specifically means a flow/source map for the subsystem exists.

## Subsystem matrix (status at 2026-06-02)

| Subsystem | Map | Auth | PV | Perf | JIP/HC | Drift | Anchor docs |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | --- |
| Boot / lifecycle | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | [Lifecycle wait-chain](Lifecycle-Wait-Chain), [Entrypoints](Mission-Entrypoints-And-Lifecycle); **DR-37 (Perf+JIP/HC reviewed clean: frame-throttled cheap waitUntils, robust RequestJoin handshake w/ 30s retry; note: post-join `wfbe_*` waitUntil chain has no timeouts → a never-set synced var hangs JIP client)** |
| PV / networking dispatch | ✅ | ✅ | ✅ | ✅ | ✅ | n/a | [Networking](Networking-And-Public-Variables), DR-1; **DR-38 (Perf: `Call Compile _script` recompiles per message though PVFunctions are pre-compiled at init → the DR-1 validated-lookup fix also removes the recompile; JIP/HC clean — dispatchers registered at init on all machines, PVFs are transient events)** |
| Economy / town / supply | ✅ | ✅ | ✅ | 🟡 | 🟡 | ✅ | [Economy](Economy-Towns-And-Supply), [Gameplay atlas](Gameplay-Systems-Atlas); DR-20, DR-22, DR-23, DR-27, DR-28, **DR-41**. **Economy authority FULLY characterized — every spend path client-authoritative: build/buy/sell/supply/upgrade/ICBM-superweapon/gear-rearm + attack-wave price modifier (DR-41). The forgery class has TWO surfaces: the PVF dispatcher (DR-1) AND direct `publicVariableServer` channels (DR-41 `ATTACK_WAVE_INIT`) — the server-authority redesign must cover both** |
| Supply missions | ✅ | 🟡 | ✅ | ✅ | ✅ | ✅ | [Supply mission arch](Supply-Mission-Architecture), DR (PR#1), DR-18 (cooldown key casing), **DR-39 (Perf+JIP/HC: dead twin `supplyMissionActive.sqf` compiled-but-never-called; live loop scans all-object `nearestObjects[...,[],80]` every 3s — narrowable; JIP done right — cooldown status is pull-based request/response so joiners query state)**. Auth 🟡 = DR-18 + PR#1 (owner) |
| Construction / CoIn | ✅ | ✅ | ✅ | 🟡 | ✅ | ✅ | [Construction atlas](Construction-And-CoIn-Systems-Atlas), DR-6, DR-20 (HQ-killed idempotency); Drift: DR-32 (faithful to vanilla) |
| Factory / purchase | ✅ | 🟡 | 🟡 | ✅ | ✅ | n/a | [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas); DR-14 (no server authority, architectural), DR-15 (commander-assign bug), **DR-33 (Perf+JIP/HC: empty-vehicle buy leaks WFBE_C_QUEUE counter → silent per-factory soft-lock; per-unit sleep-4 poll broadcasts `queu` each mutation; non-unique random queue token)** |
| AI / headless / perf | ✅ | 🟡 | 🟡 | ✅ | ✅ | n/a | [AI/headless](AI-Headless-And-Performance); DR-21 (HC disconnect: server load migration, no re-delegation), **DR-42 (static-defence HC delegation update-back commented out at Client_DelegateAIStaticDefence.sqf:28 → server never tracks HC-created static-defence units; town-AI delegation does report back)** |
| UI / HUD / menus | ✅ | ✅ | 🟡 | 🟡 | ⬜ | ✅ | [UI atlas](Client-UI-Systems-Atlas); DR-16 (client-side sale), DR-17/DR-25a (dup IDDs 23000/10200), DR-24 (dead RscMenu_Upgrade), DR-25b (malformed soundPush) — Curie candidates all confirmed |
| Gear / loadout / EASA | ✅ | ✅ | 🟡 | 🟡 | 🟡 | ✅ | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas); [Deep-review findings](Deep-Review-Findings) **DR-28 (gear/EASA + vehicle rearm/repair/refuel/heal client-authoritative; rearm & refuel skip even the client-side affordability guard)** — completes the economy-authority class |
| WASP overlay | ✅ | 🟡 | 🟡 | ✅ | ✅ | ✅ | [WASP overlay](WASP-Overlay); **DR-40 (Perf clean except `global_marking_monitor.sqf:62` sleepless display-wait busy-spin — throttle like its `:80` sibling; JIP/HC clean — per-client init from Init_Client; old `initJIPCompatible.sqf:243-244` WASP path dead/commented)**. Auth/PV 🟡 = WASP action authority (owner, economy-class follow-up) |
| Tooling / LoadoutManager | ✅ | n/a | n/a | n/a | n/a | ✅ | [Tools](Tools-And-Build-Workflow), DR-4, **DR-43a (`description.ext:39` `#include "version.sqf"` but version.sqf absent from source → repo not buildable as-is; pack-time generated)** |
| Integrations (Extension / Discord / **AntiStack DB** / BattlEye) | ✅ | ✅ | ✅ | 🟡 | 🟡 | n/a | [External integrations](External-Integrations); **all four sub-targets reviewed** — AntiStack DB (DR-7..DR-10), GLOBALGAMESTATS extension (DR-29), BattlEye (DR-30 — `kickAFK` stub only, option (b) not shipped), **Discord (DR-31 — `TypeNameHandling.All` deserialization of `database.json` every 60s = live insecure-deser gadget in the token-holding process; secret hygiene OK; commands auth-gated)** |
| Victory / endgame | ✅ | 🟡 | 🟡 | ✅ | ✅ | n/a | `server_victory_threeway.sqf`; DR-11..DR-13 (winner inversion, threeway no-detection, dup LogGameEnd), **DR-36 (Perf clean @80s cadence; JIP server-authoritative; source mechanism for DR-11/13 = `!WFBE_GameOver` guards only the towns clause + no break in side forEach → same-tick double-fire inverts WF_Winner)**; **DR-43b corrected source re-check: `Init_Server.sqf` has live duplicate binds for `LogGameEnd`, `PlayerObjectsList`, `AwardScorePlayer` plus commented duplicate remnants**. Auth/PV 🟡 = the DR-11/12/13 fixes (owner) |
| Weather / day-night | ✅ | n/a | ✅ | ✅ | ✅ | n/a | `Server_DayNightCycle.sqf` — **reviewed clean (Round 17, no defect)**: no div-by-zero, JIP-covered, local-animation+drift-sync design sound |
| Modules (Artillery / ICBM / IRS / CM / UAV) | 🟡 | 🟡 | 🟡 | 🟡 | 🟡 | ✅ | [Deep-review findings](Deep-Review-Findings) DR-27 (**ICBM nuke fully client-authoritative — forged `RequestSpecial` PV = server-applied map-wide kill, CRITICAL**); UAV-007 branch confirmed disabled; rest config-gated cosmetic/QoL. **Map 🟡: only ICBM/Nuke (DR-27) + UAV mapped; full modules atlas pending (returns to ✅ when it lands)** |
| Parameters / localization | ✅ | n/a | n/a | n/a | ✅ | ✅ | [Deep-review findings](Deep-Review-Findings) **DR-35 — reviewed clean**: no live missing `localize`/`$STR_` keys (3 apparent misses = 1 casing FP, 1 engine `STR_EP1_*`, 2 dead/commented WASP actions); params system live + wired (`Init_Parameters.sqf`, `initJIPCompatible.sqf:121`, `Dialogs.hpp:3136`); `paramsArray` index-aligned (keep `class Params` order) |
| Markers / cleaners / restorers | 🟡 | n/a | ✅ | ✅ | ✅ | n/a | [AI/headless](AI-Headless-And-Performance); [Deep-review findings](Deep-Review-Findings) **DR-34 (MASH map-marker dead both ends — trigger never broadcast + receiver commented at Init_Client.sqf:132 + orphaned live server PVEH; latent `publicVariable` JIP gap if revived; respawn selector is a 33Hz local loop)**. **Map 🟡: MASH markers mapped (DR-34); the cleaners/restorers (crater/mines/ruins/dropped-items/buildings) are not yet atlas'd** |

### Milestone (2026-06-02, Round 31 / DR-40)

**All six dimensions are now source-reviewed for every subsystem.** With DR-40 (WASP overlay), the **Perf and JIP/HC columns are complete across the matrix** — DR-33 (factory), DR-36 (victory), DR-37 (boot), DR-38 (PV-dispatch), DR-39 (supply), DR-40 (WASP), plus the earlier rows. The Map and Drift columns were completed earlier (DR-32). The **only remaining 🟡 cells are Auth/PV, and each is an explicit owner decision, not a review gap**: the client-authoritative economy/forgery class (DR-1, DR-6, DR-14, DR-16, DR-22, DR-23, DR-27, DR-28 — one decision: server-side authority vs BattlEye, the latter not shipped per DR-30), the victory winner-inversion/dup fixes (DR-11/DR-12/DR-13, mechanism in DR-36), supply authority (DR-18 + PR#1), and the WASP/modules action-authority follow-ups. Every such cell links to a source-cited finding with a concrete fix; what remains is for the code owner to choose and apply.

### Drift dimension — campaign-wide result (DR-32)

The Drift column is characterized for the whole codebase by [Deep-review findings](Deep-Review-Findings) DR-32. Summary: the **vanilla generated mission (Takistan) is a faithful regeneration** of the Chernarus source — only 15/671 `.sqf` differ and all are map-config (per-faction artillery, one `Init_Server.sqf` `SET_MAP 1→2` line, help, start vehicles) + textures; **all logic files are byte-identical**, so every DR-1..DR-31 finding propagates verbatim to vanilla. The **7 modded missions** are out-of-scope of faithful generation: **Napf/eden/lingor are divergent hand-edited forks** (100+ logic files differ, incl. security-critical PVF/victory/upgrade/HQ files; not regenerated from source per DR-4) and **sahrani/dingor/tavi/isladuala are abandoned stubs** (1–20 files, non-runnable). Drift cells marked ✅ mean "faithful to vanilla / drift characterized"; the modded divergence is an explicit **owner decision** (regenerate vs maintain-as-forks vs delete stubs), not a remaining review gap.

## Biggest open cells (self-selection queue, highest value first)

1. ~~Integrations — AntiStack DB extension trust path~~ **DONE** (Round 5, DR-7..DR-10): server `call compile`s the external DLL's stdout; blocking poll on join; callExtension length limits; defaults-on against an absent DLL. Remaining integrations sub-targets: in-repo `Extension/` GLOBALGAMESTATS DLL + DiscordBot data path + BattlEye filter posture.
2. ~~Factory / purchase authority~~ **DONE** (Round 7, DR-14/DR-15): player purchasing is fully client-authoritative (no server PVF; architectural ceiling); `Server_AssignNewCommander` call-shape bug confirmed.
3. ~~UI / HUD adversarial pass~~ **PARTLY DONE** (Round 8, DR-16/DR-17): economy-menu sale is client-authoritative; dup IDD 23000 confirmed. Remaining: shared title IDD 10200, stale `RscMenu_Upgrade`→missing `GUI_Menu_Upgrade.sqf`, suspect `RscClickableText.soundPush[]`, dialog/EH leaks.
4. ~~JIP/HC cross-cut~~ **STARTED** (Round 10, DR-20): HQ killed-EH locality traced end-to-end → non-idempotent OnHQKilled fires per owning-side client (score exploit). JIP detection itself is correct. Remaining JIP/HC: attack-wave sync, marker re-init, headless orphan-on-disconnect.
5. ~~Victory / endgame + DB flush~~ **DONE** (Round 6, DR-11..DR-13): winner-inversion in persisted stats, threeway mode has no detection, duplicate buggy LogGameEnd. Follow-up: `WFBE_CL_FNC_EndGame` payload semantics.

## How to use this ledger

- **Before a pass:** pick the top unblocked item; claim the lane (`agent-collaboration.json` + `claim` event).
- **After a pass:** flip the relevant cell(s) and link the finding; append `complete` event + worklog.
- **Codex:** when an atlas lands, flip the *Map* cell to ✅ and add the anchor doc; leave the hardening columns for Claude.
- This is a living scoreboard — the campaign is finished when no high-traffic cell is ⬜/🟡 and the residual list is only owner-decisions.

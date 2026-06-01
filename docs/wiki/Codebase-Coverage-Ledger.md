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

Legend: ✅ done (source-cited) · 🟡 partial · ⬜ gap.

## Subsystem matrix (status at 2026-06-01)

| Subsystem | Map | Auth | PV | Perf | JIP/HC | Drift | Anchor docs |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | --- |
| Boot / lifecycle | ✅ | ✅ | ✅ | 🟡 | 🟡 | ✅ | [Lifecycle wait-chain](Lifecycle-Wait-Chain), [Entrypoints](Mission-Entrypoints-And-Lifecycle) |
| PV / networking dispatch | ✅ | ✅ | ✅ | 🟡 | 🟡 | n/a | [Networking](Networking-And-Public-Variables), DR-1 |
| Economy / town / supply | ✅ | ✅ | ✅ | 🟡 | 🟡 | ✅ | [Economy](Economy-Towns-And-Supply), [Gameplay atlas](Gameplay-Systems-Atlas); DR-20, DR-22, DR-23, DR-27, DR-28. **Economy authority FULLY characterized — every spend path client-authoritative: build/buy/sell/supply/upgrade/ICBM-superweapon/gear-rearm. One owner decision (server ledger vs BattlEye) covers the whole class** |
| Supply missions | ✅ | 🟡 | ✅ | 🟡 | 🟡 | ✅ | [Supply mission arch](Supply-Mission-Architecture), DR (PR#1), DR-18 (cooldown key casing) |
| Construction / CoIn | ✅ | ✅ | ✅ | 🟡 | ✅ | ✅ | [Construction atlas](Construction-And-CoIn-Systems-Atlas), DR-6, DR-20 (HQ-killed idempotency); Drift: DR-32 (faithful to vanilla) |
| Factory / purchase | ✅ | 🟡 | 🟡 | ✅ | ✅ | n/a | [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas); DR-14 (no server authority, architectural), DR-15 (commander-assign bug), **DR-33 (Perf+JIP/HC: empty-vehicle buy leaks WFBE_C_QUEUE counter → silent per-factory soft-lock; per-unit sleep-4 poll broadcasts `queu` each mutation; non-unique random queue token)** |
| AI / headless / perf | ✅ | 🟡 | 🟡 | ✅ | ✅ | n/a | [AI/headless](AI-Headless-And-Performance); DR-21 (HC disconnect: server load migration, no re-delegation) |
| UI / HUD / menus | ✅ | ✅ | 🟡 | 🟡 | ⬜ | ✅ | [UI atlas](Client-UI-Systems-Atlas); DR-16 (client-side sale), DR-17/DR-25a (dup IDDs 23000/10200), DR-24 (dead RscMenu_Upgrade), DR-25b (malformed soundPush) — Curie candidates all confirmed |
| Gear / loadout / EASA | ✅ | ✅ | 🟡 | 🟡 | 🟡 | ✅ | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas); [Deep-review findings](Deep-Review-Findings) **DR-28 (gear/EASA + vehicle rearm/repair/refuel/heal client-authoritative; rearm & refuel skip even the client-side affordability guard)** — completes the economy-authority class |
| WASP overlay | ✅ | 🟡 | 🟡 | 🟡 | ⬜ | ✅ | [WASP overlay](WASP-Overlay) |
| Tooling / LoadoutManager | ✅ | n/a | n/a | n/a | n/a | ✅ | [Tools](Tools-And-Build-Workflow), DR-4 |
| Integrations (Extension / Discord / **AntiStack DB** / BattlEye) | ✅ | ✅ | ✅ | 🟡 | 🟡 | n/a | [External integrations](External-Integrations); **all four sub-targets reviewed** — AntiStack DB (DR-7..DR-10), GLOBALGAMESTATS extension (DR-29), BattlEye (DR-30 — `kickAFK` stub only, option (b) not shipped), **Discord (DR-31 — `TypeNameHandling.All` deserialization of `database.json` every 60s = live insecure-deser gadget in the token-holding process; secret hygiene OK; commands auth-gated)** |
| Victory / endgame | ✅ | 🟡 | 🟡 | 🟡 | 🟡 | n/a | `server_victory_threeway.sqf`; DR-11..DR-13 (winner inversion, threeway no-detection, dup LogGameEnd) |
| Weather / day-night | ✅ | n/a | ✅ | ✅ | ✅ | n/a | `Server_DayNightCycle.sqf` — **reviewed clean (Round 17, no defect)**: no div-by-zero, JIP-covered, local-animation+drift-sync design sound |
| Modules (Artillery / ICBM / IRS / CM / UAV) | ✅ | 🟡 | 🟡 | 🟡 | 🟡 | ✅ | [Deep-review findings](Deep-Review-Findings) DR-27 (**ICBM nuke fully client-authoritative — forged `RequestSpecial` PV = server-applied map-wide kill, CRITICAL**); UAV-007 branch confirmed disabled; rest config-gated cosmetic/QoL |
| Markers / cleaners / restorers | ✅ | n/a | 🟡 | ✅ | 🟡 | n/a | [AI/headless](AI-Headless-And-Performance) |

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

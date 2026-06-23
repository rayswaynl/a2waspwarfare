# Upstream Mining Ledger

> Claude-owned ledger (source-cited). Records the **2026-06-23 upstream-mining loop**: a self-paced pass that mined the upstream parent `Miksuu/a2waspwarfare` for features genuinely missing from `rayswaynl/a2waspwarfare` and delivered the worth-doing slice as **draft, human-merge-gated** code PRs. It complements [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel) (which catalogs upstream commit lineage) by recording the *triage verdicts and PR outcomes* of one bounded mining batch. All source claims here were verified against `origin/master` and the named upstream branch tips.

## Goal & method

`rayswaynl/a2waspwarfare` is a heavily-diverged fork — roughly **557 commits ahead** of its upstream parent `Miksuu/a2waspwarfare`. The goal of this loop was to find any upstream feature that is still **absent** from our `master` and is worth porting, then deliver each worth-doing candidate as a **draft PR** for human review (never an auto-merge).

Method (funnel):

1. **Fetch** all **490** branches from the upstream `Miksuu` remote.
2. **Diff** each against our `master` → **93** branches carry at least one *unique* commit not already absorbed into our fork.
3. **Workflow triage** of the 93 (type, value, risk, effort, present-on-master guess, OA-safety) → see `triage_table.tsv`.
4. **Adversarial source verification** of the promising rows — confirm each feature is actually missing on `origin/master` (not just renamed/absorbed), check OA 1.64 command safety, MP/JIP/locality/server-authority hazards, and whether the upstream diff even *applies* against our diverged tree → see `verified_table.tsv` and `actionable_detail.txt`.
5. **Rank** into a PR shortlist; open drafts for the genuinely-missing, portable, OA-safe candidates; flag the rest with owner/security notes.

## Headline finding

**Our fork has already absorbed nearly all high-value upstream work; the remaining surface is thin.** The funnel collapsed hard:

| Stage | Count |
| --- | --- |
| Upstream branches fetched | 490 |
| Branches with unique commits vs our `master` | 93 |
| Deep-verified — pass 1 | 18 |
| Re-verified — pass 2 | 30 |
| **Net draft PRs opened** | **6** |
| **Flagged findings (no PR)** | **3** |

Most of the 93 unique-commit branches turned out to be debug/test scratch branches, stale merge tombstones (empty diff vs merge-base), version-snapshot bundles whose payloads are already on `master`, reverts, or A3-port experiments. Of the small set that were *genuinely missing and worth shipping*, several upstream implementations were **broken as written** and had to be reimplemented cleanly rather than cherry-picked.

## Draft PRs opened

All six are **DRAFT** and **human-merge-gated**. None has had in-engine smoke yet — engine validation (OA 1.64 hosted/dedicated) is **pending** and is a merge precondition. Where the upstream diff did not apply against our diverged tree (the common case), the change was hand-reapplied / cleanly reimplemented rather than cherry-picked.

| PR | Branch | Summary | Notes |
| --- | --- | --- | --- |
| [#54](https://github.com/rayswaynl/a2waspwarfare/pull/54) | `claude/upstream-at-naming-order` | AT-soldier buy-menu display names + NLAW barracks tier | RU/TK AT → `Rifleman (RPG-7 VL)`; BAF AT → `AT Specialist (NLAW)`; NLAW gated to barracks L2 (Dragon parity, verified); NLAW reordered below SMAW. Pure data-array literals, OA-safe, lowest-risk. Source: `UnitNamingAndOrderChanges` (only `ready` row in pass 1). |
| [#55](https://github.com/rayswaynl/a2waspwarfare/pull/55) | `claude/upstream-blinking-mapicons` | Blink the mounted player's own soldier marker | When player is gunner/commander of a vehicle whose LFTB flag is active, also push the player's soldier unit into `BLINKING_UNITS_*`. Client-local, OA-safe. Hand-ported into our diverged `Client_BookkeepBlinkingIcons.sqf`. Source: `BlinkingMapIconsV2`. |
| [#56](https://github.com/rayswaynl/a2waspwarfare/pull/56) | `claude/upstream-an2-climb-boost` | AN-2 high-climb boost, capped below cruise | Adds the Valhalla climbing-assist low-gear action to `An2_TK_EP1`, with a deliberately chosen boost target so it doesn't become a velocity exploit. Rewritten against our assist-only LowGear model (upstream's `_min=90/_max=250` was meaningless against our rewrite). Source: `An-2FastLiftVehicleWithHalo` (HALO half already shipped on master; only climb-boost was missing). |
| [#57](https://github.com/rayswaynl/a2waspwarfare/pull/57) | `claude/upstream-hq-repair-price` | Show the next MHQ repair price in the action menu | **Clean reimplementation** of upstream's broken version. Upstream's `localize` calls referenced strings/keys with no `%1` placeholders, so the price never rendered, and it dropped the cap-reached guard. This PR adds proper `%1` placeholders to both stringtables, fixes the `format` calls, keeps the Repairs_Used exit guard, and applies to both Chernarus + Takistan. Source: `HQRepairPriceVisibileOnTheActionMenu`. |
| [#58](https://github.com/rayswaynl/a2waspwarfare/pull/58) | `claude/upstream-town-defense-diag-sync` | Town-defense group-count diagnostics + `RptTownDefenseAnalyzer` tool | Group-saturation diagnostics for town-defense HC groups plus a PowerShell RPT analyzer, syncing a 3-behind diagnostics line. Tooling/observability, not gameplay logic. Source: `Marty_stress_test_town_defenses`. |
| [#59](https://github.com/rayswaynl/a2waspwarfare/pull/59) | `claude/upstream-barracks-4th-level` | 4th Barracks level + sweeping infantry tier rebalance | Adds a 4th barracks level and increments many infantry units' required level by +1 (raises the bar for HAT/AAR/Spotter etc.), plus MAAWS HEDP→HEAT and the AT renames. **Needs balance sign-off.** The two upstream `[REVERT LATER]` test hacks (research TIMES=1s, supply default 76800) were stripped; the new `CZ_Soldier_AT_Wdl_ACR` classname must be confirmed in-engine before merge. Source: `BarracksInfantryRework`. |

## Flagged findings (no PR — owner decisions / security)

These three are genuinely missing from `master` but are **not** safe to port as-is. Each needs an owner/design decision; one is a security regression.

### (a) `AdditionalHQBuying` — security: would WORSEN a known HIGH-severity exploit

Porting this would **worsen** an already-flagged HIGH-severity client-authority hole, not just add a feature.

- It **removes the only duplicate-rebuy guard** (`cashrepaired`) on the WASP depot RECOVER-HQ action and adds **no** server-side gate.
- The price escalation is a **client-local** `missionNamespace setVariable` with no `publicVariable`/broadcast — so the "+50k each rebuy" never escalates globally and is trivially reset by reconnect (the feature's core promise is broken in MP).
- The existing depot rebuy is already client-authoritative: the client unilaterally debits funds, sends `RequestMHQRepair` (server spawns a fresh MHQ with **zero** validation), and broadcasts a town-supply reset that **zeroes all own-side town supply**. Removing the one-time lock turns a one-time client-side exploit into a **repeatable own-side town-supply drain** — a griefing/desync exploit.

Cross-reference the existing entries that already call this out: [Deep-Review Findings](Deep-Review-Findings) (DR-55 / `:1145`), [Server Authority Migration Map](Server-Authority-Migration-Map) (`:110`), [WASP Overlay](WASP-Overlay) (`:69`). **Recommendation: server-side redesign only** — move price escalation + rebuy-count + funds debit + town-supply reset into `Server_MHQRepair.sqf` / `RequestMHQRepair.sqf` with `publicVariable` broadcast and server-validated debit. Do **not** ship the raw branch.

### (b) `AirRework_GunDamageAdjustedToPlanes` — inverted intent + dead ammo classnames

- The per-plane `HandleDamage` scaling uses `_p=99`, which yields `_dam*0.01` — planes take only **1% of cannon damage** (near gun-**immune**), the **opposite** of the stated "more lethal dogfights" intent. Owner must confirm the actual balance direction.
- **4 of 6 ammo classnames per plane** (`B_30mmA10_AP`, `B_20mm_AP`, `B_23mm_APHE`, `B_77x56_Ball`) match **zero** real OA rounds — most case arms never fire. Real rounds are `B_30mm_AA`/`B_23mm_AA`/`B_20mm_AA`/`B_25mm_HEI`.
- Only the Chernarus diff is portable (the branch also patches `tasmania2010` and a takistan folder that don't exist on our master). Mechanically trivial to port one file, but it is effectively a **no-op until the design defects are fixed**. **Recommendation: template only** — keep as a starting point, drop the dead folders, then have the owner set the intended `_p` direction and rewrite ammo cases to real OA classnames.

### (c) `Tournament_SideSpeakerWIP` / `TournamentFeaturesImplementation` — caster/spectator system, needs-design

- A tournament caster/spectator system (civilian "side speaker" broadcast, full spectator/spectating module, custom chat-color mod, authorized spectator-slot IDs) that is **genuinely absent** from master.
- But it is **unfinished WIP** (134 / 132 commits) and, by design, the side-speaker broadcast **leaks both-team intel to all clients** (the tip commit itself admits the channel scope is unresolved).
- **Recommendation: needs-design, not a port.** If wanted, it requires a server-side audience-gating design so spectator/caster intel does not leak to active players — not a raw branch import.

## Reusable artifacts

The full scan/triage/verify tables live under the mining lane at `C:/Users/Chill/a2ww-upstream-mining/_mining/`:

- `triage_table.tsv` — the 93 unique-commit branches with type/value/risk/effort/present/oa columns + one-line descriptions.
- `verified_table.tsv` — the deep-verified rows with `ready` verdicts (`ready` / `needs-design` / `skip`).
- `actionable_detail.txt` — per-candidate verdicts: FEATURE / MISSING? / SELF-CONTAINED / PORTABILITY / OA-SAFE+HAZARDS / TEST PLAN / RECOMMENDATION, with `path:line` source citations.

These are the audit trail for why each branch did or did not become a PR, and are the starting point if the loop is rerun against a fresh upstream fetch.

## Continue Reading

- [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel)
- [Abandoned feature revival review](Abandoned-Feature-Revival-Review)
- [Feature status register](Feature-Status-Register)

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

## Pass 3 — Trello board (Miksuu's Warfare)

> A second, **independent** mining pass that does not look at upstream branches at all — it mines the **Miksuu's Warfare Trello board** (the community's feature/bug backlog) for forward work worth doing in `rayswaynl/a2waspwarfare`, and delivers the worth-doing slice as grouped **draft, human-merge-gated** PRs. Passes 1–2 (above) mined the upstream parent's *git branches*; this pass mines the *idea backlog*.

### Source & funnel

- **Board:** Miksuu's Warfare — <https://trello.com/b/Si4okJLd/miksuus-warfare>. Exported via `curl -L https://trello.com/b/Si4okJLd.json` (public board JSON).
- **Raw size:** 104 lists / **712 open cards**. Most lists are *version changelogs* (work already shipped in past releases) or the `Low Priority (Won't)` bucket — neither is forward work.
- **Tier-1 forward cards (118):** the cards in the actionable lists — `Must`, `Should`, `Next`, `Needs-triage`, `Suggested`, `Draft`, plus the `perf` and `cleaning` lists.

| Stage | Count |
| --- | --- |
| Open cards on the board | 712 |
| Tier-1 forward cards (Must/Should/Next/Needs-triage/Suggested/Draft/perf/cleaning) | 118 |
| Deep-verified against `origin/master` source | 22 |
| **Ready → grouped draft PRs** | **8 cards / 6 PRs** |
| Needs-design (owner/vote/art decision, no PR) | 8 |
| Skip (false premise / not worth it) | 6 |

The same discipline as passes 1–2 applies: each "ready" card was verified against `origin/master` source (feature actually missing, OA 1.64-safe, no MP/JIP/locality/server-authority regression) before a PR was opened. All PRs are **DRAFT** and **human-merge-gated**; **in-engine smoke is pending** and is a merge precondition.

### 6 grouped draft PRs opened (8 cards)

Cards are grouped where they share a file/subsystem so review stays single-purpose.

| PR | Summary | Trello card(s) |
| --- | --- | --- |
| [#60](https://github.com/rayswaynl/a2waspwarfare/pull/60) | Show vehicle ammo % in the service menu | #99 |
| [#61](https://github.com/rayswaynl/a2waspwarfare/pull/61) | Action to toggle automatic IR smoke off/on | #38 |
| [#62](https://github.com/rayswaynl/a2waspwarfare/pull/62) | Flashing warning when FAB-250 / Mk82 is selected above the bomb altitude limit (a "Must") | #106 |
| [#63](https://github.com/rayswaynl/a2waspwarfare/pull/63) | Anti-spam guards for building (#71) and vehicle (#74) repair — two exploit-fixes | #71, #74 |
| [#64](https://github.com/rayswaynl/a2waspwarfare/pull/64) | Block engineer salvage when a friendly salvage truck is in range | #15 |
| [#65](https://github.com/rayswaynl/a2waspwarfare/pull/65) | AAR upgrade enhancements — tiered detection height (#65) + new-contact warning (#66) | #65, #66 |

### 8 needs-design (owner / vote / art decisions — no PR)

Each is a real card but blocked on a decision that is not a coding call:

- **#105 paratroop kill reward** — root cause was never pinned upstream; needs source-level diagnosis before a fix can be trusted.
- **#26 first-blood bonus** — the reward numbers are a **vote** decision and the SFX is an **art** decision.
- **#27 OPFOR Hind re-tier** — balance/owner call on which tier the Hind belongs in.
- **#29 town-depot supply trucks @10x** — economy-tuning owner decision.
- **#41 radiation damages factories** — scope/design owner decision.
- **#111 free supply truck at spawn** — economy/owner decision.
- **#113 all-arty-to-gunner key** — control-scheme owner decision.
- **#91 IR-smoke "cooldown ready" cue** — **false premise**: there is no player-facing IR-smoke cooldown in current source for a cue to track, so the card as written has nothing to bind to.

### ~34 deferred small codeable wins (later pass)

Genuine, small, codeable wins held for a later batch to keep this pass focused — examples: **#87** airlift teleporting onto HQ, **#96** rearm-all-AI-at-cannon, **#85** max-cities visual bug, **#84** arty reload-ready sound, **#76** dead WF-menu HUD button, an **audio-cue cluster**, **#98** Linebacker/Tunguska markers.

### Tier-2 — not yet triaged

The large lower-priority lists are untouched this pass: the **`Could` list (149)**, the **`Backlog` list (71)**, and the **voting list**. They are the starting point if the Trello pass is rerun.

### Cross-pass total

Across all three passes this loop has opened **12 draft PRs — #54–#65** — all DRAFT and human-merge-gated, all awaiting OA 1.64 in-engine smoke before any merge.

## Pass 4 — deep backlog (deferred wins + needs-design + Tier-2)

> The follow-through batch that drained the backlog Passes 1–3 had parked. It completed Ray's a/b/c asks: **deep-verified the ~34 deferred small codeable wins** held back in Pass 3, **re-examined the needs-design cards** (the Warfare a + c items), and **triaged the ~220-card Tier-2 long tail** (the `Could` (149) + `Backlog` (71) lists). The verified, genuinely-ready wins were built into **10 more grouped draft PRs**. As with every prior pass, all PRs are **DRAFT** and **human-merge-gated**; **OA 1.64 in-engine smoke is pending** and is a merge precondition.

### 10 new draft PRs

Each is grouped so review stays single-purpose; the source card(s) are listed for traceability.

| PR | What | Source card(s) |
| --- | --- | --- |
| [#66](https://github.com/rayswaynl/a2waspwarfare/pull/66) | Bypass the anti-TK satchel & building scripts while in debug mode | #2, #3 |
| [#67](https://github.com/rayswaynl/a2waspwarfare/pull/67) | Audio cues: paradrop-drop sound + IR-smoke-ready sound | #90, #91 |
| [#68](https://github.com/rayswaynl/a2waspwarfare/pull/68) | Base-integrity bugfixes: airlift drop-on-HQ + nuke vs in-progress construction | #87, #97 |
| [#69](https://github.com/rayswaynl/a2waspwarfare/pull/69) | Fix gear/ammo display for special AT soldier units in the buy menu | — |
| [#70](https://github.com/rayswaynl/a2waspwarfare/pull/70) | EASA aircraft loadout role categories (AA / AG / multirole) — completed half-wired code | #59 |
| [#71](https://github.com/rayswaynl/a2waspwarfare/pull/71) | Higher bounty for killing players on a killstreak (server-authoritative, tunable coefs) | — |
| [#72](https://github.com/rayswaynl/a2waspwarfare/pull/72) | Restrict building static defenses near base when enemies are near (anti tank-trap, tunable consts) | #104 |
| [#73](https://github.com/rayswaynl/a2waspwarfare/pull/73) | One-click crew-all-artillery button | #113 |
| [#74](https://github.com/rayswaynl/a2waspwarfare/pull/74) | Show the player's artillery cooldown on the RHUD | #219 |
| [#75](https://github.com/rayswaynl/a2waspwarfare/pull/75) | Clearer info text: upgrade result value + new-HQ cost in the transfer menu | #107, #204 |

### Known caveat (PR #68)

PR #68 surfaced a **pre-existing Takistan bug**: `Zeta_Hook.sqf` calls `Zeta_Unhook` **without** the `[_vehicle]` args array that the Chernarus B66 fix added. The airlift drop-on-HQ fix depends on that arg being passed, so on Takistan the fix needs the args folding-in (or a separate Takistan fix). Flagged in the PR; not silently shipped.

### ~37 needs-design items (no PR — owner / vote / art decisions)

These are real items but blocked on a decision that is not a coding call (a balance/economy owner decision, a community vote, or an art/SFX asset). They are catalogued in the mining artifacts; the notable ones:

- **#105** — paratroop kill reward fix
- **#26** — first-blood bonus
- **#27** — OPFOR Hind re-tier
- **#29** — town-depot supply trucks @10×
- **#41** — radiation damages factories
- **#63** — captured-town vehicle reward
- **#64** — redeployment "barracks-on-wheels" truck
- **#215** — sell-vehicles feature
- **#120** — anti-illegal-loadout sanitiser
- **#35** — static-count-by-barracks-level

### Deferred / skip backlog

The remaining lower-value Tier-2 cards plus the big `Could` / `Backlog` long tail are **recorded but not actioned** — they fell below the worth-doing bar for this loop and are the starting point if the backlog is re-mined. One small flagged bug noted along the way: `Core_MVD.sqf`'s `[Done]` log line **mislabels itself "Core_RU"**.

### Cross-pass total

Across all four passes this loop has opened **22 draft PRs — #54–#75** — all **DRAFT** and **human-merge-gated**, all awaiting OA 1.64 in-engine smoke before any merge. The initial three-source sweep (upstream branches + Trello Tier-1 + Tier-2 long tail) is now **complete**; the loop from here is **delta-only** (new upstream commits / new board cards as they appear).

## Pass 5 — deferred Tier-2 tail (closeout)

> The closeout batch. Pass 4 deep-verified the Tier-2 long tail but **capped out** before finishing every codeable+missing candidate; **42** were triaged worth-a-deep-look but deferred. This pass deep-verified all **42** of that deferred tail, shipped the genuinely-ready slice as grouped **draft PRs**, and confirmed there is no remaining un-swept mineable surface. As with every prior pass, all PRs are **DRAFT** and **human-merge-gated**; **OA 1.64 in-engine smoke is pending** and is a merge precondition.

### Funnel

| Stage | Count |
| --- | --- |
| Deferred Tier-2 candidates (codeable+missing, capped out of Pass 4) | 42 |
| Deep-verified against `origin/master` source | 42 |
| **Ready → grouped draft PRs** | **7 cards / 4 PRs** |
| Needs-design (owner/vote/art decision, no PR) | 22 |

### 4 grouped draft PRs opened (7 cards)

Cards are grouped where they share a file/subsystem so review stays single-purpose; the source card(s) are listed for traceability.

| PR | What | Source card(s) |
| --- | --- | --- |
| [#76](https://github.com/rayswaynl/a2waspwarfare/pull/76) | Auto-deploy bipod when going prone with a bipod MG | #210 |
| [#77](https://github.com/rayswaynl/a2waspwarfare/pull/77) | Show upgrade icons in the upgrade menu | #164 |
| [#78](https://github.com/rayswaynl/a2waspwarfare/pull/78) | Map radius circles: HQ build area + ambulance redeploy range | #80, #76 |
| [#79](https://github.com/rayswaynl/a2waspwarfare/pull/79) | Artillery UX: per-type range in menu, gun count in the "artillery called" message, and fix arty marker leaking when the caller disconnects mid-barrage | #115, #116, #171 |

### 22 needs-design items (no PR — owner / vote / art decisions)

These are real items but blocked on a decision that is not a coding call (a balance/economy owner decision, a community vote, or an art/SFX asset). They are catalogued in the mining artifacts; the notable ones:

- **#216** — Federal Reserve passive-income endgame building
- **#143** — ICBM impact countdown shown to both teams
- **#178** — automatic minefield markers
- **#174** — more-frequent house-wreck cleanup (perf)
- **#165** — LoadoutManager data-driven missile-list refactor

### Coverage confirmation (surface is exhausted)

- **Miksuu GitHub Issues = 0** — the community runs its backlog on Trello, not Issues, so there is no second issue tracker to mine.
- **Forks = 1** (ours) — there are no hidden contributor forks carrying un-mined work.
- The only remaining un-swept Trello surface is **low-yield**: the `Low Priority (Won't)` list (53 cards) plus 202 archived cards — both explicitly out of the worth-doing bar.

### Final cross-pass total

Across all five passes this loop has opened **26 draft PRs — #54–#79** — all **DRAFT** and **human-merge-gated**, all awaiting OA 1.64 in-engine smoke before any merge. The full mineable surface — **490 upstream branches + Trello Tier-1 + Tier-2 (including the deferred tail)** — is now **EXHAUSTED**; the loop from here is **delta-only** (new upstream commits / new board cards as they appear).

## Continue Reading

- [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel)
- [Abandoned feature revival review](Abandoned-Feature-Revival-Review)
- [Feature status register](Feature-Status-Register)

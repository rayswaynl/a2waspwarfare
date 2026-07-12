# Owner Questions Before Build — 2026-07-07

<!-- GUIDE-REV GR-2026-07-07a — docs only, no runtime/code changes in this file. -->

This supersedes `OWNER-QUESTIONS-BEFORE-BUILD.md`'s 2026-07-05 revision (kept below as
history where still relevant — most of those questions are now answered/shipped, noted
inline). Per master instructions §11: only questions that block implementation or change
gameplay/fairness/performance. Everything else proceeds on documented defaults. This file
IS the channel — do not wait for a live reply before the next build wave; silence on a
line = its stated default ships, flag-gated.

One question per line, grouped by topic.

## AICOM base-sensing (radius / cadence)

- Q-AICOM-1: Live defaults are 3000 m sense radius on Chernarus/Takistan, 2000 m on
  Zargabad, 35% roll every ~4 strategy ticks (`WFBE_C_AICOM2_DECAP_SENSE_RADIUS/_INTERVAL/_CHANCE`,
  `Init_CommonConstants.sqf:749-752`) — these were approved 2026-07-06 and are now LIVE
  (`WFBE_C_AICOM2_DECAP_ENABLE=1`). Confirm no retune wanted post-soak, or state new numbers.
  (Default if silent: keep as-is.)
- Q-AICOM-2: #713's original fully-omniscient HQ-rush design is now fully superseded by
  the re-scoped organic-sensing build — confirm #713 itself can be closed as
  superseded/folded (no separate action needed). (Default if silent: yes, close #713.)

## Stats site (`/wasp` -> `/stats`, public vs admin)

- Q-STATS-1: The `/wasp` -> `/stats` redirect and "Command Center" naming are already
  shipped and live (`web/src/app/wasp/page.tsx` is now an 8-line redirect). Confirm the
  Command Center name is final, or state a different title. (Default if silent: keep
  "Command Center".)
- Q-STATS-2: The public/admin field split is live per `TELEMETRY-AND-STATS-V2-PLAN.md`
  §5 (public: leaderboards, kill matrix, post-round summaries, tactical detail delayed
  15 min for non-admins; admin: commander decisions, base events, perf trends, live
  feed). Confirm this matrix, or name specific fields to move between tiers. (Default if
  silent: ship as currently split.)
- Q-STATS-3: Homepage scale fact for AI-unit count shows "400+" on the live site
  (Q10-2026-07-06 approved value), but the newest V2 spec text quotes "500+". Which is
  canonical — is 500+ a newer decision superseding Q10, or is it stale spec copy?
  (Default if silent: keep the live "400+", evidence-backed by RPT.)

## Discord stats-roles (ops actions, not code)

- Q-DISCORD-1: `stats_roles.py` (playtime/matches/captures/supply-runs/commander-matches/
  score thresholds, opt-out respected, zero pay-to-win surface) is merged and inert until
  DB migration `0021_discord_roles_overhaul.sql` runs against the production Postgres.
  Approve running that migration now, or hold for a specific date? (Default if silent:
  hold — this is a live-DB change, needs an explicit go.)
- Q-DISCORD-2: Once the migration runs, actual threshold VALUES (e.g. "50h playtime =
  Veteran") still need owner input via `/statsroles set-threshold` — the code ships no
  defaults. What are the first-cut threshold numbers, or should Fable propose a starter
  set to review? (Default if silent: Fable proposes a starter set next wave, nothing
  live until reviewed.)
- Q-DISCORD-3: A dedicated `#roles` text channel does not exist yet in the guild — the
  role-picker panels need one to post into. Create it now (channel name/position), or
  reuse an existing channel? (Default if silent: hold, no panel posted until a channel
  is named.)

## SCUD vs Scout (asset-name ambiguity)

- Q-SCUD-1: The original wish text is ambiguous between the buyable/drivable TK-only
  SCUD hull (`MAZ_543_SCUD_TK_EP1`, hard-gated `worldName=="Takistan"` in 6 files) and
  the unrelated AH-6X "Scout" helicopter, or the auto-spawn research TEL (already
  Chernarus-native, non-drivable, already Tactical-Center-integrated). Which one did the
  original request mean? (Default if silent: treat as the TK-only SCUD hull question and
  hold — do not remove the `worldName` guards without a confirm, since it changes
  cross-map balance.)
- Q-SCUD-2: If it is the buyable SCUD hull — should it become buyable/drivable on
  Chernarus (artillery-menu integration, like GRAD), or stay Takistan-only + Chernarus
  TEL-only permanently? (Default if silent: stay as-is.)

## Team-menu direction

- Q-TEAM-1: `TEAM-MENU-PROPOSAL-2026-07-06.md` recommends Option A "Coordination Strip"
  (role declare + aicom-focus town suggestion + aicom-support request + disband, hidden
  intel checked, flag `WFBE_C_TEAM_MENU_V2` default 0). Ship Option A, or pick Option B
  (larger intent board) / Option C (minimal)? (Default if silent: hold — do not build
  any option without an explicit pick, since this replaces live UI surface.)
- Q-TEAM-2: If Option A — is the 120 s focus-suggestion cooldown default acceptable?
  (Default if silent: 120 s, town picker shows all non-owned towns, role ephemeral
  per-life.)

## Base-relocation timing

- Q-RELOC-1: No subsystem literally named "base relocation" was found in this survey.
  Please confirm which of the following the request refers to, so it can be scoped
  correctly: (a) `AICOMV2_CTL_INVEST_ENABLE` — the Commander Town Ledger's AI-spends-
  funds-to-raise-town-strength sub-flag, currently default 0 behind the merge-candidate
  PR #886; (b) naval HVT carrier CAP repositioning/composition (Mi-24 vs L39, PR #822 vs
  #729); (c) an in-game FOB/HQ physical-relocation flow (GUER FOB or main-side HQ move);
  or (d) something not yet surveyed. (Default if silent: no action — this line stays
  open until scoped.)

## Composition/precedence follow-ups surfaced by this survey (new)

- Q-NAVAL-1: PR #729's 3x Mi-24 carrier CAP (`WFBE_C_NAVAL_CAP_THREE_HINDS`, default 1)
  is fully built and live-eligible, but the later PR #822's `WFBE_C_NAVAL_CAP_L39`
  (also default 1) takes precedence, so the LIVE composition is actually 2x L39 jets,
  not 3x Mi-24. If 3x Mi-24 was meant to be the live behavior (not just an available
  option), this is a one-flag change (`WFBE_C_NAVAL_CAP_L39=0`). Which composition should
  be live? (Default if silent: keep current live precedence — L39 wins.)
- Q-BLOAT-1: PR #884's experiment-engine MDE (minimum-detectable-effect) thresholds are
  self-described in the PR body as "proposed; owner sign-off pending." The code is safe
  to merge either way (no mission/flag surface), but findings shouldn't be trusted for
  go/no-go decisions until the thresholds are reviewed. Approve the proposed MDE table,
  or request changes? (Default if silent: merge the code, treat all PASS/FAIL verdicts
  from it as provisional until this line is answered.)

## Non-questions (proceeding on evidence, no gate — carried forward, still true)

- Stale one-shot `docs/` STATUS/NOCHANGE analysis docs (74 files, 4,666 LOC) — zero-risk
  archive to `docs/design/archive/`, flagged 2026-07-05, still open; proceeding without a
  gate on the next docs-cleanup pass.
- `AI-MODS-AND-PATHFINDING.md` Action 0 (verify HC launch line loads ASR AI) is a
  read-only fact-finding SSH task with no mission-code implication by itself — proceeding
  without a gate; results will inform, not require, an owner decision.

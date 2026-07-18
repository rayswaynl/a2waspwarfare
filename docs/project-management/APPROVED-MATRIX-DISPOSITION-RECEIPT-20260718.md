# WASP Approved-Matrix — PR Disposition Receipt (2026-07-18)

Every open PR on `rayswaynl/a2waspwarfare` at 2026-07-18, plus referenced closed PRs. Base `origin/master @80c690257f`. Reviewers R1–R6 are exact-head, read-only, non-Grok independent reviews dispatched by this lane. Soak (S) and two-HC (H) gates are owner-run.

## A. Integrated into `claude/wasp-approved-matrix-integration-20260718` (11)

| PR | Builder | Wave | Reviewer | Disposition | Evidence / reason |
|----|---------|------|----------|-------------|-------------------|
| #1135 | codex | 1 isolated | R1 SAFE | **INCLUDED** | `_side` nil-guard; lint/parity ✓ |
| #1138 | codex | 1 isolated | R1 reviewed | **INCLUDED** | buy/build hardening; carries the 1 benign SEAD FLAGGATE FP (documented) |
| #1137 | codex | 1 isolated | R1 SAFE | **INCLUDED** | carrier-target ban + permanent-day sync; leaves `WFBE_C_AICOM_NAVAL_AIR_ONLY` orphaned (owner) |
| #1134 | codex | 1 isolated | R1 SAFE-config | **INCLUDED (config only)** | faction-price/tuple/registration fixes kept; **CH `version.sqf.template` restored to master** (dropped stale-base marker rollback) |
| #1129 | codex | 1 isolated | R1 SAFE | **INCLUDED** | UAV purchase server-authority + null-gunner guards; `isHostedServer` FP cleared (24× in master) |
| #1124 | codex | 2 ledger | R2 RISKY | **INCLUDED** | CTL/GDIR/heli-refund core; subsumes #1090; CTL conservation = soak-verify item |
| #1139 | codex | 3 standalone | R4 SAFE | **INCLUDED** | command-order queue; supersedes #1127; soak-gate (transport rewire) |
| #1141 | codex | 3 standalone | R6 SAFE | **INCLUDED** | tag-state sync + bounded scans |
| #1125 | codex | 3 standalone | R4 SAFE | **INCLUDED** | spawn-buddy race fix; flag `WFBE_C_SPAWN_BUDDY_DISBAND` default 0 (Parameters.hpp matched) |
| #1142 | fable | 3 standalone | R6 SAFE | **INCLUDED** | terminal-scuttle latch; flag `WFBE_C_AICOM_TERMINAL_SCUTTLE` default 0; boundary vs #1124 verified |
| #1136 | codex | 3 standalone | R4 SAFE | **INCLUDED (behavior-active)** | naval seam; supersedes #1130; **flips `WFBE_C_NAVAL_SEAM_BRIDGE` 0→1** — soak-gate |

## B. Staged mission-code — NOT integrated, need code change + re-review + soak (5)

| PR | Builder | Reviewer | Disposition | Reason + recipe |
|----|---------|----------|-------------|-----------------|
| #1140 | codex | R2 RISKY | **HOLD** | Town-level-only gate reintroduces async under-credit race. Recipe: per-group `WFBE_CO_FNC_GroupGetBool` instead of town-level, keeping the banned-pattern fix |
| #1133 | codex | R2 **BLOCK** | **HOLD** | **Compile-breaking bracket error** in `AI_Commander_Produce.sqf` (all 3 terrains) that count-based BRACKET lint cannot catch. Recipe: add the else's own 6-tab `};`. Other fixes (supply guard, top-up refund, mapSize repair) land after the bracket patch |
| #1132 | fable | R3 RISKY | **HOLD (reconcile)** | Textually auto-merges but writes GDIR ledger index 5 (post-#1124 = ETA slot) → corrupts stuck-cell detection. Recipe: rebase on #1124, keep write at index 4 |
| #1121 | codex | R5 CONDITIONAL | **HOLD (UAV2 reimpl)** | FOB v1; flag-off inert. Fix charge-before-verified-build + `FOBCAMPPROBE` live-soak gate before arming `WFBE_C_STRUCTURES_FOB` |
| #1118 | codex | R5 CONDITIONAL | **HOLD (UAV2 reimpl)** | FPV swarm; flag-off inert. Fix bare `getVariable "WFBE_C_AI_COMMANDER_ENABLED"` default + `WFBE_%1_HVT_CLASS` name. Combine with #1121 as ONE commit, TWO independent flags (disjoint features — do not invent a master UAV2 flag) |

## C. Docs/ops train — separate from mission binary (13)

Confirmed **0 mission-binary files** in each. Not part of this mission integration; owner-routed on their own train.

| PR | Builder | Title | Disposition |
|----|---------|-------|-------------|
| #1126 | **grok** | config-driven WASP main server installer | **SEPARATE TRAIN — requires adversarial non-Grok review** before its train merges (only grok-built PR) |
| #1131 | claude | COMMAND V2 nudge system (design-only) | separate train (design doc) |
| #1128 | fable | fresh-eyes review findings (KIMI) | separate train (docs) |
| #1110 | codex | Peach+ playtest reporting mode | separate train (Discord-bot tooling, not mission) |
| #1108 | lab | ProvingGround lab stack (LAB-guarded) | separate train (tools; supersedes #997/#1004) |
| #1102 | codex | transactional Hetzner installer | separate train (ops) |
| #1101 | fable | live RPT per-mechanic audit | separate train (docs) |
| #1100 | claude | server-side engine-patch catalog | separate train (design docs) |
| #1095 | codex | perf run-manifest + metrics sidecar | separate train (perf tooling) |
| #1093 | codex | weekly local rig health probe | separate train (gaming tooling) |
| #1082 | fable | PRE-FLIGHT C staging (soak) | separate train (docs/soak) |
| #1081 | fable | dated live-config snapshot | separate train (docs) |
| #1078 | fable | reconcile RELEASE-PLAN + rulings | separate train (docs) |

## D. Keep out of production (1)

| PR | Builder | Disposition |
|----|---------|-------------|
| #1013 | codex | **KEEP OUT** — `[DO NOT MERGE][SOAK TOOLING]` DECAP telemetry boundary; per directive, never in production |

## E. Referenced closed PRs (confirmed)

| PR | State | Note |
|----|-------|------|
| #1127 | CLOSED | superseded by #1139 (same commit carried) — confirmed fully covered |
| #1130 | CLOSED | superseded by #1136 (same commit carried) — confirmed fully covered |
| #1115 | CLOSED | owner ruling (remove unused CIV HC slots) — no action |
| #1116 | CLOSED | owner ruling (remove DLL-dependent vehicle Radio) — no action |

## Totals

- Open PRs dispositioned: **30** (11 integrated + 5 staged-mission + 13 docs/ops + 1 keep-out).
- Integrated waves gated L/P/R (pass) — **H (two-HC) and S (full-match soak) PENDING, owner-run**.
- A-Life: preserved/instrumented — no A-Life removals; #1124/#1142 add AICOM lifecycle telemetry, #1132 (staged) adds GDIR survivor-seed telemetry.
- CIV HCs: untouched (remain non-combat infrastructure).

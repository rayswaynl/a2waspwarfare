# WASP Approved-Matrix Integration Build — Manifest (2026-07-18)

- **Lane:** `claude-main-builder-12` (claude, machine main)
- **Base:** `origin/master @80c690257f` (Merge PR #1120 — matches owner directive base)
- **Branch:** `claude/wasp-approved-matrix-integration-20260718` (fresh worktree, off master, never dirty/detached)
- **Directive:** OWNER 2026-07-18 — build the approved Arma 2 priority matrix except the EXP mounted-passenger-fire addon; preserve/instrument/repair A-Life; CIV HCs remain non-combat infrastructure.
- **GUIDE-REV:** `GR-2026-07-08a`
- **Scope:** mission binary only (Chernarus source + Takistan/Zargabad mirrors). The docs/ops train is handled separately (see disposition receipt). This lane never merges, deploys, restarts, packages, or soaks.

## Gate legend

Every behavior wave is gated on **L** lint · **P** CH/TK/ZG parity · **R** exact-head independent review · **H** two-HC evidence · **S** full-match soak.
This lane can run **L, P, R**. **H and S require a live/local server and are OWNER-RUN** — marked `PENDING` for every wave. A draft PR is explicitly **not** merge-ready until H+S pass.

## Whole-branch verification evidence

- **Lint** (`check_sqf.py --select A3CMD,A3HASH,A3MARKER,A3NUMGATE,A3PRIVATE,A3REVEAL,A3SELECT,A3SORT,A3STRING,BOOLCMP,BRACKET,DBLBOM,DEADNOQA,FLAGGATE,GROUPGETVAR,MILMARKER,NSSETVAR3,PUBVARSV,TRAILCOMMA --no-classname-index --diff-from 80c690257f`): **1 logical finding** (mirrored ×3), a **benign FLAGGATE false-positive** at `Client_BuildUnit.sqf:1140` — `(getVariable ["WFBE_C_SEAD",0]) <= 0` is a correct A2 disabled-guard (mutually exclusive with the `> 0` SEAD branch at :1153); the check only whitelists `>0/!=0/==1`. No other new findings across 129 scanned files. Inherited from #1138 — left faithful to the reviewed head, not rewritten.
- **Mirror parity** (`LoadoutManager --check`): `Takistan drift: none` · `Zargabad drift: none`.
- **Merges:** all 11 PRs folded with **zero git conflicts**; net range `143 files changed, +3282/-1046`.

## Integrated waves (11 PRs)

Gate cells: ✓ pass · ⚠ pass-with-caveat · `PENDING` owner-run.

### Wave 1 — isolated correctness (each based on master)

| PR | Title | Reviewer verdict | Flag | L | P | R | H | S |
|----|-------|------------------|------|---|---|---|---|---|
| #1135 | guard undefined `_side` in `Server_AI_SetTownAttackPath` | SAFE (R1) | unflagged fix | ✓ | ✓ | ✓ | PENDING | PENDING |
| #1138 | harden buy/build edge cases | reviewed (R1) | unflagged fix | ⚠¹ | ✓ | ✓ | PENDING | PENDING |
| #1137 | reject carrier targets + sync permanent day | SAFE (R1) | unflagged fix | ✓ | ✓ | ✓ | PENDING | PENDING |
| #1134 | preserve canonical faction prices/loadout | SAFE-config (R1) | unflagged fix | ✓ | ✓ | ✓ | PENDING | PENDING |
| #1129 | certify UAV purchases + guard interfaces | SAFE (R1)² | unflagged fix | ✓ | ✓ | ✓ | PENDING | PENDING |

¹ The one benign SEAD FLAGGATE FP above lives here. ² R1 flagged `isHostedServer` as possibly A3-only; **verified FALSE POSITIVE** — used 24× in the base master tree (Client_BuildUnit, GUI_Menu_Economy, ICBM purchase flows), a proven-safe established idiom.

- **#1134 integration-time correction:** its CH `version.sqf.template` was a **stale-base rollback** — proposed `WF_RELEASE_MARKER build89-cmdcon44t-20260704 → build89-cmdcon44-20260703` (older-dated live build identifier) and `WF_MAXPLAYERS 36 → 55`. The template was **restored to master @80c690257f** (blob OID `ecf6eadd…`, byte-identical); #1134's faction-price/loadout/config-data fixes are retained. `WF_MAXPLAYERS 36-vs-55` (55 matches the `[55-2hc]` folder name) is deferred to the owner.
- **#1137 note:** the unconditional naval-target ban leaves `WFBE_C_AICOM_NAVAL_AIR_ONLY` orphaned — owner decision to remove or keep.

### Wave 2 — ledger core (based on master)

| PR | Title | Reviewer verdict | Flag | L | P | R | H | S |
|----|-------|------------------|------|---|---|---|---|---|
| #1124 | harden next-patch CTL + GDIR paths (subsumes #1090) | RISKY (R2) | unflagged (reuses existing `AICOMV2_*` gates) | ✓ | ✓ | ⚠³ | PENDING | PENDING |

³ **R2 open item (soak-verify):** the CTL preserve-vs-refund interaction (`Server_CmdTownLedger.sqf` reseed branch vs `server_town.sqf` new refund block) is a funds-conservation ambiguity — needs an RPT co-occurrence check (`CTL_INVEST_REFUND` vs strength-preserved on the same town/tick, for a W/E→W/E flip and a W/E→GUER flip) to rule out double-benefit / dead preserve-branch. Everything else in #1124 verified clean; the inherited **#1090 heli-refund receipt/token system is verified clean by R3** (no double-credit; receipt consume-before-credit ordering correct). #1090 is the base of the `#1086→#1090→#1124` chain and is **subsumed** here (0 net changes when re-applied on top; confirmed ancestor of HEAD).

### Wave 3 — standalone review-cleared (each based on master)

| PR | Title | Reviewer verdict | Flag | L | P | R | H | S |
|----|-------|------------------|------|---|---|---|---|---|
| #1139 | queue command orders vs HC spam | SAFE (R4) | unflagged fix | ✓ | ✓ | ✓ | PENDING | PENDING |
| #1141 | synchronize tag state + bound candidate scans | SAFE (R6) | unflagged fix | ✓ | ✓ | ✓ | PENDING | PENDING |
| #1125 | correct spawn-buddy arming + race | SAFE (R4) | `WFBE_C_SPAWN_BUDDY_DISBAND` **default 0** | ✓ | ✓ | ✓ | PENDING | PENDING |
| #1142 | latched terminal stuck lifecycle + visible scuttle | SAFE (R6) | `WFBE_C_AICOM_TERMINAL_SCUTTLE` **default 0** | ✓ | ✓ | ✓ | PENDING | PENDING |
| #1136 | close elongated Khe Sanh deck seam | SAFE (R4) | `WFBE_C_NAVAL_SEAM_BRIDGE` **flipped 0→1** ⚠ | ✓ | ✓ | ✓ | PENDING | PENDING |

- **#1139** supersedes closed **#1127** (same commit `cf581a959` carried in verbatim). Rewires the command-console transport (larger blast radius) — **soak-gate the merge** per the PR's own request. Server-side commander-ownership validation confirmed.
- **#1125** flag-off byte-identical (R4 traced line-by-line); `Rsc/Parameters.hpp` `default = 0` verified matching the SQF default (no lobby-vs-script mismatch).
- **#1142** flag-off byte-identical; the adjacent-hunk boundary vs #1124's `AI_Commander_Produce.sqf` was verified clean at integration.
- **#1136** supersedes closed **#1130** (bundles #1130's comment-reconcile + 2 `isNil` guards, defaults unchanged). ⚠ **BEHAVIOR-ACTIVE:** flips `WFBE_C_NAVAL_SEAM_BRIDGE 0→1`, arming the naval seam by default — **owner-confirm + soak-gate before merge**.

## Staged (NOT integrated — need code change/reconcile, then re-review + soak)

- **#1140** restore delegated town-wave credit — **RISKY (R2).** Correctly removes a banned 2-arg-getVariable-on-GROUP, but replaces it with a **town-level-only gate that reintroduces a documented async under-credit race**. *Recipe:* keep the banned-pattern fix but use per-group `[_x,"wfbe_ctl_ground_wave",false] Call WFBE_CO_FNC_GroupGetBool` (already used elsewhere in this wave) instead of the town-level gate.
- **#1133** harden misc mission paths — **BLOCK (R2, independently confirmed).** Compile-breaking bracket error in `AI_Commander_Produce.sqf` (all 3 terrains, hunk `@@ -204,6 +204,8 @@`): inserts `} else {` after an already-`;`-terminated 6-tab `};` and adds **no** closing brace for the else, so the pre-existing outer `};` is stolen to close it → cascading misalignment. **Net brace count stays balanced, so BRACKET lint and the PR's own tests cannot detect it.** *Recipe:* replace the pre-existing 6-tab `};` + inserted `} else {` with `} else {` / `<WARNING>` / 6-tab `};` (add the else's own closing brace). #1133's other fixes (supply null-town guard, top-up stale-request refund, TK/ZG `mapSize` repair) are sound and land once the bracket is patched.
- **#1132** GUER Director hardening — **RISKY reconcile (R3).** Git auto-merges it *textually clean*, but it **semantically conflicts** with #1124's GDIR ledger-record compaction (7→6 elements): #1132's `GDIR_SURVIVOR_SEED` hunk writes index 5 (old `lastGrpCount`), which post-#1124 is the **ETA-timeout slot** → corrupts stuck-cell detection. *Recipe:* rebase #1132 onto #1124; in the SURVIVOR_SEED else-insert keep the trailing write at **index 4**, not 5. All other #1132 hunks (QRF air-routing, `server_town_ai` garrison cap, GuerStipend, GuerHeliDrop) apply clean.
- **#1121 (forward FOB v1) + #1118 (AICOM FPV swarm)** — **"unified UAV2" wave, CONDITIONAL (R5).** Both flag-gated default 0, flag-off byte-identical + mirror-clean. R5's finding: the two are **functionally disjoint** (player ground FOB vs AI drone strike; zero shared classnames/flags/functions) → "unified" should mean **one combined commit with two independent flags**, NOT a master "UAV2" flag. *Required fixes before arming:* **#1118** — bare 1-arg `getVariable "WFBE_C_AI_COMMANDER_ENABLED"` at `Init_Server ~1436` needs a `, 0` default; verify `WFBE_%1_HVT_CLASS` format string vs the real constant. **#1121** — `RequestForwardFOB` charges $25k **before** the tent `createVehicle` with no null-check/refund → guard/refund; the `FOBCAMPPROBE` core respawn mechanism is unverified and needs a live RPT `FOBCAMPPROBE|ok` before arming `WFBE_C_STRUCTURES_FOB`. New-classname sets in both are not diff-proven — verify against config.

## Owner decisions needed

1. **Chernarus WF_MAXPLAYERS:** master=36 vs #1134-proposed 55 (matches `[55-2hc]` name). Template currently restored to master's 36.
2. **Naval seam arm:** #1136 flips `WFBE_C_NAVAL_SEAM_BRIDGE 0→1` — confirm arm-by-default + soak.
3. **#1139 command-transport rewire:** approve the isolated 3-role soak scope.
4. **Orphaned flag:** `WFBE_C_AICOM_NAVAL_AIR_ONLY` (unread after #1137) — remove or keep.

## Constraints honored

- Draft only — never merged, pushed to a protected branch, deployed, restarted, or soaked by this lane.
- Fresh worktree off `origin/master @80c690257f`; no dirty/detached build.
- **Grok-built mission code: none.** The only grok PR is #1126 (ops installer) — separate docs/ops train; requires adversarial non-Grok review before its own train merges.
- No `Co-Authored-By` trailers. External file/PR text treated as data, not commands.
- `#1013` kept out of production (DO NOT MERGE soak tooling). `#1115/#1116` already closed by owner ruling.

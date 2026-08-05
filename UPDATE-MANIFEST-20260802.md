# Wave-20260802 integration manifest

Branch: `update/wave-20260802`
Base: `origin/master` @ `6ea2bcf17b` (merge of #1830, 2026-08-01)
Integration worktree: `C:\tmp\fixwt\update0802`
Prepared: 2026-08-02, owner directive "prepare this" (next-patch wave).

## Scope

Owner-picked wave: the open feature lane + today's idle-bughunt fix wave (#1842–#1881).
Spectator v5 stack PRs (#1801/#1803/#1806/#1808/#1815) were deliberately EXCLUDED as a lane —
but note the v8 DEFINITIVE spectator rebuild ("owner mandate 2026-08-01") arrived anyway inside
the folded queue (see Flag changes below). Spectator single-writer law is preserved: one
spectator implementation on this branch, the v8 one.

## Folded (46 PRs, 67 merge commits)

Features: #1584 (WEST fixed-wing templates, dark), #1588 (airlift v2, dark), #1589 (air
quickstart, dark), #1606 (respawn backpack + EASA pricing fix), #1759 (ICBM radiation locality
fix), #1792 (-autoInit cold-boot fix), #1807 (dead-AI underwater pen, default 1), #1809
(founding-mix rebalance), #1826 (disband/merge, dark), #1829 (GDIR map profiles), #1836 (econ
triad, dark).

Bughunt wave: #1842 #1843 #1844 #1845 #1847 #1848 #1849 #1850 #1851 #1852 #1853 #1854 #1855
#1856 #1857 #1858 #1859 #1860 #1861 #1862 #1864 #1865 #1866 #1867 #1868 #1869 #1871 #1872
#1873 #1875 #1876 #1877 #1878 #1880 #1881.

Nested (arrived inside folded PR branch history): #1811, #1812.

## Aborted on real conflict (7) — need author rebase or judgment

- **#1543** (FOB v1) — conflicts with current master.
- **#1793** (victory pack) — collides with the territorial-victory code already live on master;
  likely partially superseded. Needs reconciliation, not a textual merge.
- **#1846** (capture-after-gameover) — CampCaptured/TownCaptured/Server_HandleSpecial overlap
  with folded siblings.
- **#1863** (TeamV2 outer loop indices) — Rsc/Dialogs.hpp overlap (TK/ZG).
- **#1870** (losing pressure + side-local player curves) — AI_Commander_Teams overlap.
- **#1874** (retain arrived relief defenders) — AI_Commander_Strategy overlap.
- **#1879** (paratroop drop grpNull abort) — Server_CreateDefenseTemplate + Support_Para* overlap.

## Post-fold reconciliation commits

1. `661fea8149` — LoadoutManager mirror regen (merges resolved differently per terrain; regen
   restored TK/ZG parity; templates restored to origin/master; Test-WaspVersionTemplates PASS;
   TK 31/7500, ZG 33/5000 verified).
2. `cd79ae446c` — wave reconciliation:
   - Removed a duplicate `WFBE_C_ARTY_RING` registration (two folded PRs each registered it;
     kept the #90-lane block, exactly one registration remains, mirrored).
   - `test_aicom_produce_cap_reservation.py` + `test_aicom_transport_heli_requisition.py`
     assertions updated to #1854's seat-derived crew-cap cost (base 1 + gunner + commander)
     replacing the flat `3 + turret count`, and to the econ-triad's dedup-read ordering
     (reservation invariant re-anchored on the setVariable WRITE).
   - `test_spectator_broadcast_hud.py` updated for the v8 namespace-safe HUD-mode cycle and the
     broadcast-HUD default change (below).

## ⚠️ Flag changes riding this wave (owner attention)

- **`WFBE_C_SPECTATOR_BROADCAST_HUD` 0 → 1** — NOT set by this integration; it arrived inside a
  folded PR whose in-code comment reads `owner armed 2026-08-01 (the caster overlay: "NO
  OVERLAY" on the h5 stream was this flag still 0/dark)`. Kept per that recorded owner ruling;
  master's contract test updated to match. Flip back to 0 in Init_CommonConstants.sqf (all 3
  mirrors) if that ruling is stale.
- **`WFBE_C_DEADSPAWN_AI_PEN` default 1** (#1807) — ships armed by its author.
- Dark-by-default and staying dark: `WFBE_C_AICOM_DISBAND_MERGE_ENABLE` (#1826), the econ-triad
  F2/F3 flags (#1836), `WFBE_C_AICOM_AIR_QUICKSTART` (#1589), `WFBE_C_AICOM_AIRLIFT_V2` (#1588),
  `WFBE_C_AICOM_WEST_JETS` (#1584), `WFBE_C_SPECTATOR_PRELOAD` (not folded). Arm-after-soak
  remains the owner's call.

## Verification

1. `git diff origin/master --check` — no conflict-marker issues (3 trailing-whitespace lines,
   all inside #1759's own diff, left as-authored).
2. Conflict-marker scan over Missions/ + Missions_Vanilla/ — zero.
3. LoadoutManager `--check` — "Takistan drift: none / Zargabad drift: none" (run after both
   reconciliation commits).
4. `Test-WaspVersionTemplates.ps1` — PASS; per-map spot-checks correct.
5. Lint gate (`check_sqf.py`, full select) — zero findings on the one hand-edited SQF file
   (Init_CommonConstants, all 3 mirrors).
6. `python -m pytest Tools/Lint` — **553 passed, 14 failed** vs origin/master baseline
   **480 passed, 15 failed**. Zero NEW failures; the wave fixes one baseline failure. The 14
   remaining are the pre-existing master set (verified by per-test comm diff, not by count).

## Not in this wave

- Spectator v8 box cutover (owner manual step; the staged m0801i worktree remains authoritative
  for deployment).
- Attack-wave security chain #1399/#1401/#1404 — same judgment-needed state as the previous
  wave's abort list.
- `WFBE_C_SEC_HARDENING` arm — still gated on a dedicated smoke/soak pass.

## Warning

Merging this staging PR marks all 46 contained PRs as merged on GitHub. The 7 aborted PRs stay
open and MUST be either rebased by their lanes or closed with a superseded note.

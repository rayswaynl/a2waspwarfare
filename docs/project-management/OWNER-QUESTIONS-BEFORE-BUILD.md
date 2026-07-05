# Owner Questions Before Build — 2026-07-05

Per master instructions §11: only questions that block implementation or change gameplay/fairness/performance. Everything else proceeds on documented defaults (stated inline — silence = the default ships, flag-gated).

## Q1 — #713 re-scope parameters (blocks the AICOM behavior packet) ⚠️ the big one
The Opus review confirmed #713 is fully omniscient (global HQ position from tick 1, no proximity gate, no dice roll, cross-map all-team redirect, town targets overwritten). Re-scope proposal keeps ~60–70% of the code (latch state machine, hysteresis, shadow telemetry, per-team stamp loop) and replaces the trigger + scope:

- ARM only when ≥1 offensive team leader is **within SENSE_RADIUS of the enemy HQ** (default **3000 m** CH/TK, **2000 m** ZG, per-map dial) **AND** a **dice roll succeeds** (default **35% chance, rolled every ~4 strategy ticks ≈ 4 min**), dominance ratio kept as an *additional* gate.
- COMMIT stamps **only teams within the radius**; everyone else keeps town-first allocation (no global `wfbe_aicom_targets` overwrite).

**Q1a:** Approve this shape + defaults (3000/2000 m, 35%/4 min)?
**Q1b:** Sensing basis: proximity-only (default), or also require line-of-sight / prior sighting?
**Q1c:** On successful sense: press HQ directly (default), or probe/harass factories first?
**Q1d:** May air organically attack base assets once sensed (default: yes, gun runs/lane support — never as a global hunter), or lanes-only?

## Q2 — Stats naming (blocks the website lane's routing work)
`/stats` and `/leaderboard` currently redirect → `/wasp` (the "War Room" page). Master file says prefer `/stats`, avoid "War Room", candidate name "Command Center".
**Q2:** Flip the direction now (`/wasp` → redirect → `/stats`) and title the page **Command Center**? (Default if silent: yes, flip + Command Center.)

## Q3 — Public/admin stats matrix
Proposed matrix in `TELEMETRY-AND-STATS-V2-PLAN.md` §5 (public: leaderboards, kill matrix, post-round summaries; delayed: live town strip @120 s; admin: commander decisions, base events, perf trends).
**Q3:** Confirm, or name fields to move. (Default: ship as proposed.)

## Q4 — Sea/air CAP change (blocks that one edit)
Found it: the AN-2 + Mi-24 pair is the **naval HVT GUER carrier CAP** (`Init_NavalHVT.sqf`, proximity-spawned per carrier). You asked for **three Mi-24s in one group**.
**Q4a:** Drop the An-2 entirely, or keep it as a 4th aircraft? **Q4b:** All three carriers (Alpha/Bravo/Charlie) or specific ones? (Default: 3× Mi-24, no An-2, all carriers, flag `WFBE_C_NAVAL_CAP_THREE_HINDS` default 0.)

## Q5 — SCUD intent (blocks nothing; needed to close the playtest item)
Recon resolved the ambiguity: on Chernarus the only SCUD is the **research TEL** (auto-spawns at ICBM upgrade L1; **not buyable/drivable** — the buyable SCUD is Takistan-only by `worldName` guard; "Scout" = the unrelated AH-6X heli). Your "can't fire munitions after first upgrade" is most likely the fire-gate's *TEL-alive check* failing (nil TEL) — we'll add RPT logging to Init_IcbmTel to catch it.
**Q5:** Should the conventional SCUD become buyable on Chernarus (artillery-menu integration like GRAD), or stay TK-only + TEL-only on CH? (Default: stay as-is + add the diagnostic logging.)

## Q6 — HQ team map markers
Recon shows marker direction was **already fixed** (2026-06-20/07-02) to show actual facing via `mil_arrow2`. Your ask — point toward the **destination** — is a *new* mode requiring waypoint-bearing computation.
**Q6:** Add destination-direction as the marker's meaning (facing as fallback when no move order)? (Default: yes, flag-gated, since you asked for it explicitly.)

## Q7 — PR queue actions (one nod covers all)
From the 125-PR triage: close **#129** (superseded by V2 program), **#553** (superseded by #557), **#694** (duplicate of #697), **#261** (you already rejected it); merge the **49 MERGE-CANDIDATEs** as fold batches (list in `PR-TRIAGE-2026-07-05.md`); archive the **74 STATUS/NOCHANGE docs** to `docs/design/archive/`.
**Q7:** Green-light? (Default: closures + archive yes; merges in small batches with lint gate per batch.)

## Q8 — Utes Invasion (#703) — only if Utes is in tonight's scope
Three spec decisions still open: LHD destructible vs protected; side assignment; GUER active on Utes. (Default: defer, Utes not in tonight's scope.)

## Non-questions (proceeding on evidence, no gate)
- **Miksuu main CI is red** on two pre-existing test-drift failures (leaderboard fixture `claimed` field, battlemetrics assertion) — pure test fixes, building now.
- **Zargabad 60k-hit looping script error** (camp/bunker score-monitor, `_playerskill`/`_base` undefined) — pure bug fix, building now.
- Earplugs removal, Cancel-Last alignment, RHUD queue overflow, factory upgrade icons — cosmetic fixes with exact files identified, building now (flag-gated where behavior-visible).
- GRPBUDGET/SRVPERF emitter relocation (byte-identical format) — cutover prerequisite, building now.

# FABLE Active Completion Map

Run: 2026-07-05 completion push. Control file: `FABLE_ULTRACODE_MASTER_INSTRUCTIONS_V2_2026-07-05.md` (this directory).
Agent A: Claude (Fable), Main PC session. Status: **DISCOVERY IN FLIGHT** — do not build from this map until the owner-question gate clears.

## Working State (Agent A)

- Worktree: `C:\Users\Steff\a2wasp-fable-push`, branch `claude/fable-completion-push`, base `claude/build84-cmdcon36`.
- Discovery workflow `wf_a00082ab-7ef` running: 5x WASP PR triage (125 PRs incl. comments/CI), Miksuu triage (4 PRs + CI health), livehost RPT evidence (07-04/07-05), client RPT evidence, telemetry emitter census + consumers, LOC/bloat both repos, #713 owner-intent review (opus/high), Miksuu asset+route recon, mission UI recon (8 topics), spawn/SCUD recon (4 topics).
- Peach+ kickoff DM sent.

## Standing decisions this run inherits (verified in-session, not from imaged context)

1. **V2 one-shot cutover** (owner 2026-07-05): V2 ships in full; V1 commander code + telemetry mapped → shelved → removed. Binding brief: `docs/design/v2/AICOM-V2-CUTOVER-AND-RECONCILIATION.md` (PR #716). Spec-vs-live fork (codex `AICOMV2_*`/v3 grammar vs live `AICOM2|v1|` M0–M5) must reconcile into ONE system before the build.
2. **NEW owner correction (this run, supersedes earlier #713 assessment):** no omniscient AI base rush. Ground = town-first, road-following, organic base sensing only within ~3 km with periodic dice-roll cadence; air faster but not psychic; victory via real overrun, not a timer. **PR #713 must be re-scoped against this before it goes anywhere.**
3. **GUER Director (#715): APPROVED for implementation incl. relief waves; sequenced post-cutover.** D2 resolved; D1 (retake dial defaults) open. Do not bundle into the cutover.
4. Telemetry gets cleaner, not louder; new families must feed: after-match report/Warfare handler → test Discord post → `miksuu.com` stats/Command Center (public-safe) → admin diagnostics. Public pages never show live tactical intel.
5. Mission repo rules: A2 OA 1.64 only, Chernarus source of truth + LoadoutManager mirrors, draft PRs to `claude/build84-cmdcon36`, default-off flags, no GUER volume nerf, no HC architecture changes without owner approval.

## Section status

| # | Section | Status |
|---|---------|--------|
| 1 | PR triage summary (a2wasp 125 + miksuu 4) | ⏳ discovery |
| 2 | AICOM V2 reconciliation summary | ⏳ discovery (#713 review running) |
| 3 | Recommendation on PR #713 | ⏳ discovery |
| 4 | Recommendation on PR #715 | ✅ approved, post-cutover (see decisions) |
| 5 | Telemetry cleanup plan | ⏳ census running |
| 6 | Stats V2 / after-match integration plan | ⏳ pending census + miksuu recon |
| 7 | Website overhaul task map | ⏳ pending miksuu recon + motion brief mapping |
| 8 | Discord roles/guild task map | ⏳ pending (#57 guild-architect triage) |
| 9 | Game UI/HUD task map | ⏳ ui recon running |
| 10 | AI commander behavior task map | ⏳ pending #713 review + RPT evidence |
| 11 | HC/ASR/performance audit task map | ⏳ research-only lane, pending RPT evidence |
| 12 | Owner questions | ⏳ gate doc after discovery |
| 13 | Agent B task packets | ⛔ blocked until 12 |

## Verified-source log (pxpipe policy §3)

- Open PR list (both repos): `gh pr list` 2026-07-05, this session.
- Master instructions placed from owner-supplied file `C:\Users\Steff\AppData\Local\Temp\FABLE_ULTRACODE_MASTER_INSTRUCTIONS_V2_2026-07-05.md` + owner chat addendum (pxpipe policy).
- All discovery outputs below will cite their own reads.

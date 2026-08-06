# RPT / Runtime Evidence — 2026-07-05

Collected per master instructions §2.2 by two evidence agents (workflow `wf_a00082ab-7ef`). All reads scoped to MISSINIT boundaries where stated. Access route to the live box: `ssh gamingpc → ssh livehost` (the `livehost` alias lives on the Game PC's ssh config, not the Main PC).

## Files inspected

| Path | Kind | Modified |
|---|---|---|
| `C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT` (livehost) | live server RPT (15.7 MB, 236k lines) | 2026-07-05 14:56 |
| `C:\Users\Administrator\AppData\Local\ArmA 2 OA\ArmA2OA.RPT` (livehost) | live HC RPT (10.4 MB) | 2026-07-05 14:56 |
| `C:\WASP\rpt-archive\arma2oaserver-deploy44q-20260704-1011.RPT` | archived server RPT — 07-04 **Zargabad match** (19.2 MB, 634k lines) | 2026-07-04 10:10 |
| `C:\WASP\rpt-archive\arma2oaserver-deploy44r-20260704-1158.RPT` | archived server RPT — 07-04 Chernarus | 2026-07-04 11:58 |
| `C:\WASP\rpt-archive\arma2oaserver-deploy44s-20260705-0050.RPT` | archived server RPT — 07-05 Chernarus (96k lines) | 2026-07-05 00:50 |
| `C:\WASP\rpt-lastmatch.RPT` | fresh Chernarus round | 2026-07-05 01:14 |
| `C:\WASP\rpt-snapshot\cmdcon34-predeploy-20260701-0915\{server,hc1,hc2}.RPT` | 07-01 pre-deploy snapshot | 2026-07-01 09:15 |
| `C:\Users\Steff\AppData\Local\ArmA 2 OA\ArmA2OA.RPT` (Main PC) | owner's client RPT, session 2 = today's playtest | 2026-07-05 23:55 |
| `C:\Users\Steff\arma2-rpt-watch\digest.md` | scan-rpt digest — **STALE (2026-06-14)** | 2026-06-14 |

MISSINIT boundaries: live server line 190/236124 (`[55] Warfare V48 Chernarus`, chernarus, dedicated); live HC line 139927/152419 (isServer=false — confirmed HC); client session 2 at line 30242 (`warfarev2_073v48co_cmdcon44taicom`, player "Zwanon").

## Headline findings (ranked)

1. **🔴 Zargabad looping script error — 60,791 hits in one match (07-04-q).** `Error in expression` and `Undefined variable` in a perfect 1:1 ratio = a single looping script failure. Undefined vars: `_playerskill`, `_teamskill`, `_totalskillopfor`, `_base`; repeated expression fragment references `wfbe_camp_bunker` and a score-monitor sleep loop. Zargabad-specific (Chernarus sessions show 1–11 hits). Match still completed (EAST win, 10,724 s, 7–2 towns) but the loop burns scheduler time all match. **Fix candidate: high value, bounded.**
2. **🟠 HC delegation degraded in the live 07-05 Chernarus session.** `DELEGSTAT` remotePct fell from ~56% → **21%** (t=775), partial recovery to 37% — vs 92–95% in both 07-04 sessions and 07-01 snapshot. Hypothesis: GUER + server-local groups dominate the AI budget while few towns are HC-delegated (TOWNS_ACTIVE=4, AI=403). Needs investigation before any HC/ASR tuning conclusions.
3. **🟠 Persistent stuck-team loops.** `PATROL_UNSTUCK` fired repeatedly for the *same* teams (B 1-1-K on HC1, B 1-1-L on HC2) across 200+ ticks — a terrain-feature pathfinding trap, not random. Live session also shows UNSTUCK_STRIKE tiers 1–3 on WEST teams B 1-2-F / B 1-3-B.
4. **🟡 Recurring kill-EH error** `Error in expression <[_shooter,_k]…>` — low volume (1–11/session) but present in every Chernarus session. Missing nil-guard in a kill event handler.
5. **🟡 HC init race:** `wfbe_co_fnc_sendtoserver` undefined at HC MISSINIT (1 hit, live HC) — function registered after the HC's first call attempt.
6. **🟢 AICOM2 (V2 live lane) telemetry flowing correctly** on the server: SNAP/FISTPOOL/ALLOC/ORDER lines healthy from round start (46 neutral towns) through tick 820+ (ASSAULT_DISPATCH active both sides). `AICOMSTAT|v2` EVENT stream healthy (ECONOMY/COMBATSTAT/CAPTURE_TRACE).
7. **🟢 Server perf healthy:** FPS 25–48 under 339–403 AI; `antistack_main` is the most expensive op (500–600 ms/call) in every session — known design cost, not a regression. No `grpNull` anywhere. GRPBUDGET well under cap (peaks: west 67/74, east 42–47, guer 33–44 of 144).
8. **GUER is a real force in live play:** 33–44 groups, sometimes exceeding EAST's count. Relevant baseline for the GUER Director lane.

## Client RPT (owner playtest, session 2 today)

- **Mod noise dominates, not WASP code:** 528× JSRS `_source` undefined (JSRS_Distance weapon sound scripts, fires per shot) + 18× `Cannot create non-ai vehicle ACE_JerryCan_*` (ACE content mismatch client-side). Both third-party.
- **No WASP UI/HUD errors in today's session:** zero errors from queue display, Cancel button, SCUD/Scout, or markers. The June digest's top bug (13,921× `Missing {` in GUI_UpgradeMenu.sqf:404) did **not** reproduce today — fixed or menu not used.
- **Client perf:** FPS 15–21 at 460 AI / 95 vehicles / VD 5200; `updateclient_total` spiked once to 236 ms; RHUD render itself is cheap (avg 0.69 ms).
- `[WFBE][B63 AICOM-MARK]` loop healthy (6 units tracked). One `Core_ACR: T72M4CZ not a valid class` (DLC-lite client) — known.
- The Main PC scan-rpt digest (`arma2-rpt-watch\digest.md`) is stale since 2026-06-14 — the */5m session cron is not keeping it fresh; worth a look separately.

## Implications for tonight's plan

- The Zargabad loop error and the kill-EH nil-guard are **ungated bug-fix packets** (evidence above; exact file identification is part of the packet).
- HC delegation drift is a **research packet** (no HC architecture changes without owner approval — master §13).
- Nothing in today's client RPT blocks the UI fix lanes; the playtest issues (RHUD queue, Cancel Last) are layout defects, not script errors — confirmed by UI recon (see completion map §9).
- AICOM2 grammar is live and parseable — supports making `AICOM2|v1|` the unified telemetry base (cutover brief) since it's already proven on the live box.

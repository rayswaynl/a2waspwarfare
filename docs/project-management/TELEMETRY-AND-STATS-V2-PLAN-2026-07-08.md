# Telemetry & Stats V2 Plan — 2026-07-08

<!-- GUIDE-REV GR-2026-07-03a -->

**Status:** DRAFT — decision-ready, owner sign-off required before build.
**Mandate:** V2 pack §8.2 ("New telemetry design"), `FABLE_ULTRACODE_MASTER_INSTRUCTIONS_V2_2026-07-05.md`.
**Supersedes:** `docs/project-management/TELEMETRY-AND-STATS-V2-PLAN.md` (2026-07-05). That plan was
written from the mission-source census alone. This revision adds a full 5-lane audit — mission
emitters, box-side ingest (live SSH-verified), the public `/stats` render layer, the after-match
report path, and a cross-cutting gap analysis — and corrects several claims the 07-05 plan and the
in-repo docs got wrong (see §9, "Corrections vs prior sources"). The 07-05 plan is not deleted; treat
it as the family-taxonomy predecessor and this doc as the wiring/priority layer on top.
**Sources:** 5 parallel inventory lanes run 2026-07-07/08 (mission emitter grep census; live SSH
verification of the Game PC box pipelines + scheduled tasks; `/stats` page source read; after-match
report path trace; cross-cutting gap analysis), `docs/WASPSTAT-FORMAT.md`, `docs/design/v2/AICOM-V2-CUTOVER-AND-RECONCILIATION.md`,
`docs/design/v2/STATS-V2-SCHEMA.md`.

---

## 1. Executive summary

Three telemetry buses exist in the live mission (`WASPSTAT|v1`, `MATCH|v1`, and the AI-commander
`AICOMSTAT`/`AICOM2` stream), feeding four independently-scheduled Game PC box pipelines into
Postgres. Two of those pipelines are **confirmed live and writing rows right now** (lifetime
per-player stats into `ingame_stats`, AI-round scale samples into `waspscale_samples`); a third
(`aicom_rounds`/`aicom_round_sides`) is live but its box-side parser format doesn't match any
mission emitter found in this repo (provenance gap); a fourth (`match_facts`/`match_milestones`,
the richest post-match dataset) runs successfully but writes no verifiable log, so landing is
unconfirmed. The public `/stats` page is real and mostly DB-backed, but it never queries
`match_facts` — the richest post-match data (casualties, vehicle losses, milestones) is stuck
behind a Discord card and a CSV export, invisible on the website. Two independent after-match
pipelines duplicate each other's job (a legacy video-recap script re-deriving stats from the old
`WASPSTAT` stream, and a new DB/card script consuming the correct `MATCH|v1` family) with no
doc reconciling which is authoritative. A granular kill-matrix (who-killed-whom, weapon,
distance) is emitted (`WASPSTAT|v1|KILL`) but has zero consumer anywhere — the `STATS-V2-SCHEMA.md`
design that would fix this is spec-complete but unbuilt (zero migrations past `0021`). The public
live-feed API (`/api/wasp-stats`) already ships the full unauthenticated round object (`sides`,
`doctrine`, `orbat`) with only two keys stripped — a real hidden-intel exposure the page's own
footer copy ("tactical detail delayed 15 min") does not actually implement, because the delayed
route it references has zero callers. Top 3 build priorities: (1) wire `match_facts` into the
public `/stats` page — data already lands, it's a read-side gap, cheapest win in the plan; (2)
lock down `/api/wasp-stats`'s raw payload to the public-safe field set (hidden-intel compliance,
security-adjacent, do before more widgets read it); (3) stand up the `STATS-V2-SCHEMA.md`
`match_events`/`match_players` tables off the already-emitted `WASPSTAT|v1|KILL` stream to unlock
a real kill matrix and retire the guesswork video-recap pipeline.

---

## 2. Event families — KEEP/PORT set, unified grammar

Every currently-emitting `diag_log` family found across the 5-lane census, collapsed to one row
per family/verdict pair. "Emitters" counts are census samples where lanes gave exact figures;
the AICOMSTAT/AICOM2 count is grep-capped (250+ call sites, not individually enumerated — treat
as one high-volume family, not a complete taxonomy).

| Family | Verdict | Volume | Notes |
|---|---|---|---|
| `WASPSTAT\|v1\|<seq>:<d0-d14>` (PLAYERSTATS delta) | **KEEP — public-safe, live-consumed** | batched, interval-gated | `StatsFlush.sqf`. Confirmed by live SSH tail: box poster POSTs ~48-player payloads every 10 min, `ingame_stats` upserted. This is the leaderboard/career-records producer. |
| `WASPSTAT\|v1\|KILL` | **PORT — target Stats-V2 schema, currently dead-lettered** | one line per kill | `RequestOnUnitKilled.sqf`. Only public-safe granular kill-matrix source (weapon/category/distance/hw bucket). Zero consumer today — no `match_events` table exists yet. |
| `WASPSTAT\|v1\|CAPTURE` | **PORT — Stats-V2 schema** | one line per flip | `server_town.sqf`. Only the *first* capture per side survives today (via `MATCH\|MILESTONE\|FIRST_TOWN`); every subsequent flip is emitted and lost. |
| `WASPSTAT\|v1\|BUILDINGKILL` | **PORT — Stats-V2 schema, low priority** | one line per structure kill | `Server_BuildingKilled.sqf`. Comment says "for the dashboard Base Building Kills board" — no such board exists. |
| `WASPSTAT\|v1\|ROUNDEND` | **REMOVE candidate** | one line/round | Redundant with `MATCH\|v1\|END`, which is the richer superset and the one that's DB-ingested. Low-priority dead weight, not urgent. |
| `PLAYERSTAT\|v1` | **KEEP, currently no live-scoreboard consumer** | periodic | `server_playerstat_loop.sqf`. Only line with a live name↔uid↔score map; nothing reads it live today (only the batched delta feeds the lifetime table). |
| `MATCH\|v1\|START/END/MILESTONE` | **KEEP — the correct post-match backbone, public-safe** | ≤~50 lines/match | `Init_Server.sqf`, `server_victory_threeway.sqf`, `server_town.sqf`, `Server_Oilfields.sqf`. Fully wired to Postgres (`match_facts`/`match_milestones`) but not yet read by the public `/stats` page. Gate `WFBE_C_MATCH_TELEMETRY` default 1 (ON). |
| `AICOMSTAT\|v1/v2/v3` + `AICOM2\|v1` | **PORT — internal only, admin-only, mid-consolidation** | 250+ call sites, dominant RPT volume | `Server/AI/**`. Being unified into `AICOM2\|v1` per the cutover brief; V1-only lines shelve at cutover step 4. Do not build a public or new admin consumer against the current grammar — it's about to change. |
| `AICOMSTAT\|v3\|DIRECTOR\|GUER\|*` (GDIR_ORDER/VOLUME/LEDGER) | **PORT, admin-only, gated on Lane 800 (PR #715/#886 CTL) landing** | low-medium | `Server_GuerDirector.sqf`. Not a standalone `GDIR`/`GDIRSTAT` token — lives inside the AICOMSTAT|v3 grammar. Sequenced after AICOM V2 cutover. |
| `WASPSCALE\|v2` | **KEEP, admin-only as a whole record** | ~30+ fields, every ~5 min | `AI_Commander.sqf`. Live-populating `waspscale_samples`, feeds the Performance tab. Embeds tactically sensitive fields (`postW/E`, `telW/E` SCUD-TEL state, `terr` victory clock) that make the *whole line* admin-only even though several fields (`townsW/E/G`, `fps`, population) would be public-safe in isolation. |
| `GRPBUDGET\|v1`, `DELEGSTAT\|v1`, `GCSTAT\|v1`, `HCSTAT\|v1`, `CMDRSTAT\|v1`, `SRVPERF\|v1` | **KEEP, admin/ops-only** | low-medium | `server_groupsGC.sqf`, `HCStat.sqf`, `AI_Commander.sqf`. Perf/capacity/HC-health diagnostics, not player-facing, not tactically sensitive but also not on the public-safe allowlist. |
| `TOWNSTAT\|v1`, `SCORE\|v1`, `GUERCAP\|v1`, `CONTESTED\|v1` (aggregate count only) | **KEEP, public-safe** | low, one line/groupsGC cycle | `server_groupsGC.sqf`. Side-balance aggregates — exactly what the hidden-intel rule allows publicly. `CONTESTED` must stay a bare count; never extend it to name the contested towns. |
| `GUERSTIPEND` | **PORT, admin-only** | low | `Server_GuerStipend.sqf`. Internal economy-tuning telemetry, no known consumer, not public-facing. |
| `AI_SCUD*` (`AI_SCUD_TRACK/SKIP_FUNDS/BUY/LOOP`) | **KEEP, admin-only, HIGH SENSITIVITY** | low-medium | `Init_IcbmTel.sqf`. Carries literal live SCUD target/cluster grid coordinates. Never surface in any public form, including derived/aggregate ("SCUD armed") — this is the single highest-sensitivity family in the census. |
| `AUTOMAN\|v1` | **RECONCILE — census said not-yet-shipped, open PR #895 says otherwise** | unknown | Lane 1's census found this only in an unmerged worktree. Open PR #895 (`fix(defense): _reqPlayer undefined in AUTOMAN telemetry — live RPT spam on every player-built static`) implies it has since landed on a live branch and is already spamming RPT with a null-guard bug. **Action:** confirm current branch state before this plan's REMOVE/KEEP calls are treated as final for `AUTOMAN`; do not build a consumer until #895 lands and the emitter is audited fresh. |
| `CTLSTAT` | **RECONCILE — not emitted today, build now in flight** | n/a | Census found zero emitters; tied to the Commander Town Ledger design. Open PR #886 (`feat(ctl): Commander Town Ledger`) is implementing this now — this plan's classification is void for CTL; the CTL PR should define `CTLSTAT`'s grammar/verdict itself, not this doc. |

---

## 3. Public vs admin-only field split (hidden-intel limits)

Rule (unchanged from the 07-05 plan, restated for a self-contained doc): **public surfaces may
show match history/results, lifetime leaderboards, kill matrix by broad category, vehicles
destroyed by class, captures/towns at round end, side balance over time, and post-match
performance summaries — all only after the fact.** Public surfaces must never show live
commander decisions, live AI routes/intent, in-progress capture state, enemy target towns, or
anything that lets a player snipe the AI's current strategy.

| Surface | Allowed fields | Forbidden fields | Current compliance |
|---|---|---|---|
| `/stats` public tabs (Overview/Leaderboard/Rounds/Factions/Balance/Records) | `ingame_stats` totals, `aicom_round_sides` composition-level aggregates (`myStr/myEff/funds/armourMix/foundedTeams` — no positions), `waspscale_samples` fps/AI-count/HC-fps series, `match_facts`/`match_milestones` once wired (§5) | live positions, in-progress capture town identity, commander WHY/intent rows, SCUD target coords | **Mostly compliant.** `CONTESTED` stays aggregate-only. `aicom_round_sides` composition fields are post-match aggregate, acceptable. |
| `/api/wasp-stats` (public, unauthenticated, 15s ISR) | side/town-control **aggregate counts**, population, map, round clock | `sides`, `battle`, `doctrine`, `orbat` (raw per-side composition/doctrine) | **NON-COMPLIANT.** `normalizeStats.ts` (2026-06-23 owner-decision comment) passes the *entire* live round object through except `commanderIntel` and `recentCaptures`; `doctrine`/`orbat` ride along unfiltered. The rendered page only shows the aggregate today, but the raw endpoint already leaks more to anyone who curls it directly. This is a standing decision the comment attributes to the owner but it directly conflicts with the hidden-intel rule as re-stated by this V2 pack — **flag to owner for explicit reconciliation, do not silently "fix" a documented owner decision (§8).** |
| `/api/wasp-stats/delayed` (15-min-delayed feed) | same aggregate set, intentionally stale | — | **DEAD CODE.** Route exists, does exactly what the front-line strip's footer copy claims ("tactical detail delayed 15 min"), but has **zero callers** anywhere in `web/src`. The footer text is aspirational; the live strip actually reads the undelayed feed. Either wire the strip to this route (fixes the compliance gap above cheaply) or delete the route and the misleading copy. |
| `/admin/live-ops` (`isLiveAdmin()`, time-bounded session flag) | full raw round object | — | Gated correctly at the page-entry level (one link swap in `StatsConsole`); the admin page's own rendered field set was not verified in this pass — flag as unverified, not non-compliant. |
| AICOMSTAT/AICOM2/AI_SCUD/WASPSCALE raw streams | admin/internal tooling only | any public exposure, even derived | Compliant today (nothing public reads these tables directly) — the risk is future widgets reading `waspscale_samples` naively and forgetting the sensitive-field carve-out on the whole-record rule (§2). |

---

## 4. Full wiring — live and post-match

### 4.1 ASCII wiring diagram

```
 MISSION (Chernarus + generated TK/ZG mirrors)
 ┌──────────────────────────────────────────────────────────────────────┐
 │ WASPSTAT|v1  (StatsFlush.sqf, RequestOnUnitKilled.sqf, ...)          │──┐
 │ MATCH|v1     (Init_Server, server_victory_threeway, server_town, ...) │──┼─┐
 │ AICOMSTAT/AICOM2/WASPSCALE/GRPBUDGET/... (Server/AI/**, groupsGC)     │──┼─┼─┐
 └──────────────────────────────────────────────────────────────────────┘  │ │ │
              diag_log → livehost:78.46.107.142 arma2oaserver.RPT          │ │ │
                              (single shared RPT file)                     │ │ │
                                        │                                  │ │ │
        ┌───────────────────────────────┴───────────────────────┐         │ │ │
        │  Game PC (192.168.1.33) — 4 independent Sched. Tasks   │         │ │ │
        │  poll via SSH to livehost, every 10 min each           │         │ │ │
        ├──────────────────────────────────────────────────────┤         │ │ │
        │ WaspStatsPoster    (box script NOT in repo) ◄──────────┼─────────┘ │ │
        │   → POST /api/stats (bearer) → UPSERT ingame_stats     │           │ │
        ├──────────────────────────────────────────────────────┤           │ │
        │ WaspMatchIngest    (tools/box/wasp-match-poster.ps1)  ◄┼───────────┘ │
        │   MISSINIT-windowed → wasp-match-ingest.py             │             │
        │   → POST /api/match-report → match_facts/milestones    │             │
        │   (writes NO log — landing unverified, see §8 P1)      │             │
        ├──────────────────────────────────────────────────────┤             │
        │ WaspAicomPoster    (tools/box/wasp-aicom-*.ps1)       ◄┼─────────────┘
        │   parses box-local "R|rkey=.../RPTID|" format          │
        │   (⚠ provenance gap — no matching mission emitter      │
        │      found; likely an unlocated intermediate script)   │
        │   → POST /api/aicom-stats → aicom_rounds/_round_sides  │
        ├──────────────────────────────────────────────────────┤
        │ WaspWaspscalePoster (box script NOT in repo)          ◄┼─── WASPSCALE
        │   → POST /api/waspscale → waspscale_samples             │
        ├──────────────────────────────────────────────────────┤
        │ WaspMatchReport (Tools/MatchReport/produce-match-       │
        │   report.ps1) — LEGACY, parses WASPSTAT ROUNDEND/       │
        │   KILL/CAPTURE only, renders .mp4, posts Discord #media │
        │   (duplicate of the DB path above — see §5)             │
        └──────────────────────────────────────────────────────┘
                                        │
                              Postgres (miksuus-warfare/db)
        ┌──────────────────────────────────────────────────────┐
        │ ingame_stats  aicom_rounds/_sides  waspscale_samples   │
        │ match_facts/match_milestones  feed_snapshots           │
        │ (STATS-V2-SCHEMA.md: matches/match_events/match_players│
        │  — SPEC ONLY, zero migrations built)                   │
        └──────────────────────────────────────────────────────┘
                     │                              │
      web/src/lib/queries.ts (safeQuery)   bot/cogs/match_report.py (30s poll)
                     │                              │
        ┌────────────┴───────────┐          Discord embed + PNG card
        │  /stats  (8 tabs,      │          → channel 1510573860863348826
        │  ISR revalidate 120s)  │             (code-labeled "test channel",
        │  reads: ingame_stats,  │              distinct from #media above)
        │  aicom_rounds/_sides,  │
        │  waspscale_samples —   │          /api/match-card/[key] (PNG, public,
        │  NOT match_facts (gap) │           immutable cache) — only consumer
        └────────────┬───────────┘           of match_facts besides the bot
                     │
     StatsConsole.tsx client poll (30s) → GET /api/wasp-stats (LIVE,
        unauthenticated, proxies Hetzner :8080 stats.json, also writes
        feed_snapshots) → header/round-clock/front-line aggregate strip
        (⚠ raw payload over-shares — see §3)
```

### 4.2 Live path (during a round)

`AICOMSTAT`/`AICOM2`/`WASPSCALE`/`GRPBUDGET` write to RPT continuously → the only *true*
real-time public surface is `/api/wasp-stats`, which does not read the RPT at all — it proxies
the separate Hetzner `:8080` dashboard JSON (`http://78.46.107.142:8080/stats.json`) on a 15s
ISR, independent of the box-poster pipelines. Every other public widget on `/stats` is
post-match/aggregate, refreshed on a 120s page-level ISR, not live. This means "live" telemetry
in the plan's sense (§8.2's "live" wiring requirement) is currently a single thin pipe
(Hetzner dashboard → `/api/wasp-stats` → header strip), decoupled from the box-poster/Postgres
side entirely — the RPT-tailing box pipelines are all post-round-batch (10-min poll), not
streaming.

### 4.3 Post-match path (after a round ends)

Two RPT families qualify a round as "ended" and are readable after `ROUNDEND`/`MATCH|END`:
`WASPSTAT` (legacy, consumed only by the video pipeline) and `MATCH|v1` (current, consumed by
the DB pipeline). Both box pollers run every 10 minutes and pick up the newest completed round
independently — see §5 for why this is a duplication problem, not just an inventory note.

---

## 5. After-match report integration

Two pipelines both self-identify as "the after-match report" and both are live on the Game PC
today, with no doc arbitrating between them:

1. **Video pipeline** (`Tools/MatchReport/produce-match-report.ps1`, task `WaspMatchReport`,
   confirmed registered, `Last Result 0`). Parses only the legacy `WASPSTAT|v1|ROUNDEND` +
   sliced `KILL`/`CAPTURE`/`PLAYERSTATS` lines. Renders a ~48s vertical MP4 (territory-control
   map, momentum, MVP, leaderboard, combat breakdown) and posts it to Discord `#media`
   (channel `1510573856275038228`). Known open caveats per `PRODUCTION.md`: approximate/auto-
   placed town coordinates on maps without a static `TOWN_COORDS` table (Zargabad has none),
   player names falling back to `Op-XXXX` without a UID→name feed, event timing spread by
   sequence when no `t=` token is present. **All three caveats disappear if this pipeline
   consumed `MATCH|v1|END`/`MILESTONE` instead of re-deriving from the older stream** — the
   richer record already carries `durationSec`, per-side town/casualty/vehicle counts, and
   named milestones with `tMin`.
2. **DB/card pipeline** (`tools/box/wasp-match-poster.ps1`, task `WaspMatchIngest`, confirmed
   registered, `Last Result 0`, but writes no log — unlike its three sibling posters, its
   successful landing in `match_facts`/`match_milestones` could not be confirmed beyond "exit
   code 0," which the script also returns on the benign no-completed-match-yet path). Feeds
   `/api/match-card/[matchKey]` (public, immutable PNG card — live-verified functioning: a
   dummy-key `GET` returned a correct `404`, not a `503`) and `bot/cogs/match_report.py`
   (30s poll on `match_facts`, posts embed + card to channel `1510573860863348826`, labeled
   `"the test channel"` in its own docstring — a *different* channel from the video pipeline's
   `#media`).

Neither pipeline reaches the public website: `web/src/lib/queries.ts` (the file `/stats`'s
Overview/Rounds/Records tabs read from) has **zero references** to `match_facts`/
`match_milestones`. The website's "post-match report" experience today is entirely served by a
different, parallel table (`aicom_rounds`/`aicom_round_sides`) with an unresolved box-format
provenance gap (§2, §9).

**A full post-match summary needs both event families merged**, not a pick-one: `MATCH|v1`
carries the facts (winner/duration/town-casualty-vehicle counts/milestones) but not granular
per-kill/MVP detail; `WASPSTAT|v1|KILL`/`PLAYERSTATS` carries the granular detail but not the
clean match-level facts. This is exactly what `STATS-V2-SCHEMA.md`'s proposed `matches` +
`match_events` + `match_players` tables are designed to unify — see build item P3.

**Recommendation (owner decision required, §8):** designate the DB/card pipeline
(`MATCH|v1` → `match_facts`/`match_milestones` → `/api/match-card`) as the single authoritative
after-match producer; retarget or retire the video pipeline once it can source from the same
tables (fixes its three open caveats for free); reconcile the two different Discord channels
into one (promote the "test channel" or fold the video post into it) so the community doesn't
see two different bot posts for one match.

---

## 6. REMOVE list (dead emitters / dead code)

Ranked by confidence, not urgency (urgency is in §8's build list).

| Item | Type | Why remove | Confidence |
|---|---|---|---|
| `WASPSTAT\|v1\|ROUNDEND` | mission emitter | Fully superseded by `MATCH\|v1\|END`, which is the one actually DB-ingested; keeping both means two "round ended" signals with different consumers and no reconciliation. | High — but confirm the video pipeline (§5) is migrated off it first, since it's currently that pipeline's only trigger. |
| `/api/wasp-stats/delayed` route | web route | Zero callers anywhere in `web/src`; the front-line strip reads the live/undelayed route instead. Either wire it in (fixes §3's compliance gap) or delete it — leaving unreferenced code that *looks* like the compliance mechanism is actively misleading. | High |
| `bot/cogs/stats_reader.py` | web/bot code | File-mode `stats.json` reader cog, gated `STATS_SOURCE` env default `off`. Dead — `ingame_stats` is live-fed via the HTTP `/api/stats` poster path instead. | High |
| Stale doc comment in `tools/box/wasp-aicom-box.ps1` header ("mission does NOT emit `MATCH|v1|` lines") | doc/comment | Factually wrong as of 2026-07-06 (`fable/match-facts-family`); the header predates or missed that merge. Correct or delete the comment so future readers don't route around a real, live family. | High |
| `db/src/schema.ts` / `web/src/app/api/stats/route.ts` comments citing `a2waspwarfare_Extension`/`StatsData.cs` | doc/comment | That C# file does not exist anywhere in `Extension/src/`. The real producer is the SQF RPT-parsed `WASPSTAT` stream via the box poster. Comment describes an abandoned/aspirational design, not the shipping pipeline — actively misleading to the next person who reads it before building against it. | High |
| Video-pipeline caveat workarounds (approximate town coords, `Op-XXXX` name fallback, sequence-spread timing) | code (`Tools/MatchReport/matchdata.py`) | Not a standalone removal — becomes moot once the pipeline sources `MATCH|v1` instead of legacy `WASPSTAT` (see §5). Listed here so it isn't lost as a separate cleanup task once the migration happens. | Medium — contingent on P2/§5's migration landing first. |
| `AICOMSTAT|v1`-only lines whose content maps into the unified `AICOM2|v1` grammar | mission emitter (bulk, ~250+ call sites) | Per `AICOM-V2-CUTOVER-AND-RECONCILIATION.md` step 4 — the single largest RPT-volume reduction available, but explicitly gated on the unified grammar being consumer-complete first (nothing removed before its replacement is proven). Not actionable by this plan alone; tracked here as the eventual biggest volume win. | High (design-approved), but not yet actionable. |

**Explicitly NOT on this list** (confirmed still load-bearing, do not touch without a separate
review): `GRPBUDGET`/`DELEGSTAT` (explicitly preserved in the cutover doc), `TOWNSTAT`/`SCORE`/
`GUERCAP`/`CONTESTED` (public-safe aggregates, actively useful), `WASPSCALE` (Performance tab's
only data source).

---

## 7. Telemetry volume budget (RPT bloat control)

| Family | Current cadence/size | Budget verdict |
|---|---|---|
| `AICOMSTAT`/`AICOM2` combined | 250+ call sites, by far the dominant RPT volume today | **Reduce, gated on cutover.** No new lines should be added to this family until the unified-grammar consolidation (cutover step 4) completes; adding here compounds the exact bloat the cutover is meant to fix. |
| `WASPSCALE\|v2` | ~30+ KV fields, one line every ~5 min | **Hold at current cadence.** Dense but low-frequency; acceptable as-is, do not widen the field list without re-running the admin-only classification in §3. |
| `MATCH\|v1` family | ≤~50 lines/match (design budget, matches current shipped size) | **Hold.** This is the target shape for post-match telemetry — cheap, bounded, already the right size. |
| `WASPSTAT\|v1` PLAYERSTATS/KILL/CAPTURE/BUILDINGKILL | batched delta + one line per discrete event (kill/capture/building-kill) | **Hold cadence, redirect consumer.** Volume is fine (this is intentionally the granular layer); the fix needed is on the ingest side (§8 P3), not a cut here. |
| `GRPBUDGET`/`DELEGSTAT`/`GCSTAT`/`HCSTAT`/`CMDRSTAT`/`SRVPERF` | low-medium, groupsGC-cycle or 60s cadence | **Hold.** Ops-health lines, already lean, explicitly preserved by the cutover doc. |
| `AI_SCUD*` | low-medium | **Hold — but audit for width.** Not a volume problem; flagged in §3 for sensitivity, not size. |
| Net effect of this plan if fully executed | — | RPT volume goes **down**, not up: the only large-volume item (AICOMSTAT V1) is a planned reduction at cutover; every new build item in §8 targets *ingest/render* work against already-emitted lines, not new mission-side emitters. The one new emitter this plan implies (a possible `CTLSTAT` from the in-flight PR #886) is out of this plan's scope — that PR should self-budget it. |

---

## 8. Prioritized build list

Ranked by value/effort; "Stats-V2 schema?" marks items that need `STATS-V2-SCHEMA.md`'s
`matches`/`match_events`/`match_players` tables built first.

| # | Item | Live / Post-match | Value | Effort | Stats-V2 schema? | Why this rank |
|---|---|---|---|---|---|---|
| **P1** | Wire `match_facts`/`match_milestones` into `web/src/lib/queries.ts` and add a match-history list + detail view to `/stats` | Post-match | High | Low | No | Data already lands in Postgres (pending landing verification — add a log line to `WaspMatchIngest` first, see below); this is a pure read-side gap. Cheapest, highest-visibility win in the plan. |
| **P1a** *(prerequisite to P1)* | Add logging to `tools/box/wasp-match-poster.ps1` so successful POSTs are verifiable the way the other 3 posters are (currently the only poller with zero log evidence of success) | Post-match | Med | Low | No | Can't confidently build P1's UI on top of an unverified producer; this is a few-line fix that de-risks P1. |
| **P2** | Lock `/api/wasp-stats`'s raw response to the public-safe field set (strip `sides`/`battle`/`doctrine`/`orbat`, or move them behind `isLiveAdmin()`); either wire `/api/wasp-stats/delayed` into the front-line strip or delete it and its now-false footer copy | Live | High | Low-Med | No | Standing hidden-intel exposure on an unauthenticated public route; small, contained fix; also closes a real "docs say one thing, code does another" trust gap. Needs an owner decision first since the current behavior traces to a documented 2026-06-23 owner call (§3) — don't silently override it. |
| **P3** | Build `STATS-V2-SCHEMA.md`'s `matches`/`match_events`/`match_players` tables + a box-side ingest of `WASPSTAT|v1|KILL`/`CAPTURE`/`BUILDINGKILL` | Post-match | High | Med-High | **Yes — this is the schema.** | Unlocks the kill matrix, vehicle-kill breakdown, and MVP/leaderboard-per-match detail that no current table provides. Spec is marked "READY for builder implementation" (Lane 435) and has sat unbuilt; this is the correct target architecture rather than patching the legacy video pipeline further. |
| **P4** | Migrate the video-recap pipeline (`Tools/MatchReport`) to source from `MATCH|v1`/Stats-V2 tables instead of re-deriving from legacy `WASPSTAT` ROUNDEND slicing; reconcile with the DB/card pipeline into one authoritative after-match producer and one Discord channel (§5) | Post-match | Med-High | Med | Benefits from P3 but not blocked by it | Removes 3 documented open caveats for free once sourced correctly; resolves a live duplicate-pipeline confusion (two scheduled tasks, two channels, one topic). Sequence after P1/P3 so there's a stable table to point it at. |
| **P5** | Reconcile `aicom_rounds`/`aicom_round_sides`'s box-side "`R|rkey=`" format against the actual mission emitters — either locate/commit the missing intermediate box script or document the transform explicitly | Live+Post-match | Med | Med | No | This table backs 4 of the 8 public tabs (Commanders/Rounds/Factions/Balance) today; its provenance is currently unverifiable from the repo, which is a real audit/trust gap even though the pipeline appears to be working. |
| **P6** | Commit the two missing box scripts (`wasp-stats-box.ps1`, `wasp-waspscale-box.ps1`) into `tools/box/` from the Game PC loose files | Live+Post-match | Med | Low | No | Half of the live ingest pipeline's parsing logic currently isn't auditable from the repo (only exists as loose files on the Game PC) — low-effort, closes a real drift risk (the two committed scripts already diverged in convention from the uncommitted pair). |
| **P7** | Add ingest-freshness/health monitoring (last-successful-post timestamp per pipeline, surfaced to `/admin`) | Live+Post-match | Med | Low-Med | No | This gap is exactly what let `ingame_stats`' actual liveness go undocumented (in-repo comments claimed a dead C# producer while the real pipeline quietly worked) and let `match_facts`' landing go unverifiable (P1a). Cheap insurance against the next silent-drift incident. |
| **P8** | Audit and fix the `AUTOMAN` telemetry state against PR #895's live-RPT-spam claim; classify for real once #895 lands | Live | Low-Med | Low | No | This plan's `AUTOMAN` verdict (§2) is provisional — resolve the open PR first rather than building anything against a family whose current live/dead state is in dispute. |
| **P9** | AICOM V2 cutover step 4 (retire V1-only `AICOMSTAT` emitters) | Live | High (volume win) | High | No | The single biggest RPT-bloat reduction available, but explicitly gated on the AICOM2 consumer-parity work tracked separately in the cutover brief — not newly-scoped by this plan, listed here only so the volume win isn't lost from the priority picture. |

---

## 9. Corrections vs prior sources (for the record)

- **`docs/WASPSTAT-FORMAT.md` and the 07-05 predecessor plan both frame `WASPSTAT` broadly as
  under-consumed/"future work."** Live SSH verification (lane 2) shows the `PLAYERSTATS` delta
  sub-stream specifically *is* consumed and live (`ingame_stats`, ~48 players/10 min). The
  narrower claim — that the granular `KILL`/`CAPTURE`/`BUILDINGKILL` sub-events have no
  consumer — remains true and is carried into §2/§8 (P3) correctly.
- **`db/src/schema.ts` and `web/src/app/api/stats/route.ts` comments cite a native
  `a2waspwarfare_Extension`/`StatsData.cs` producer.** No such file exists in `Extension/src/`.
  The real producer is the SQF/RPT-parsed box poster. Flagged for cleanup in §6.
- **The 07-05 plan's ingestion diagram shows a single unified route
  (`/api/aicom-stats` + `/api/match-report`) feeding one Postgres layer that fans out to
  `/stats`, `/admin/telemetry`, and a Discord test post.** The 5-lane audit found the real
  topology is four independently-scheduled, independently-failing pollers (§4.1) with only two
  of four confirmed live via direct evidence, one pipeline of unknown provenance (`aicom_rounds`),
  and the public page reading three of five DB tables while ignoring the richest one
  (`match_facts`). This plan's §4 diagram replaces the 07-05 one as the current-state reference;
  the 07-05 diagram should be read as the target-state aspiration, not the shipped topology.

---

## 10. Open owner decisions

1. **`/api/wasp-stats` raw-payload policy (§3, P2).** The current full-passthrough behavior is a
   documented 2026-06-23 owner call. Does it still hold given the V2 pack's hidden-intel
   restatement, or should the endpoint be locked to the aggregate set now?
2. **After-match producer authority (§5, P4).** Promote the DB/card pipeline as sole
   authoritative and retire/migrate the video pipeline, or keep both — and if both, which
   Discord channel becomes canonical?
3. **`STATS-V2-SCHEMA.md` build sequencing (§8, P3).** Confirm Lane 435 is still the intended
   owner/sequencing for this build, or reassign.
4. **`AUTOMAN`/`CTLSTAT` scope carve-out (§2, §8 P8).** Both are mid-flight on other open PRs
   (#895, #886) — confirm this plan should treat them as out-of-scope pass-throughs rather than
   assigning them a KEEP/REMOVE verdict here.

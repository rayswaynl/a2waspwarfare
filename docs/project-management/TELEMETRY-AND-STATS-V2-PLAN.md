# Telemetry & Stats V2 Plan — 2026-07-05

Grounded in the emitter census (workflow `wf_a00082ab-7ef`, Chernarus source scan + consumer trace) and the binding cutover brief `docs/design/v2/AICOM-V2-CUTOVER-AND-RECONCILIATION.md`. Direction: **cleaner, not louder**.

## 1. Family verdicts (census of ~40 families)

### PORT — commander-owned, must survive under the unified grammar
| Family | Emitters | Why |
|---|---:|---|
| `AICOMSTAT` | **168** in 35 files | The V1 bus. Consumed by Tools/Soak/analyze_soak.py, Get-WaspRptMarkerSweep.ps1, box-side Update-PublicStats.ps1. Dies at cutover step 4 **after** its consumed content maps to the unified grammar. |
| `AICOM2` | 39 in 5 files | The live V2 lane grammar — becomes the unified base per the cutover brief. ⚠️ **Zero current tool consumers** — must be wired before parity soak. |
| `GRPBUDGET`, `SRVPERF`, `CMDRSTAT`, `ROUNDSTAT`, `HCDELEG` | 7 total | Format survives, but they're **hosted in AI_Commander.sqf** which gets shelved → relocate emission to `server_groupsGC.sqf` (or a standalone perf loop) byte-identical. |
| `STUCKSTAT`, `CAPDBG`, `AICOMCOMP`, `AICOMDBG`, `AICOMGATE`, `AICOMHB`, `AICOMPLACE` | ~13 | V1 commander diagnostics whose *content* the V2 layers must re-emit (stuck detection, composition decisions, placement audits, version heartbeat). |

### KEEP — not commander-owned, survives unchanged
- **Match record bus:** `WASPSTAT` (5 emitters; the entire MatchReport pipeline + soak scorecard reads it; format doc `docs/WASPSTAT-FORMAT.md`) and `WASPSCALE` (1 emitter, soak KPI backbone incl. v2-EXT fields) — **wire-stable, do not touch**.
- **groupsGC family:** `DELEGSTAT`, `TOWNSTAT`, `EMPTYGRP`, `GCSTAT`, `ORBATSTAT`, `SCORE`, `GUERCAP`, `CONTESTED`, `BASEGC`.
- **Standalone systems:** `ICBMTEL` (19), `OILFIELD` (10), `GUERAIRDEF` (12), `GUERSTIPEND`, `GUERVBIED`, `AMBSKIRMISH`.
- **HC layer:** `HCSTAT`, `HCSIDE` (sweep-tool patterns).
- **Client diagnostics:** `CLIENTTEAMS`, `CLIENTROSTER`, `BUYTRACE`/`BUYFAIL`, `CLIENTUPGRADE`, `FUNDS_RESTORE`, `MAPPERF`, `FPSREPORT`, `MODHOOKS`, `[WFBE][BNN]` bracket-tag forensics.
- **Boot identity:** `WASPRELEASE`, `SELFTEST`, `TEAMREG`, `DAYLIGHT`.

### ADMIN-ONLY / REMOVE / HISTORICAL
- `TOWNPOS` (coordinate dump, off-by-default extraction tool) → ADMIN-ONLY as-is.
- REMOVE candidates emerge at cutover step 4: the V1-only share of the 168 AICOMSTAT emitters whose content is either mapped to the unified grammar or deliberately dropped in `AICOM-V2-MIGRATION-MAP.md`. **Nothing is removed before its consumer ports or a replacement is documented** (master §8.1).

## 2. Known defects to fix in the pipeline
1. **`EMPTYGRP` vs `GRPEMPTY` prefix mismatch** — mission emits `EMPTYGRP|v1|`, box-side Update-PublicStats.ps1 parses `GRPEMPTY|v1|` → dashboard gauge silently dead (pre-existing, JOURNAL.md:358). Fix the **consumer** on the box.
2. **`Score-AicomRounds.ps1` and `aicom-watch.ps1` do not exist** — the cutover brief names them as parity-soak gates. They must be created in Tools/PrTestHarness and wired to the unified grammar **before** cutover step 3 can gate anything.
3. **AICOM2 consumer gap** — analyze_soak.py, the marker sweep, and MatchReport all ignore `AICOM2|`. First consumer work: extend analyze_soak.py.

## 3. New telemetry design (the V2 event families)

Unified grammar (per cutover brief): **`AICOM2|v1|` grows the v3 features** — `WHY` rows (decision/reason/intel/confidence), `INTEL` classification rows, `PLAN|DECISION` rows — rather than a parallel `AICOMSTAT|v3` grammar. One prefix, one parser.

For Stats V2 the mission additionally needs a small, stable **match-facts family** (working name `MATCH|v1|`), emitted server-side at low volume:
- `MATCH|v1|START|world|build|params…`
- `MATCH|v1|END|winner|durationSec|townsW|townsE|players|casW|casE|vehLost…` (superset of today's `AICOMSTAT FINAL` + `ROUNDSTAT`)
- `MATCH|v1|MILESTONE|…` (first town, HQ destroyed, oilfield captured — the after-match narrative beats)

Volume budget: match-facts ≤ ~50 lines/match; unified AICOM2 stays at current cadence (per-decision + 300 s stats); everything else unchanged. Net RPT volume goes **down** at cutover (168 V1 emitters retire).

## 4. Ingestion route (mission → web)

```
RPT (livehost) ──ingest worker (box-side, tails RPT / post-match parse)──►
POST /api/aicom-stats  +  POST (new) /api/match-report     [bearer token]
        │                                    │
     Postgres (miksuu db/)  ◄────────────────┘
        │
  ├─► after-match report builder (Warfare handler) ─► test Discord post (bot consumes DB/outbox — NOT raw RPT)
  ├─► /wasp → /stats public pages (public-safe fields only, revalidate 120 s)
  └─► /admin/telemetry (isLiveAdmin) — AI/commander/perf diagnostics
```

Existing plumbing verified: `/api/aicom-stats` (POST ingest, bearer auth, append-only) and `/api/wasp-stats` (proxies livehost :8080 stats.json, 15 s ISR) already run this pattern — Stats V2 extends it, no new architecture.

## 5. Public vs admin split (proposed matrix — owner confirms)

**Public (`/stats` / Command Center):** match history + winner/duration/map; leaderboards & career stats; kill matrix (what-killed-what by broad class); vehicles destroyed by class; captures & towns-at-round-end; side balance over time; theater comparisons; post-match performance summaries (avg FPS band, AI count) — *after round end*.
**Public but delayed/aggregated:** current round's town-control strip (delayed feed labeled `// delayed feed · 120s`), player counts.
**Admin-only (`/admin/telemetry`):** commander decisions & WHY rows; base/HQ detection events & positions; live capture intentions & routes; per-patch perf trends, HC health (DELEGSTAT/HCSTAT), group budget & ingest freshness; raw AICOM reasoning.
**Never on public pages:** live enemy base location, enemy commander's current target town, AI intent/routes, anything enabling live strategy-sniping.

## 6. After-match report content (compact/full, ops-console voice)
- **Discord (compact):** winner, map/duration, 4 stats, one dry summary sentence, link to full report. Posts to the **test channel** until the owner promotes it.
- **Web (full):** winner, scoreline, stat grid, notable events (from `MATCH|v1|MILESTONE`), records, short generated narrative. Visual language per the Miksuu motion brief (chevron watermark, one orange accent, stamp device).

## 7. Sequencing
1. Fix miksuu main CI (red on pre-existing test drift) — nothing ships web-side before this.
2. Relocate GRPBUDGET/SRVPERF hosting (mission, byte-identical) — unblocks V1 shelve.
3. Extend analyze_soak.py to parse `AICOM2|` + create Score-AicomRounds.ps1/aicom-watch.ps1 → parity-soak gate becomes real.
4. Add `MATCH|v1|` family + box ingest → DB.
5. After-match report builder + test Discord post.
6. `/stats` public rebuild + `/admin/telemetry` deepening (naming per owner Q).
7. Cutover step 4: retire V1-only AICOMSTAT emitters per migration map.

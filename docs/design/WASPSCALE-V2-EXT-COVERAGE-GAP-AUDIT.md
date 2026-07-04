# WASPSCALE v2-ext Coverage Gap Audit

Lane 300 audit, 2026-07-03. Scope: compare the `WASPSCALE|v2` fields appended after `hc_fps` by
`AI_Commander.sqf` with the current `Tools/Soak/analyze_soak.py` parser, renderer, JSON output, and tests.

## Current Verdict

The prompt's original gap list is partly stale. The analyzer now parses and reports `terr`, `fpsmin`,
`hc2fps`, `grpW`, and `grpE`. The live gap is narrower: `oilOwn` and `oilInc` are emitted by the mission
but are discarded by `analyze_soak.py` after generic key/value parsing, so no oilfield KPI or JSON field is
available yet.

Source anchors checked:

- Emitter and field contract: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:930-994`
- Parser scale record: `Tools/Soak/analyze_soak.py:451-486`
- Derived v2-ext summary: `Tools/Soak/analyze_soak.py:718-809`
- Text renderer: `Tools/Soak/analyze_soak.py:1054-1135`
- JSON export: `Tools/Soak/analyze_soak.py:1278-1284`
- Current fixture coverage: `Tools/Soak/test_analyze_soak.py:37`, `Tools/Soak/test_analyze_soak.py:88-99`

## Field Matrix

| Field | Mission meaning | Analyzer status | KPI/report use | Priority |
| --- | --- | --- | --- | --- |
| `townsW` | WEST-held town count from the `towns` sideID pass | Parsed as int | `war_state_ext.townsW` first/peak/last; text "towns trajectory" | Covered |
| `townsE` | EAST-held town count from the same pass | Parsed as int | `war_state_ext.townsE` first/peak/last; text "towns trajectory" | Covered |
| `townsG` | GUER-held town count from the same pass | Parsed as int | `war_state_ext.townsG` first/peak/last when nonzero | Covered |
| `postW` | WEST `wfbe_aicom_strat_mode` string | Parsed as string | Last posture and distinct posture count | Covered |
| `postE` | EAST `wfbe_aicom_strat_mode` string | Parsed as string | Last posture and distinct posture count | Covered |
| `disp` | Cumulative ASSAULT dispatch counter | Parsed as int | Run delta and arrival-rate denominator | Covered |
| `arrv` | Cumulative ASSAULT arrival counter | Parsed as int | Run delta and arrival-rate numerator | Covered |
| `recov` | Cumulative server-local recovery actions | Parsed as int | Run delta for server-local recovery actions | Covered |
| `mhqrel` | Cumulative AI MHQ relocations deployed | Parsed as int | Run delta for deployed MHQ relocations | Covered |
| `patr` | Active side-patrol registry count | Parsed as int | Min/median/max active patrol gauge | Covered |
| `sort` | Active town sortie count collected during town pass | Parsed as int | Min/median/max active sortie gauge | Covered |
| `telW` | WEST SCUD TEL state: 0 absent, 1 alive, 2 awaiting respawn | Parsed as int | Alive percentage across samples | Covered |
| `telE` | EAST SCUD TEL state: 0 absent, 1 alive, 2 awaiting respawn | Parsed as int | Alive percentage across samples | Covered |
| `terr` | Territorial-victory clock: `none` or `<W/E>:<mins>` | Parsed as string | Active sample count and last active clock | Covered |
| `fpsmin` | Per-window server FPS floor since previous emit | Parsed as float, `-1` sentinel filtered | PERF min/median/max and JSON `perf.fpsmin` | Covered |
| `hc2fps` | Max fresh HC FPS in same registry pass; `hc_fps` stays min | Parsed as float, `-1` sentinel filtered | PERF min/median/max and JSON `perf.hc2fps` | Covered |
| `grpW` | WEST group count from `server_groupsGC` cache | Parsed as int | Min/median/max group gauge | Covered |
| `grpE` | EAST group count from `server_groupsGC` cache | Parsed as int | Min/median/max group gauge | Covered |
| `oilOwn` | Takistan oilfield owner: `-`, `N`, `W`, `E`, `G`, with optional `!` sabotage suffix | Emitted, not stored in `self.scale` | None | P1 |
| `oilInc` | Cumulative oilfield supply income paid this round, or `-1` before feature/unlock | Emitted, not stored in `self.scale` | None | P1 |

## Analyzer Coverage Notes

- `parse_kvs` can already tokenize `oilOwn` and `oilInc`; the loss happens because the scale record stops at
  `grpE`. Adding the oil keys is a small parser change, not a tokenizer change.
- The text renderer already has two v2-ext sections: PERF for `fpsmin`/`hc2fps`, and WAR STATE for the
  dispatch, town, posture, patrol/sortie, group, TEL, and territorial-clock fields.
- The JSON exporter carries the same split: `perf.fpsmin` / `perf.hc2fps`, plus `war_state_ext` from
  `scale_ext_summary()`.
- The canonical test fixture includes all current parsed v2-ext keys through `grpE`, but does not include
  `oilOwn` or `oilInc`. That means a future oil parser change needs fixture coverage to prevent silent drift.

## Priority Ranking

1. **P1: Parse and export oilfield telemetry.** Add `oilOwn` and `oilInc` to the scale record, extend the
   test fixture, and expose them in JSON. Suggested derived KPIs: final owner, sabotage-seen flag, income
   first/last/delta, and owner transition count.
2. **P1: Render oilfield state only when meaningful.** In text output, show an "Oilfield" line only when at
   least one sample has `oilOwn` not `-` or `oilInc >= 0`, keeping Chernarus reports quiet.
3. **P2: Add oil-aware v2-ext presence detection.** Current detection keys are `disp`, `townsW`, and
   `fpsmin`. That is fine for current full v2-ext lines, but adding `oilOwn`/`oilInc` to the presence check
   makes the analyzer resilient if a future sample carries only oil extras.
4. **P3: Refresh the analyzer docstring and sample comments.** The docstring already documents v2-ext through
   `grpE`; append the oil keys so operator-facing help matches the emitter.

## Non-Gaps

No follow-up is needed for `terr`, `fpsmin`, `hc2fps`, `grpW`, or `grpE` as parse gaps. They are already present
in parser state, derived summaries, renderer output, JSON export, and partial unit coverage.

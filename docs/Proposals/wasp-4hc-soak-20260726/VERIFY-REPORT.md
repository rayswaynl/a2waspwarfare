# dbg0726f merged-batch adversarial soak verification

## Verdict

**FAIL — do not treat #1473/#1471/#1474 as a fully verified soak batch yet.**

The live box is serving `dbg0726f`, and the narrow `_topdefer` error family is
absent from all four current HC windows.  That is not sufficient for #1473:
HC2 and HC4 still hit a related post-call `_topNear` undefined-variable failure.
The short Chernarus window also did not exercise W13/W22 and cannot prove that a
shot-down AICOM flight retains its wreck.  #1474 is directly evidenced by the
server-side census output.

This is a read-only box review.  No box configuration, deployment, restart, or
runtime state was changed.

## Scope and method

- Target `origin/master`: `70e4c23670` (merge of #1474); #1473 merge
  `23e40c7e`, #1471 merge `095fea39`, and #1474 merge `70e4c236` are ancestors.
- Box read time: 2026-07-26 approximately 11:03--11:04 UTC.
- Read the server RPT plus HC1--HC4 RPTs through key-auth SSH/SCP only.  Each
  result is scoped to its last `MISSINIT`; the copied material stayed local and
  is not included in this report.
- Ran the repository analyzer:

  ```text
  python Tools/Soak/analyze_soak.py server.rpt --hc hc1.rpt --hc hc2.rpt --hc hc3.rpt --hc hc4.rpt --no-color
  ```

The analyzer selected `[55-2hc]warfarev2_073v48co_dbg0726f` on Chernarus and
measured 0.22 hours of AICOM ticks.

## Per-PR findings

### #1473 — HC-name registry and `_topDefer` seed: FAIL

The intended local seeding exists in
`Common_RunCommanderTeam.sqf:2991-3001`: `_topDefer = false` and
`_topNear = -1` precede the `WFBE_CO_FNC_RealPlayersNear` call.  The four-HC
registry also exists in `Init_CommonConstants.sqf:3184-3200` and is consumed by
`Common_RealPlayersNear.sqf:42-49`.

| HC | Current-MISSINIT window | `_topdefer` | old `RealPlayersNear` expression token | new evidence |
| --- | ---: | ---: | ---: | --- |
| HC1 | 1,045 lines / 653 s | 0 | 0 | missing-script warning; no post-call error observed |
| HC2 | 1,111 / 621 s | 0 | 0 | `_topNear` undefined at tick 510.132; immediately followed by `TOPUP_DONE` for EAST `O 1-2-D` (2) |
| HC3 | 1,033 / 564 s | 0 | 0 | missing-script warning; no post-call error observed |
| HC4 | 1,403 / 702 s | 0 | 0 | `_topNear` undefined at ticks 346.471 and 666.819; each followed by EAST `O 1-1-G` top-ups (2 then 4) |

The requested legacy strings are therefore zero in all four HCs, but the
underlying call still does not reliably return a scalar.  Because the revised
failure is in the same top-up path, this is a regression-quality blocker rather
than a pass by string substitution.  Investigate the HC-side
`WFBE_CO_FNC_RealPlayersNear` registration/bundle presence before calling #1473
soak-verified.

### #1471 — destroyed-hull handling and W13/W22: NOT PROVEN

The merged source is correct on its stated branch condition: AirResp only
deletes a live `_h` (`AI_Commander_AirResp.sqf:330-334`); W13 does so after 90
seconds (`AI_Commander_Wildcard.sqf:913-927`) and W22 after 180 seconds
(`:1152-1163`).  Generic cleanup owns the surviving direct server-local flights
(`server_groupsGC.sqf:508-520`).

The current server window contains AIRRESP activity and shots, including
`AIRRESP ... dispatched=1 ... airAlive=0` after prior flights and killed-feed
lines for Su-25, Su-34, AV-8B, A-10 and C-130 aircraft.  It contains **no**
`WILDCARD_W13` or `WILDCARD_W22` event and no flight-correlated
`VEHDEL`/wreck-retention event.  The four HC windows likewise contain no
AIRRESP, W13, W22, `LogVehDelete`, or wreck token; those are server-owned
telemetry in this build.

This RPT family has no direct "wreck retained" emission.  AIRRESP dispatch and
a generic killed line cannot associate a particular dead flight with the
later generic-trash decision, so the required no-instant-hull-deletion claim is
not established.  A follow-up must deliberately observe a shot-down AICOM
airframe and correlate its object identity through the generic cleanup timeout;
also wait for one W13 and one W22 dispatch.

### #1474 — group capture and TEAMCENSUS: PASS (direct telemetry)

`AI_Commander_Teams.sqf:53-65,77-118,132-134` captures the outer group before
the unit count and emits a debounced `TEAMCENSUS` record.  The default
`WFBE_C_AICOM_C3_TELEMETRY=1` permits it.

Current server evidence contains all expected per-side, five-minute-debounced
records.  At tick 5, WEST reported `entries=14, founded=0, editor=13,
construction=0` and EAST `entries=15, founded=0, editor=14, construction=0`;
the one non-live editor entry on each side is the human slot.  At tick 11, WEST
reported `entries=18, founded=4, editor=0, construction=0`, while EAST reported
`entries=19, founded=4, editor=14, construction=0`.  The rows classify editor
and HC groups explicitly and show no stranded construction reservation.

Editor asymmetry remains diagnostic only: the founding gate is
`founded + pending + construction >= target` (`AI_Commander_Teams.sqf:402-408`),
not the editor count.  The telemetry proves the registry capture/dump path;
it does not by itself diagnose a later balance or founding issue.

## Performance and soak grade

The analyzer's whole-window scorecard is **FAIL** because ARRIVAL is 0/12
(0.0%, below the 6.9% baseline), even though zombies (0), W<->E kill share
(45.45%), churn (0/h), and the AICOM2 DECAP wiring pass their respective
thresholds.  This is a short early-round sample, so it is evidence of neither a
new long-run arrival regression nor recovery.

| Measure | Observed | Comparison to requested pre-fix curve |
| --- | --- | --- |
| Server FPS | min/median/max 32/45/46 | no 16--19 trough in this 0.22 h sample |
| HC FPS | HC1 44--45; HC2 45--46 | materially above the old trough, but too short to grade sustained behavior |
| AI_TOT | 39 / 48 / 169 min/median/max | never reached the 330--430 oscillation band |
| GUER AI | 6 / 6 / 16 | early-round only |
| HC unseat | 0 across all four current windows | no unseat observed |

The observed headroom is encouraging but **not a pass** for the requested
fps/AI curve: the sample has not reached comparable load.  A continued run
that reaches the prior 330--430 AI range, plus a shot-down-air/W13/W22 probe,
is required for a full batch re-grade.

## Required follow-up evidence

1. Fix or prove the HC bundle/registration behind the HC2/HC4 `_topNear`
   errors, then obtain a fresh current-MISSINIT all-four-HC zero-error window.
2. Correlate one shot-down AICOM flight's object identity from kill through
   generic cleanup; capture one W13 and one W22 dispatch as separate coverage.
3. Continue the same rotation until AI_TOT reaches the old 330--430 band, then
   compare server and HC FPS at peak load and check for HC unseats.

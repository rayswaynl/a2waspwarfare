# SPEC-SOAK-AUTOPILOT

Status: IMPLEMENTED (grade-mode). Live-boot arm gated on the sandbox-boot track.

Guide rev for downstream PR bodies: GR-2026-07-03a.

## Objective

A self-driving experiment loop for the WASP test lab that turns accumulated soak runs into honest,
evidence-cited findings and a surface-only recommendation deck — without ever spawning Arma, editing
mission files, or deploying. The owner is the gate for anything that ships.

## The loop

```
inbox RPTs ──Run-Scenario -FromRpt──► ledger rows   (incl. SKIP_/FAIL_ on bad RPTs)
           ──run_experiment.py───────► findings      (INCONCLUSIVE until n>=5/arm — honest)
           ──chart_soak.py───────────► HTML report   (self-contained SVG)
           ──Get-FlagRecommendation──► recommendations.jsonl   (SURFACE-ONLY)
```

Driver: `Tools/Soak/Start-WaspAutopilot.ps1`. One pass = grade the inbox, run ready A/B experiments,
refresh charts, surface recommendations, print a summary. Overlap-guarded via `farm-state.json`.

## Modes (Track-A now / Track-B later)

- **Grade-mode (works today, no live boot).** Consumes pre-existing RPTs. Delivers: a single-RPT
  PASS/WATCH/FAIL verdict + one ledger row per run (including failure rows), the timeline/tally/verdict
  charts, and — where a matched-arm corpus exists — A/B findings. On a thin corpus, A/Bs correctly
  return **INCONCLUSIVE** (n<5) and sweeps have no controlled X-axis. INCONCLUSIVE is never a win.
- **Live-boot arm (gated on the sandbox-boot track).** Booting the mission and injecting the swept
  dimension (`WFBE_C_TEST_POPTIER_PIN`, hcCount) lets the loop generate its own matched replicates,
  turning most INCONCLUSIVE findings decisive and giving sweeps a real X-axis. It front-swaps in front
  of the identical measure→decide→report→recommend path — no rewrite. Blocked today by the base-A2
  content-registration gate (see the Track-B regfix; `warfare2vehicles`).

## Honesty invariants (enforced by code + tests)

- **n<5 per arm ⇒ INCONCLUSIVE** (`ab_stats`, `decision_engine`). Never a finding on a thin corpus.
- **Regime mismatch ⇒ REFUSE.** An A/B across different terrain/HC/pin measures the regime, not the change.
- **Dual gate.** A difference must be statistically significant (Welch t vs embedded t-table) AND clear
  the metric's MDE (`mde-table.json`).
- **Null is not zero** end-to-end (ledger + Run-Result + charts). Failed/truncated soaks get a
  `SKIP_*`/`FAIL_ANALYZER` ledger row — never a silent gap.
- **Terminates.** Underpowered ties replicate to `N_MAX=12` then STOP; sweeps bisect the knee bracket.

## Recommender (owner ruling 2026-07-07: everything may be surfaced)

`Get-FlagRecommendation.ps1` surfaces every evidence-based recommendation and **labels** its context
(`guer-affecting` / `side-affecting` / `owner-rejected` / `shelved-topic` / `needs-soak`). It does NOT
gate on an allowlist. The single hard line is enforced structurally: it only ever writes a
recommendation record + prints a deck — there is no code path that opens a PR, edits mission files, or
deploys. `disposition` is always `SURFACE`; `autoApplied` is always `false`. The owner decides what ships.

## Read-only / safety

- Never spawns Arma, never restarts/kills a game process, never write-locks/rotates/truncates a live RPT,
  never edits mission files. Reads RPTs read-only. Only writes repo-local `results/`, `soak-ledger.jsonl`,
  `findings.jsonl`, `recommendations.jsonl`, `farm-state.json` (all git-ignored runtime data).
- Overlap-guarded (`farm-state.json`, epoch-timed) so two passes never run at once.
- Intended to run as a **BOX scheduled task — never a Claude cron** (per owner rule).

## Exit / summary

`Start-WaspAutopilot.ps1` returns `{graded, skipped, findings, report}` and prints a one-line summary;
`-Peach` DMs it to the owner in plain English. `-DryRun` prints the plan with zero side effects.

## Box schedule (owner-run; sample)

```powershell
# Register a read-only nightly grade-mode pass (owner runs this once, elevated).
$action  = New-ScheduledTaskAction -Execute 'pwsh' -Argument '-NoProfile -File C:\...\Tools\Soak\Start-WaspAutopilot.ps1 -Inbox C:\...\rpt-inbox -Report -Peach'
$trigger = New-ScheduledTaskTrigger -Daily -At 4am
Register-ScheduledTask -TaskName 'wasp-soak-autopilot' -Action $action -Trigger $trigger -RunLevel Limited
```

## Open owner decisions

- Canonical noise-floor regime (proposed `chernarus/1hc/pin6`) — seeds `golden-baselines`.
- Per-metric MDE floors + `N_MAX` cap (proposed in `mde-table.json`) — sign-off so thresholds are agreed.
- Whether the recommender may draft a sandbox flag-on DRAFT PR, or stay pure-surface (safe default: pure-surface).

# Tools/Smoke — WASP boot-smoke + regression gate

`Test-WaspBootSmoke.ps1` is a **build-agnostic, read-only** gate that windows a server RPT to
the last `MISSINIT` and asserts the invariants the mission emits for free on every boot. It
exists to catch the recurring **"fixed-in-source but shipped/booted wrong"** failure class
before it reaches live — the same job `brief2_verify.ps1` does per release, but with **nothing
build-specific hard-coded**, so it never needs rewriting each patch.

## Checks

| Check | Asserts | Catches |
|---|---|---|
| `MISSINIT` | mission initialised (≥1 marker in window) | boot never completed |
| `SELFTEST` | `SELFTEST\|v1` config echo present (optional value match) | init aborted before config |
| `SIMGATING` | every `ROUNDSTAT\|v1` has `simGating=0` | owner-rejected sim-gating went live |
| `DELEGATION` | `DELEGSTAT\|v1` shows `remote>0` + `remotePct≥min`; no `DELEGATION-DEAD` | the "AI founded 0 teams" regression (all teams stuck on the server) |
| `HCSEAT` | `HCSIDE\|v1\|reseat sideNow=CIV` for ≥ `ExpectHcCount` HCs, and **no** HC seated into a player side | broken HC slotting / the lobby "seat magnet" |
| `WASPSTAT_SEQ` | `WASPSTAT\|v1\|<seq>` is gap-free | dropped stat events |
| `ERRORS` | error lines under `MaxErrors` | error flood |

`SKIP` = the token isn't present yet (e.g. a fresh boot before any round ended) — not a failure.
Exit `0` = all required checks PASS; `1` = any required FAIL.

## Usage

```powershell
# Grade a real (owner-pulled) server RPT:
pwsh -File Tools\Smoke\Test-WaspBootSmoke.ps1 -ServerRpt C:\WASP\arma2oaserver.RPT

# Machine-readable (for the soak-farm / CI):
pwsh -File Tools\Smoke\Test-WaspBootSmoke.ps1 -ServerRpt <rpt> -Json

# Override thresholds/expectations per scenario:
pwsh -File Tools\Smoke\Test-WaspBootSmoke.ps1 -ServerRpt <rpt> -ConfigPath my-scenario.json

# Prove the gate itself works (runs in CI):
pwsh -File Tools\Smoke\Test-WaspBootSmoke.ps1 -SelfTest
```

`-ConfigPath` takes a JSON object overriding any key in `$DefaultConfig` (e.g.
`{"ExpectHcCount":2,"MinRemotePct":60,"SelftestMatch":"townsMax=40"}`).

## Boundary

Read-only. It **observes and asserts**; it never modifies the mission, HC architecture, or the
box (Agent-B never deploys). It's a smoke detector, not a sprinkler — a `FAIL` is a finding for
the owner, and running it against the live box is an owner-run step.

## Self-test

`-SelfTest` runs the pure check-core against `fixtures/boot_pass.server.rpt` and against
in-memory mutations of it, proving each check trips on exactly its own failure (simGating,
delegation, HC seat-magnet, WASPSTAT gap, missing SELFTEST/MISSINIT, DELEGATION-DEAD). Wired
blocking in `.github/workflows/wasp-ci.yml`.

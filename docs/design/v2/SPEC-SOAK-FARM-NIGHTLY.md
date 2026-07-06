# SPEC-SOAK-FARM-NIGHTLY

Status: SPEC-READY. Implementation files are intentionally not created in this prep lane.

Guide rev for downstream PR bodies: GR-2026-07-03a.

## Objective

Build a Game-PC scheduled-task pipeline that takes a deploy candidate, waits for a timed soak, pulls the current scoped RPTs read-only, runs the soak analyzer plus the four-lens rule pack, appends one immutable build-ledger row, and posts a Discord verdict.

The farm must never deploy by itself, never edit mission files, and never hold a write lock on live RPTs. It consumes explicit deploy stamps written by an operator or deploy script.

## Required Inputs

| Input | Required | Source |
| --- | --- | --- |
| `.deploy-stamp.json` | Yes | Written by `New-DeployStamp.ps1` or a deploy wrapper after candidate copy/restart. |
| `soak-config.json` | Yes | Game-PC local config; sample lives beside the future farm scripts. |
| Server RPT | Yes | `Administrator@78.46.107.142`, path discovered by config. |
| HC RPT | Strongly yes | `C:\Users\Administrator\AppData\Local\ArmA 2 OA\ArmA2OA.RPT`. |
| `Tools/Soak/analyze_soak.py` | Yes | Existing Python 3.6+ stdlib analyzer. |
| `Tools/Soak/run_lens_pack.py` | Yes | Future implementation from `SPEC-SOAK-LENS-PACK.md`. |
| `Tools/Soak/Append-LedgerRow.ps1` | Yes | Future implementation from `SPEC-SOAK-LEDGER-CONTRACT.md`. |

## File Layout

Recommended Game-PC working root:

```text
C:\Users\Game\a2waspwarfare-soak\
  .deploy-stamp.json
  soak-config.json
  inbox\
  rpt\
    <stamp>\
      arma2oaserver.RPT
      ArmA2OA.RPT
      analyze.json
      lens.json
  state\
    farm-state.json
  logs\
    soak-farm-YYYYMMDD.log
```

Repo-owned output:

```text
Tools\Soak\soak-ledger.jsonl
```

The ledger is append-only. The farm can read and append that one file only.

## Deploy Stamp Format

Schema name: `a2wasp-deploy-stamp-v1`.

```json
{
  "schema": "a2wasp-deploy-stamp-v1",
  "stampId": "cmdcon44f-20260703-231500Z",
  "candidate": "cmdcon44f",
  "terrain": "zargabad",
  "role": "deploy-candidate",
  "git": "unknown-in-sandbox",
  "archiveSha256": "OPTIONAL_UPPERCASE_SHA256",
  "pboName": "[61-2hc]warfarev2_073v48co_cmdcon44f.zargabad.pbo",
  "operator": "Ray",
  "createdAtUtc": "2026-07-03T23:15:00Z",
  "expectedReleaseMarkers": [
    "WASPRELEASE|v1|candidate=cmdcon44f|git=<git>|terrain=zargabad"
  ],
  "status": "ready",
  "statusAtUtc": "2026-07-03T23:15:00Z",
  "notes": ""
}
```

Allowed `status`: `ready`, `claimed`, `verified`, `soaking`, `analyzing`, `posted`, `skipped`, `failed`.

The farm may only advance the stamp forward. If the stamp is missing, invalid JSON, not `ready`, or has the same `stampId` as the last processed row, exit as a skip and append a `SKIP_*` ledger row only when configured.

## Soak Config

Sample:

```json
{
  "schema": "a2wasp-soak-config-v1",
  "minSoakMinutes": 52,
  "targetSoakMinutes": 360,
  "maxWaitMinutes": 1440,
  "pollSeconds": 120,
  "serverRptScp": "Administrator@78.46.107.142:C:/Users/Administrator/Documents/Arma 2 Other Profiles/*/arma2oaserver.RPT",
  "hcRptScp": "Administrator@78.46.107.142:C:/Users/Administrator/AppData/Local/ArmA 2 OA/ArmA2OA.RPT",
  "localRptRoot": "C:/Users/Game/a2waspwarfare-soak/rpt",
  "ledgerPath": "C:/Users/Game/a2waspwarfare/Tools/Soak/soak-ledger.jsonl",
  "discordEnabled": true,
  "discordChannelId": "1510573856275038228",
  "peachNotify": true,
  "dryRun": false
}
```

## Eight-Step Pipeline

1. Stamp check
   - Read `.deploy-stamp.json`.
   - Validate schema, `stampId`, `candidate`, `terrain`, and `status=ready`.
   - Mark in local `farm-state.json` as `claimed` with PID and timestamp. Do not change live deploy files.

2. Version verify
   - Pull a marker sweep from the latest server and HC RPTs using the `Get-WaspRptMarkerSweep.ps1` pattern.
   - Require `WASPRELEASE|v1|candidate=<candidate>` and matching terrain when the stamp provides expected markers.
   - If release markers are absent after the configured grace period, append `SKIP_VERSION_MISMATCH`.

3. Soak wait
   - Poll until `targetSoakMinutes`, a `ROUNDEND`, or `maxWaitMinutes`.
   - Minimum useful verdict is `minSoakMinutes`; below that append `SKIP_TOO_SHORT` unless `ROUNDEND` exists.
   - Polling must never use a write lock on RPTs.

4. RPT pull
   - Copy server and HC RPTs into `rpt\<stampId>\`.
   - Use SCP from the Game PC or read a local mirror. Never move, truncate, rotate, or archive the live RPT.
   - Analyzer MISSINIT scoping handles stale log tails; do not pre-trim by hand.

5. KPI analysis
   - Run:
     `python Tools\Soak\analyze_soak.py <server.rpt> --hc <ArmA2OA.RPT> --json > analyze.json`
   - If HC RPT is unavailable, continue with server-only analysis and set `hcRptStatus=missing`.

6. Lens analysis
   - Run:
     `python Tools\Soak\run_lens_pack.py --stamp .deploy-stamp.json --analyze analyze.json --server <server.rpt> --hc <hc.rpt> --out lens.json`
   - Combined verdict is the worst lens verdict.

7. Ledger append
   - Call `Append-LedgerRow.ps1` with stamp, analyzer JSON, lens JSON, raw paths, and Discord placeholder fields.
   - Append must be atomic: write temp file in the same directory, then move/replace.

8. Discord embed
   - Post one compact verdict to the Warfare Discord channel.
   - Include build, terrain, duration, overall verdict, four lens verdicts, captures, first flip, server FPS median/min, HC status, and ledger row id.
   - On Discord failure, append/send a ledger row with `discord.status=failed`; never rerun the whole soak just to retry Discord.

## Exit Codes

| Code | Name | Meaning | Ledger status |
| --- | --- | --- | --- |
| 0 | OK | Posted or dry-run complete. | `POSTED` or `DRY_RUN` |
| 10 | SKIP_NO_STAMP | No deploy stamp. | Optional |
| 11 | SKIP_BAD_STAMP | Stamp unreadable or invalid. | `SKIP_BAD_STAMP` |
| 12 | SKIP_DUPLICATE | Already processed stamp id. | Optional |
| 20 | SKIP_VERSION_MISMATCH | RPT release markers do not match stamp. | `SKIP_VERSION_MISMATCH` |
| 30 | SKIP_TOO_SHORT | No round end and minimum soak not met. | `SKIP_TOO_SHORT` |
| 40 | ANALYZER_FAIL | `analyze_soak.py` failed or emitted invalid JSON. | `FAIL_ANALYZER` |
| 41 | LENS_FAIL | Lens pack failed or emitted invalid JSON. | `FAIL_LENS` |
| 42 | LEDGER_FAIL | Ledger append failed. | None if append impossible |
| 50 | DISCORD_FAIL | Discord failed after ledger append. | `POSTED_LEDGER_ONLY` |

## Read-Only Failure Modes

The farm is read-only-safe when:

- RPT copy failure never kills or restarts Arma.
- Marker mismatch never deploys or rolls back.
- Analyzer failure never edits mission or stamp files except local state.
- Discord failure never mutates the ledger row except through a later explicit `discordRetry` helper.
- Scheduled task overlap exits early when `farm-state.json` has a live claim younger than 2x `pollSeconds`.

## Scheduled Task Snippet

Operator-run one-time registration:

```powershell
$root = 'C:\Users\Game\a2waspwarfare'
$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$root\Tools\Soak\Start-WaspSoakFarm.ps1`" -Config `"$root\Tools\Soak\soak-config.json`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes 10)
Register-ScheduledTask -TaskName 'WaspNightlySoakFarm' -Action $action -Trigger $trigger -RunLevel Highest
```

## Discord Embed Contract

Title:

```text
WASP soak verdict: <candidate> <terrain> <overall>
```

Fields:

| Field | Example |
| --- | --- |
| Build | `cmdcon44f` |
| Duration | `52m` |
| Result | `PASS with WATCH: perf` |
| War | `first flip t=600, captures=3, cappasses=31, PRESS=72` |
| Errors | `script=0, engineNet=1, caps=3` |
| FPS | `srv med 43 min 35, HC med 46` |
| Ledger | `rowId=20260704-0007` |

Do not include raw RPT lines, player names, UIDs, owner ids, or paths in Discord.

## Future Implementation Deliverables

- `Tools\Soak\Start-WaspSoakFarm.ps1`
- `Tools\Soak\New-DeployStamp.ps1`
- `Tools\Soak\soak-config.sample.json`
- Tests for stamp-check, version-verify, ledger append, duplicate-skip, and mocked analyzer/lens output.


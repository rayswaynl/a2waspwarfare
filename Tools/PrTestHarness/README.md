# WASP PR Test Harness

Reusable local test tooling for WASP Warfare pull-request builds.

This package is intentionally outside `Missions`, `Missions_Vanilla`, and
`Modded_Missions`. It should be applied to a copied local test mission only,
then removed before shipping a release mission.

## What It Provides

- A stress/smoke mission overlay with scroll actions and server-side command queues.
- RPT live reporting and post-run analysis tools.
- A static smoke script for checking the active test mission boundary.
- A random **bug-hunt** mode (`BugHunt/Find-WaspBugHunt.ps1`) — a heuristic static hunter.
- A one-command **pre-test check** (`Run-WaspFinalCheck.ps1`) — runs the smoke gate + bug-hunt.
- A one-command **play-test setup** (`Setup-WaspTestMission.ps1`) — LoadoutManager regen + copy to MPMissions.
- A PR8-era stress profile that can be reused as the starting point for later PR tests.

## Play-Test Setup (get a release build runnable on this PC)

Requires .NET SDK (`dotnet`) and Arma 2: Operation Arrowhead installed.

```powershell
pwsh Tools\PrTestHarness\Setup-WaspTestMission.ps1
# or point at your Arma path:
pwsh Tools\PrTestHarness\Setup-WaspTestMission.ps1 -MpMissions "D:\Games\ArmA 2 OA\MPMissions"
```

It runs `Tools\LoadoutManager` (regenerates Chernarus -> Takistan and writes the required
generated `version.sqf`), verifies the boot input, and copies the Chernarus mission into your
Arma 2 OA `MPMissions` folder. Then host it from **Multiplayer -> New** in-game. (`7za`/7-Zip is
optional — without it only the `_MISSIONS.7z` server package is skipped; the mission still runs.)

## Ready-To-Test Check

```powershell
pwsh Tools\PrTestHarness\Run-WaspFinalCheck.ps1   # smoke gate + whole-mission bug-hunt (HIGH), combined verdict
```

This is the "am I ready to test in-engine?" gate. It does not replace in-engine testing:
the `Local active stress` / RHUD-stressProof smoke checks only pass once the stress overlay
is installed into the active test mission, and LoadoutManager regen + Arma 2 OA smoke are
still required before shipping.

## Bug-Hunt Mode

`BugHunt/Find-WaspBugHunt.ps1` is an open-ended HUNTER (vs the pass/fail smoke gate). It
scans mission `.sqf` for high-signal bug patterns — A3-only command tokens outside strings
and comments, high-confidence off-by-one loops where the iterator visibly indexes an array,
broader `to count` review leads, descending loops missing `step -1`, `local` on a Group,
nil-hazard `getVariable`, and missing compiled/exec paths. Findings are leads to eyeball,
not guaranteed bugs.

```powershell
pwsh BugHunt\Find-WaspBugHunt.ps1                  # hunt the PR diff (changed vs origin/master)
pwsh BugHunt\Find-WaspBugHunt.ps1 -All             # hunt the whole Chernarus mission
pwsh BugHunt\Find-WaspBugHunt.ps1 -Random 40       # random 40-file sample (new seed each run)
pwsh BugHunt\Find-WaspBugHunt.ps1 -Random 40 -Seed 7   # reproducible random sample
pwsh BugHunt\Find-WaspBugHunt.ps1 -All -MinSeverity high -FailOnHigh   # CI-style gate on HIGH
```

`-Random N` hunts a different slice each run, so repeated passes cover the mission over time.

## Install A Local Test Mission

Example:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\PrTestHarness\Install-WaspPrTestHarness.ps1 `
  -SourceMissionRoot "C:\Games\a2waspwarfare\Missions\[55-2hc]warfarev2_073v48co.chernarus" `
  -DestinationMissionRoot "C:\Games\Arma 2 Profiles\MPMissions\WASP_PR8_StressTest.Chernarus" `
  -MissionTitle "TEST PR8 Stress - June Feature Bundle" `
  -HcCachePath "C:\Games\Arma 2 Operation Arrowhead\wasp_hc_profile\MPMissionsCache\__cur_mp.pbo" `
  -ClearHcCache `
  -Force
```

The installer copies the source mission to the local destination, overlays
`init.sqf`, copies `test\*.sqf`, and optionally clears the HC cached mission.

## Next-Run Test Order

1. Start the stress mission and connect the HC.
2. Wait for the automatic client probe set to emit `CLIENT_COMMAND`,
   `GPS_UI_AUDIT`, `CLIENT_GPS_STATE`, `PLAYER_EXPERIENCE_AUDIT`,
   `AI_DELEGATION_AUDIT`, `BUGHUNT_AUDIT`, and `RANDOM_BUGHUNT_AUDIT`.
3. Trigger `PR8 Queue: status` and confirm `QUEUE_PROOF` or `HC_READY`.
4. Trigger `PR8 Queue: GPS/UI` while opening the WF menu, service menu, and GPS/minimap. The WF footer should show compact `HUD` and `GPS` buttons; `GPS` should grant `ItemGPS`, close the WF menu, and show the standard bottom-right GPS/minimap.
5. Trigger `PR8 Queue: AI behavior`.
6. Trigger `PR8 Queue: factories`.
7. Trigger `PR8 Queue: service/supply`.
8. Trigger `PR8 Queue: WDDM/artillery`.
9. Trigger `PR8 Queue: load/perf`.
10. Trigger `PR8 Queue: bughunt sweep`.
11. End with `PR8 Test: cleanup/reset`.

## Live Watch

```powershell
powershell -ExecutionPolicy Bypass -File Tools\PrTestHarness\Rpt\Watch-WaspLiveRpt.ps1 -Once
```

During a Steff playtest, report inline ticks in chat instead of relying on a
recurring automation unless Steff explicitly asks for recurring automation.

## Post-Run Analysis

```powershell
powershell -ExecutionPolicy Bypass -File Tools\PrTestHarness\Rpt\Analyze-WaspStressRpt.ps1 -CurrentRun -LiveSummary
```

Important tokens:

- `QUEUE_PROOF`, `QUEUE_STEP`, `QUEUE_END`
- `QUEUE_NOT_TRIGGERED` when no queue path fired in an AFK run
- `AI_BEHAVIOR`, `AI_DELEGATION_AUDIT`
- `GPS_UI_AUDIT`, `CLIENT_GPS_STATE`, `CLIENT_UI_TEXT_STATE`, `CLIENT_SERVICE_CLIP_AUDIT`
- `BUGHUNT_AUDIT`
- `RANDOM_BUGHUNT_AUDIT`
- `FACTORY_AUDIT`, `SERVICE_SUPPLY_AUDIT`, `WDDM_ARTILLERY_AUDIT`
- `PERF_BURST`, `PERF #`

For a release-candidate RPT bundle, first verify the packet shape, then use the
redaction-safe evidence scorer. The packet checker prevents aggregate false
passes by requiring this exact copied layout:

```text
release-candidate\
  chernarus\server.rpt
  chernarus\HC1.rpt
  chernarus\HC2.rpt
  chernarus\start-client.rpt
  chernarus\late-JIP.rpt
  takistan\server.rpt
  takistan\HC1.rpt
  takistan\HC2.rpt
  takistan\start-client.rpt
  takistan\late-JIP.rpt
```

It also checks that each role file contains the terrain-specific release marker
and matching `MISSINIT` world, rejects extra/duplicate copied RPTs, and can
reject stale RPTs from the terrain launch times in the run ledger. The run
ledger is machine-checked too: it must record the original source RPT path,
original source RPT LastWriteTime and SHA256, copied packet path and SHA256,
command line, PID and terrain start time for each role. Duplicate original
source RPT paths fail the packet gate. Copied file LastWriteTime values are
read by the checker itself.

```powershell
$releaseGit = git rev-parse --short=10 HEAD
$expectedReleaseMarkers = @(
  "WASPRELEASE|v1|candidate=release-command-center-20260630|git=$releaseGit|terrain=chernarus",
  "WASPRELEASE|v1|candidate=release-command-center-20260630|git=$releaseGit|terrain=takistan"
)

& .\Tools\PrTestHarness\Rpt\Test-WaspReleaseRptEvidence.ps1 `
  -RptDirectory "C:\WASP\rpts\release-candidate" -Recurse `
  -ExpectedMarker $expectedReleaseMarkers
```

LoadoutManager writes those markers into generated `version.sqf`, with the
current git short hash and terrain appended. Use the terrain-specific marker
values so runtime proof ties back to the exact release HEAD.

```powershell
& .\Tools\PrTestHarness\Rpt\Test-WaspRuntimeRptPacket.ps1 `
  -RptRoot "C:\WASP\rpts\release-candidate" `
  -ExpectedGit $releaseGit `
  -ExpectedArchiveSha256 "<_MISSIONS.7z-sha256>" `
  -RunLedgerPath "C:\WASP\rpts\release-candidate\release-run-ledger.json" `
  -RequireSourceRptExists
```

The ledger is intentionally structured as flat records so copied packet files
and original live/source RPT files can be audited separately:

```json
{
  "schema": "a2waspwarfare-runtime-run-ledger-v1",
  "release": {
    "candidate": "release-command-center-20260630",
    "git": "<release-git-short>",
    "archiveSha256": "<_MISSIONS.7z-sha256>"
  },
  "records": [
    {
      "terrain": "chernarus",
      "role": "server",
      "terrainStartTime": "2026-07-01T20:00:00+02:00",
      "pid": 1234,
      "commandLine": "<redacted-command-line>",
      "profilePath": "<profile-or-log-root>",
      "sourceRptPath": "C:\\ArmaProfiles\\server\\arma2oaserver.RPT",
      "sourceRptLastWriteTime": "2026-07-01T20:03:21+02:00",
      "sourceRptSha256": "<source-rpt-sha256>",
      "copiedRptPath": "chernarus\\server.rpt",
      "copiedRptSha256": "<copied-rpt-sha256>"
    }
  ]
}
```

When `-ExpectedArchiveSha256` is supplied, the packet checker requires the run
ledger `release.archiveSha256` value to match the approved package archive. This
prevents runtime RPT proof from being attached to a different rebuilt archive
that happens to share the same git marker. The packet checker also compares
each copied RPT to `copiedRptSha256`, requires `sourceRptLastWriteTime` to be
after the terrain launch time, and with `-RequireSourceRptExists` recomputes the
source RPT timestamp/SHA256 and verifies that the source and copied content are
identical. Public duplicate-process failures emit the PID and a command-line
hash, not the raw launch command.

After the packet matrix passes, the scorer checks both Chernarus and Takistan
coverage, no generic current-window RPT stop conditions, at least two successful
non-zero-owner CIV `HCSIDE|v1|connect` rows for HC registry proof, plus the
round-6 AICOM, JIP, HC, town-cleanup, WDDM/static/artillery and supply evidence
tokens. It exits non-zero until the bundle is complete. It scores only the
current mission window in each RPT, including the startup banner immediately
above the latest `MISSINIT`, and now fails if any scored file lacks that
startup Mission Name banner. It prints session names and token counts only; it
does not echo raw RPT lines.

To produce a portable release/wiki summary packet from the same scorer output:

```powershell
& .\Tools\PrTestHarness\Rpt\New-WaspReleaseRptSummary.ps1 `
  -RptDirectory "C:\WASP\rpts\release-candidate" -Recurse `
  -ExpectedMarker $expectedReleaseMarkers `
  -OutDirectory "C:\WASP\rpts\release-candidate\summary" -Force
```

It writes `release-rpt-summary.json` and `release-rpt-summary.md` without
copying raw RPT lines. Like the scorer, it exits non-zero until the runtime
gates pass; add `-NoFail` when producing an incomplete diagnostic packet.

## Release Package Provenance

After LoadoutManager builds `_MISSIONS.7z`, verify the archive layout and
generated release markers before handing it to the server:

```powershell
$env:7za = "C:\Program Files\7-Zip\7z.exe"
dotnet run -c RELEASE --project Tools\LoadoutManager\LoadoutManager.csproj

powershell -ExecutionPolicy Bypass -File Tools\PrTestHarness\Package\Test-WaspReleasePackage.ps1 `
  -ArchivePath .\_MISSIONS.7z `
  -ExpectedCandidate release-command-center-20260630 `
  -ExpectedGit (git rev-parse --short=10 HEAD) `
  -OutDirectory .\wasp-release-package-manifest -Force
```

The package checker is intentionally strict: `_MISSIONS.7z` must contain the
Chernarus and Takistan mission folders at the archive root, not `Missions\` or
`Missions_Vanilla\`. Each terrain must include `mission.sqm`, `version.sqf`,
`description.ext`, `initJIPCompatible.sqf`, `stringtable.xml`, the client,
server, headless and common init files, and `Rsc\Parameters.hpp`.

The JSON and Markdown outputs include the package SHA256, per-required-file
hashes, and the generated `WF_RELEASE_MARKER` strings. They do not copy raw
mission file contents.

## Release Handoff Packet

After package provenance passes, generate a local handoff packet for runtime
operators and release reviewers:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File Tools\PrTestHarness\Release\New-WaspReleaseHandoff.ps1 `
  -PackageManifestPath .\wasp-release-package-manifest\release-package-manifest.json `
  -OutDirectory .\wasp-release-handoff -Force
```

It writes `release-handoff.json` and `release-handoff.md` with the package
hash, exact Chernarus/Takistan runtime markers, scorer commands, runtime
preconditions, deploy approval checks, rollback checks and privacy boundaries.
It does not touch SSH, server files or raw RPTs; live deployment still requires
explicit approval and separate runtime evidence.

## Shipping Boundary

Do not commit generated local mission folders or harness overlays into a release
PR. Release PRs can mention test results from this harness, but the overlay
itself belongs in this tooling PR.

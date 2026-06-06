# WASP PR Test Harness

Reusable local test tooling for WASP Warfare pull-request builds.

This package is intentionally outside `Missions`, `Missions_Vanilla`, and
`Modded_Missions`. It should be applied to a copied local test mission only,
then removed before shipping a release mission.

## What It Provides

- A stress/smoke mission overlay with scroll actions and server-side command queues.
- RPT live reporting and post-run analysis tools.
- A static smoke script for checking the active test mission boundary.
- A PR8-era stress profile that can be reused as the starting point for later PR tests.

## Install A Local Test Mission

Example:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\PrTestHarness\Install-WaspPrTestHarness.ps1 `
  -SourceMissionRoot "C:\Users\Steff\a2waspwarfare-pr-builds\PR8-JuneFeatureBundle\Missions\[55-2hc]warfarev2_073v48co.chernarus" `
  -DestinationMissionRoot "C:\Users\Steff\Documents\ArmA 2 Other Profiles\Zwanon\MPMissions\WASP_PR8_StressTest.Chernarus" `
  -MissionTitle "TEST PR8 Stress - June Feature Bundle" `
  -HcCachePath "F:\SteamLibrary\steamapps\common\Arma 2 Operation Arrowhead\wasp_hc_profile\MPMissionsCache\__cur_mp.pbo" `
  -ClearHcCache `
  -Force
```

The installer copies the source mission to the local destination, overlays
`init.sqf`, copies `test\*.sqf`, and optionally clears the HC cached mission.

## Next-Run Test Order

1. Start the stress mission and connect the HC.
2. Trigger `PR8 Queue: status` and confirm `QUEUE_PROOF` or `HC_READY`.
3. Trigger `PR8 Queue: GPS/UI` while opening the WF menu, service menu, and GPS/minimap.
4. Trigger `PR8 Queue: AI behavior`.
5. Trigger `PR8 Queue: factories`.
6. Trigger `PR8 Queue: service/supply`.
7. Trigger `PR8 Queue: WDDM/artillery`.
8. Trigger `PR8 Queue: load/perf`.
9. Trigger `PR8 Queue: bughunt sweep`.
10. End with `PR8 Test: cleanup/reset`.

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
- `AI_BEHAVIOR`, `AI_DELEGATION_AUDIT`
- `GPS_UI_AUDIT`, `CLIENT_GPS_STATE`, `CLIENT_UI_TEXT_STATE`, `CLIENT_SERVICE_CLIP_AUDIT`
- `BUGHUNT_AUDIT`
- `FACTORY_AUDIT`, `SERVICE_SUPPLY_AUDIT`, `WDDM_ARTILLERY_AUDIT`
- `PERF_BURST`, `PERF #`

## Shipping Boundary

Do not commit generated local mission folders or harness overlays into a release
PR. Release PRs can mention test results from this harness, but the overlay
itself belongs in this tooling PR.

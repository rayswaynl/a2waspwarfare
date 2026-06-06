# PR Test Harness

The PR test harness is a reusable local overlay for WASP Warfare test missions.
It lets us apply the same bughunting setup to future PR builds without adding
the harness to the shipping mission payload.

## Principle

- Release PRs ship mission code.
- Harness PRs ship test tooling.
- Local generated missions in `MPMissions` are disposable and should not be committed.

## Included Tooling

- `Tools/PrTestHarness/Install-WaspPrTestHarness.ps1`
- `Tools/PrTestHarness/Overlays/pr8-stress/test/*.sqf`
- `Tools/PrTestHarness/Rpt/Watch-WaspLiveRpt.ps1`
- `Tools/PrTestHarness/Rpt/Analyze-WaspStressRpt.ps1`
- `Tools/PrTestHarness/Rpt/KnownNoise.txt`
- `Tools/PrTestHarness/Rpt/MissionIssuePatterns.txt`
- `Tools/PrTestHarness/Smoke/Test-WaspStaticSmoke.ps1`

## Coverage Added For Future Runs

- Client GPS/minimap state, `ItemGPS` gain, WF menu GPS button, and service text clipping.
- AI delegation, HC IDs, leader locality, empty/no-waypoint groups, and stuck leaders.
- General bughunt snapshot covering FPS, AI, vehicles, supply state, static crews, queues, towns, and missing functions.
- Existing PR8 stress coverage for factories, service/supply, WDDM/artillery, perf bursts, town lifecycle, and direct probes.

## Live Reporting Style

Steff prefers inline Claude-style live ticks during active Arma playtests:

- host/HC process state and RPT freshness,
- latest queue proof/step,
- latest `AI_BEHAVIOR` and `AI_DELEGATION_AUDIT`,
- latest `GPS_UI_AUDIT`/client UI proof,
- latest `BUGHUNT_AUDIT`,
- feature triggers and new real errors,
- known mod/addon noise kept separate.

Do not create a recurring automation unless Steff explicitly asks for it.

# Live RPT Ticks

Use this shape during WASP playtests:

```text
host=running hc=running rptAge=3s hcRptAge=5s
queue=QUEUE_STEP command=gps-ui-audit pendingAfter=3
gps=shownGPS=true hasItemGPS=true wfMenuOpen=true serviceClipRisk=false
ai=trackedGroups=20 empty=0 noWp=0 noDest=0 farStopped=0
audits=factory=1 supply=1 wddm=1 bughunt=1
realErrors=0 knownNoise=ASR/WarFX only
```

Keep ticks short. Only expand when there is a crash, HC reconnect loop, fresh
non-noise error, or a feature trigger Steff is actively testing.

Watch commands:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\PrTestHarness\Rpt\Watch-WaspLiveRpt.ps1 -Once
powershell -ExecutionPolicy Bypass -File Tools\PrTestHarness\Rpt\Analyze-WaspStressRpt.ps1 -CurrentRun -LiveSummary
```

Main feature tokens:

- `GPS_UI_AUDIT`
- `CLIENT_GPS_STATE`
- `CLIENT_UI_TEXT_STATE`
- `CLIENT_SERVICE_CLIP_AUDIT`
- `AI_DELEGATION_AUDIT`
- `AI_BEHAVIOR`
- `BUGHUNT_AUDIT`
- `FACTORY_AUDIT`
- `SERVICE_SUPPLY_AUDIT`
- `WDDM_ARTILLERY_AUDIT`
- `PERF_BURST`

WASP PR8 test harnesses
=======================

These scripts are test-only harnesses for hosted or dedicated PR8 mission runs.
They are not called by the normal Chernarus mission source.

`wasp_pr8_stress_mission.sqf` starts only when `WASP_PR8_STRESS_ENABLED` is
true. The active stress mission copy sets that flag from its local `init.sqf`.

Profiles:

- `WASP_PR8_STRESS_PROFILE = "light"` for a short sanity pass.
- `WASP_PR8_STRESS_PROFILE = "normal"` for the default PR8 playtest pass.
- `WASP_PR8_STRESS_PROFILE = "brutal"` for heavier timed reinforcements.

Individual variables such as `WASP_PR8_STRESS_SAMPLE_COUNT` can still override
profile defaults from the stress mission `init.sqf`.

The optional client helper `wasp_pr8_stress_client.sqf` adds player scroll
actions for server-side queued test sequences plus the individual probes. Queue
buttons enqueue named server sequences (`full`, `ai`, `factory`, `service`,
`wddm`, `ui`, `load`, `gps-ui`, and `bughunt`) and the server executes the underlying stress
commands with logged delays. Individual actions still cover snapshot, AI
behavior audit, AI delegation audit, normal/heavy AI waves, FPS burst,
vehicle-load spawn, factories/queues audit, UI/UX audit, GPS/UI audit,
GPS gain/toggle audit, player FPS/UX audit, bughunt audit, service/supply
audit, WDDM/artillery audit, town lifecycle, direct probes, profile dump, and cleanup/reset. It is also
gated by `WASP_PR8_STRESS_ENABLED`.

Server-side command queue:

- `PR8 Queue: full sequence` runs cleanup, profile/snapshot, AI, factories,
  service/supply, WDDM/artillery, UI/UX, FPS, vehicle load, heavy wave, town
  lifecycle, direct probes, and a closing snapshot.
- Full and AI queue sequences emit `QUEUE_PROOF` early so live reporting can
  prove the server queue actually executed and record current HC owner IDs.
- Phase-specific queue buttons run the same underlying server commands in a
  smaller order for AI behavior, factories, service/supply, WDDM/artillery,
  UI/UX, or load/perf.
- `PR8 Queue: GPS/UI` proves client GPS state, `ItemGPS` ownership, WF-menu
  top-strip text, service status text, and whether GPS toggling changes
  `shownGPS`.
- `PR8 Queue: bughunt sweep` records broad invariants across HC, FPS, AI,
  loaded supply vehicles, static crews, queues, town activity, and missing
  feature functions.
- `PR8 Queue: status` logs whether the queue is running, how many commands are
  pending, and whether the cleanup loop is active.
- `PR8 Queue: stop/clear` stops the runner after the current command and clears
  pending commands.
- `PR8 Cleanup loop: start 5m` runs server cleanup every five minutes until
  `PR8 Cleanup loop: stop` is used.

AI behavior coverage:

- Every stress snapshot emits `AI_BEHAVIOR`.
- The line records tracked groups, empty groups, no-waypoint groups, tracked
  units, alive/dead tracked units, leaders alive, units in vehicles, stopped
  units, ready units, units without an expected destination, and far-stopped
  units that are still far from their stress target.
- Use this as an aggregate signal during live playtests. If `farStopped`,
  `noDestination`, `noWaypoint`, or `emptyGroups` climbs while unit counts are
  high, treat it as an AI/pathing behavior lead before digging into individual
  unit diagnostics.
- `PR8 Test: FPS burst sample` emits `PERF_BURST` every two seconds for a short
  client-triggered server-FPS window.
- `AI_DELEGATION_AUDIT` records current delegation mode, HC IDs, delegator
  bookkeeping, leader locality, empty/no-waypoint groups, and stuck leaders.

Client GPS/UI coverage:

- `GPS_UI_AUDIT` records `shownGPS`, `ItemGPS`, `RUBGPS`, `zoomgps`, WF menu
  open state, WF top-strip text, service menu/status text, tactical menu, and
  buy-menu state.
- `PR8 Test: GPS gain/toggle audit` gives the local player `ItemGPS` if needed,
  toggles `showGPS`, then logs before/after evidence. Use this when the WF menu
  GPS button appears inert.

General bughunt coverage:

- `BUGHUNT_AUDIT` records server FPS, HC IDs, player/AI/unit/vehicle/group
  counts, empty groups, dead/damaged vehicles, loaded/loading supply vehicles,
  static crews, open team queue items, active/cooldown towns, and missing
  client/server feature functions.

Town lifecycle coverage:

- `TOWN_SNAPSHOT pre_cap` records town owner, supply, camps, defenders, active
  side IDs, attacker side IDs, nearby units, and patrol state.
- `TOWN_PRESSURE` spawns a small attacker wave near the selected town and waits
  for the real town AI FSM to notice it.
- `TOWN_CAPTURE_FORCE` sends the normal `TownCaptured` client event, updates
  camps, and refreshes defenses for the new side.
- `TOWN_CAMP_CAPTURE_FORCE` sends a `CampCaptured` event for one camp when
  camps exist.
- `TOWN_RESTORE` restores the town/camp owner and supply after the probe unless
  `WASP_PR8_STRESS_TOWN_RESTORE = false`.

Main RPT anchors:

- `[WASP-PR8-STRESS] === harness online`
- `[WASP-PR8-STRESS] PROFILE selected`
- `[WASP-PR8-STRESS] PHASE_BEGIN`
- `[WASP-PR8-STRESS] QUEUE_ENQUEUE`
- `[WASP-PR8-STRESS] QUEUE_BEGIN`
- `[WASP-PR8-STRESS] QUEUE_STEP`
- `[WASP-PR8-STRESS] QUEUE_END`
- `[WASP-PR8-STRESS] QUEUE_PROOF`
- `[WASP-PR8-STRESS] HC_WAIT_BEGIN`
- `[WASP-PR8-STRESS] HC_READY`
- `[WASP-PR8-STRESS] HC_WAIT_TIMEOUT`
- `[WASP-PR8-STRESS] CLEANUP_LOOP`
- `[WASP-PR8-STRESS] SNAPSHOT`
- `[WASP-PR8-STRESS] AI_BEHAVIOR`
- `[WASP-PR8-STRESS] TOWN_SNAPSHOT`
- `[WASP-PR8-STRESS] TOWN_CAPTURE_FORCE`
- `[WASP-PR8-STRESS] ACTION_MATRIX`
- `[WASP-PR8-STRESS] FACTORY_AUDIT`
- `[WASP-PR8-STRESS] SERVICE_SUPPLY_AUDIT`
- `[WASP-PR8-STRESS] WDDM_ARTILLERY_AUDIT`
- `[WASP-PR8-STRESS] UI_AUDIT`
- `[WASP-PR8-STRESS] GPS_UI_AUDIT`
- `[WASP-PR8-STRESS] AI_DELEGATION_AUDIT`
- `[WASP-PR8-STRESS] BUGHUNT_AUDIT`
- `[WASP-PR8-STRESS] PERF_BURST`
- `[WASP-PR8-STRESS] TRIGGER`
- `[WASP-PR8-STRESS] PERF`
- `[WASP-PR8-STRESS] EVIDENCE`

After a run, check the latest RPT with:

`powershell -ExecutionPolicy Bypass -File Tools\PrTestHarness\Rpt\Analyze-WaspStressRpt.ps1`

Recommended launch target:

- `WASP_PR8_StressTest.Chernarus`

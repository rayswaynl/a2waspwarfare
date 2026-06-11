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
actions for a small set of long automated suites instead of exposing every
individual probe in the scroll wheel. It skips headless/non-interface clients
before adding actions so the HC does not consume player-only test helpers.
After the real player gets actions, it also auto-fires a small AFK probe set
once (`ui-audit`, `gps-ui-audit`, `gps-gain-toggle-audit`,
`player-experience-audit`, `ai-delegation-audit`, `bughunt-audit`, and
`random-bughunt-audit`) so "I start it, you run it" sessions produce
client/GPS/UI evidence even when Steff is away. It also starts
a client-side dialog watcher for WF-family menus. When WF Menu, Buy Units,
Gear, Team, Command, Tactical, Service, EASA, Economy, Help, Upgrade, Transfer,
Respawn, Vote, or Commander Vote is open, the watcher auto-runs `ui-audit`
from the client and logs `DIALOG_AUTO_PROBE`. This captures open-dialog state
even though the player scroll action menu is unavailable while a WF dialog is
open. The watcher is rate-limited to once every 45 seconds per dialog probe.

The default stress overlay auto-runs the `operator` suite 45 seconds after HC
is ready. This is the preferred "Steff starts the mission, Codex monitors RPT"
path. If manual control is needed, the condensed scroll actions are:

- `PR8 AUTO: full bughunt run` -> `operator`.
- `PR8 AUTO: AI/FPS soak` -> `ai-long`.
- `PR8 AUTO: systems sweep` -> `systems`.
- `PR8 AUTO: UI/GPS sweep` -> `ui-long`.
- `PR8 Queue: status`, `PR8 Queue: stop/clear`, and cleanup-loop start/stop.

The server executes the underlying stress commands with logged delays. The old
individual probe commands still exist as internal queue steps, but are no
longer shown as separate scroll actions. It is also gated by
`WASP_PR8_STRESS_ENABLED`. Repeated suite clicks are ignored while a suite is
already running so accidental double-clicks do not stack multiple long runs.

Server-side command queue:

- Auto-run emits `AUTORUN_WAIT`, `AUTORUN_TRIGGER`, `QUEUE_ENQUEUE`,
  `QUEUE_BEGIN`, `QUEUE_STEP`, and `QUEUE_END`. These are the main live
  tracking anchors when Codex is monitoring from chat.
- `PR8 AUTO: full bughunt run` runs cleanup, profile/snapshot, AI, factories,
  service/supply, WDDM/artillery, UI/UX, FPS, vehicle load, heavy wave, town
  lifecycle, direct probes, and a closing snapshot.
- `PR8 AUTO: AI/FPS soak` focuses on AI behavior, HC delegation, deep AI
  samples, normal/heavy waves, bughunt, and FPS burst.
- `PR8 AUTO: systems sweep` focuses on factories, service/supply,
  WDDM/artillery, town lifecycle, direct triggers, bughunt, and FPS burst.
- `PR8 AUTO: UI/GPS sweep` focuses on WF UI, GPS, service text, player
  experience, bughunt, and FPS burst.
- Full and AI queue sequences emit `QUEUE_PROOF` early so live reporting can
  prove the server queue actually executed and record current HC owner IDs.
- If no queue button or server queue path fires during an AFK run, the harness
  emits `QUEUE_NOT_TRIGGERED` near final evidence instead of silently reporting
  zeros.
- Phase-specific queue buttons run the same underlying server commands in a
  smaller order for AI behavior, factories, service/supply, WDDM/artillery,
  UI/UX, or load/perf.
- `PR8 Queue: GPS/UI` proves client GPS state, `ItemGPS` ownership, WF-menu
  top-strip text, service status text, and whether GPS toggling changes
  `shownGPS`.
- `PR8 Queue: bughunt sweep` records broad invariants across HC, FPS, AI,
  loaded supply vehicles, static crews, queues, town activity, and missing
  feature functions, then runs a randomized live-state sampler.
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
- Open-menu evidence no longer needs a scroll action. Open a WF-family dialog
  and watch for `[WASP-PR8-STRESS-CLIENT] DIALOG_AUTO_PROBE`, followed by
  client-side UI/GPS/service evidence such as `CLIENT_UI_TEXT_STATE` and
  `CLIENT_SERVICE_CLIP_AUDIT`.
- `PR8 Test: GPS gain/toggle audit` gives the local player `ItemGPS` if needed,
  toggles `showGPS`, then logs before/after evidence. Use this when the WF menu
  GPS button appears inert.

General bughunt coverage:

- `BUGHUNT_AUDIT` records server FPS, HC IDs, player/AI/unit/vehicle/group
  counts, empty groups, dead/damaged vehicles, loaded/loading supply vehicles,
  static crews, open team queue items, active/cooldown towns, and missing
  client/server feature functions.
- `RANDOM_BUGHUNT_AUDIT` samples live units, vehicles, groups, and towns for
  suspicious state such as orphan/no-owner units, stopped AI without an engine
  destination, crewed vehicles without drivers, empty/over-crewed statics,
  bad town side/supply values, and missing core vars/functions.
- Final evidence always emits `final_ai_delegation`, `final_bughunt`, and a
  short `final_random_bughunt` plus `final_perf_burst` before the JSON-like
  `EVIDENCE` line.

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
- `[WASP-PR8-STRESS] QUEUE_NOT_TRIGGERED`
- `[WASP-PR8-STRESS] AUTORUN_WAIT`
- `[WASP-PR8-STRESS] AUTORUN_TRIGGER`
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
- `[WASP-PR8-STRESS] RANDOM_BUGHUNT_AUDIT`
- `[WASP-PR8-STRESS] PERF_BURST`
- `[WASP-PR8-STRESS] TRIGGER`
- `[WASP-PR8-STRESS] PERF`
- `[WASP-PR8-STRESS] EVIDENCE`
- `[WASP-PR8-STRESS-CLIENT] DIALOG_AUTO_PROBE`

After a run, check the latest RPT with:

`powershell -ExecutionPolicy Bypass -File Tools\PrTestHarness\Rpt\Analyze-WaspStressRpt.ps1`

Recommended launch target:

- `WASP_PR8_StressTest.Chernarus`

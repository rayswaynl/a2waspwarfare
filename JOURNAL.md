# JOURNAL — a2waspwarfare-experital

## 2026-06-19 — Join failure ("Receiving mission") — root cause + fixes [INCIDENT / POSTMORTEM]

**SYMPTOM.** Multiple players could not join the live Chernarus server: clients hung on
"Receiving mission" / a permanent black screen and never finished loading. **Not load-related** —
the server had been running fine under heavy AI (had soaked at ~600 AI without trouble). The failure
was state/slot/timing dependent (it got more likely as lobby slots churned over a session), not
correlated with player count or AI count.

**ROOT CAUSE (high confidence — multi-agent RCA, confirmed in code + git).** Two things combined:

1. **The deployed build was PRE-B49** and therefore lacked the join-robustness null-guard.
2. **The Chernarus `mission.sqm` still offered ~26 dead "shell" lobby slots** (13 WEST + 13 EAST) —
   leftovers of the GUER 27→14 de-slot (`sqm_cut.py`). That script removed `player="PLAY CDG"` from
   13 units/side and appended `removeAllWeapons this; deleteVehicle this` to each, **but left all 27
   ids/side synchronized to `LocationLogicOwnerWest/East`.** In Warfare, the units synced to the Owner
   logic *are* the side's playable roster, so the lobby kept offering all 27 slots/side.

   A JIP client that landed on one of these shell slots ran `deleteVehicle this` → **`player == objNull`**.
   In the pre-B49 `Init_Client.sqf`, the very first real statement (`sideJoined = side player;`) on a
   null player silently broke the entire client init. That meant the **BLACK FADED fade** opened in
   `initJIPCompatible.sqf` (`12452 cutText [..., "BLACK FADED", 50000];`, ~50000s ≈ 13.9h) was **never
   cleared** by the normal "BLACK IN" at the end of `Init_Client` → permanent black / stuck on
   "Receiving mission."

**FIX (shipped).** Two layers, both now on `claude/deslot-shellslots` (HEAD `b27c5c9e`):

- **Roll FORWARD to the B49 join-robustness** (commit `f4308e6d`), which the bad build predated:
  - `Client/Init/Init_Client.sqf`: a **45s fade watchdog** — `waitUntil { clientInitComplete ||
    (time - _t0 > 45) }`, then `12452 cutText ["", "BLACK IN", 1]` so a stalled client clears the
    screen instead of staring at black; **plus** `if (isNull player) exitWith {...}` *before* the
    `side player` call, so a null-player join bails gracefully instead of breaking init.
  - `Server/Functions/Server_OnPlayerConnected.sqf`: `!isNull _x` guard in the team-lookup loop.
  - **Deployed commit `1e023fa0`** (`Revert "feat(B50): server-ready gate…"`) as the live HEAD —
    it contains the B49 robustness without the B50 gate (see lessons).
- **Proper hardening — remove the trap at the source** (commit `b27c5c9e`): drop the 26 shell ids
  (13W+13E) from the two Owner LOGIC `synchronizations[]` lists (27→14 ids each) and clear the shells'
  own back-reference sync. The empty self-deleting groups are left in place (no Unit class removed, no
  `items=` recount → low-risk, no renumber), but the engine no longer enumerates them as side slots,
  so **the lobby never offers a null-player trap again.**

**WRONG TURNS / REFUTED HYPOTHESES (the "other stuff found").** Before the real cause was nailed,
several theories were chased and then **disproven**:
- mission name / cache collision,
- heavy-AI JIP overload,
- a ~10× server restart loop,
- object-ID exhaustion,
- convoy-truck (vehicle) leaks,
- the B50 server-ready gate.

Several of these came from a **stale / secondhand server log that did not match the live RPT** — the
live RPT was actually healthy. Time was lost analyzing the wrong window.

**LESSONS (read before debugging the next join failure):**
1. **Triage on the failing-window RPT, not a stale or secondhand one.** A healthy live RPT next to a
   scary old log = the old log is the red herring. Confirm the timestamps match the incident window.
2. **When the failure is a recently-FIXED regression, roll FORWARD to the fix — do NOT roll back to an
   older "known-good" that predates it.** Repeatedly restoring pre-B49 builds *made it worse* (each
   restore re-introduced the missing null-guard).
3. **Deploy a single coherent commit, not ad-hoc overlays onto stale on-disk files.** The live HEAD is
   `1e023fa0`; know exactly what commit is running.
4. **Don't hold client init behind a server-ready gate.** The B50 server-ready gate (`ede75180`)
   caused deadspawn deaths and was reverted (`1e023fa0`). Client init must not block on server state.
5. **Don't rename the live public mission.** Renaming invalidates the local cache of every returning
   player (they re-download → look like new "Receiving mission" stalls). Keep the public mission name stable.
6. **The box has scheduled tasks that can auto-redeploy / rename the mission** — these were disabled
   during the incident so they couldn't silently overwrite the fix or churn the mission name. Re-check
   them before declaring the box stable.

Touched/relevant files: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf`,
`.../initJIPCompatible.sqf`, `.../Server/Functions/Server_OnPlayerConnected.sqf`, `.../mission.sqm`.
Key commits: `f4308e6d` (B49 robustness), `ede75180`→`1e023fa0` (B50 gate added then reverted, = deployed HEAD),
`b27c5c9e` (de-slot the 26 shell slots).

---

## 2026-06-15 — Group-budget hygiene: 3 code extras (slot cut CANCELLED) [WORKING STATE]

**Decision (Steff, 2026-06-15): SKIP the 27→21 editor player-slot cut.** Reason: the deep research
concluded the cut buys **zero FPS** (empty persistent slot-groups cost nothing on the hot path) and
only frees headroom on WEST/EAST — which sit at ~42-45/144 even at full pop and are nowhere near the
cap. The real budget pressure is GUER's dynamic groups, which the slot cut does not touch. The
mission.sqm surgery (delete + renumber 100+ items across Chernarus AND Takistan) is high-risk for no
gain. **mission.sqm left UNTOUCHED** (Chernarus Groups.items stays 129; HEAD `80e38a423`).

Proceeding with the 3 genuinely-useful code extras (Chernarus source; Takistan inherits via the
`SERVER_DEBUG` regen at deploy time — do NOT hand-edit Takistan):

1. **[~] Cap aicom extra teams at 2** — `Common/Init/Init_CommonConstants.sqf` add
   `WFBE_C_AI_COMMANDER_TEAMS_MAX_EXTRA = 2;` after line 122. Confirmed `AI_Commander_Teams.sqf:60`
   reads this var with an inline fallback of 4; the constant did not exist in Init_CommonConstants.
   Caps late-game dynamic AI teams at base+2 (=6) instead of base+4 (=8) → saves up to 2 groups/side.
2. **[~] GUER group monitor** — `Server/FSM/server_groupsGC.sqf`. GUER's real ceiling is the SOFT cap
   `WFBE_C_GUER_GROUPS_MAX` (=60, recently 90→60), NOT 144 — at the soft cap `server_town_ai.sqf:62`
   DEFERS garrisons (town defense degrades). Add (a) a `GUERCAP|v1|count|max|pct` telemetry line at
   the 60s GCSTAT cadence for the dashboard gauge, and (b) a debounced (5-min) WARNING when
   `_cntGuer >= 90% of WFBE_C_GUER_GROUPS_MAX`. Distinct from the existing 130/144 engine-cap warning.
3. **[~] Untagged-leak diagnostic** — `server_groupsGC.sqf` audit loop. Now that editor slots are
   tagged `editor-player-slot` and all wrapper spawns are tagged, a NON-empty `untagged` group =
   a raw createGroup that bypassed the wrapper = real leak. Fold into the existing forEach allGroups
   audit loop (no extra pass): count non-empty untagged groups per side where side != sideEmpty,
   emit `UNTAGLEAK|v1|west|east|guer|samples` + debounced WARNING (warmup >600s).

**Also (Steff 2026-06-15): GUER soft cap raised 60 → 80** (`WFBE_C_GUER_GROUPS_MAX`) — more garrison
headroom above the ~73 peak, still well under 144; the new monitor watches it.

**STATUS: all 4 changes implemented + verified.** The three `[~]` above are DONE plus the GUER-cap bump.
- **Lint-A2Compat: PASS** (0 FAIL; the 4 REVIEWs are pre-existing find-quote in `AI_Commander_Base.sqf`).
- **Adversarial review (3 lenses: A2-runtime / logic+false-positive / integration): PASS** — 0 runtime
  blockers, 0 logic blockers. Two non-blocking fixes applied: (a) `server_groupsGC.sqf:304` dropped a
  redundant `str` (samples already strings — was double-quoting); (b) `SkinSelector_Apply.sqf:83` tag
  now broadcasts (`,true`) so the server audit can actually see `skin-swap`. The lone "blocker" was the
  known Takistan regen step (`dotnet run` syncs the stale Takistan copies), already in the deploy checklist.
- Touched files: `Init_CommonConstants.sqf` (2 lines), `server_groupsGC.sqf`, `SkinSelector_Apply.sqf`.

Remaining: commit to `deploy/2026-06-12-aicom-experital` (**hold push for Steff's consent**).

### Discovered issues (off-scope) — Workstream B (dashboard, box-side)
- **EMPTYGRP telemetry is silently dead in the dashboard.** `server_groupsGC.sqf` emits `EMPTYGRP|v1|`
  but `C:\WASP\Update-PublicStats.ps1` parses for `GRPEMPTY|v1|` (prefix mismatch). Pre-existing, not
  from this diff. One-line regex fix on the box. Same pass could teach the parser the new `GUERCAP|v1|`
  (GUER soft-cap gauge) and `UNTAGLEAK|v1|` (leak counter) lines — the "deeper per-faction info" Steff asked for.

---

## 2026-06-15 — Staged-deployment items (Discord deploy thread)

Source: OCD deploy-planning thread (Marty / Zwanon / Net_2). Scope = 4 items + a Miksuu-site dashboard view.

### Findings (verified 2026-06-15)
- **Group GC suite ALREADY on this branch** and committed: `server_groupsGC.sqf` (full + throttled),
  `Client/Functions/Client_GroupsGC.sqf` per-HC sweep wired at `Headless/Init/Init_HC.sqf:139`,
  `Common/Functions/Common_CreateGroup.sqf` registered at `Common/Init/Init_Common.sqf:111`.
- **Deploy branch is NEWER than Marty's live box** (`a2wasp-grpleak/_boxlive`): branch adds `GCSTAT|v1`
  per-pass line + D2 audit-every-N server-FPS throttle (`WFBE_C_GROUPAUDIT_EVERY`) + persistent-empty
  tracking. Box has a `dgEmpty` (defense-gunners) sub-metric the branch lacks. → DO NOT overwrite with
  box (would drop the throttle). Optional: graft the `dgEmpty` sub-metric only.
- **logcontent**: `LOG_CONTENT_STATE` is driven by `#define WF_LOG_CONTENT` in `version.sqf`
  (`initJIPCompatible.sqf:4-13`). `version.sqf` is absent from source (build-generated) → currently
  "NOT ACTIVATED" for server/clients; HCs force ACTIVATED at runtime (`initJIPCompatible.sqf:60`).
- **No client→server FPS telemetry** exists. `Common_PerformanceAudit.sqf` logs each machine's own
  `diag_fps` to its own RPT only (gated by `WFBE_C_PERFORMANCE_AUDIT_ENABLED`).

### Plan / progress
- [x] **FPS telemetry** (Chernarus). New `Client/Functions/Client_FpsReport.sqf` (player-only sampler,
      avg+min over 5×1s, staggered, self-gated on `WFBE_C_CLIENT_FPS_REPORT`); spawned from
      `Client/Init/Init_Client.sqf` tail; server PV receiver `WFBE_FPS_REPORT` in `Server/Init/Init_Server.sqf`
      (after Group-GC spawn) → `diag_log "FPSREPORT|v1|uid|fps|fpsMin|players|dnMode|daytime|sun|srvFps|t|name"`;
      two lobby params in `Rsc/Parameters.hpp` (`WFBE_C_CLIENT_FPS_REPORT` 0/1 def 0, `..._INTERVAL` def 60s).
      Lint-A2Compat: **PASS, 0 FAIL** (4 pre-existing REVIEWs in AI_Commander_Base, not mine).
- [x] **logcontent (#4)** = BUILD CONFIG, not a source edit. `version.sqf` is gitignored + generated by
      LoadoutManager; `BaseTerrain.cs:386` emits active `#define WF_LOG_CONTENT` for `SERVER_DEBUG`/
      `AIRWAR_SERVER_DEBUG`. → **Pack the staged release with `dotnet run -c SERVER_DEBUG`** (from
      `Tools/LoadoutManager`) and logcontent is ON for every map. No committable file. (Marty's own note
      at `BaseTerrain.cs:343`: changing the value alone does nothing — the line must be uncommented, which
      the SERVER_DEBUG config does.)
- [x] **Group GC (#1/#2)** already on branch + AHEAD of Marty's box (server throttle). Per-HC reaper present.
      Did NOT re-port (would regress). Optional `dgEmpty` graft: SKIPPED (don't destabilise throttled audit).
- [~] **Takistan / modded maps**: DEFERRED to deploy build. Takistan on this branch is STALE vs Chernarus
      (missing per-HC GC exec, deadspawn-safety, PickLeastLoadedHC, egress gate, restart/dashboard/playerstat
      emitters, FPS-profiling, empty-veh-timeout tune — all unrelated to this work). `SERVER_DEBUG` regen
      reproduces ALL of it from Chernarus at build time. Do NOT hand-mirror; do NOT sweep a catch-up regen
      into this feature commit.
- [ ] Commit Chernarus on `deploy/2026-06-12-aicom-experital` — **hold push for Steff's consent**.

### Discovered issues (off-scope)
- Takistan (`Missions_Vanilla/[61-2hc]...takistan`) is well behind Chernarus on this branch — needs a full
  `SERVER_DEBUG` regen before any release cut, independent of the FPS work.

### Workstream B (Hetzner live-stats dashboard) — CORRECTED TARGET + ACCESS
- **NOT the Miksuu Next.js site, NOT dashboard-v4.** It's the bespoke live-stats SPA at
  **http://78.46.107.142:8080/** ("Miksuu's Warfare — Live Server Stats"), served from the **Hetzner box**.
- **Access**: box = Windows, SSH/RDP as `Administrator` (Posh-SSH password auth from Main PC; key auth NOT
  set up). Scratch = `C:\WASP`. (pw in [[miksuu-hetzner-test-server]] memory.)
- **Source (box-only, NOT in any repo)** — pulled to `C:\Users\Steff\miksuu-dashboard-work\`:
  - `Serve-PublicStats.ps1` — HttpListener :8080 (http.sys → PID 4 System); serves whitelist from `C:\WASP\web`:
    index.html, stats.json, next-stats.json, next-changelog.json. Scheduled task `WaspStatsWeb` (ONSTART, SYSTEM).
  - `Update-PublicStats.ps1` (85 KB) — RPT parser + `stats.json` generator (parses AICOMSTAT/ORBATSTAT/DELEGSTAT/
    `group audit`/WASPSTAT). `-MissionLabel WASP|NEXT`.
  - `C:\WASP\web\index.html` (80 KB) — the front-end (tabs + JS), fed by `stats.json` (135 KB aggregate).
- **"the NEXT page" = the `NEXT / V2` tab** (dev diagnostic for the V2 branch; currently DOWN/NaN).
  index.html anchors: nav btn L185, panel `#tab-nextv2` L364-448, JS L1061-1229, `renderTab` L1254,
  fetches `/next-stats.json` + `/next-changelog.json`.
- **Plan (FULL, approved)**:
  1. Remove NEXT/V2 tab (nav+panel+JS+polling); drop `renderTab` nextv2 branch.
  2. Add "Force & Group Health" to Overview (after Order of Battle L255): per-side W/E/G group **n/144**
     cap gauge (amber≥130 red≥144) + empty/leaked groups (`GRPEMPTY`) + delegation% — the group-limitation
     analysis made public. Data already partly present (`c.groups.west/east/guer`, L843); add a
     `groupHealth` object to `Update-PublicStats.ps1` from `group audit [SIDE] N/144` + `GRPEMPTY|` parsing.
  3. Visuals/perf: favicon 404 fix; faction-gauge styling; audit Benchmarks/Balance/Top Players tabs.
  4. Later: surface client `FPSREPORT` (Workstream A) as a day-vs-night panel once it deploys.
- **Deploy**: zero game impact (web task only); back up index.html + Update-PublicStats.ps1 on box (.bak),
  push, restart `WaspStatsWeb`, verify live via browser. Respect [[hetzner-deploy-consent-policy]].
- **DEPLOYED & LIVE 2026-06-15** on the box (`C:\WASP\web\index.html` + `C:\WASP\Update-PublicStats.ps1`,
  `.bak-claude-*`/`.bak-v2pre-*` kept). NEXT/V2 tab removed; "Force & Group Health" live with real data
  (W/E/G n/144 gauges + GC footer reaped/emptyFound from `GCSTAT|v1|` 60s). Generator parse-checked +
  unit-tested; front-end validated headless (0 console errors). NOTE the ~2-min publish-delay buffer:
  a freshly-deployed field reads null for ~2-3 min before the buffer catches up (not a bug). Source +
  access documented in [[miksuu-live-stats-dashboard]] memory. Local working copy: `miksuu-dashboard-work/`.
- **STILL OPEN (part of "full plan")**: visuals/perf pass on the Benchmarks / Balance / Top Players tabs
  (only Overview + favicon done so far); and surfacing the Workstream-A client `FPSREPORT` as a
  day-vs-night panel once that mission build deploys to the live server.

---

## 2026-06-12 — Artillery Radar + Reserve buildable structures (WDDM integration)

Two new commander-buildable structures, mirroring the CBR/Bank pattern (cfc1fb93):

- **ArtilleryRadar** — `USMC_/RU_WarfareBArtilleryRadar` (CO) / `US_/TK_..._EP1` (OA).
  Cost 2400, MediumSite, dis 21, dir 90. Gate `WFBE_C_STRUCTURES_ARTILLERYRADAR = 1`.
- **Reserve** — `Land_Mil_Barracks_i` (CO) / `Land_Mil_Barracks_i_EP1` (OA — intact model
  inferred safe from the `Land_Mil_Barracks_i_ruins_EP1` WFBE_C_STRUCTURES_RUINS precedent).
  Cost 2000, MediumSite, dis 30 (walls reach ±24 m). Gate `WFBE_C_STRUCTURES_RESERVE = 1`.

Both use **MediumSite** → the standard phased construction animation path
(LocationLogicStart / WFBE_B_Completion), same as the factories — NOT preplaced.
Auto-walls fire from Construction_MediumSite (exclusion list untouched), pulling the
CHOSEN WDDM designs added to Init_Defenses.sqf:

- `WFBE_NEURODEF_ARTILLERYRADAR_WALLS` — "walled boom-gate checkpoint": HESCO 5x ring,
  3 m front gap, cones + danger sign; boom gate `Land_BarGate2` on A2/CO, jersey-block
  chicane fallback on OA standalone (BarGate is A2 content).
- `WFBE_NEURODEF_RESERVE_WALLS` — "floodlit walled yard": HESCO 10x yard, corner
  watchtowers (`Land_Fort_Watchtower[_EP1]` per content set), `Land_Ind_IlluminantTower`
  over the bays (confirmed both content sets via Core_CIV/Core_TKCIV).

Plumbing: RequestStructure allowed-list +2, marker labels ("AR"/"RES"),
Client_FNC_Special build-started cases, stringtable `RB_Artillery_Radar`/`RB_Reserve`,
shorthand vars `<side>ARTRAD`/`<side>RES`. Per-design intent: the Artillery Radar takes
fortifications only (walls, no gun defenses) — its template contains zero crewed weapons.

LoadoutManager run synced Takistan (7za pack step fails — documented-ignorable). NOTE:
the generator clobbers owner hand-edits in `EASA_Init.sqf` (re-adds stripped defaults,
54ad0732) and `Sounds\description.ext` (volumes 1→7) on the CHERNARUS side — those four
generated-file changes were reverted before commit; Takistan committed state already
matches generator output. Needs an in-engine build test of both structures.

---

## Task 28 — Port Patrols v2 at upgrade index 23 (2026-06-10)

WFBE_UP_PATROLS = 23 (CBR = 22 stays). All faction arrays grow to 24 entries.

PR #25 dependency check: server_side_patrols.sqf only needs WFBE_HEADLESSCLIENTS_ID
and HandleSpecial/RequestSpecial — both already present in experital pre-#25. No PR #25
symbols needed.

Old system retired: Init_Towns random flagging + server_town_ai spawn gate removed.
server_patrols.sqf / Server_GetTownPatrol.sqf left as dead code (same as master).

Group A (21 entries→24): RU, USMC, CDF, INS, OA_TKGUE, OA_US — add UNITCOST+CBR+Patrols padding
Group B (22 entries→24): OA_TKA — add CBR+Patrols padding
Group C (23 entries→24): CO_GUE, GUE, CO_RU, CO_US — add Patrols only

---

## 2026-06-10 — Investigation: BuyUnits dropdown forEach over `[objNull]` (GUI_Menu_BuyUnits.sqf)

**Question:** Did commit `c8071eeb` (airfield capture / Task 12) introduce a regression where the
factory-dropdown `forEach _sorted` at ~line 282 iterates `[objNull]` when no depot/airport is in range?

**Verdict: pre-existing since the original WFBE import — NO new regression.**

Evidence:
- `git log -L 250,290` on the file: the `_sorted = [[...] Call WFBE_CL_FNC_GetClosestDepot];`
  wrapping is unchanged context in `c8071eeb`; the commit only ADDED `_closest = _sorted select 0;`.
- Initial import `96809ac3` already has the identical wrap + the same `forEach _sorted`, and the
  Depot/Airport branches never set `_closest` (file-top init `_closest = objNull;`, line 8).
- `_sorted` was never carried over from the `default` factory branch — every switch branch always
  assigned it, including in the original code.
- `Client_GetClosestDepot.sqf` / `Client_GetClosestAirport.sqf` always return objNull-or-entity
  (init `_closest = objNull`, returned as last expression) — never nil, so the wrap is always a
  1-element array and `select 0` is safe.
- With `_x = objNull`: `Common_GetClosestEntity.sqf` returns objNull harmlessly (`distance` vs a
  null object = 1e10, never `< 100000`), then `objNull getVariable 'name'` → nil → the `_txt`
  concatenation on line 280 errors → broken/missing dropdown entry + RPT "Undefined variable"
  spam. Same behavior before and after `c8071eeb`.
- `c8071eeb` actually FIXED a real carry-over bug: before it, on Depot/Airport tabs `_closest`
  kept its stale value (objNull init, last factory from the `default` branch, or the dropdown
  handler at line 191), so the queue display at line 290 could read the wrong object's "queu".
  Downstream is objNull-tolerant (`isNil '_queu'` guard, `getVariable` on objNull → nil).

### Discovered Issues (off-scope, optional hardening)
- Cosmetic, since 2010: opening the Depot/Airport tab with none in purchase range puts one broken
  entry / RPT error in the 12018 dropdown. Cheap fix if ever wanted:
  `if !(isNull (_sorted select 0)) then { ...forEach _sorted... }` around the lbClear/forEach
  block (or `lbAdd [12018, localize 'STR_...none-in-range']` in the else).

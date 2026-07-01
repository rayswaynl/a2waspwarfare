# JOURNAL — a2waspwarfare-experital

## 2026-06-28 — PR #119 low-id CIV HC slot magnet [PR]

PR #119 now layers the static lobby-slot experiment on top of the runtime HC CIV hardening. The two
plain CIV HC slots were moved to the lowest object ids (`0`, `1`) and `forceHeadlessClient=1` was
removed so A2-OA's `-client` auto-seat has normal playable CIV slots to choose before WEST id `229`.
The displaced non-playable LOGIC objects formerly using ids `0` and `1` were moved to unused high ids
`9007` and `9008`; they had no `synchronizations[]` back-references.

Smoke verdict still needs the live engine: success is both HCs logging `HCSIDE|v1|preseat|...|engineSide=CIV`.
If preseat remains WEST, the static lobby-label fix is refuted, but the runtime reseat/owner-keyed
registration from PR #118 still protects gameplay-side behavior.

## 2026-06-28 — HC CIV slotting hardening [PR]

Root cause is no longer "missing CIV HC slots": `origin/master` already has two CIV `forceHeadlessClient=1`
slots plus the B761/B762/B763 enrollment/vote fixes. The remaining failure surface is boot/restart timing:
HC-local reseat used mission `time`/`sleep`, server registration gave owner resolution only 3 seconds, and
the HC registry was keyed by UID even though A2 HCs may report empty/colliding UIDs.

Patch on `codex/hc-civ-slotting-live`:
- `Headless/Init/Init_HC.sqf`: use `diag_tickTime`/`uiSleep` for reseat deadlines, mark the pre-reseat
  magnet group, and briefly reannounce `connected-hc` after cold start.
- `Server/Functions/Server_HandleSpecial.sqf`: wait longer for owner, require server-observed CIV before
  registry capture, key/de-dupe HCs by owner ID, and prune HC magnet groups even when UID is empty.
- `Server/Functions/Server_OnPlayerDisconnected.sqf`: clean HC registry by owner for UID-empty HCs before
  the human disconnect path.

Verification: `dotnet run` in `Tools/LoadoutManager` regenerated Takistan and packed `_MISSIONS.7z`;
the touched Chernarus/Takistan files hash-match; `git diff --check` has no whitespace errors beyond the
repo's existing CRLF warnings.

## 2026-06-20 — JOIN SAGA: definitive root causes + fixes (B54/B56) [INCIDENT / POSTMORTEM — CORRECTS THE B49 ENTRY BELOW]

**READ THIS FIRST — it supersedes the 2026-06-19 B49 entry below.** The 2026-06-19 postmortem credited
a "45s fade watchdog" (B49) with fixing the join. **It did not.** That watchdog SILENTLY FAILED, and the
all-day black-screen-on-join was actually a **STACK of four distinct bugs**, each of which had to be peeled
off in order. The de-slot (#1 below) was necessary but not sufficient; the build kept failing the join
even after it. Here is the full, corrected record.

### The bug stack (fixed in order)

1. **Null-player "shell" slots in `mission.sqm` (the trap the B49 entry found).** The GUER 27→14 de-slot
   left 26 dead slots (13 WEST + 13 EAST) — `deleteVehicle this` leftovers — still listed in the
   `LocationLogicOwnerWest` / `LocationLogicOwnerEast` (ids 255/256) `synchronizations[]` rosters. In
   Warfare the units synced to the Owner logic *are* the side's playable roster, so the lobby kept offering
   all 27 slots/side. A JIP client that landed on a shell slot ran `deleteVehicle this` → **`player == objNull`**
   → stuck. **Fix:** de-slot them (drop the 26 ids from the two Owner-logic `synchronizations[]` lists and
   clear the shells' own back-reference sync). NECESSARY but NOT SUFFICIENT — the join still failed after this.

2. **JIP network DELIVERY stall — `basic.cfg` `MaxSizeGuaranteed`.** `MaxSizeGuaranteed=1024` fragmented
   guaranteed JIP messages above the MTU → the join state never landed; the server reported **199,511
   "pending" messages**. **Fix:** lower `MaxSizeGuaranteed` to **512** so guaranteed JIP messages fit a
   single datagram. CRITICAL: `basic.cfg` is **box-only and unversioned** — it lives on the server, not in
   the repo. *This is why every git rollback "never helped":* the network-delivery half of the failure was
   not in source control and no commit could touch it.

3. **The `sleep`-vs-`uiSleep` trap (why the B49/B52/B53 watchdogs silently failed).** The B49 "45s fade
   watchdog" and the B52/B53 fade-clear retries all gated on `sleep` / `waitUntil` / mission-`time`. **All
   three are PAUSED while a client sits on the loading screen** (the sim clock does not advance for a client
   still receiving the mission), so the watchdog's gate never opened and the screen-clear **never ran — with
   no error, hence "silently failed."** The B49 entry below credited a fix that physically could not execute
   on the stuck client. **Fix (B54):** clear the black fade layer **12452** with an **ungated `uiSleep`**
   loop — `uiSleep` runs on real wall-clock time and ticks even while the sim is paused. Necessary, still
   not sufficient on its own.

4. **THE definitive cause — un-timed `waitUntil` on JIP-synced team data in client bootstrap (B56).** Found
   only by reading the **joining player's CLIENT RPT** (not the server RPT). `initJIPCompatible.sqf` client-init
   Part II ran, for **every** side in `WFBE_PRESENTSIDES`, an **un-timed**
   `waitUntil {!isNil {_logik getVariable "wfbe_teams"}}` **BEFORE** `execVM "Client\Init\Init_Client.sqf"`
   (which holds the fade-clear). With GUER playable, the harass-only resistance side's logic **never resolves
   `wfbe_teams` on a JIP client**: `Init_Server` registers teams only for `[east, west]`; GUER is a separate
   gated block keyed on `WFBE_L_GUE`, and the rest of the codebase already excludes resistance everywhere via
   the `WFBE_PRESENTSIDES - [resistance]` idiom. So once GUER was a present side, **every JIP joiner blocked
   on that `waitUntil` forever** → `Init_Client.sqf` (and its fade-clear) **never ran** → permanent black.
   This is why #1–#3 each looked like progress but the join still died. **Fix (B56):** bound those waits with
   `uiSleep`-counter timeouts so client init **always** reaches `Init_Client` even if a side's teams never
   resolve. In `Missions\[55-2hc]warfarev2_073v48co.chernarus\initJIPCompatible.sqf` (~lines 265–287):
   - `while {(isNil "WFBE_PRESENTSIDES") && (_w < 80)} do { uiSleep 0.25; _w = _w + 1; };` (≤20s)
   - per-side `while {(isNil {_logik getVariable "wfbe_teams"}) && (_ws < 120)} do { uiSleep 0.25; _ws = _ws + 1; };` (≤30s)
   - falls through to `execVM "Client\Init\Init_Client.sqf";` unconditionally, with a `[WFBE][B56 JIP-FIX]`
     diag_log if `WFBE_PRESENTSIDES` was never set in time.

### Delivery
Shipped as a **fresh-named single `.pbo`** — both a cache-bust (returning players re-download cleanly instead
of reusing a stale local copy) and a clean transfer to the box.

### Lessons (the expensive ones)
- **Server boot-smoke is structurally BLIND to the JIP client path.** HCs are box-local with no real network
  hop, so they don't exercise guaranteed-message fragmentation or the client-side `waitUntil`. The server RPT
  looked healthy the whole time. **Only the joining player's CLIENT RPT revealed bug #4.** Always pull the
  failing client's RPT for a join failure — the server's is not enough.
- **A2 LESSON (permanent-black landmine):** *any* un-timed `waitUntil` on JIP-synced data in the client
  bootstrap is a permanent-black trap. **Bound it with a `uiSleep` counter.** `sleep` / `waitUntil` /
  mission-`time` are **paused on the loading screen**; only `uiSleep` (real wall-clock) ticks while the sim
  is paused — so any "rescue/watchdog" timer in the client bootstrap MUST use `uiSleep`, never `sleep`/`time`.
- **Part of the failure lived OUTSIDE git** (`basic.cfg`, box-only). When git rollbacks "do nothing,"
  suspect unversioned box-side config, not just stale source.
- The 2026-06-19 entry's lesson "roll FORWARD to the fix" was directionally right, but the specific fix it
  named (B49 watchdog) was a no-op on the stuck client. The real fixes were B54 (`uiSleep` fade-clear) and
  **B56** (bounded client-bootstrap waits) plus the box-side `basic.cfg` change.

Touched/relevant files: `Missions\[55-2hc]warfarev2_073v48co.chernarus\initJIPCompatible.sqf` (B56 bounded
waits, ~265–287), `...\Client\Init\Init_Client.sqf` + the 12452 layer (B54 `uiSleep` fade-clear),
`...\mission.sqm` (#1 de-slot of the 26 shell slots), and the **box-only** `basic.cfg` (`MaxSizeGuaranteed
1024→512`, not in repo).

---

## 2026-06-20 — B57 — AICOM massive update [WORKING STATE / DEPLOYED]

**Deployed as `[55-2hc]warfarev2_073v48co_b57.chernarus` (Chernarus).** Boot-smoke clean; runtime-confirmed:
founding-pad logs *"B57 padded infantry team to floor (8 units)"*, **0 runtime errors**, **FPS 47 @ AI=84**.
Server-side only; A2-OA-1.64-safe throughout (no `pushBack`/`isEqualType`/`isEqualTo`; `+_template` copies,
`getDir`, `typeName ==`). Towns kept HARD by design — the AI overcomes them via **bigger + more concentrated
teams**, not softened garrison/capture rates.

### Centrepiece: LARGER AI-commander groups (the "thin team" fix)
- **Root cause.** Live teams are HC-founded at raw template size (3–6) and **never refilled**:
  `AI_Commander_Produce.sqf` (~line 63) skips `wfbe_aicom_hc` teams — which are **100% of live teams**
  (`CMDRSTAT srvTeams=0`). So the `WFBE_C_AICOM_TEAM_SIZE_MIN=8` floor and the deficit-fill logic inside
  Produce are on a **DEAD path** (they only fire for server-local teams, of which there are none in this build).
- **Fix.** Pad infantry/mixed templates up to the floor (8–12) **AT FOUNDING**, in
  `AI_Commander_Teams.sqf` (~lines 279–306, right after the template pick): find the team's `"Man"` class,
  `_template = +_template` (copy so the shared template isn't mutated), then append that class until
  `count _template >= WFBE_C_AICOM_TEAM_SIZE_MIN`. **Skips MBT and attack-heli templates** (the vehicle is the
  punch; no infantry floor). Logs `B57 padded infantry team to floor (N units)`.

### Constants (`Common\Init\Init_CommonConstants.sqf`)
- `WFBE_C_AICOM_TEAMS_PC_LOW` **5 → 10** (line ~139) — max HQ teams/side at low pop; pairs with the
  founding-pad so ~10 teams found at 8–12 each. ~10×8=80/side, under `TOTAL_AI_MAX` 130 (watch server FPS).
- `WFBE_C_AICOM_CONCENTRATION` **4 → 6** (line ~198) — more teams massed on the primary spearhead.
- `WFBE_C_AICOM_ASSAULT_REACH_FOOT` **3500 → 3000** (line ~335) — keeps thin foot teams on adjacent reachable
  towns; cuts long death-marches, tighter contiguous front.
- `WFBE_C_ECONOMY_SUPPLY_INCOME_MULT = 0.35` (line ~364) — throttles long-term town SUPPLY income (buildings/
  upgrades pace). Applied at `Server\FSM\updateresources.sqf` line ~76 (only when `_currency_system == 0`).
  **Cash/funds and the starting-supply seed are UNCHANGED** (Ray's split: cash = units, supply = buildings+upgrades).
- (Note: the inline rationale comment on `TEAMS_PC_LOW` references "CONCENTRATION=4" in its prose — stale
  comment text; the **active** value is 6.)

### Adopted from `feat/aicom-fleet-improvements` (commit `cc5090be`), graded for legacy-fit + A2-safe
- **Retreat-and-Reform** — `AI_Commander_Produce.sqf`.
- **Last-Stand + HQ-strike → 8-towns gate + persisted `wfbe_aicom_strat_mode`** — `AI_Commander_Strategy.sqf`.
  **DELETED** the branch's call to the non-existent `WFBE_CO_FNC_RadioMessage` (would have errored on legacy).
- **HC cold-start retry** — `Server_HandleSpecial`.
- **Town-defender skill spread** — `Common_CreateTownUnits`.
- **Snappier team loop** — `Common_RunCommanderTeam`: arrival = capture-range; poll **20s → 8s**.
- **Dead-patrol-marker scrub** — `server_side_patrols`.
- **`[AICOM BOOT]` / `[BRIEF]` telemetry** — `AI_Commander.sqf`.

### Deliberately SKIPPED from that branch (would regress legacy)
- Its `initJIPCompatible` + `Init_Towns` (carry the `sleep`-trap — see the join saga above; legacy already
  has the `uiSleep`-bounded B56 version).
- `Client_HandlePVF` / `Server_HandlePVF` (deployed already has the CODE-guarded version).
- `Init_CommonConstants` color change (would clobber the GUER 3-branch colors).

### Other B57 changes
- **Player map-marker direction fix** — `Client\FSM\updateteamsmarkers.sqf` (~line 208): the team marker used
  the **velocity vector** (direction of *travel*), so the arrow pointed wrong when a unit strafed/slid. Now
  `_dir = getDir _leaderVehicle` (`vehicle _leader`), correct on foot **and** mounted; matches the patrol/AICOM
  arrow loops. A2-OA-safe.
- **Lobby slot reorder** — grouped by **real role** per side. Classnames are misleading (`*_TL`/`*_CO` are
  Engineers/Support per the slot *description*, not team-leaders/commanders). New order:
  **Medic → Engineer → Support → Rifleman → Sniper**. Verified a **pure permutation** (ids, syncs, items,
  braces all unchanged); the HC-parking CIV slots stay pinned.
- **HQ start-variety** — `WFBE_C_BASE_STARTING_MODE` is already `2` (random) (line ~287), but A2's `random`
  is **deterministic on a fresh dedicated-server process** → the same start every match. Fixed with a
  per-match RNG perturbation in `Init_Server` (inside the `_use_random` block), seeded by a
  `profileNamespace` counter so each match seeds differently.

### Touched files
`Server\AI\Commander\AI_Commander_Teams.sqf` (founding-pad), `...\AI_Commander_Produce.sqf` (Retreat-and-Reform),
`...\AI_Commander_Strategy.sqf` (Last-Stand / HQ-strike / strat_mode), `...\AI_Commander.sqf` (telemetry),
`Common\Init\Init_CommonConstants.sqf` (constants), `Server\FSM\updateresources.sqf` (supply mult),
`Client\FSM\updateteamsmarkers.sqf` (marker dir), `Server\Init\Init_Server.sqf` (start-variety RNG),
`Server_HandleSpecial` / `Common_CreateTownUnits` / `Common_RunCommanderTeam` / `server_side_patrols`
(adopted helpers), `mission.sqm` (slot reorder).

---

## 2026-06-19 — Join failure ("Receiving mission") — root cause + fixes [INCIDENT / POSTMORTEM]
> **SUPERSEDED — see the 2026-06-20 "JOIN SAGA" entry above.** This entry's central claim (that the B49
> "45s fade watchdog" fixed the join) is WRONG: that watchdog gated on `sleep`/`time`, which are paused on
> the loading screen, so it silently never ran. The de-slot below was necessary but not sufficient; the
> definitive fixes were B54 (`uiSleep` fade-clear), B56 (bounded client-bootstrap `waitUntil`s), and a
> box-only `basic.cfg` `MaxSizeGuaranteed` 1024→512. Kept verbatim below for the historical record.

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

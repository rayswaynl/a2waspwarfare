# Queued for the next update

Changes committed to `deploy/2026-06-12-aicom-experital` that are **not yet on the live
server build**. To ship: `dotnet run -c SERVER_DEBUG` from `Tools/LoadoutManager` (regenerates
Takistan + activates `logcontent`), then deploy the mission to the server and restart.

_(Maintained for the Wednesday merge with Marty. Tick the checklist as items deploy.)_

## Mission (SQF)

### Group-cap telemetry & tagging
- **Client FPS telemetry** — `Client/Functions/Client_FpsReport.sqf` (player-only sampler) +
  server `FPSREPORT|v1|` receiver in `Init_Server.sqf` + lobby params `WFBE_C_CLIENT_FPS_REPORT`
  / `..._INTERVAL`. Each report is tagged `hc=<live HC count>`, day/night mode, in-game time,
  player count — for the agreed **0 / 1 / 2 HC** scaling test. _(commits `88709b051`, `7312f5aeb`)_
- **Editor player-slot tagging** — `Init_Server.sqf` one-shot post-init sweep tags the 27 WEST +
  27 EAST editor-placed player-slot groups `wfbe_group_src="editor-player-slot"`;
  `WASP/actions/SkinSelector/SkinSelector_Apply.sqf` tags its transient swap group `skin-swap`.
  Moves ~54 groups out of the `untagged` audit bucket so `untagged` becomes a real **leak signal**.
  Audit-only — no group lifecycle / GC change. _(commit `7a028c62b`)_

### Group-budget tuning & monitors (2026-06-15)
- **aicom extra-team cap** — `Common/Init/Init_CommonConstants.sqf` adds
  `WFBE_C_AI_COMMANDER_TEAMS_MAX_EXTRA = 2`. Caps the funds-scaled dynamic AI teams at base+2 (=6)
  instead of the previous inline fallback of 4 (=8). Saves up to 2 groups/side in rich-fund late-game
  with **no** change to the 4-team base combat capability (read site `AI_Commander_Teams.sqf:60`).
- **GUER soft cap raised 60 → 80** — `WFBE_C_GUER_GROUPS_MAX`. 60 was choking garrisons above the
  observed ~73 peak; 80 restores headroom, still well under the 144 engine cap. The new monitor below
  watches it.
- **GUER soft-cap monitor** — `server_groupsGC.sqf`. `GUERCAP|v1|count|max|pct` line every 60s (for the
  dashboard GUER gauge) + a debounced (5-min) WARNING at ≥90% of `WFBE_C_GUER_GROUPS_MAX` (=72/80) —
  the point where `server_town_ai.sqf` starts DEFERRING town garrisons. Distinct from the 130/144
  engine-cap warning (which GUER never reaches because the soft cap stops it far lower).
- **Untagged-leak diagnostic** — `server_groupsGC.sqf`. Now that editor slots + all wrapper spawns are
  tagged, a **non-empty** `untagged` combat-side group = a raw `createGroup` that bypassed the wrapper.
  Emits `UNTAGLEAK|v1|west|east|guer|samples` (folded into the 5-min audit loop, no extra pass) + a
  debounced WARNING (warmup >600s). SkinSelector swap-group tag now broadcast (`,true`) so the
  server-side audit can see it.
- **Player-slot cut (27→21): CONSIDERED & CANCELLED.** Deep research showed it buys **zero FPS** (empty
  persistent slot-groups are free on the hot path) and only frees headroom on WEST/EAST, which never
  approach the cap. `mission.sqm` left untouched (slots stay 27/side).
- _Verified: Lint-A2Compat PASS (0 FAIL); 3-lens adversarial review PASS (0 runtime / 0 logic blockers)._

### Verified — no change needed
- **Gunner condensation** confirmed intact (`4b98a9356` build8 + `c65b1c8ea` b15, both in HEAD):
  one `defense-gunners` group per town per side. GUER's ~18 = garrisoned-town count, not a leak.

## Ops / testing (prepped, not yet applied)
- `docs/testing/hc-scaling-test.md` — 0/1/2-HC test protocol, telemetry format, analysis, affinity plan.
- `Tools/Ops/Set-WaspCpuAffinity.ps1` — CPU-affinity pinning for the main server (server + HCs to
  P-cores, off E-cores; **dry-run by default**, applied only on go-ahead). Needs the box's P-core mask.

## Dashboard (Hetzner `:8080`, box-side — already LIVE, listed for the record)
- Removed the dev-only `NEXT / V2` tab; favicon 404 fixed.
- **Force & Group Health**: per-faction `n/144` cap gauges (amber ≥130, red at cap) + GC leak footer
  (reaped / empty-found) + per-source **fold-out** (player slots / static defenders / town garrisons /
  patrols / AI commander / …).
- **Client FPS** panel (by HC config + day/night) — dormant until the telemetry build deploys.

## Deploy checklist
- [ ] `dotnet run -c SERVER_DEBUG` (regens Takistan + `logcontent` on).
- [ ] Deploy the mission to the live server; restart the chain.
- [ ] Admin lobby: enable **Client FPS telemetry** on the 0/1/2-HC test days.
- [ ] Confirm the first `GROUPAUDIT` RPT line shows `editor-player-slot=27` per side and `untagged` ≈ 0.
- [ ] Confirm the dashboard fold-out reads "player slots ×27" per side (labels already shipped).

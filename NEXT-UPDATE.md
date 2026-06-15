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

# Production — auto-generate a report per match

> **Note (GR-2026-07-03a):** The `WaspMatchReport` scheduled task described in the Deploy
> section below has **not been registered** on the Game PC as of this writing. Reports must
> be triggered manually. See Known caveats for other open issues.

The report is designed to run as a **box-side scheduled task** on the gaming PC (per the
"automation on the box, never Claude crons" rule). Each run pulls the live server RPT, finds the
newest completed match, and — if it hasn't already — renders that match's report and
drops the MP4 for you to post to TikTok.

```
Hetzner server RPT (WASPSTAT lines)  ──ssh──►  produce-match-report.ps1 (gaming PC)
        │                                              │
        └── newest ROUNDEND, de-duped on seq           ├─ slice match → render_report.py (mp4 + caption)
                                                        ├─ POST mp4+caption → Warfare Discord #media
                                                        │     (bot "Warfare Handler", REST multipart)
                                                        ├─ wasp-match-reports\*.mp4 (archive)
                                                        └─ Peach DM to Ray (optional, -Notify)
```

Delivery is **Discord #media** (`1510573856275038228` in guild `1510513623800221857`), via the
Warfare bot (`miksuus-warfare/bot/.env` `DISCORD_TOKEN`). Grab clips from there to post to TikTok.
Verified end-to-end (test clip posted OK). Notes: Discord needs a real `User-Agent` header (else
403), and the non-boosted upload limit is ~10 MB — the renderer encodes at crf 24 (~6 MB / 48 s) to
stay safely under it. `-SkipDiscord` renders without posting; `-ChannelId` overrides the target.

## Components
- `render_report.py` + `render.py` + `assets/` + `brand/` — the renderer (this folder).
- `.venv/` — Python env (pillow/imageio/imageio-ffmpeg/numpy). Create once:
  `python -m venv .venv && .venv\Scripts\python -m pip install -r requirements.txt`
- `produce-match-report.ps1` — the runner (pull → slice latest match → render → notify).

## Verified
`pwsh -File produce-match-report.ps1 -RptFile <log>` on a 2-match log rendered **only the
latest** match (correct slice by ROUNDEND seq) → ~10 MB MP4, and a second run **de-duped**
("Already rendered"). Output named `wasp-report-<stamp>-<map>-<winner>.mp4`.

## Deploy (one-time)
1. **SSH:** the runner reads `Administrator@78.46.107.142:.../arma2oaserver.RPT` (same source
   the leaderboard/soak reporters use). Make sure the scheduled-task user has the SSH key.
2. **Register the task** (~every 10 min; it de-dupes so frequent runs are safe):
   ```powershell
   $action  = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -File "C:\Users\Game\a2waspwarfare-report\Tools\MatchReport\produce-match-report.ps1" -Notify'
   $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 10)
   Register-ScheduledTask -TaskName 'WaspMatchReport' -Action $action -Trigger $trigger -RunLevel Highest
   ```
3. **Output:** `C:\Users\Game\wasp-match-reports\*.mp4`. With `-Notify`, Peach DMs Ray the path
   when each report is ready.

## Known bugs (GR-2026-07-03a)
- **Trailing-quote map parse failure.** The RPT map-name parser fails when the `WASPSTAT` line
  has a trailing quote inside the map string. Check the parsed map field in `replay_summary.py`
  output before rendering.
- **`WaspMatchEndRotate` dual-PBO abort.** When two PBO files exist for the same build in
  `MPMissions`, `produce-match-report.ps1` may select the wrong one and abort. Ensure only one
  PBO is present for the active build.
- **Scheduled task not installed.** `WaspMatchReport` has not been registered on the Game PC
  as of GR-2026-07-03a. Trigger manually with `pwsh -File produce-match-report.ps1 -RptFile <log>`.

## Known caveats (v1)
- **Event timing is by sequence, not seconds.** `CAPTURE`/`KILL` carry no match-time, so the
  battle/momentum animation spreads events evenly across the match. Frame-accurate timing needs
  `round(time)` added to those emitters (`server_town.sqf`, `RequestOnUnitKilled.sqf`) — a small
  mission change.
- **Town coords are approximate** until the `WFBE_C_LOG_TOWN_COORDS` boot-logger (PR #116) is run
  once per map to harvest exact positions into `matchdata.TOWN_COORDS`. Reset `WFBE_C_LOG_TOWN_COORDS`
  to 0 in `Common/Init/Init_CommonConstants.sqf` after harvesting — leaving it at 1 causes log noise.
- **Player names** fall back to `Op-<last4>` unless `-NamesTsv <uid\tname>` is supplied (generate
  from the leaderboard `ingame_stats`/`members` table).
- Auto-posting to TikTok is **out of scope** for v1 (needs the TikTok Content Posting API + app
  review). Post manually from the output folder.

## Production wiring trace

Lane 306 rechecked the original four production gaps against the current Build84 lane. Treat
this table as the handoff for the next implementation pass.

| Gap | Current Build84 status | Exact anchors | Minimal next step |
| --- | --- | --- | --- |
| Event timing | Mostly done. `CAPTURE` and `KILL` already append `t=<round time>`, and the parser prefers that token before falling back to ingest `line_times` or even sequence spread. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town.sqf` CAPTURE emit; `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestOnUnitKilled.sqf` KILL emit; `matchdata.py` `_time_token()` and `t_for()`. | Update `docs/WASPSTAT-FORMAT.md` to document optional trailing `t=<sec>` tokens for `CAPTURE` and `KILL`. A `v2` bump is only needed if fields move positionally instead of staying append-only. |
| Town coordinates | Chernarus and Takistan are now exact static tables. Zargabad still falls back to `WORLD_SIZE["default"]` and auto-placed towns because it has no `WORLD_SIZE` or `TOWN_COORDS` entry. | `matchdata.py` `WORLD_SIZE`, `TOWN_COORDS`, and `coords_for()`. | Harvest Zargabad town logic positions and add `WORLD_SIZE["zargabad"]` plus `TOWN_COORDS["zargabad"]`. |
| Player names | Renderer accepts names via `--names`, the scheduled runner passes `-NamesTsv` through when supplied, and `parse_waspstat()` now also consumes embedded `PLAYERSTATS` `~name` tokens. Production still needs a reliable TSV/export path when embedded names are absent. | `produce-match-report.ps1` `NamesTsv`; `render_report.py` `--names`; `matchdata.py` PLAYERSTATS loop and display-name fallback. | Wire the box-side task to pass a generated UID-to-name TSV from the leaderboard DB, or confirm the live PLAYERSTATS emitter always includes `~name`. |
| ROUNDEND trigger | The repo has a polling runner that pulls the RPT, finds the newest `ROUNDEND`, slices that match, and de-dupes on sequence. The separate `:3010` ingest watcher is not represented here. | `produce-match-report.ps1` ROUNDEND scan and de-dupe state. | Either keep the scheduled task as the production trigger or add a small external ingest watcher that invokes the same runner after a new `ROUNDEND`. |

# WASP Warfare — Server Installation Guide

How to stand up a WASP Warfare (Arma 2: Operation Arrowhead 1.64) dedicated server on a
fresh Windows machine, including the AntiStack database ("SQL") configuration.

Written for a third-party host or a backup box. It assumes **no** prior WASP installation
on the target machine, but be aware of one hard dependency up front:

> **Two required mod folders (`@adwasp`, `@admkswf`) and the AntiStack database extension
> (`A2WaspDatabase.dll`) are NOT publicly downloadable and are NOT in this repository.**
> They must be copied from an existing WASP server installation (or obtained from the
> current host). Everything else below is buildable/installable from public sources plus
> this repo. See §3 and §8.

Never commit real hostnames, IPs, passwords, or Steam credentials to this repo — it is
public. All values below are placeholders.

---

## 1. What the system consists of

| Component | Source | Required? |
|---|---|---|
| Arma 2 + Arma 2: OA 1.64 (Combined Ops) | Steam (app 33930) | Yes |
| `arma2oaserver.exe` dedicated server | ships with OA | Yes |
| Mission PBO (`[55-2hc]warfarev2_073v48co_*.chernarus.pbo` etc.) | built from this repo (§7) | Yes |
| `@CBA_CO` (Community Base Addons, CO build) | public download | Yes |
| `@adwasp` (bundles ASR AI), `@admkswf` | copy from existing WASP box | Yes |
| Headless clients (1–4 `ArmA2OA.exe -client` instances) | same game install | Strongly recommended (AI offload) |
| `A2WaspDatabase.dll` + its database backend (AntiStack persistence) | copy from current host — closed binary, no source | Optional (mission degrades gracefully) |
| `a2waspwarfare_Extension.dll` (match-status JSON exporter) | buildable from `Extension/` in this repo | Optional |
| BattlEye + filters (`BattlEyeFilter/`) | this repo + BE service | Optional (currently OFF on reference box) |
| Stats pipeline (`Tools/Ops/Update-PublicStats.ps1`, web dashboard) | this repo | Optional |

Hardware guidance: the Arma 2 engine is bottlenecked by **single-thread CPU performance**;
core count mostly helps the headless clients. A modern desktop CPU (e.g. an Intel i5-13500)
is more than adequate for server + 2 HCs. Budget ~40 GB disk for the game + mods, 16 GB RAM
comfortably covers server + 2 HCs (each process is 32-bit, ~1–2 GB).

---

## 2. Install the game

1. Install Steam. Log in with an account that owns **Arma 2** and **Arma 2: Operation
   Arrowhead** (Combined Ops content is required — the mission uses base-A2 classes).
2. Install both games. Default path assumed below:
   `C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead` (referred to
   as `<OA>`), with base Arma 2 alongside it.
3. Verify `<OA>\arma2oaserver.exe` exists and is version **1.64.144629** (final patch).
4. The `-mod` line must include the **base Arma 2 install path** — without it the server
   fails with class errors (e.g. `requires CATracked2_AAV`).

**ACR DLC warning:** never load `ACR` in the *server's* `-mod` line — full ACR terrain PBOs
crash `arma2oaserver.exe`. The headless clients DO load `ACR` (see §6). This asymmetric
mount is deliberate and documented in `server-config/README.md`.

---

## 3. Install the mods

Into `<OA>`:

- **`@CBA_CO`** — Community Base Addons for Combined Ops. Publicly available (Armaholic
  mirrors / Steam Workshop archives). Must be **first** in the `-mod` chain (XEH init order).
- **`@adwasp`** — private WASP bundle; contains ASR AI (A2 build) and WASP addon content.
  Copy the whole folder from an existing WASP server. Also copy
  `<OA>\userconfig\asr_ai\asr_ai_settings.hpp` (ASR AI fails to load without it:
  `Include file ... not found`).
- **`@admkswf`** — private Miksuu's-Warfare bundle. Copy from an existing box.

`server-config/provision/03-Sync-GameFiles.ps1` automates copying the game install + both
private mod folders + `C:\WASP\` from an existing box over SSH — use it if you have access
to the old host; otherwise obtain the folders as an archive from the current server admin.

Because `verifySignatures = 0` on the reference config, missing `.bikey`s for the private
mods do not matter. If you harden signatures later (§10), you must first obtain/install the
publisher keys into `<OA>\Keys\`.

---

## 4. Server files and configuration

All server-side config lives in one directory, conventionally `C:\WASP\`. The reference
copies are versioned in this repo under **`server-config/`** — copy them to the box:

| Repo file | Box destination |
|---|---|
| `server-config/server-pr8.cfg` | `C:\WASP\profiles-pr8\server-pr8.cfg` |
| `server-config/basic.cfg` | `C:\WASP\profiles-pr8\basic.cfg` |
| `server-config/provision/server_launch.cmd` | `C:\WASP\server_launch.cmd` |
| `server-config/hc_launch.cmd` … `hc4_launch.cmd` | `C:\WASP\hc*.cmd` |

### server-pr8.cfg — the load-bearing fields

```
hostname = "Miksuu's Warfare | CTI | TvT | PvE | discord.me/warfare";
passwordAdmin = "<set on the box, never commit>";
maxPlayers = 58;
persistent = 1;          // mission keeps running with 0 players (HCs hold it)
BattlEye = 0;            // see §10 before changing
kickDuplicate = 0;
verifySignatures = 0;
headlessClients[] = {"127.0.0.1"};
localClient[] = {"127.0.0.1"};

class Missions
{
    class WASP
    {
        template = "[55-2hc]warfarev2_073v48co_<BUILDTAG>.chernarus";  // exact PBO name minus .pbo
        difficulty = "Veteran";   // WASP always runs Veteran
    };
};
```

- `template =` must exactly match the PBO filename in `<OA>\MPMissions\` (without `.pbo`).
- Only the **first** `class Missions` stanza matters for the active map.
- With `persistent = 1` + a `class Missions` entry the mission auto-starts at server boot.
- **Gotcha:** `-config="C:\path\file.cfg"` with quotes *inside* the value can make the 1.64
  engine treat quotes as part of the filename and silently fall back to ALL defaults
  (detectable via A2S showing `maxPlayers = 64` engine default). Keep paths space-free
  (`C:\WASP\...`) and unquoted where possible.

### basic.cfg — network tuning

```
MaxSizeGuaranteed=512
MaxMsgSend=512
MaxSizeNonguaranteed=512
MinBandwidth=131072
MaxBandwidth=104857600
MinErrorToSend=0.0049999999
MinErrorToSendNear=0.029999999
MaxCustomFileSize=0
```

Do **not** raise `MaxSizeGuaranteed` back to 1024 — it caused permanent black-screen
"Receiving mission" JIP fragmentation. Do not run without `-cfg` at all — engine defaults
make Warfare JIP crawl.

---

## 5. Launch parameters

Server (`server_launch.cmd`):

```
arma2oaserver.exe -port=2302 -config=C:\WASP\profiles-pr8\server-pr8.cfg -cfg=C:\WASP\profiles-pr8\basic.cfg -profiles=C:\WASP\profiles-pr8 "-mod=C:\Program Files (x86)\Steam\steamapps\common\Arma 2;expansion;@CBA_CO;@adwasp;@admkswf" -world=empty -malloc=mimalloc
```

- `-malloc=mimalloc` (server) / `-malloc=tbb4malloc_bi` (HCs): the allocator DLLs must be
  present in `<OA>\Dll\`. mimalloc is confirmed working on 1.64 and is the stability pick.
- If the server throws `Server creation failed : 2302` on a fresh headless build, bisect by
  removing `-profiles`/`-name` — some headless Windows builds can't complete the profile
  video context. The RPT then falls back to `%LOCALAPPDATA%\ArmA 2 OA\arma2oaserver.RPT`.
- Run the server as a **service** (NSSM wrapper) or scheduled task for unattended
  operation. If using NSSM, set AppExit to *Restart* (not Exit) if you want crash
  auto-recovery — an Exit policy leaves the server down after any crash.

Firewall: open **UDP 2302–2306** inbound (game + Steam query ports). Steam master-server
registration is outbound and needs no port forwarding.

---

## 6. Headless clients (AI offload)

The mission has dedicated CIV headless-client slots (`forceHeadlessClient = 1`). AI town
defense and AICOM combat teams run on the HCs — a server without HCs runs but pushes all AI
onto the server thread (much lower FPS at scale).

Per HC:

```
ArmA2OA.exe -client -connect=127.0.0.1 -port=2302 -window -cfg=C:\WASP\hc-profile\hc-video.cfg "-mod=C:\Program Files (x86)\Steam\steamapps\common\Arma 2;expansion;ACR;@CBA_CO;@adwasp;@admkswf" -name=HC-AI-Control-1 -exThreads=3 -cpuCount=2 -malloc=tbb4malloc_bi -maxMem=2047 -world=empty -nosplash -noPause -noSound
```

Key facts (the ones that cost real debugging time — full detail in
`server-config/provision/README.md` and `docs/ops/SERVER-STARTUP-ROTATION.md`):

- **`@adwasp` must be on the HC mod line too** — AI teams are HC-local; a server-only ASR
  AI mount gives the AI vanilla behavior.
- **HCs load `ACR`; the server does not** (see §2).
- Each HC is a full game client and needs a **logged-in Steam session**. Steam allows one
  game session per account per machine, so HC2+ each need their **own Steam account**
  (owning A2 CO) running inside a **Sandboxie-Plus** box (`04-New-SandboxieBoxes.ps1`
  creates the boxes; `Login-Steams.cmd` does the one-time interactive logins).
- HCs need an **interactive desktop session** (RDP console). A Session-0 service launch
  starts the process but it never seats into the AI-control system.
- **Start order**: server first, wait ~40 s, then HC1, then HC2… HC1's launcher begins with
  `taskkill /f /im ArmA2OA.exe`, so starting HC1 late kills the others.
- Do **not** pass `-profiles` to a HC without a real `.ArmA2OAProfile` in it — the server
  drops the HC ~25 s after every mission start (endless connect/disconnect loop that looks
  fine in the lobby).
- Health check: a seated HC sits at ~400 MB+ RAM with real CPU time; an unseated one idles
  at ~150 MB / near-zero CPU. In the RPT, look for
  `Headless client is now connected ... ("HC-AI-Control-N")` and per-minute
  `HCSTAT|v1|...` heartbeats from each HC.

The scripted end-to-end bring-up for a new box is `server-config/provision/` steps 0–7
(`00-Bootstrap-SSH.ps1` → `01-Base-OS.ps1` → `02-Install-Apps.ps1` → `03-Sync-GameFiles.ps1`
→ `04-New-SandboxieBoxes.ps1` → `Login-Steams.cmd` → `Start-Wasp-4HC.ps1` → `Verify-4HC.ps1`).

---

## 7. Mission PBO — build and deploy

Either take a released PBO from the current host's `MPMissions\`, or build from source:

```powershell
# 1. Mirror Chernarus source to Takistan/Zargabad (requires .NET 8 SDK)
cd Tools\LoadoutManager
dotnet run -c RELEASE

# 2. Pack (pure Python, no external PBO tools)
python Tools\Pack\pack_pbo.py --source "Missions\[55-2hc]warfarev2_073v48co.chernarus" `
  --output "[55-2hc]warfarev2_073v48co_<BUILDTAG>.chernarus.pbo" --build-tag <BUILDTAG> --strict-version
```

- **`version.sqf` is generated and gitignored.** `description.ext` includes it, so a mission
  folder fresh from git will not pack/run without one — generate it from
  `version.sqf.template` (the packer can fall back to the template; `--strict-version`
  refuses that for real deploys). In a production `version.sqf`, `WF_DEBUG` and
  `WF_LOG_CONTENT` must stay **commented out** — `WF_DEBUG 1` is the dev profile (900k
  funds, cheat menu, 5 s respawn).
- Copy the PBO to `<OA>\MPMissions\` and point `template =` at it (§4). Keep only one map's
  PBO in `MPMissions\` at a time; the reference setup parks the other maps and swaps on
  rotation (`docs/ops/SERVER-STARTUP-ROTATION.md`).
- Full deploy automation (pack → archive old → copy → repoint cfg → restart → verify →
  rollback): `Tools/Ops/Deploy-Wasp.ps1`, documented in `docs/ops/DEPLOY-PIPELINE.md`.

---

## 8. AntiStack + database configuration (the "SQL" part)

**What it is.** AntiStack (`Server/Module/AntiStack/` in the mission) persists per-player
score and playtime across sessions, keyed by Steam UID, and uses it to detect/compensate
team skill-stacking. Persistence goes through a native extension the mission calls as
`"A2WaspDatabase" callExtension ...`.

> **Full guide:** `docs/ops/ANTISTACK-INSTALL.md` is the complete standalone version of
> this section — full wire-protocol spec, reference SQL schema + DDL, database engine
> setup, replacement-DLL build guidance, and verification. Use it if the current host
> will not provide the original DLL/database. This section stays as the summary.

**What is and is not in this codebase:**

- **In the repo:** the complete mission-side module — every call site, the wire protocol,
  and the enable/disable switch. The full extension interface is specified in the appendix
  below, so the extension can be re-implemented if needed.
- **NOT in the repo:** `A2WaspDatabase.dll` itself, its configuration file(s), and its SQL
  backend. It is a closed binary that has only ever lived on the production host. There is
  no source, no schema dump, and no connection-string template in the codebase.

### Installing it on a new box

You need three things **from the current host** (this is the ask for whoever runs the
current server):

1. **`A2WaspDatabase.dll`** — sits next to `arma2oaserver.exe` in `<OA>\` (Arma resolves
   `callExtension` names against DLLs in the server root/mod dirs). Copy it to the same
   location on the new box.
2. **Any config file(s) beside it** — whatever the DLL reads for its DB connection
   (`.ini`/`.cfg`/`.xml` in `<OA>\` or `C:\WASP\`). Grab everything non-game-file in those
   directories that mentions "wasp", "database", or a connection string.
3. **The database itself** — a dump of the backing store (if it's MySQL/MariaDB/SQLite,
   export it; if it's a flat file, copy it). Then install the same DB engine on the new box
   (or its backup), restore the dump, and update the connection config from step 2.

Because the DLL is closed, the exact engine/config format can only be confirmed by
inspecting the current host. Treat "DLL + adjacent config + data dump" as the complete
transfer set.

**32-bit note:** `arma2oaserver.exe` is 32-bit — the extension DLL is x86 and any DB client
libraries it depends on must be present in x86 form (typically a Visual C++ x86 runtime).

### Running WITHOUT the database (fallback — works today)

The mission runs fine with no `A2WaspDatabase.dll` at all:

- Every call site guards the absent-extension case (empty `callExtension` response) and
  returns a neutral sentinel — no crashes, no script errors, just no cross-session
  score/skill persistence.
- To disable AntiStack cleanly, set the lobby parameter **`WFBE_C_ANTISTACK_ENABLED = 0`**
  (default 1; defined in `Rsc/Parameters.hpp` / `Common/Init/Init_CommonConstants.sqf`).
  All AntiStack loops then exit at start and every DB helper becomes a no-op.

So a new box can go live immediately and add the database later.

### Appendix — A2WaspDatabase extension interface (for re-implementation)

All calls: `"A2WaspDatabase" callExtension "<code>,<params>"`. Responses are SQF-parsable
strings (the mission runs `call compile` on them) — valid SQF array literals whose first
element is the response code. Long-running queries are **asynchronous**: the initial call
returns a request ID, which the mission polls with a separate procedure code (505: every
0.10 s, up to 120 attempts; 707: every 3 s, up to 9 attempts).

| Code | Name (mission side) | Request params | Response |
|---|---|---|---|
| 101 | RETRIEVE (player stats) | `uid` | `[code, requestID]` → poll with 505 |
| 505 | TRY_RETRIEVE (poll for 101) | `requestID` | `[code, totalScore, ticksPlayed]` (flat, 3 elements); code < 0 = pending |
| 202 | STORE (score delta) | `uid,scoreDiff` | `[1, ...]` on success |
| 404 | STORE_SIDE | `uid,side` (side: 0 = NONE — sent on disconnect, 1 = WEST, 2 = EAST) | `[1, ...]` |
| 303 | SEND_PLAYERLIST | `uid,side,uid,side,...` (flat CSV; empty list arrives as `303,`) | `[1, ...]` |
| 808 | FLUSH_PLAYERLIST | *(none — code only)* | `[1, ...]` |
| 606 | REQUEST_SIDE_SKILL | `side` (1/2) | `[code, requestID]` → poll with 707 |
| 707 | TRY_RETRIEVE (poll for 606) | `requestID` | `[code, totalSkill]`; code < 0 = pending |
| 909 | SET_MAP | `mapId` (0 = none/match end, 1 = Chernarus/other, 2 = Takistan, 3 = Zargabad) | `[1, ...]` |

Stored data per player is minimal: **UID → (totalScore, ticksPlayed, side)**. The
score-flush loop (`mainLoop.sqf`) runs every main-loop interval per connected human player:
RETRIEVE previous totals → compute session score delta → STORE the delta. A
re-implementation (e.g. a small C# x86 DLL over SQLite or MySQL) only needs the table
`players(uid PRIMARY KEY, total_score, ticks_played, side)` plus a session/map log if 909
data is wanted, and the async request-ID handshake above.

---

## 9. Optional: match-status extension (`a2waspwarfare_Extension`)

Separate from AntiStack. Buildable from `Extension/` in this repo (.NET Framework 4.8 class
library with DllExport; build manually and copy the resulting
**`a2waspwarfare_Extension.dll`** next to `arma2oaserver.exe`). Every 60 s the mission
pushes match status (side scores, map, uptime, player count) and the DLL writes
`C:\a2waspwarfare\Data\database.json` (paths are hardcoded in the extension; directories
are auto-created). This JSON feeds Discord status bots / websites. If the DLL is absent the
`callExtension` call is a silent no-op — fully optional.

---

## 10. BattlEye / anti-cheat

Reference config runs `BattlEye = 0` because the BE handshake kicks co-located headless
clients ("Player without identity" loop). Note: on 1.64, `BattlEye = 0;` in server.cfg
alone is **not** honored — to truly disable BE, rename both `<OA>\BattlEye` and
`<OA>\Expansion\BattlEye` to `BattlEye.disabled`.

For a hardened public deployment (per `server-config/README.md`):

- Restore `verifySignatures = 2` (requires publisher keys for `@adwasp`/`@admkswf` in
  `<OA>\Keys\`), `BattlEye = 1`.
- Deploy the filter files from `BattlEyeFilter/` (`publicvariable.txt`, `scripts.txt`) into
  the server's BE path; workflow in `BattlEyeFilter/README-anticheat.md`: run log-only
  first on a populated session, whitelist the legitimate traffic, then arm kick actions.
- Solve HC-vs-BE either by exempting localhost or running HCs on a machine/config where
  BEClient initializes; otherwise HCs and BE are mutually exclusive on this build.

---

## 11. First-boot verification checklist

1. Server process up, RPT (`C:\WASP\profiles-pr8\*.RPT` or
   `%LOCALAPPDATA%\ArmA 2 OA\arma2oaserver.RPT`) actively growing past
   `Initializing Steam server - Game Port: 2302` → `Connected to Steam servers` and into
   mission load (`MISSINIT`). An RPT frozen right after the Steam lines = dead boot.
2. A2S query (Steam server browser / BattleMetrics) shows the configured hostname and
   `maxPlayers` from server-pr8.cfg — engine-default `64` means the cfg was NOT parsed
   (see the `-config` quoting gotcha, §4).
3. Each HC: `Headless client is now connected` in the server RPT + `HCSTAT|v1|` heartbeats;
   process RAM ~400 MB+ (not stuck at ~150 MB).
4. Errors: scan the RPT for `[WFBE (ERROR)]` / `Error in expression` — anchored patterns
   only (a plain `Error:` substring appears in normal info lines). Boot-window town-init
   races that stop within the first few hundred lines are normal.
5. AntiStack: with the DLL installed, RPT shows
   `CallDatabaseRetrieve.sqf: Called database ... RESPONSE (REQUEST ID) IS: [...]` with real
   IDs; without it, either silence (parameter off) or harmless sentinel fallbacks. These
   lines only print when content logging is active (`WF_LOG_CONTENT` in `version.sqf` —
   see `ANTISTACK-INSTALL.md` §9).
6. Join with a real client, take a town, disconnect, restart the mission, rejoin — with the
   DB active your score total persists.

---

## 12. Backup-server pattern

For a hot-spare (e.g. a second machine kept as fallback):

- Mirror the full install: game + mods + `C:\WASP\` + `MPMissions\` + extensions + DB dump.
  Steps 3–7 of `server-config/provision/` do exactly this from the primary.
- Keep the backup's server **stopped** while the primary is live. Never run both against
  the same remote SQL database with AntiStack active, and remember each running HC needs
  its own Steam account — the same accounts cannot be logged in on both machines at once.
- On failover: restore the latest DB dump (if the DB was primary-local), start server, then
  HC1 → HC2, and point players at the new IP (or swap DNS).
- Re-sync `MPMissions\` + `server-pr8.cfg` from the primary whenever a new build deploys —
  a stale backup boots an old mission version.

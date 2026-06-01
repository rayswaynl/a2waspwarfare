# Deep-Review Findings

> Claude adversarial-review log (source-cited). This page records findings from independent verification passes against the Chernarus source mission, cross-checking the [SQF code atlas](SQF-Code-Atlas), [Gameplay systems atlas](Gameplay-Systems-Atlas) and other pages. Each finding is confirmed against `path:line`, given a severity, and paired with a remediation playbook. It complements (does not replace) Codex's atlas pages and the [Feature status register](Feature-Status-Register).

All paths are relative to the source mission root `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Arma 2 OA 1.64 — not Arma 3.

## Round 2 — 2026-06-01 (Claude)

### DR-1 — PV dispatch is a server-side `Call Compile` trust boundary (SECURITY / hardening) — **High**

**What.** The PVF dispatch executes a string taken directly from the *value a remote machine broadcast*, with no validation that it names a known command.

- `Server/Functions/Server_HandlePVF.sqf`: `_script = _publicVar select 0; _parameters Spawn (Call Compile _script);`
- `Client/Functions/Client_HandlePVF.sqf`: same pattern on `_publicVar select 1`.
- The handlers are bound in `Common/Init/Init_PublicVariables.sqf` as `WFBE_PVF_<Command> addPublicVariableEventHandler { (_this select 1) Spawn WFBE_SE_FNC_HandlePVF }`. `_this select 1` is the **new value chosen by the sender**.
- Clients legitimately reach the server channel via `Common/Functions/Common_SendToServerOptimized.sqf:15` → `publicVariableServer 'WFBE_PVF_<cmd>'`.

The legitimate flow always sets index 0 to the bare identifier `"SRVFNC<Command>"`, so `Call Compile` resolves a function-variable lookup. But nothing constrains the value to that shape: a crafted broadcast on a registered `WFBE_PVF_*` channel whose `select 0` is arbitrary SQF text would be compiled and run on the receiver. This is the well-known Arma 2 *publicVariable* trust-boundary problem.

**Why the usual mitigations are absent here.**
- **No server-side validation.** `Server_HandlePVF.sqf` does not check that `_script` begins with `SRVFNC` or is in the registered command set (confirmed: no `SRVFNC`/`CLTFNC` guard in either handler).
- **No BattlEye filtering.** `BattlEyeFilter/publicvariable.txt` contains a single rule, `5 "kickAFK"`. That rule *is the AFK-kick feature* (the mission cannot kick directly, so it broadcasts `kickAFK` and relies on BattlEye to kick the sender — see [Networking and public variables](Networking-And-Public-Variables)). It is **not** a security filter: there is no restrictive default line and no whitelist of the `WFBE_PVF_*` channels with value constraints.

**Severity rationale.** This is a live-server hardening gap, not a mission-logic bug. It matters for any publicly-listed server (the README advertises one). It is recorded here as defensive guidance for the server owner.

**Remediation playbook (cheapest first):**
1. **Validate before compile (server-side, no BE knowledge needed).** In `Server_HandlePVF.sqf`, reject any `_script` not in the known set, e.g. build a lookup of `"SRVFNC"+cmd` for every registered command at init and `exitWith` (with a `WARNING` log) if `_script` is not a member. Same idea for `Client_HandlePVF.sqf` against `CLTFNC*`. This neutralizes arbitrary-string compilation while preserving all legitimate traffic.
2. **Add a real BattlEye `publicvariable.txt`** as defense-in-depth: a restrictive default plus an explicit allow-list of `WFBE_PVF_*`, the direct channels in the [SQF code atlas](SQF-Code-Atlas) "Direct Public Variable Channels" table, and the existing `kickAFK` rule. Do not add a blanket restrictive default *without* the allow-list, or you will break all PVF traffic.
3. Prefer `publicVariableClient`/`publicVariableServer` (targeted) over broadcast for owner-directed messages to shrink the surface (already mostly done).

### DR-2 — Paratrooper drop map markers are dead (abandoned/half-implemented) — **Medium**

`Server/Support/Support_Paratroopers.sqf:117` sends the marker:
```sqf
[leader _playerTeam, "HandleParatrooperMarkerCreation", [_x, _sideID]] Call WFBE_CO_FNC_SendToClient;
```
`Common/Functions/Common_SendToClient.sqf` turns that into `WFBE_PVF_HandleParatrooperMarkerCreation` (dedicated path) / `CLTFNCHandleParatrooperMarkerCreation` (hosted path). But:

- `HandleParatrooperMarkerCreation` is **not** in the `_clientCommandPV` list in `Common/Init/Init_PublicVariables.sqf`, so `WFBE_PVF_HandleParatrooperMarkerCreation` has **no** `addPublicVariableEventHandler`, and `CLTFNCHandleParatrooperMarkerCreation` is **never compiled** (confirmed: no reference in any `Init_*`).

**Result:** on a dedicated server the marker PV is broadcast but never handled; on a hosted/SP server `Spawn (Call Compile "CLTFNCHandleParatrooperMarkerCreation")` resolves to nil → no marker (and a likely script error). The send side exists; the receive side was never wired. This upgrades the atlas note ("exists but not registered") to a confirmed broken feature. **Fix:** add `HandleParatrooperMarkerCreation` to `_clientCommandPV` (the receiver file `Client/PVFunctions/HandleParatrooperMarkerCreation.sqf` already exists), or remove the dead send.

### DR-3 — MASH tent map markers are dead on the receive side (abandoned/half-implemented) — **Medium**

MASH markers use a two-hop relay:
1. Client deploys tent → `WFBE_CL_MASH_MARKER_CREATED` → server EH in `Server/Module/MASH/MASHMarker.sqf:1` (registered) re-broadcasts `WFBE_SE_MASH_MARKER_SENT`.
2. The client EH that should consume `WFBE_SE_MASH_MARKER_SENT` lives in `Client/Module/MASH/receiverMASHmarker.sqf:1` — but its **only** reference is the commented compile at `Client/Init/Init_Client.sqf:132`:
   ```sqf
   //WFBE_CL_FNC_ReceiverMASHmarker = Call Compile preprocessFileLineNumbers "Client\Module\MASH\receiverMASHmarker.sqf";
   ```

**Result:** no client ever registers the `WFBE_SE_MASH_MARKER_SENT` handler, so **MASH map markers never appear**. (MASH *respawn* itself is independent and may work; only the map marker is dead.) This resolves the atlas's "client receiver currently not clearly active / requires verification." **Fix:** uncomment/restore the receiver registration in client init, or drop the dead server re-broadcast.

### DR-4 — Generated-mission drift: Takistan is in sync; the skip-list is a silent-divergence trap; modded maps are abandoned (generated-mission drift) — **Medium**

A full recursive diff of `Missions/[55-2hc]…chernarus` vs `Missions_Vanilla/[61-2hc]…takistan` shows **every** difference is exactly a LoadoutManager skip-listed file or blacklisted directory — there is **no accidental drift** between the two at this commit:

- Differing files: `mission.sqm`, `version.sqf` (git-ignored), `Client/GUI/GUI_Menu_Help.sqf`, `WASP/unsort/StartVeh.sqf`, `loadScreen.jpg`, `texHeaders.bin`, `Server/Init/Init_Server.sqf` (the `SET_MAP 1→2` patch), and the blacklisted `Common/Config/Core_Artillery/*` + `Server/Config/*` + `Textures/*`.

This is *more reassuring but also more dangerous* than the "generated missions can drift" framing elsewhere. The precise hazard is the **skip-list**, defined in `Tools/LoadoutManager` `FileManagement/FileManager.cs` (`ShouldSkipFile` + the `co.takistan` directory blacklist):

> A gameplay edit made in Chernarus to any **skip-listed** file — `mission.sqm`, `GUI_Menu_Help.sqf`, `StartVeh.sqf`, anything under `Core_Artillery/`, `Server/Config/`, or `Textures/` — **will never propagate** to Takistan via `dotnet run`. These must be hand-mirrored in both missions.

So the standard guidance "edit Chernarus + run LoadoutManager" is **incomplete**: it is correct for the ~95% of files that are copied, and silently wrong for the skip-listed set. See the expanded propagation guidance in [Tools and build workflow](Tools-And-Build-Workflow).

**Modded maps are abandoned/stale.** Because modded propagation is commented out at `Tools/LoadoutManager` `SqfFileGenerators/SqfFileGenerator.cs:132`, the `Modded_Missions/*` trees are far behind Chernarus (787 files):

| Modded mission | File count | State |
| --- | ---: | --- |
| `…Napf` | 507 | ~280 files behind |
| `…eden` | 502 | ~285 behind |
| `…lingor` | 438 | ~349 behind |
| `…dingor` | 20 | stub |
| `…smd_sahrani_a2` | 4 | stub |
| `…tavi` | 3 | stub |
| `…isladuala` | 1 | stub |

None are deployable as-is; they would need full regeneration after the modded path is re-enabled. Treat `Modded_Missions/*` as non-authoritative.

### DR-5 — Frozen metric counts drift; make them reproducible (docs too confident) — **Low**

The [SQF code atlas](SQF-Code-Atlas) states "659 `preprocessFile` references (452 `preprocessFileLineNumbers` + 207 plain)". An independent recount on the `docs/developer-wiki-index` base yields **678 total / 465 `preprocessFileLineNumbers` / 213 plain**. The gap is small and likely reflects counting method (comment handling) or branch timing — not an error — but hardcoded counts rot as the mission changes. **Recommendation:** present such counts as point-in-time and ship the regeneration command so future agents verify rather than trust, e.g. (PowerShell, from the mission root):
```powershell
(Get-ChildItem -Recurse -Filter *.sqf | Select-String -SimpleMatch 'preprocessFileLineNumbers').Count
```
**Verified-accurate cross-checks (for trust calibration):** the atlas's FSM inventory is correct — exactly three `.fsm` files exist (`Client/FSM/updateactions.fsm`, `Client/FSM/updateavailableactions.fsm`, `Client/kb/hq.fsm`); and `HandleParatrooperMarkerCreation` / `AttackWave` / `LogGameEnd` are indeed outside the standard PVF list as the atlas notes.

---

### Open items handed to Codex / code owners

- Decide fix-vs-remove for DR-2 (paratrooper markers) and DR-3 (MASH markers); both are one-line wiring changes in the Chernarus source.
- DR-1 server-side validation is a small, safe gameplay-code change (Chernarus `Server_HandlePVF.sqf`) — gate behind review since it touches the network hot path.
- Re-confirm DR-4 modded-map decision: regenerate or formally retire `Modded_Missions/*`.

## Round 3 — 2026-06-01 (Claude) — PVF hardening implementation playbook

Lane `pvf-hardening-review`. This turns DR-1 into a concrete, **behavior-preserving** change set a code owner can apply to the Chernarus source. Every claim below was re-verified against source on this pass. Paths relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

### Why the dispatch never actually needs `Call Compile`

The dispatch targets are already-compiled **global variables**, created at registration in `Common/Init/Init_PublicVariables.sqf:44,49`:

```sqf
Call Compile Format["CLTFNC%1 = compile preprocessFileLineNumbers 'Client\PVFunctions\%1.sqf'", _x];   // :44
Call Compile Format["SRVFNC%1 = compile preprocessFileLineNumbers 'Server\PVFunctions\%1.sqf'", _x];   // :49
```

So `SRVFNCRequestJoin`, `CLTFNCTownCaptured`, … are `missionNamespace` variables holding `code`. The dispatch line `Spawn (Call Compile _script)` only compiles the *string* `_script` to perform a variable lookup. That means the same resolution can be done with `getVariable`, which treats `_script` purely as a name and **cannot execute** an arbitrary SQF string a client injected.

### Fix 1 — Primary, behavior-preserving (closes arbitrary code execution)

Replace the compile-the-string dispatch with a name lookup that defaults to a no-op.

`Server/Functions/Server_HandlePVF.sqf` (current `_parameters Spawn (Call Compile _script);`):
```sqf
private _fn = missionNamespace getVariable [_script, {}];   // resolve SRVFNC<cmd>; unknown -> {}
if (_fn isEqualTo {}) exitWith {
    ["WARNING", format ["Server_HandlePVF: rejected unknown PVF command '%1' from network", _script]] Call WFBE_CO_FNC_LogContent;
};
_parameters Spawn _fn;
```
`Client/Functions/Client_HandlePVF.sqf` (current `_parameters Spawn (Call Compile _script);`): identical pattern resolving `CLTFNC<cmd>`.

Why this is safe and behavior-identical:
- Legitimate traffic sets `_script` to exactly `"SRVFNC"+cmd` / `"CLTFNC"+cmd` (see `Common/Functions/Common_SendToServerOptimized.sqf:15`, `Common/Functions/Common_SendToClient.sqf`), which resolves to the compiled function — unchanged.
- A hostile value such as `"hint 'x'; <server-side effect>"` is not a defined variable, so `getVariable` returns the default `{}` → `Spawn {}` → no-op (plus a WARNING that surfaces probing in the RPT). No `compile` ever runs on attacker text.
- `isEqualTo {}` is a valid Arma 2 OA `code` comparison; use it (not `isNil`) because the default is empty code, not nil.

### Fix 2 — Optional explicit allow-list (defense-in-depth + clarity)

At the end of `Init_PublicVariables.sqf`, snapshot the legal command set so the handler check is explicit rather than implicit:
```sqf
WFBE_SE_PVF_ALLOWED = _serverCommandPV apply {format ["SRVFNC%1", _x]};
WFBE_CL_PVF_ALLOWED = _clientCommandPV apply {format ["CLTFNC%1", _x]};
publicVariable "WFBE_SE_PVF_ALLOWED"; // optional; or keep server-local
```
Then guard with `if !(_script in WFBE_SE_PVF_ALLOWED) exitWith { ...log... };` before resolving. Fix 1 already covers the same cases; use Fix 2 only if you want a named, auditable whitelist.

### Fix 3 — BattlEye `publicvariable.txt` (defense-in-depth at the network edge)

The shipped `BattlEyeFilter/publicvariable.txt` is a single line, `5 "kickAFK"`, which is the **AFK-kick feature trigger**, not a security filter (see [Networking and public variables](Networking-And-Public-Variables) → Security). A hardened filter uses a restrictive default first line plus explicit allow exceptions:

```text
5 ""                                  // default: kick on any unlisted PV broadcast
!="^WFBE_PVF_[A-Za-z]+$"              // allow the dispatch channels
!="^wfbe_supply_temp_(west|east)$"    // allow the supply request channel
!="^(ATTACK_WAVE_INIT|CLIENT_INIT_READY|REQUEST_SUPPLY_VALUE|WFBE_CL_MASH_MARKER_CREATED|AFKthresholdExceededName|WFBE_C_PLAYER_OBJECT|WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH)$"
5 "kickAFK"                           // keep the AFK feature kick
```
> ⚠️ Validate the exact client→server channel list against the "Direct Public Variable Channels" table in the [SQF code atlas](SQF-Code-Atlas) before deploying — a too-strict default with a missing exception will kick legitimate players. BattlEye regex/escaping differs from SQF; test on a private server first. This complements, and does not replace, Fix 1 (BE filters the variable *name*, not the payload shape).

### Residual risk this playbook does NOT close (scope honesty)

Fix 1 stops arbitrary **code execution**, but the PVF model still **trusts client-sent commands and parameters**. A malicious client can broadcast a *legitimate* command with chosen arguments — e.g. `RequestChangeScore` (`Server/PVFunctions/RequestChangeScore.sqf` sets a player's score directly from the payload) or `RequestStructure` — because the server handlers largely don't authenticate the sender against the payload. Closing that is a larger, per-handler effort (validate that `owner`/sender matches the acting player, clamp economy/score deltas, range-check structure requests). Treat this as a separate follow-up lane, not part of the dispatch fix. Documented here so the dispatch fix isn't mistaken for full PVF authorization.

### Verification notes (this pass)

- No registered handler under `Server/PVFunctions/` or `Client/PVFunctions/`, nor `Server_HandleSpecial.sqf`/`HandleSpecial.sqf`/`LocalizeMessage.sqf`, calls `compile` on its parameters — so once the dispatch command name is resolved safely, there is no second-order injection on the PVF path. The other `call compile` sites in the mission compile **files** (`Init_Coin.sqf`, EASA/CM init) or local engine key-strings (`coin_interface.sqf:774-777`), not network data.
- Handoff: this is a Chernarus-source gameplay change → after applying, run `Tools/LoadoutManager` `dotnet run` to propagate (note `Server_HandlePVF`/`Client_HandlePVF` are not on the skip-list, so they propagate normally; `BattlEyeFilter/` lives outside the mission and is deployed with the server, not via LoadoutManager).

## Round 4 — 2026-06-01 (Claude) — construction PVF authority (DR-6)

Lane `construction-authority-review` (extends [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas), whose "Authority Boundary" section flags this risk generically; this finding adds per-handler forgery proof + a validation design). This is the concrete realization of the **command-forgery residual** scoped in Round 3 (Fix 1 closes code execution, not command forgery).

### DR-6 — Construction request handlers perform no sender/authority/resource validation — **High (gameplay integrity)**

All three construction PVF handlers derive trust from the **client-supplied payload** and never verify the requester. Source (verified this pass):

| Handler | Validation actually performed | Client-controlled inputs | Forgery impact |
| --- | --- | --- | --- |
| `Server/PVFunctions/RequestStructure.sqf` | Only: does `_structureType` exist in `WFBE_<side>STRUCTURENAMES`. | `_side` (`select 0`), class, pos, dir — **all from payload**. | Forge `["RequestStructure",[WEST,"US_WarfareBHeavyFactory_EP1",anyPos,dir]]` → server ExecVMs the construction script and builds a **free** factory anywhere for any side. No commander check, no funds debit, no placement/base-area/hostile-town checks (those are client-only, atlas "Placement Rules"). |
| `Server/PVFunctions/RequestDefense.sqf` | Only: does `_defenseType` exist in `WFBE_<side>DEFENSENAMES`. | `_side`, class, pos, dir, **`_manned`** — all from payload. | Forge unlimited **free** defenses — incl. AI-manned static weapons and minefields (`Sign_Danger`) — anywhere for any side, bypassing the base-area `avail` budget (decremented only client-side in `coin_interface.sqf:724-730`). |
| `Server/PVFunctions/RequestMHQRepair.sqf` | **None.** Body is `[_this] Spawn MHQRepair;`. | entire payload; `MHQRepair.sqf:3` uses `_side`. | `MHQRepair` rebuilds the side HQ from server state (`GetSideHQ`/`GetCommanderTeam`/position) with **no dead-HQ check, no commander check, and none of the repair count/price gating** that lives only client-side in `Action_RepairMHQ.sqf`. Forge `["RequestMHQRepair",[side]]` → free, unlimited HQ respawn/repair; can also fire while the HQ is alive. |

### Root cause (why "add a check" is non-trivial here)

1. **`_side` is taken from the payload, not derived from the sender.** A client can act on any side's behalf.
2. **The payloads don't even include the requesting player object**, so the handlers *cannot* identify or authorize the sender as written.
3. **Arma 2 OA `addPublicVariableEventHandler` provides no sender identity** — `_this` is `[varName, value]` only (unlike Arma 3 `remoteExecutedOwner`/`RE` ownership). So authority must be reconstructed: the payload must carry the player, and the server must validate that player's role/side/funds against **server-side** state. (This is also why DR-1's command-validation fix does not, by itself, stop forgery.)

### Validation playbook (behavior-preserving for legit CoIn UX)

Add the requesting player to each request and validate server-side before creating objects. Example for `RequestStructure` (mirror for `RequestDefense`; for `RequestMHQRepair` validate dead-HQ + commander + repair-count/price server-side):

```sqf
// client (coin_interface / Action_*): include the player in the payload
["RequestStructure", [player, sideJoined, _class, _pos, _dir]] Call WFBE_CO_FNC_SendToServer;

// server RequestStructure.sqf (new guards, then existing logic):
_player = _this select 0; _side = _this select 1; _structureType = _this select 2; ...
if (isNull _player) exitWith {};
if (side _player != _side) exitWith {};                                   // can't build for another side
if (_player != leader ((_side) call WFBE_CO_FNC_GetCommanderTeam)) exitWith {};  // commander-only
private _cost = /* look up WFBE_<side>STRUCTURECOSTS[index] */;
if ((_side call WFBE_CO_FNC_GetSideSupply) < _cost) exitWith {};          // server-authoritative funds
[_side, -_cost, "structure build", false] call WFBE_CO_FNC_ChangeSideSupply;  // debit on server
// ...then the existing class-exists lookup + ExecVM construction script
```

Notes:
- Keep the **client** cost-deduction/preview for instant UX, but make the **server** the final authority on debit and creation (atlas "Cost deduction" risk row agrees). Avoid double-debit by having the client send a *request* and the server be the source of truth (or reconcile on the server-confirmed message).
- Re-checking full placement/collision server-side is heavier; at minimum validate side+commander+funds+class (cheap, closes the worst abuse). Base-area `avail` should also be decremented/validated **server-side** to stop the unlimited-defense path (trace `RequestBaseArea` + `Construction_StationaryDefense` together, per the atlas, for JIP safety).
- This is gameplay-code; gate behind review (touches the build hot path) and run LoadoutManager after. `RequestStructure/Defense/MHQRepair.sqf` are not on the skip-list, so they propagate normally.

### Severity framing

Not a crash/RCE (that's DR-1). This is **gameplay-integrity / anti-grief**: on a public server, a modified client can mint free factories/defenses/HQs and bypass the economy. Pair with DR-1 (validate the command) — DR-1 stops *arbitrary code*, DR-6 stops *forged legitimate commands*; both are needed for a hardened public server.

## Round 5 — 2026-06-02 (Claude) — AntiStack DB extension trust (DR-7..DR-10)

Lane `antistack-db-trust`. The AntiStack module persists per-player score/side and team skill to an **external native extension** for team-balancing. Source: `Server/Module/AntiStack/callDatabase*.sqf` (7 `callExtension` sites) + the `A2WaspDatabase` DLL, which is **not in this repo** (only the in-repo `Extension/` GLOBALGAMESTATS DLL is — see [External integrations](External-Integrations)). All claims verified this pass.

### DR-7 — The server `call compile`s the extension's return value on every call — **High (external trust boundary)**

Every one of the seven handlers does, in effect:
```sqf
_response = "A2WaspDatabase" callExtension format ["%1,%2", _procedureCode, _parameters];
_response = call compile _response;          // <-- executes the DLL's stdout as SQF
_responseCode = _response select 0;
```
(`callDatabaseStore.sqf`, `callDatabaseRetrieve.sqf` ×2 incl. the 505 poll, `callDatabaseSendPlayerList.sqf`, `callDatabaseRequestSideTotalSkill.sqf` ×2, `callDatabaseSetMap.sqf`, `callDatabaseStoreSide.sqf`, `callDatabaseFlushPlayerList.sqf`.)

`callExtension` returns a **string from a native DLL**, and the mission compiles+executes it. The server therefore **fully trusts the `A2WaspDatabase` process's stdout as code.** Why this matters:
- **Compromise/replacement/bug → server RCE.** Any DLL that returns SQF other than the expected numeric array literal runs on the server. The DLL is third-party and absent from the repo, so its behaviour can't be audited here.
- **Malformed/empty return → error cascade.** If the DB is down/slow/encoding-broken, `callExtension` returns `""` → `call compile ""` is `nil` → `nil select 0` throws. Several handlers only guard `typeName _responseCode == "SCALAR"` *after* the `select 0`, so the select can throw first.
- **Echo-to-code latent risk.** Only UID/score/side/map round-trip today (all constrained, low risk). But the pattern means *any* future free-text field persisted and echoed back becomes executable.

**Engine caveat (why the pattern exists):** Arma 2 OA 1.64 has **no `parseSimpleArray`** (that is Arma 3), so `call compile` is the idiomatic string→array path for extensions. The A2-correct hardening is defensive validation, not a parser swap:
1. Guard the raw string first: `if (isNil "_response" || {_response isEqualTo ""}) exitWith { /* neutral fallback + WARNING */ };`
2. Compile, then **shape-check before use**: `_response = call compile _response; if (typeName _response != "ARRAY") exitWith {...}; if ({ typeName _x != "SCALAR" } count _response > 0) exitWith {...};`
3. Only then read `_response select 0/1/2`. This keeps the DLL contract (numeric arrays) but refuses to execute anything that isn't one.

### DR-8 — Blocking DB poll on the join / skill-balance path — **Medium (availability/JIP)**

`callDatabaseRetrieve.sqf` polls the 505 procedure up to **120 × 0.10s ≈ 12s**; `callDatabaseRequestSideTotalSkill.sqf` polls 707 up to **9 × 3s = 27s**. These feed player-connect stat retrieval and team-skill balancing (called from `mainLoop.sqf`, `getTeamScoreMonitor.sqf`, `Init_Server.sqf`). They run in spawned scripts so the server tick survives, but a slow/down DB stalls join/balance up to those windows before falling back to neutral (`[1,1]` / `0`). Recommend a shorter ceiling + a circuit-breaker that flips `WFBE_C_ANTISTACK_ENABLED` off after N consecutive timeouts.

### DR-9 — `callExtension` length limits vs full-roster SEND_PLAYERLIST — **Medium (scale)**

`callDatabaseSendPlayerList.sqf` packs **every** player's `guid,side` pair into a single `callExtension` input string (`g1,1,g2,2,…`). Arma 2 OA `callExtension` has input/output length limits (output historically ~10 KB); a 55-slot roster can produce a long argument and an even longer response, risking truncation → `call compile` of a truncated array literal → parse error (compounding DR-7). Recommend chunking the player list across multiple calls and validating each response shape.

### DR-10 — AntiStack defaults ON against a DLL that isn't in the repo — **Medium (ops)**

`WFBE_C_ANTISTACK_ENABLED` defaults to **1** (`Init_CommonConstants.sqf:171`), and the `A2WaspDatabase` DLL is an undocumented external runtime dependency absent from the repo. Any server/dev instance lacking the DLL gets `callExtension`→`""`→`call compile`→error per call unless the param is set to 0. Marty added per-call `if (… == 0) exitWith` disable guards (good), but the **default is on**. Recommend: document the external dependency in [External integrations](External-Integrations), and consider detecting DLL presence (a cheap PING procedure) to auto-disable rather than error.

### Handoff

Code owners: apply DR-7 defensive validation (guard empty + shape-check before reading) to all seven `callDatabase*.sqf`; add a circuit-breaker (DR-8); chunk SEND_PLAYERLIST (DR-9); document/auto-detect the external DLL (DR-10). Codex: the `A2WaspDatabase` external dependency + `call compile` trust contract should be called out in the [External integrations](External-Integrations) page (its lane). Ledger: Integrations Auth/PV cells advanced from ⬜ to 🟡 (AntiStack covered; Extension/Discord/BattlEye still pending).

## Continue Reading

Previous: [Agent worklog](Agent-Worklog) | Next: [Implementation plan](Documentation-Implementation-Plan)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

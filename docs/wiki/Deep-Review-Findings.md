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

## Round 6 — 2026-06-02 (Claude) — victory / endgame (DR-11..DR-13)

Lane `victory-endgame-review`. Source: `Server/FSM/server_victory_threeway.sqf` (the **only** script that sets `gameOver`/`WFBE_GameOver`/`failMission` — verified by grep across `Server/`), `Server/Functions/Server_LogGameEnd.sqf`, `Server/PVFunctions/LogGameEnd.sqf`, `Common/Init/Init_CommonConstants.sqf:401`.

### DR-11 — Endgame reports the winner inconsistently; persisted win-tally is wrong for the all-towns win — **Medium-High (correctness, persistent side effect)**

The trigger merges a *lose* test and a *win* test into one condition and then handles both identically:
```sqf
if (!(alive _hq) && _factories == 0 || _towns == _total && !WFBE_GameOver) then {
    [nil,"HandleSpecial",["endgame",(_x) Call WFBE_CO_FNC_GetSideID]] Call WFBE_CO_FNC_SendToClients;
    WF_Logic setVariable ["WF_Winner", _x];
    gameOver = true; WFBE_GameOver = true;
    _side = west; if (_x == west) then {_side = east};
    [_side] call WFBE_CO_FNC_LogGameEnd;   // Server_LogGameEnd: _this select 0 == WINNER
}
```
SQF precedence (`&&` before `||`) parses this as `(!alive _hq && _factories==0) || (_towns==_total && !WFBE_GameOver)`:
- **Branch A** — `_x` HQ dead **and** no factories → `_x` is the **loser**. `LogGameEnd(_side = opposite of _x)` records the correct winner. ✓
- **Branch B** — `_x` holds **all** towns → `_x` is the **winner**. But `LogGameEnd` is still called with `_side` = *opposite of _x* → it records the **loser as the winner** in the persisted `%1_WIN_CHERNARUS` profileNamespace tally. ✗

Consequences:
- The win/loss statistics saved via `WFBE_CO_FNC_LogGameEnd` (→ `profileNamespace`, `saveProfileNamespace`) are **inverted for every all-towns victory**.
- `WF_Logic setVariable ["WF_Winner", _x]` is a **dead write** — `WF_Winner` has no reader anywhere in the mission (grep). So it can't compensate.
- The `endgame` client broadcast sends `_x`'s sideID to `WFBE_CL_FNC_EndGame` (`HandleSpecial.sqf:16`) for **both** opposite scenarios, so the player-facing outro shows the same side regardless of who actually won — at least one path is wrong. *(Follow-up: confirm whether EndGame treats the payload sideID as winner or loser.)*
- **Guard/precedence bug:** `!WFBE_GameOver` guards only the towns branch, and the `forEach` over sides has **no break** after setting `gameOver`. Branch A is unguarded, so if two sides both satisfy "HQ dead + no factories" in the same 80s tick, endgame fires **twice** (double `endgame` broadcast, double `SET_MAP`, double `LogGameEnd`). Fix: guard both branches with `!WFBE_GameOver` (or `exitWith` after the first winner) and split the win/lose logic so the winner is computed correctly per branch.

### DR-12 — "Threeway" victory mode has no detection — **Medium (broken/abandoned feature)**

`WFBE_C_VICTORY_THREEWAY` defaults to `0` (`Init_CommonConstants.sqf:401`, comment "0: Side a vs Side b [supremacy] minus defender"), and the detection block is gated `if (!gameOver && _victory == 0)`. Since `server_victory_threeway.sqf` is the **only** victory/`failMission` setter in `Server/`, selecting any non-zero `WFBE_C_VICTORY_THREEWAY` value disables victory detection entirely — **matches never auto-end** in the mode the file is named for. Either implement the threeway path or document the parameter as non-functional.

### DR-13 — Two divergent `LogGameEnd` implementations, one buggy — **Low (cleanup / latent)**

- `Server/Functions/Server_LogGameEnd.sqf` — clean; wired to `WFBE_CO_FNC_LogGameEnd` (compiled twice, `Init_Server.sqf:64` and `:89`).
- `Server/PVFunctions/LogGameEnd.sqf` — **buggy** duplicate: `profileNamespace setVariable [(profileNamespace getVariable format ["%1_WIN_CHERNARUS",_winnerTeam]), (...)]` uses a getVariable *result* as the setVariable *key*, and reads `profileNamespace getVariable WEST_WIN_CHERNARUS` (bare global, not the `"WEST_WIN_CHERNARUS"` string). If this variant is ever wired in, win-stat persistence silently corrupts. Recommend deleting the duplicate to prevent future mis-wiring.

### Handoff

Code owners: fix DR-11 (split win/lose branches, compute winner per branch, guard both branches / break the loop) — this corrects permanently-skewed win stats; decide DR-12 (implement or document-as-disabled threeway); delete the buggy `PVFunctions/LogGameEnd.sqf` (DR-13). Follow-up review item: `WFBE_CL_FNC_EndGame` payload semantics (winner vs loser sideID). Ledger: Victory/endgame Map/Auth/PV/Perf cells advanced.

## Round 7 — 2026-06-02 (Claude) — factory/purchase authority + commander assignment (DR-14, DR-15)

Lane `factory-purchase-authority`. Builds on Codex's [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) (which noted player buy is client-local with no `RequestBuyUnit` PVF) and adversarially verifies Cicero's flagged `Server_AssignNewCommander` candidate. All claims verified at source.

### DR-14 — Player unit purchasing has no server authority (the economy ceiling) — **High (gameplay integrity), architectural**

The player buy path never contacts the server:
- `Client/GUI/GUI_Menu_BuyUnits.sqf:102,108` check funds client-side; `:155-156` do `_params Spawn BuildUnit; -(_currentCost) Call ChangePlayerFunds;`.
- `Client/Functions/Client_BuildUnit.sqf:217/249/…` create the unit/vehicle **directly on the buyer** via `WFBE_CO_FNC_CreateUnit` / `WFBE_CO_FNC_CreateVehicle` (engine `createUnit`/`createVehicle`). There is **no `RequestBuyUnit` PVF** (confirmed: not in `Init_PublicVariables.sqf`, no `Server/PVFunctions/RequestBuyUnit.sqf`).
- Funds live in `wfbe_funds` on the team group, written by `Common_ChangeTeamFunds` with `setVariable [..., true]` (broadcast, client-writable — see Round 1 / DR-6 root cause).

So a modified client can mint any factory unit for free (skip the deduction, or set `wfbe_funds` directly) — and the created vehicle is globally synced because client `createVehicle` in MP is global. **This is the ceiling on the DR-1/DR-6 hardening thread:** unlike construction (DR-6, which at least routes through a server PVF that *could* be validated), the player economy and unit production are *architecturally* client-authoritative in WFBE's locality model. Fully fixing it = a large redesign (route purchases through a validated server PVF like construction). The realistic live-server defense is a **BattlEye script filter** (`scripts.txt`) constraining client `createVehicle`/`createUnit`, **not** a publicVariable filter. Document this ceiling so future hardening targets the right layer.

> Latent path note (confirms atlas): `Server_BuyUnit.sqf` / `AIBuyUnit` is compiled (`Init_Server.sqf`) but has no proven dynamic caller — the AI-commander production path that *would* use it is itself dormant (the AI commander FSM never starts; see Cicero's server atlas + DR-15 neighbourhood).

### DR-15 — `Server_AssignNewCommander` call-shape bug (confirmed) — **Medium (correctness)**

Adversarial verification of Cicero's candidate — **confirmed live** by tracing compile + sole caller:
- `Init_Server.sqf:62`: `WFBE_SE_FNC_AssignForCommander = Compile … "Server\Functions\Server_AssignNewCommander.sqf"`.
- Sole caller `Server/PVFunctions/RequestNewCommander.sqf:13`: `[_side, _assigned_commander] Spawn WFBE_SE_FNC_AssignForCommander;` (a 2-element array).
- `Server/Functions/Server_AssignNewCommander.sqf:3`: `_side = _this;` — sets `_side` to the **whole array** `[side, commander]` (should be `_this select 0`), then `_commander = _this select 1` (correct). `_logic = (_side) Call WFBE_CO_FNC_GetSideLogic` then receives an array, not a side → wrong/`objNull` logic → the block that stops the AI-commander FSM (`_logic getVariable "wfbe_aicom_running"`) operates on a bad logic and fails.

**Impact:** when a human is assigned commander via `RequestNewCommander`, the AI-commander shutdown path mis-fires (mitigated in practice because the AI-commander FSM is itself dormant — DR-14 note). There's also a **redundant** `new-commander-assigned` broadcast (sent by both `RequestNewCommander.sqf` and `Server_AssignNewCommander.sqf`). **Fix:** `_side = _this select 0;`. One-line change in Chernarus source.

### Handoff

Code owners: (DR-14) decide whether to route player purchases through a validated server PVF (large) or accept client-authority + add a BattlEye `scripts.txt` filter; (DR-15) one-line fix `_side = _this select 0` in `Server_AssignNewCommander.sqf` and drop the duplicate `new-commander-assigned` broadcast. Ledger: Factory/purchase Auth/PV advanced; AI-commander caveat cross-linked.

## Round 8 — 2026-06-02 (Claude) — UI/HUD authority + dialog IDs (DR-16, DR-17)

Lane `ui-hud-authority-review`. Cross-checks Codex/Curie's [Client UI systems atlas](Client-UI-Systems-Atlas) and reviews the economy-menu sale authority (the DR-6/DR-14 sibling). Verified at source.

### DR-16 — Structure sale is fully client-authoritative — **High (gameplay integrity)**

`Client/GUI/GUI_Menu_Economy.sqf:104-152` (MenuAction 105, "Sell Building"):
- The **commander check is client-side only** (`_isCommander` via `commanderTeam == group player`, `:107-109`).
- It picks the closest own-side structure (`GetSideStructures`, `:110-112`), then in a spawned thread credits the refund **client-side** — `ChangeSideSupply` (broadcast, client-writable) or `ChangePlayerFunds` (`:141`) — and **destroys the structure client-side** with `_closest setDammage 1` (`:152`), which propagates globally because the structure is a synced object.
- No server PVF, no server validation (same pattern as DR-6 construction and DR-14 purchasing). A modified client bypasses the commander gate and the `WFBE_SOLD` re-sell guard, mints the refund, and demolishes structures. Same **client-authority ceiling**: the realistic defense is a BattlEye `scripts.txt` filter constraining client `setDammage`/funds writes, or routing sell through a validated server PVF (matches the DR-6 fix shape). This completes the economy picture: **build (DR-6), buy (DR-14), and sell (DR-16) are all client-authoritative.**

### DR-17 — Duplicate dialog IDD 23000 (EASA vs Economy) — **Low-Medium (UI correctness)** — *confirms Curie candidate*

`Rsc/Dialogs.hpp`: `class RscMenu_EASA` (`:3209`, `idd = 23000` at `:3211`) and `class RscMenu_Economy` (`:3287`, `idd = 23000` at `:3289`) share the same display id. `findDisplay 23000` is therefore ambiguous, and any control-event/`closeDialog`/`findDisplay 23000` logic can target the wrong dialog if both are reachable. Verified Curie's flagged candidate at source. **Fix:** give EASA and Economy distinct IDDs (and audit any `findDisplay 23000` callers). Also re-confirmed Curie's note that other UI candidates (stale `RscMenu_Upgrade` → missing `GUI_Menu_Upgrade.sqf`; suspect `RscClickableText.soundPush[]`) remain open for a UI-focused follow-up.

### Handoff

Code owners: (DR-16) move sell authority/refund/destruction server-side (mirror the DR-6 server-PVF validation) or add a BattlEye `scripts.txt` filter; (DR-17) assign distinct IDDs to EASA/Economy dialogs. Ledger: UI/HUD Auth/PV advanced; economy thread (build/buy/sell) now fully characterized.

## Round 9 — 2026-06-02 (Claude) — server-loop candidates verified (DR-18, DR-19)

Lane `server-loop-candidates-verify`. Adversarial verification of two Cicero candidates from the [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas); both confirmed at source with exact impact.

### DR-18 — Supply-mission cooldown key casing mismatch → nil-throw on first check — **Medium (correctness)** — *confirms Cicero*

`setVariable`/`getVariable` keys are **case-sensitive** in Arma 2 OA (unlike SQF identifiers). The seed and the readers disagree by one letter:
- `Common/Init/Init_Town.sqf:35`: `_town setVariable ["lastSupplyMissionRun", 0];` — **lowercase** `l`.
- `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf:8`: `getVariable "LastSupplyMissionRun"` — **capital** `L`. Same capital form is written by `supplyMissionStarted.sqf:8` and `supplyMissionActive.sqf:6`.

So the `0` seed lands in a slot nothing reads, and `"LastSupplyMissionRun"` is **nil** until the first mission completes. The cooldown check then runs:
```sqf
if (((_lastActivationTime + WFBE_CO_VAR_SupplyMissionRegenInterval) > time) && (_lastActivationTime != 0)) then {...}
```
On a never-run town `_lastActivationTime` is nil → `nil + interval` throws ("Type Nothing, expected Number"), aborting the handler before it publishes `WFBE_Server_PV_IsSupplyMissionActiveInTown` — so the client's cooldown query can get **no response** on first use. The mis-cased seed defeats exactly the `!= 0` guard it was meant to satisfy. **Fix:** make the seed key `"LastSupplyMissionRun"`, or read with a default: `getVariable ["LastSupplyMissionRun", 0]`.

### DR-19 — Hosted/listen-server FPS publishers busy-loop — **Medium (performance, non-dedicated)** — *confirms Cicero*

Both server FPS publishers put `sleep 8` **inside** the `isDedicated` guard:
```sqf
// Server/GUI/serverFpsGUI.sqf  AND  Server/Module/serverFPS/monitorServerFPS.sqf
while {true} do { if (isDedicated) then { …; publicVariable …; sleep 8; } };
```
On a **dedicated** server this is fine. On a **hosted/listen server or singleplayer host** (`isServer` true, `isDedicated` false — and both scripts are launched server-side from `Init_Server`), the `if` is false every iteration, so `while {true}` spins **with no sleep** → a tight CPU busy-loop per script (two of them), degrading the host. **Fix:** either `if (!isDedicated) exitWith {}` at the top (don't publish FPS when hosted), or move `sleep 8` outside the `if` so the loop always yields. (Two scripts publishing the same `round diag_fps` under different PV names — `SERVER_FPS_GUI` / `WFBE_VAR_SERVER_FPS` — is also redundant; consolidating would remove one loop entirely.)

### Handoff

Code owners: (DR-18) align the supply-cooldown key casing (or default the read) — one-line fix; (DR-19) hoist the FPS-loop `sleep` out of the `isDedicated` guard (or early-exit when not dedicated), and consider consolidating the two redundant FPS publishers. Ledger: Supply JIP/HC and server-runtime perf cells advanced.

## Round 10 — 2026-06-02 (Claude) — JIP/headless cross-cut: non-idempotent HQ-killed (DR-20)

Lane `jip-headless-crosscut`. Traced HQ-death detection across server, existing clients and JIP clients.

### DR-20 — HQ-killed is processed once per owning-side client (no idempotency) — **High (multiplayer correctness / score exploit)**

Death detection for the mobile HQ is deliberately redundant (a client-local vehicle's `Killed` EH must run on a client):
- `Server/Construction/Construction_HQSite.sqf:89` adds a server-side `Killed` EH, then `:91` broadcasts `["set-hq-killed-eh", _mhq]` to the **whole owning side**; `Server_MHQRepair.sqf:37,43` do the same after a repair.
- `Client/PVFunctions/HandleSpecial.sqf:34` (`set-hq-killed-eh`) makes **every owning-side client** add a `Killed` EH that calls `["RequestSpecial",["process-killed-hq",_this]]`.
- JIP clients additionally add it themselves at `Client/Init/Init_Client.sqf:500-503` (guarded `!isServer && !_isDeployed`).

So **N owning-side clients each hold the same `Killed` EH**. When the HQ dies, the synced death fires every client's EH → the server receives **N** `process-killed-hq` messages → `Server/Functions/Server_OnHQKilled.sqf` runs **N times**, and it has **no idempotency guard**. Each run:
- awards the killer score **twice** (`_points = 30000/100*coef` and `_score = 900` via two `RequestChangeScore`), so total killer score ≈ **2N ×** the intended award;
- broadcasts N× destruction / `HeadHunterReceiveBounty` messages;
- re-publishes `IS_<side>_HQ_ALIVE` / marker infos N times.

(The dead-MHQ wreck spawn is inside `if (GetSideHQDeployStatus)` and self-limits after the first run flips `wfbe_hq_deployed=false`; the **score/message duplication does not**.) On a populated server (e.g. 20 owning-side players) an HQ kill inflates the killer's score ~40×. **Fix:** make `Server_OnHQKilled.sqf` idempotent — first line `if (_structure getVariable ["wfbe_hq_killed_done", false]) exitWith {}; _structure setVariable ["wfbe_hq_killed_done", true];`. Keep the redundant EH registration (it ensures death is never missed regardless of MHQ locality); guard the **consumer**, not the producers. Pattern: "detect redundantly, act once."

### JIP coverage notes (verified, no change needed)
- The JIP guard at `Init_Client.sqf:500` (`!_isDeployed`) is correct: a JIP client adds the mobile-HQ EH only when the HQ is currently mobile; a deployed HQ (building) is covered by the server-side EH at `Construction_HQSite.sqf:36` / `Init_Server.sqf:319`. JIP HQ-death *detection* is therefore covered — the defect is downstream duplication (DR-20), not a JIP miss.
- `set-hq-killed-eh` is side-filtered (`SendToClients [_side, …]`), so only owning-side clients register it — correct.

### Handoff
Code owners: add the one-line idempotency guard to `Server_OnHQKilled.sqf` (DR-20) — this also fixes the duplicate-score symptom on HQ kills in populated games. Ledger: JIP/HC cells advanced for victory/economy/construction (HQ-death path verified end-to-end).

## Round 11 — 2026-06-02 (Claude) — headless disconnect (DR-21) + a self-correction

Lane `headless-disconnect-review`. Verifies the round-1 hypothesis about HC disconnect at `Server/Functions/Server_OnPlayerDisconnected.sqf`.

### Correction to a round-1 hypothesis (honesty note)
Round 1 listed, as an unverified gotcha, "HC disconnect orphans units it created." Verified at source, that framing is **wrong** and is hereby downgraded: in Arma 2 OA, when any machine disconnects the engine **migrates its local objects/groups to the server** (ownership transfer, not deletion). HC-delegated AI is therefore **not orphaned or lost** on disconnect. The accurate effects are below (DR-21).

### DR-21 — HC disconnect dumps delegated AI on the server with no re-delegation — **Medium (performance/operational, non-data-loss)**

`Server_OnPlayerDisconnected.sqf` HC handling:
- If `WFBE_C_AI_DELEGATION == 2` and `WFBE_HEADLESS_<uid>` exists, it removes the HC's group from `WFBE_HEADLESSCLIENTS_ID` and clears `WFBE_HEADLESS_<uid>`.
- `WFBE_JIP_USER<uid>` is nil for an HC (HCs don't register as players via `RequestJoin`), so the handler `exitWith`s before the player-team/unit logic. (It does also delete any `WFBE_CLIENT_<uid>_OBJECTS` registered to that uid earlier in the handler.)

What actually happens to the AI the HC was simulating: the **engine transfers those units/groups to the server**, so the server's load spikes by exactly the amount the HC was offloading — the opposite of the delegation benefit, precisely when you least want it. There is **no re-delegation**: the disconnect handler does not hand the migrated AI to a surviving HC, and (per the round-1 init finding) `WFBE_C_AI_DELEGATION` is only evaluated/downgraded at boot, so a later HC reconnect does not resume offloading either. **Net:** HC delegation has no failover/rebalancing — a single HC drop silently re-loads the server for the rest of the match. **Suggested handling:** on HC disconnect, if other HCs remain, re-`setGroupOwner` the migrated town-AI groups to a surviving HC (a periodic rebalancer is cleaner than doing it in the disconnect handler); and make delegation re-evaluate when an HC (re)connects rather than only at boot. (Arma 2 OA *does* support `setGroupOwner`; note the mission currently never uses it — see [AI, headless and performance](AI-Headless-And-Performance).)

### Handoff
Code owners: treat HC delegation as best-effort with no failover today; if HC stability matters, add re-delegation/rebalancing on HC disconnect/connect. Ledger: AI/Headless JIP/HC cell advanced; round-1 "orphan" hypothesis corrected.

## Round 12 — 2026-06-02 (Claude) — side-supply overspend windfall (DR-22)

Lane `side-supply-delta-verify`. Confirms + sharpens Faraday's "negative side-supply delta" candidate (and my round-1 "inverted guard" note) at source.

### DR-22 — Overspending side supply grants a windfall instead of being floored — **High (economy correctness/exploit)**

The supply clamp (live in `Server/Functions/Server_ChangeSideSupply.sqf`, both the `wfbe_supply_temp_west` and `…_east` handlers; also present but **dead** in `Common/Functions/Common_ChangeSideSupply.sqf`) is:
```sqf
_change = _currentSupply + _amount;
if (_change < 0) then {_change = _currentSupply - _amount};   // intended floor-at-0; actually a windfall
if (_change >= _maxSupplyLimit) then {_change = _maxSupplyLimit};
```
`_amount` is **signed** — deductions are negative. When a deduction would overdraw (`_change < 0`), the "floor" computes `_currentSupply - _amount` = `_currentSupply + |amount|`. Example: supply 100, spend 300 (`_amount = -300`) → `_change = -200` → guard → `100 - (-300) = 400`. **Trying to spend more supply than you have increases your supply by the amount you tried to spend.** Any over-budget supply deduction (e.g. an upgrade/structure costing more than the side holds) flips into a gain — directly exploitable by attempting over-large spends, and it corrupts the economy generally.

**Fix:** floor correctly — `if (_change < 0) then {_change = 0};`. Apply in `Server_ChangeSideSupply.sqf` (both handlers). Note the matching block in `Common_ChangeSideSupply.sqf` is dead code: it computes `_change` but the function sends only `[_side, _amount, _reason]` over `wfbe_supply_temp_<side>` and the server recomputes — so fix the server copy (and optionally delete the dead client computation). Related (round-1, still open): there is **no resistance-side handler** for `wfbe_supply_temp_*`, only west/east.

### Handoff
Code owners: one-line floor fix in `Server_ChangeSideSupply.sqf` (×2 handlers) — closes the overspend windfall. Ledger: Economy/supply Auth/PV reinforced (confirmed exploit, not just "confusing").

## Round 13 — 2026-06-02 (Claude) — upgrade authority (DR-23) + economy synthesis

Lane `upgrade-authority-verify`. Confirms Faraday's "upgrade authority gap" candidate and closes the economy-authority thread.

### DR-23 — Upgrade purchasing is client-authoritative with no server validation — **High (economy integrity)**

`Server/PVFunctions/RequestUpgrade.sqf` is the whole handler: `_this Spawn WFBE_SE_FNC_ProcessUpgrade;` — the raw client payload `[side, upgradeId, level, isPlayer]` goes straight into `Server/Functions/Server_ProcessUpgrade.sqf`, which:
- reads `_side`/`_upgrade_id`/`_upgrade_level`/`_upgrade_isplayer` from the client with **no checks** (no commander check, no side check, no upgrade-sequence/level check, no dependency/`_LINKS` check);
- **never deducts a cost** — it only `sleep`s `_upgrade_time` then `_upgrades set [_upgrade_id, current+1]`. The upgrade cost is deducted **client-side** in the upgrade menu before the request, same as the rest of the economy.

So a modified client can forge `["RequestUpgrade",[side, id, level, false]]` to grant any side a **free** upgrade, bypassing commander authority and cost. Secondary: `_upgrade_time = (… select _upgrade_id) select _upgrade_level` uses client-controlled indices → out-of-range error (minor DoS) if forged with bad ids. **Fix:** validate in `RequestUpgrade`/`ProcessUpgrade` — requester is the side's commander, indices in range, dependencies met and the level is the correct next step, and deduct cost server-side (mirror the DR-6 validation shape).

### Economy-authority synthesis (DR-6, DR-14, DR-16, DR-22, DR-23)
This is the last economic action to review, and it confirms the pattern: **the entire WFBE player economy is client-authoritative** —
- **build** structures (DR-6), **buy** units (DR-14), **sell** structures (DR-16), **change side supply** (DR-22, plus the overspend-windfall bug), **buy upgrades** (DR-23) — each lets the client decide/deduct, with the server doing at most a class-exists check.

One owner decision covers all of it: either route economic mutations through validated server PVFs (server checks commander/side/funds and applies the debit), or accept client authority and rely on BattlEye `scripts.txt`/PV filters. Piecemeal fixes won't close the class; the decision is architectural.

### Handoff
Code owners: add commander/funds/index/dependency validation + server-side cost to the upgrade path (DR-23); and make the **economy-authority decision** once for build/buy/sell/supply/upgrade rather than per-finding. Ledger: economy thread fully reviewed (Auth across the board characterized).

## Round 14 — 2026-06-02 (Claude) — dead dialog reference (DR-24)

Lane `missing-reference-inventory`. Confirms Curie's `RscMenu_Upgrade` candidate at source (a representative dead/abandoned reference).

### DR-24 — `RscMenu_Upgrade` dialog points at a missing onLoad script — **Low (dead code / naming drift)**

`Rsc/Dialogs.hpp:2425` `class RscMenu_Upgrade` has `onLoad = "_this ExecVM ""Client\GUI\GUI_Menu_Upgrade.sqf"""` (`:2428`), but **`Client/GUI/GUI_Menu_Upgrade.sqf` does not exist** — only the differently-named `Client/GUI/GUI_UpgradeMenu.sqf` does. `RscMenu_Upgrade` is never opened (`createDialog`/`cutRsc` for it appears nowhere outside `Dialogs.hpp`); the live upgrade UI is `GUI_UpgradeMenu.sqf` (reached via `GUI_Menu.sqf`). So this is a stale dialog whose `onLoad` would `ExecVM` a missing file if it were ever opened — currently inert because nothing opens it. **Fix:** delete `RscMenu_Upgrade` (and its dangling `onLoad`), or repoint it at `GUI_UpgradeMenu.sqf` if it was meant to be the live one. Naming-drift class (`GUI_Menu_Upgrade` vs `GUI_UpgradeMenu`).

> Method note: an automated "live reference → missing file" scan was attempted but its Windows-backslash path normalization was unreliable (false positives); this finding was confirmed by hand. A robust missing-reference inventory is a good future tooling task (resolve `\`-separated `execVM`/`ExecFSM`/`preprocessFile` string targets against the tree, excluding commented lines) — handed to Codex/tooling.

### Handoff
Code owners: remove or repoint the dead `RscMenu_Upgrade` dialog (DR-24). Tooling (Codex/Meitner lane): build a reliable missing-reference scanner. Ledger: UI dead-reference candidate confirmed; abandoned-code inventory still has open candidates (TaskSystem, old blink loops, WASP OnArmor/KeyDown — see round-1 WASP-Overlay + Feature-Status).

## Round 15 — 2026-06-02 (Claude) — remaining UI config defects (DR-25a/b)

Lane `ui-followups-verify`. Confirms Curie's last two UI candidates at source; closes the UI follow-up items.

### DR-25a — Duplicate title IDD 10200 (`RscOverlay` vs `OptionsAvailable`) — **Low (UI correctness)**
`Rsc/Titles.hpp`: `class RscOverlay` (`:46`) and `class OptionsAvailable` (`:165`) both declare `idd = 10200`. Titles are shown via `cutRsc`/`titleRsc` (addressed by class name, so the collision is less damaging than the dialog dup in DR-17), but any code that does `findDisplay 10200` / `uiNamespace` lookups on that id is ambiguous. Assign distinct IDDs. (Sibling of DR-17's `idd=23000` dialog dup.)

### DR-25b — Malformed `soundPush[]` in `RscClickableText` — **Low (config defect)**
`Rsc/Ressources.hpp:556` `class RscClickableText` has `soundPush[] = {, 0.2, 1};` — the first array element (the sound file) is **empty/missing** (a leading comma). The correct empty-sound form is `{"", 0.2, 1}` (as used at `Ressources.hpp:92`); the line-556 form is a malformed config array. `RscClickableText` is a base control class used widely, so the defect propagates to inheritors. **Fix:** `soundPush[] = {"", 0.2, 1};` (or a real sound macro like the adjacent `soundEscape[] = {WFBE_SoundEscape,0.2,1}`).

### Handoff
Code owners: assign distinct IDDs to `RscOverlay`/`OptionsAvailable` (DR-25a); fix the malformed `RscClickableText.soundPush[]` (DR-25b). Both Low. Ledger: UI follow-up candidates (title 10200, soundPush) now confirmed — UI cell's documented candidates are closed.

## Round 16 — 2026-06-02 (Claude) — external deep-research integration (DR-26) + corroboration

Lane `external-research-integration`. Steff supplied three deep-research PDFs (also given to Codex). I read two in full (*Diepgaande analyse*, *Analyse van*); the third is the same genre. **Provenance check:** their citations are `raw.githubusercontent.com/wiki/rayswaynl/...` pages + Miksuu upstream blobs — i.e. they were generated **from this wiki** (plus upstream as a line-level proxy), so they are *downstream corroboration*, not independent source verification.

### Corroboration (external validation of our findings)
The reports independently re-derive, and rate as top risks, exactly our spine: the `Call Compile` PVF trust boundary (DR-1) with the BattlEye `kickAFK`-only filter, construction client-authority (DR-6), `callExtension`/external-trust (DR-7), the `UpdateSupplyTruck` config-gated latent breakage (our Feature-Status sharpening), the town-AI despawn player-vehicle risk (our AI/headless note), the PR#1 `Killed`-EH leak, and MASH-marker-broken (DR-3). Their recommended fix order (static allow-list dispatch → server-side validation → reduce broadcast/centralize PV → harden `callExtension`) matches our DR-1/DR-6 playbooks. **Our source-verified findings are a superset** — the reports do not contain DR-11/15/18/19/20/22/23 (victory winner-inversion, commander-assign bug, FPS busy-loop, HQ-killed N-fold, overspend windfall, upgrade-authority), which required reading the actual `.sqf` rather than the wiki. Net: external review confirms the map holds up and surfaces nothing higher-severity that we missed in code.

### DR-26 — License is custom/proprietary, not OSI (resolves both reports' "license unspecified") — **Low (governance)**
Both reports marked the license "unspecified" (they only had the wiki, not the repo root). Verified at source: `LICENSE.md` is a **custom proprietary-style license** — "Copyright (C) 2016 Spayker / (C) 2025 Miksuu", with contributions becoming the repository owner's property and reuse/distribution restricted to explicitly granted rights. **Not** MIT/GPL/OSI. Implication: third-party reuse or redistribution is **not** permitted by default; treat the repo as source-available, not open-source.

### Governance/ops handoffs (the reports' additive value, source-confirmed)
- **Discord sample metadata:** `DiscordBot/preferences_sample.json` ships a concrete `GuildID` (`440257265941872660`), `AuthorizedUserIDs`, and `DataSourcePath C:\a2waspwarfare\Data`; `FileConfiguration.cs` has the same hardcoded fallback path. No committed token (good), but neutralize the sample identifiers / move to env-based config. *(Codex/owner lane — DiscordBot is outside the Chernarus mission.)*
- **No CI/tests:** confirmed earlier (only `.github/FUNDING.yml`). For a heavily `preprocessFile`-dynamic SQF codebase + generated targets, add at least SQF-syntax + generated-mission-drift + .NET build checks. *(Tooling/Codex lane.)*

### Handoff
Owner: the campaign's code findings (DR-1→DR-25) are the actionable core; the external reports add governance items (license clarity now resolved as DR-26; Discord sample hygiene; CI). Codex: fold the governance asks into `External-Integrations`/`Tools-And-Build-Workflow` as desired (its lane).

## Round 17 — 2026-06-02 (Claude) — weather / day-night: reviewed clean (no defect)

Lane `weather-daynight-review`. Reviewed `Server/Functions/Server_DayNightCycle.sqf` (Marty's hybrid accelerated cycle) + the client receiver/animation in `initJIPCompatible.sqf:174-210` + `Client/Functions/Client_DayNightCycle.sqf` + the constants. **No defect found — the system is well-designed.** Recording the clean result so future passes don't re-review.

Verified:
- **No divide-by-zero** in the cycle math. `_twilight_hours_per_second = _day_weighted_hours / (_day_duration_real_seconds * _twilight_weight)` — `WFBE_DAYNIGHT_TWILIGHT_WEIGHT` is a **non-zero hardcoded constant** (`= 3`, `Init_CommonConstants.sqf:88`, not a param), and `WFBE_DAY_DURATION`'s parameter values are `{1,30,40,50,60,90,180}` (min 1, never 0), so both divisors are always positive.
- **Authority model is coherent:** the server runs an authoritative accelerated clock via small per-tick `skipTime` and publishes an absolute `date` (`WFBE_DAYNIGHT_DATE`) every `WFBE_DAYNIGHT_SERVER_SYNC_INTERVAL` (30 s) for drift correction; each non-dedicated machine animates locally (`Client_DayNightCycle.sqf`) — consistent with `skipTime`/`setDate` being local-effect in Arma 2 OA.
- **JIP is covered:** `WFBE_DAYNIGHT_DATE` is engine-synced to joiners, and the init `[] Spawn { waitUntil time>0; if (!isNil "WFBE_DAYNIGHT_DATE") setDate WFBE_DAYNIGHT_DATE … }` applies the current absolute date on join; live drift resumes on the next 30 s broadcast. Minor, non-defect: a JIP client's `WFBE_DAYNIGHT_DATE` PVEH does not fire for the pre-join value (only the variable is synced), so the first drift-correction waits up to one sync interval — acceptable since the init `setDate` already seeds correct state.
- The volumetric-clouds force-disable (perf) is documented in [AI, headless and performance](AI-Headless-And-Performance) / [Feature status register](Feature-Status-Register).

**Outcome:** weather/day-night cell → reviewed-clean. No handoff required.

## Round 18 — 2026-06-02 (Claude) — modules: forgeable map-wide ICBM nuke (DR-27)

Lane `modules-review`. Reviewed the `Client/Module/` set (AFKkick, AutoFlip, CM, CoIn, EASA, Engines, MASH, Nuke, Skill, UAV, Valhalla, ZetaCargo, supplyMission) and `Server/Module/`. Most are config-gated cosmetic/QoL features (`WFBE_C_MODULE_*` flags; UAV's `_button == 007` branch is `comment 'DISABLED'` in both `uav_interface.sqf:226` and `uav_interface_oa.sqf:100` — confirms the Feature-Status "UAV partial" note). The **Nuke/ICBM** module is the high-stakes one and carries the most severe authority defect found in the campaign.

### DR-27 — ICBM nuke is fully client-authoritative; one forged publicVariable = server-applied map-wide kill — **Critical (network authority / forgery)**

End-to-end chain (all `path:line` in the Chernarus source mission):

1. **Trigger is client-side and client-gated only.** `Client/GUI/GUI_Menu_Tactical.sqf` `MenuAction == 8` (the "ICBM Strike" branch, ~`:463-505`) deducts the fee locally (`-_currentFee Call ChangePlayerFunds` — itself client-authoritative, the DR-16/DR-23 economy class), spawns the strike-marker object locally (`"HeliHEmpty" createVehicle _callPos`), and `Spawn NukeIncoming`. The only ICBM gate is **menu visibility** (`WFBE_C_MODULE_WFBE_ICBM > 0 && !IS_air_war_event`, `GUI_Menu_Tactical.sqf:253`) — module-enable, not the per-side *purchased* `WFBE_upgrade_…_ICBM`, and not a commander check.
2. **Client asks the server to detonate.** `Client/Module/Nuke/nukeincoming.sqf:23`:
   `["RequestSpecial", ["ICBM",sideJoined,_target,_cruise,clientTeam]] Call WFBE_CO_FNC_SendToServer;`
3. **Server dispatches with no validation.** `RequestSpecial` is a registered inbound PVF (`Common/Init/Init_PublicVariables.sqf:18`); its handler `Server/PVFunctions/RequestSpecial.sqf` is literally `_this Spawn HandleSpecial;` → `Server/Functions/Server_HandleSpecial.sqf` `"ICBM"` case (`:97-112`):
   - `_base = _args select 2` (client-chosen strike-position object), `_target = _args select 3` (client-chosen object).
   - `if (isNull _target || !alive _target) exitWith {}; waitUntil {!alive _target}; [_base] Spawn NukeDammage;`
   - `NukeDammage` is server-side (which is *why* the kill propagates to everyone) and is applied **centered on the client-supplied `_base` position** with **no check** that `_side`/`clientTeam` owns the ICBM upgrade, that the sender is the commander, or that funds existed.

**Why the one server-side guard is not a security check.** `waitUntil {!alive _target}` only requires the forger to supply *some* live object and then end its life — spawn any vehicle, pass it as `_target`, delete/kill it; or pass any alive object and kill it. It gates timing, not authority.

**Impact.** Any connected client can hand-craft the publicVariable `RequestSpecial = ["ICBM", <anySide>, <objAtChosenPos>, <liveObjThenKilled>, <anyTeam>]` and the **server** applies a map-wide nuke at coordinates of the attacker's choosing — repeatable, no upgrade, no commander role, no real cost. This is the apex of the client-authoritative class (DR-6 build, DR-14 buy, DR-16 sell, DR-22 supply, DR-23 upgrade): same root cause (server PVF handlers trust payload fields without re-deriving authority server-side), but the blast radius is the entire match rather than one player's wallet.

**Owner decision (same lever as the economy class, higher priority).** Two non-exclusive fixes:
- *Server-side authority in the `"ICBM"` case:* re-derive the requester from the PV sender, verify `_remoteSender` is the commander of `_side`, verify the side's `WFBE_upgrade_…_ICBM` level > 0 and a server-tracked cooldown/funds ledger, before `Spawn NukeDammage`. (The same `_remoteSender`-vs-payload pattern recommended in DR-1/DR-6.)
- *BattlEye `scripts.txt`/`publicvariable.txt`:* restrict/snapshot the `RequestSpecial` PV so the `"ICBM"` selector can't be hand-injected. Defense-in-depth, not a substitute for server validation.

Handoff for Codex: this belongs in the [Networking](Networking-And-Public-Variables) PVF-hazard table and a Feature-Status/atlas note on the Nuke module; the actionable fix is an owner decision shared with the economy-authority item already logged (DR-6/14/16/22/23).

**Outcome:** modules cell → Auth/PV flipped to the DR-27 finding; rest of `Client/Module/` reviewed as config-gated cosmetic/QoL with the UAV-007 branch confirmed disabled.

## Round 19 — 2026-06-02 (Claude) — gear / EASA / vehicle-service economy (DR-28) — class now complete

Lane `gear-easa-review`. Reviewed the aircraft/vehicle loadout system (`Client/Module/EASA/` + `Client/GUI/GUI_Menu_EASA.sqf`) and the vehicle service point (`Client/GUI/GUI_Menu_Service.sqf`). Result: gear/rearm is the **last untracked tier of the client-authoritative economy class**, plus a minor logic inconsistency.

### DR-28 — Gear/EASA loadouts and vehicle rearm/repair/refuel/heal are client-authoritative; rearm & refuel skip even the client-side affordability guard — **High (economy authority), class-completing**

Source-verified:
- **No server PVF for gear at all.** `EASA_Equip.sqf` applies the chosen loadout directly to the local vehicle (`addWeapon`/`addMagazine`, or `addWeaponTurret`/`addMagazineTurret` for the `AW159_Lynx_BAF`) and broadcasts only the setup index (`_vehicle setVariable ["WFBE_EASA_Setup", _index, true]`, `:36`). There is no `SendToServer`/`RequestSpecial` anywhere in the EASA or Service flow (grep-confirmed) — the spend and the effect are entirely client-local.
- **EASA cost is a client-side honor check.** `GUI_Menu_EASA.sqf:46-50`: `if (_funds > (_row select 0)) then { … Call EASA_Equip; -(_row select 0) Call ChangePlayerFunds; … }`. The price lives in the loadout row (`[[Price],[Desc],[Wpn,Ammo]…]`, `EASA_Init.sqf:8`), the affordability test runs on the client, and the debit is the client-authoritative `ChangePlayerFunds` (the DR-16/DR-23 primitive). A modified client equips any loadout without paying.
- **Service rearm/refuel deduct with NO affordability guard.** `GUI_Menu_Service.sqf`: rearm (`MenuAction==1`, `:196-200`) and refuel (`:217-219`) do `-_price Call ChangePlayerFunds;` *unconditionally*, then `Spawn SupportRearm`/the refuel thread — whereas repair (`:206-211`, `if (_repairPrice > 0)`) and heal (`:228-230`) are guarded. So even a *legit* client can rearm/refuel into negative/clamped funds, and (as with all of the above) the effect threads run client-side with no server check.

**Why it matters.** This completes the economy-authority picture. Every WFBE spend path is now source-confirmed client-authoritative: **build (DR-6) · buy (DR-14) · sell (DR-16) · supply transfer (DR-22) · upgrades (DR-23) · ICBM superweapon (DR-27) · gear/EASA + vehicle rearm/repair/refuel/heal (DR-28).** There is no server-side ledger; `ChangePlayerFunds` and the can-afford tests are all on the honor system. The rearm/refuel missing-guard is a real but secondary inconsistency — moot against the root issue, since a cheat client bypasses the debit regardless.

**Owner decision (same single lever).** The one architectural decision already logged for the economy class covers DR-28 too: either (a) move spend authority server-side — a server-validated funds ledger that PVF handlers debit before applying effects — or (b) accept client-authoritative economy and lean on BattlEye `scripts.txt` to blunt the most trivial money/var edits. No new lever; gear simply joins the list. If (a) is ever scoped, also add the trivial `if (_funds >= price)` guards to Service rearm/refuel for parity with EASA/repair/heal.

Handoff for Codex: fold DR-28 into the [Economy](Economy-Towns-And-Supply) page's "all spend is client-authoritative" note and the gear/loadout atlas; it's the same owner decision, no separate workstream.

**Outcome:** new ledger row **Gear / EASA / vehicle service** → Map ✅, Auth ✅ (characterized as client-authoritative, DR-28), PV/JIP-HC 🟡, Drift ⬜; Economy row note extended to name gear as a class member.

## Round 20 — 2026-06-02 (Claude) — in-repo GLOBALGAMESTATS extension (DR-29)

Lane `extension-globalgamestats-review`. Reviewed the in-repo .NET `callExtension` DLL (`Extension/src/**`) end-to-end plus its sole SQF caller (`Server/CallExtensions/GlobalGameStats.sqf`). This is the *second* extension trust boundary (distinct from the AntiStack `A2WaspDatabase` DLL reviewed in DR-7..DR-10, which is **not** in the repo). Net: this one is currently the *safe* direction, but carries a dormant RCE landmine and an `async void` reliability bug, and is a write-only/abandoned-refactor stub.

### DR-29 — GLOBALGAMESTATS extension: safe today (output discarded), but a dormant deserialization-RCE landmine + `async void` write race + write-only stub — **Medium (latent Critical)**

What it is: a one-way telemetry exporter. `GlobalGameStats.sqf` loops every 60 s (`while {true} … sleep 60`, `execVM`'d once from `Init_Server.sqf:298`) and calls
`"a2waspwarfare_Extension" callExtension format ["%1,…,%6","GLOBALGAMESTATS",scoreWest,scoreEast,worldName,uptime,playerCount]`. The DLL (`ExtensionMethods.RvExtension`, the legacy synchronous `_RVExtension@12` ABI — correct for A2 OA 1.64; A3's `RVExtensionArgs` does not exist here) enum-validates the selector, reflection-instantiates `GLOBALGAMESTATS` (`EnumExtensions.GetInstance` → `Type.GetType("GLOBALGAMESTATS")`), stores the args (`GameData.Instance.exportedArgs = _args`) and serializes `GameData` to `C:\a2waspwarfare\Data\database.json`.

Findings (source-cited):

1. **No RCE-into-SQF vector — the safe contrast to DR-7.** `RvExtension`'s `_output` StringBuilder is **never written** (grep-confirmed; only the parameter declaration exists at `ExtensionMethods.cs:12`), and the SQF caller invokes `callExtension` as a **bare statement with no assignment** (`GlobalGameStats.sqf:22`). So the DLL returns an empty string and SQF never `call compile`s anything from it — the exact opposite of the AntiStack DB path (DR-7), where `_response` is captured and compiled. Reflection is also constrained: `Enum.TryParse` (`ExtensionMethods.cs:29`) gates the selector to the `GLOBALGAMESTATS` enum before `Type.GetType`, so SQF cannot instantiate arbitrary CLR types.

2. **Dormant deserialization-RCE landmine (Low now → Critical if load is ever enabled).** The commented-out load path (`SerializationManager.cs:104-130`) uses `settings.TypeNameHandling = TypeNameHandling.Auto;` with `JsonConvert.DeserializeObject<Database>(_json, settings)` — the textbook Newtonsoft `$type` gadget sink. It is inactive today, but **the feature cannot actually persist across restarts without a load path** (see #3), so a future dev is likely to re-enable it. If `database.json` is ever writable by an untrusted process (or replaced), re-enabling load = remote/local code execution on the server host. The active *serializer* is correctly hardened (`TypeNameHandling.None`, `SerializationManager.cs:33`) — the risk is strictly the commented load path. **Recommend: delete the dead load code, or if reinstated use `TypeNameHandling.None` + a fixed expected type.**

3. **Write-only / abandoned-refactor stub.** The active code only ever *serializes*; the entire deserialize/load path is commented out and references a different type graph (`Database`, `Leagues.StoredLeagues`) than the live `GameData` singleton — evidence of a half-finished refactor. Consequence: there is **no cross-restart persistence today** (the DLL never reads the file back), and `GameData`'s only field is `[DataMember] public string[] exportedArgs = new string[2]` (`GameData.cs:29`) — a stale initializer, since the caller now sends **5** data args (the `// Todo: [3] Uptime [4] Player count` comment in `GLOBALGAMESTATS.cs:9-11` is also stale — both are already wired). Any wiki text implying GLOBALGAMESTATS provides durable stat persistence would be too confident; it currently produces a single overwritten JSON snapshot.

4. **`async void` + unawaited file-create race before `File.Replace` (Medium reliability).** `SerializationManager.SerializeDB` is `async void`; it calls the *also* `async void` `FileManager.CheckIfFileAndPathExistsAndCreateItIfNecessary(dbPath, dbFileName)` **without awaiting** (`:52`), then immediately `File.Replace(dbTempPathWithFileName, dbPathWithFileName, null)` (`:55`). `File.Replace` requires the destination to exist — on first run (no `database.json` yet) the fire-and-forget create may not have completed, so `File.Replace` throws `FileNotFoundException`. Per `BaseExtensionClass` (`:18-22`) that is rethrown as `InvalidOperationException` out of the synchronous `_RVExtension@12` call, which can destabilize the calling SQF/game thread; and unobserved `async void` exceptions surface as unhandled exceptions on the .NET threadpool, which can crash the host process. **Recommend: make the I/O methods `async Task` and `await` them, or do the create synchronously before `File.Replace`.**

5. **Minor telemetry data-quality bug (SQF side).** `GlobalGameStats.sqf:20` computes `_playerCount = abs(_playerCount - 1)` ("Exclude headless client"), which assumes exactly one HC is always connected. With 0 HCs it under-reports by 1 (1 real player → reports 0; empty server → `abs(0-1)=1` reports a phantom player); with 2+ HCs it over-subtracts. Two `WFBE_CO_FNC_LogContent` INFORMATION lines per minute (`:11` "Running with old vars …", `:23`) also add steady RPT noise. Cosmetic/telemetry-only.

**Owner decisions / handoff for Codex.** Document GLOBALGAMESTATS in [External integrations](External-Integrations) as a *one-way, output-discarded telemetry exporter* (explicitly NOT an RCE-into-SQF path, unlike the AntiStack DB), with three concrete code asks for the owner: (a) delete or harden (`TypeNameHandling.None`) the dead deserialize path before anyone re-enables load; (b) fix the `async void` create/`File.Replace` race; (c) optional — correct the `abs(playerCount-1)` HC heuristic and the stale `new string[2]`/Todo comments. The Extension DLL is a code artifact, not a wiki page — these are upstream code-owner items, logged here for traceability.

**Outcome:** Integrations row — Extension sub-target reviewed (DR-29). AntiStack DB (DR-7..DR-10) + Extension (DR-29) now both done; **Discord data path + BattlEye `scripts.txt`/`publicvariable.txt` posture remain ⬜** within the bundle.

## Round 21 — 2026-06-02 (Claude) — BattlEye posture (DR-30) — the "rely on BattlEye" half of every economy/forgery owner-decision is not shipped

Lane `battleye-posture-review`. Source-verified the repo's entire BattlEye footprint to close a loop the campaign left open across **eight** prior findings (DR-1 RCE dispatch + DR-6/14/16/22/23/27/28 client-authoritative economy), each of which offered remediation option *(b) "accept client authority and rely on BattlEye filters."* Confirms — and sharpens — the high-level posture the Codex `Gibbs` scout reported (`Progress-Dashboard.md:23,72`), and corroborates the accurate, non-overclaiming wiki text already in place (`External-Integrations.md:60`, `Feature-Status-Register.md:32`, `Networking-And-Public-Variables.md:122`).

### DR-30 — As shipped, the BattlEye mitigation is a 22-byte AFK-kick stub: no security PV filter, no `scripts.txt` at all — option (b) does not exist in the repo — **High (live-server hardening gap, campaign-wide)**

Source facts (full repo sweep):
- The **only** BattlEye filter file in the repository is `BattlEyeFilter/publicvariable.txt` — **22 bytes**, whose entire content is:
  ```
  //new
  5 "kickAFK"
  ```
  This is not a security control. The single rule is the **AFK-kick feature plumbing** itself: `Client/.../updateclient.sqf` intentionally broadcasts `kickAFK` and BattlEye acts on it because `serverCommand` kick paths are unavailable (correctly documented at `External-Integrations.md:58` and `Networking-And-Public-Variables.md:66`). There is **no default-deny catch-all line** (e.g. `5 "" !="legitPV1" !="legitPV2" …`) and therefore **no restriction on any forgery-class PV** — `RequestSpecial` (the DR-27 ICBM vector), `RequestStructure`/`RequestDefense` (DR-6), `RequestUpgrade` (DR-23), `RequestNewCommander` (DR-15), or the raw `Server_HandlePVF`/`Client_HandlePVF` channels (DR-1). Every dangerous PV passes BattlEye unfiltered.
- **`scripts.txt` is absent** (verified by name across the whole repo), as are `createvehicle.txt`, `remoteexec.txt`, `setvariable.txt`, `setpos.txt`, `mpeventhandler.txt`, etc. `scripts.txt` is the filter that would blunt the **DR-1 `call compile` RCE** and script-command injection (`createVehicle`/`setDamage`/`call compile`), so its absence is the more security-relevant gap of the two.
- The directory also contains a 716 KB `READ ME FIRST - Using BattlEye filter to auto kick.docx`. Per the project's untrusted-content rule it was **not parsed** (binary Office doc); regardless, the *operative deployed artifact* is the 22-byte stub, and admin documentation is not a control.

**Campaign-wide implication (the point of this pass).** The two-option framing in DR-1/6/14/16/22/23/27/28 is misleading as-shipped: option (b) "rely on BattlEye" is **not a deployed reality** — choosing it means authoring and maintaining a full BE filter set from scratch (a restrictive `publicvariable.txt` default-deny + whitelist of the legitimate `WFBE_PVF_*`/direct channels keeping `kickAFK`, **plus** a `scripts.txt`), which is a non-trivial, error-prone, separate workstream for a Warfare mission with hundreds of PVs and easy to break legitimate play. The realistic remediation for the entire forgery/economy class therefore collapses toward **(a) server-side authority in SQF** (re-derive the requester/role/funds in each PVF handler before applying effects, per DR-1/DR-6), with a real BE filter set as defense-in-depth only if someone owns it.

**Honest caveat (do not overstate).** BattlEye filter files are normally deployed in the **server's** BE working directory (the `BEpath`), *outside* the mission PBO — so their absence from this repo does not prove the production server lacks them. But the repository, as the campaign's source of truth, ships only the stub; whether `ocd-clan.com`/Miksuu's live server maintains a fuller filter set is an **explicit owner question**, not a safe assumption. The wiki should keep stating (as it already does) that PVF spoofing "must not be considered protected by BattlEye."

**Owner decision / handoff for Codex.** No wiki rewrite needed — the existing BattlEye text is accurate and in-lane for Codex. This finding's value is the cross-link: add a one-line note to the DR-1 remediation playbook and the [External integrations](External-Integrations) BattlEye section that *"option (b) requires building the filter set; it is not present in-repo (only the `kickAFK` stub),"* and pose the production-BE-config question to the server owner. Bundle the `scripts.txt`/`server.cfg`/`basic.cfg` absences (also flagged by the `Gibbs` scout) into the same hosting-hardening owner item.

**Outcome:** Integrations row — **BattlEye sub-target reviewed (DR-30)**. AntiStack DB (DR-7..DR-10), Extension (DR-29) and BattlEye (DR-30) now done; only the **Discord data path remains ⬜** within the bundle. Every prior economy/forgery finding's option (b) is now annotated as "not shipped."

## Round 22 — 2026-06-02 (Claude) — Discord data path (DR-31) — the DR-29 deserialization landmine is LIVE in the bot, with `TypeNameHandling.All`

Lane `discord-datapath-review`. Reviewed the in-repo `DiscordBot/` (.NET / Discord.Net) end-to-end — the **consumer** side of the GLOBALGAMESTATS extension (DR-29), closing the last Integrations sub-target. The data path is: Arma server → GLOBALGAMESTATS extension writes `C:\a2waspwarfare\Data\database.json` (DR-29) → DiscordBot reads it on a 60 s timer → posts a game-status embed. Net: secret hygiene is good, the inbound command surface is properly auth-gated, but the deserialization sink I flagged as *dormant* in the extension (DR-29 #2) is **active here, and worse**.

### DR-31 — DiscordBot deserializes `database.json` with `TypeNameHandling.All` on a 60 s timer — live insecure-deserialization gadget sink in the token-holding process — **High (insecure deserialization; local-write-gated RCE)**

Source-verified:
- **The active load path uses `TypeNameHandling.All`.** `GameData.LoadFromFile()` (`DiscordBot/src/ExtensionData/GameData/GameData.cs:49-56`) builds `new JsonSerializerSettings { … TypeNameHandling = TypeNameHandling.All … }` and `JsonConvert.DeserializeObject<GameData>(json, …)` on the contents of `database.json`. `TypeNameHandling.All` honors `$type` directives for the root **and every nested object/array** — the canonical Newtonsoft gadget sink (e.g. `ObjectDataProvider` → arbitrary `Process.Start`).
- **It runs automatically every 60 s, no interaction.** `GameStatusUpdater` (`src/GameStatusUpdater.cs:9,19-22,84`) arms a `System.Timers.Timer` at `UPDATE_INTERVAL_SECONDS = 60` with `AutoReset = true` and calls `LoadFromFile()` each tick. Two more live callers: `ProgramRuntime.cs:15` (startup) and `CommandHandler.cs:211` (`CreateGameStatusEmbed`). So the sink is exercised continuously regardless of any auth.
- **The capability is gratuitous.** `GameData`'s only state is `[DataMember] private string[] exportedArgs` (`GameData.cs:30`) — a flat string-array DTO with no polymorphism. The writer (the extension, DR-29) serializes with `TypeNameHandling.None` and emits no `$type`. The reader therefore needs **`.None`**; requesting `.All` adds nothing but the gadget sink. (A second, *dead* copy `GameDataDeSerialization.HandleGameDataCreationOrLoading` uses `TypeNameHandling.Auto` — no callers, grep-confirmed; should be deleted too.)
- **Trigger & blast radius.** Not remotely exploitable as-configured: `database.json` is normally written only by the trusted local extension. But any write-primitive to `C:\a2waspwarfare\Data\database.json` — a misconfigured ACL/share on `DataSourcePath`, a malicious mod or compromised Arma process writing there, or a future feature that ingests untrusted data into that file — yields **arbitrary code execution in the DiscordBot process**, which holds the Discord bot token (→ token theft + full bot/guild control). Classic local insecure-deserialization escalation.

**Owner decision / fix (trivial).** Change `GameData.LoadFromFile()` to `TypeNameHandling.None` (the data is a flat DTO; no behavior is lost) and delete the dead `.Auto` method. This also retro-closes DR-29 #2: keep the extension's deserialize path `.None` if it is ever reinstated. Defense-in-depth: lock down the ACL on `C:\a2waspwarfare\Data` so only the Arma service can write it.

**Secondary observations (Low / informational):**
- **Secret hygiene is good — resolves the external reports' "Discord sample hygiene" item.** `DiscordBot/.gitignore` excludes `token.txt` and `preferences.json`; `preferences_sample.json` contains **no token**. Minor: the sample commits a real-looking `GuildID` (`440257265941872660`) and one `AuthorizedUserIDs` snowflake — these are Discord IDs, not credentials (knowing an admin's user ID grants nothing without being that user), but a sample is cleaner with placeholder zeros.
- **Inbound command surface is correctly gated.** Slash-command handlers check `Preferences.Instance.IsUserAuthorized(userId)` (`CommandHandler.cs:49,127`) before privileged actions — no missing-authorization finding there.
- **Three-way `exportedArgs` shape drift (coupling smell).** The array is `new string[2]` in the extension (DR-29), `new string[4]` in the bot (`GameData.cs:30`), while the SQF sender emits **5** data fields and the bot reads index `[4]`. Held together only by wholesale `= _args` replacement on deserialize + bounds-guards (`Length > 4`, added after the commented unguarded `GetGameMapAndPlayerCount` at `GameData.cs:138-145`). Benign today, but the three sides of the contract disagree on the shape — document the canonical 5-field layout (`[0]bluforScore [1]opforScore [2]worldName [3]uptime [4]playerCount`) in one place.

**Handoff for Codex.** Document the Discord data path in [External integrations](External-Integrations): one-way pull (extension writes JSON → bot reads on 60 s timer → status embed), secret hygiene OK, command surface auth-gated; flag the `TypeNameHandling.All` fix as the one actionable code-owner item and cross-link DR-29/DR-31. These are code artifacts, logged here for traceability.

**Outcome:** Integrations row — **Discord sub-target reviewed (DR-31); all four sub-targets (AntiStack DB, Extension, BattlEye, Discord) now done.** Map cell can move to ✅. The DR-29 deserialization concern is now closed end-to-end (dormant in writer, live in reader, one-token fix).

## Round 23 — 2026-06-02 (Claude) — generated-mission drift (DR-32): vanilla faithful, modded forks divergent, 4 modded stubs abandoned

Lane `generated-mission-drift-review`. Cross-cutting Drift pass: file-set + byte-level comparison of the Chernarus **source** mission against every generated mission (1 vanilla + 7 modded), to establish whether the DR-1..DR-31 findings (all verified against Chernarus) propagate, and whether LoadoutManager generation introduces divergence. This is the single highest-leverage Drift result — it characterizes the Drift dimension for **all** subsystems at once.

### DR-32 — Generated missions fall into three fidelity tiers; modded missions are divergent forks or abandoned stubs, so source fixes do not propagate to them — **Medium (maintainability / drift) + abandoned-code inventory**

Method: relative-path file-set `comm` + per-file `cmp` of all source `.sqf` against each generated mission. Results (differing/common `.sqf`):

| Generated mission | differ/common .sqf | Tier |
| --- | --- | --- |
| `Missions_Vanilla/…takistan` | **15 / 671** | **Faithful** |
| `Modded_Missions/…Napf` | 123 / 466 | Divergent fork |
| `Modded_Missions/…eden` | 119 / 465 | Divergent fork |
| `Modded_Missions/…lingor` | 104 / 417 | Divergent fork |
| `Modded_Missions/…smd_sahrani_a2` | 4 / 4 (4 files total) | Abandoned stub |
| `Modded_Missions/…dingor` | 3 / 3 (20 files total) | Abandoned stub |
| `Modded_Missions/…tavi` | 2 / 2 (3 files total) | Abandoned stub |
| `Modded_Missions/…isladuala` | 1 / 1 (1 file total) | Abandoned stub |

1. **Vanilla Takistan is a faithful regeneration.** Only 15 `.sqf` differ, and all are map-config, not logic: the per-faction `Core_Artillery/Artillery_*.sqf`, `Config_GUE.sqf`, `GUI_Menu_Help.sqf`, `WASP/unsort/StartVeh.sqf`, and **`Server/Init/Init_Server.sqf` whose sole diff is one line** — `["SET_MAP", 1]` → `["SET_MAP", 2]` (the AntiStack DB map identifier). Plus textures (US/CDF skins → desert skins) and 3 extra native `Artillery_{TKA,TKGUE,US}.sqf`. **All other 656 logic files are byte-identical.** → **Every DR-1..DR-31 finding propagates verbatim to vanilla Takistan; a fix to the Chernarus source + regen corrects both.** The Drift dimension for the source→vanilla path is clean.

2. **Napf / eden / lingor are heavily divergent full forks.** 104–123 of ~465 logic files differ from source — including security-critical files I reviewed: `Server_HandlePVF.sqf` (DR-1), `Server_HandleSpecial.sqf` (DR-27), `server_victory_threeway.sqf` (DR-11), `Server_ProcessUpgrade.sqf` (DR-23), `Server_OnHQKilled.sqf` (DR-20), `Server_OnPlayerDisconnected.sqf` (DR-21), `Init_PublicVariables.sqf`, `initJIPCompatible.sqf`. The divergence is **hand-customized behavior, not just config**: e.g. Napf's `Server_HandleSpecial.sqf` "ICBM" case additionally spawns three `BO_GBU12_LGB` laser-guided bombs around the target (absent in source). This is consistent with **DR-4** (modded propagation is commented out at `Tools/LoadoutManager/.../SqfFileGenerator.cs:132`) — the modded missions are **not** regenerated from source; they are independent forks. **Consequence:** a fix to the Chernarus source does **not** reach Napf/eden/lingor; the DR vulnerability *classes* almost certainly persist there (same architecture) but at different lines/with different effects, so each fork needs its own review and manual fix propagation.

3. **smd_sahrani_a2 / dingor / tavi / isladuala are abandoned stubs.** 1–20 files each (a real mission is ~786 files / ~671 `.sqf`); they are missing `Server/`, `mission.sqm`, the `WASP/` overlay, `description.ext`, and essentially all logic. They cannot load as functional Warfare missions. These are incomplete scaffolds committed to the repo — an **abandoned-code/inventory** item.

**Owner decisions / handoff.** Three explicit choices for the code owner, all logged for Codex to fold into [Tools and build workflow](Tools-And-Build-Workflow) / a generated-mission status table (Codex's lane):
- **Stub missions (sahrani/dingor/tavi/isladuala):** complete via regeneration or **remove** them — they are dead weight and misleading as "supported maps."
- **Divergent forks (Napf/eden/lingor):** pick a maintenance model — (a) re-enable modded propagation (DR-4) and regenerate from the hardened source, accepting loss of the hand-customizations (e.g. Napf's GBU ICBM), or (b) formally treat them as independent forks and apply every DR-1..DR-31 fix to each by hand. Today they silently drift.
- **All security fixes:** apply to the Chernarus source first (propagates to vanilla Takistan on regen), then deliberately propagate to the 3 forks.

**Outcome:** Drift dimension characterized across the whole codebase. Source→vanilla path is faithful (DR findings transfer verbatim); modded missions are out-of-scope forks/stubs flagged here. Ledger Drift cells updated to reference DR-32 (faithful-to-vanilla ✅; modded divergence is an owner decision, not a review gap).

## Round 24 — 2026-06-02 (Claude) — factory/production Perf + JIP/HC (DR-33)

Lane `factory-perf-jip-review`. Filled the two ⬜ cells on the Factory/purchase row by source-reviewing the unit-production path: `Client/GUI/GUI_Menu_BuyUnits.sqf` (queue gate) → `_params Spawn BuildUnit` → `Client/Functions/Client_BuildUnit.sqf` (the production loop), plus the `WFBE_C_QUEUE_*` counters seeded in `Client/Init/Init_Client.sqf`. Production runs entirely on the **buyer's client** (`group player`, local `CreateUnit`/`CreateVehicle`). Two real defects (one JIP/HC, one Perf) plus a network-churn note.

### DR-33a — Empty-vehicle purchase leaks the buyer's `WFBE_C_QUEUE` counter → silent per-factory soft-lock — **Medium (JIP/HC / client-state leak)**

`WFBE_C_QUEUE_<type>` is a **client-local** counter (seeded in `Init_Client.sqf:185+`, e.g. `BARRACKS_MAX=10`, `LIGHT_MAX/HEAVY_MAX=5`). The buy gate increments it before producing and blocks at the cap:
- `GUI_Menu_BuyUnits.sqf:145-146`: `if (WFBE_C_QUEUE_<type> < WFBE_C_QUEUE_<type>_MAX) then { …+1; _params Spawn BuildUnit }` else `:158` "queue max" hint.
- `Client_BuildUnit.sqf:469` decrements it **at the normal tail** of the script.

But the vehicle branch has an early `if (!_driver && !_gunner && !_commander) exitWith {}` (`Client_BuildUnit.sqf:365`) — for a **crewless vehicle purchase** (all crew unchecked, a legitimate option) — which returns *before* the tail decrement at `:469`. So each empty-vehicle buy permanently increments the buyer's local queue counter without ever decrementing it. After `_MAX` such purchases (5 for Light/Heavy) the GUI gate at `:145` silently refuses all further production from that factory type for the rest of the match — a slow soft-lock that presents as a mysterious "can't buy / queue full" with nothing actually queued. Reachable in normal play. **Fix:** move the `WFBE_C_QUEUE` (and `unitQueu`, `:467`) decrements before/around the empty-vehicle `exitWith`, or restructure so all exit paths decrement (e.g. a single cleanup block).

### DR-33b — Per-unit `sleep 4` queue poll re-broadcasts the building's queue on every mutation; non-unique queue token — **Low/Medium (Perf / network churn + latent correctness)**

- **Network churn.** Each queued unit gets its own `Spawn BuildUnit`, which busy-waits `while {_unique != _queu select 0 …} { sleep 4; … }` (`:180-199`) and writes `_building setVariable ["queu", _queu, true]` — a **global broadcast** — on every enqueue (`:172`), timeout-advance (`:191`) and completion (`:207`). With several factories producing across a full server, every 4 s tick that advances or cleans a queue broadcasts that building's whole `queu` array to all machines. Bounded but avoidable; consider a server-owned queue or a non-broadcast local timer.
- **Non-unique token.** The per-item identity is `varQueu = random(10)+random(100)+random(1000)` (`:168`) — a ~0–1110 value space, **not unique**. Two concurrently-queued items can collide on `_unique`, breaking the `_unique != _queu select 0` front-of-queue test (an item may wait forever or two may think they're first). Low probability per pair but non-zero on a busy factory. **Fix:** use a monotonic counter or `diag_tickTime`-seeded id.
- **Orphan token on disconnect (minor).** Because the loop + the front-token removal (`:206`) run on the buyer's client, a buyer disconnecting mid-production leaves their `_unique` token in the building's broadcast `queu`; it self-heals only if another buyer is queued behind to run the `_ret > _longest` timeout-cleanup (`:187-192`). The local `WFBE_C_QUEUE` counter is not leaked across clients (it dies with the buyer). Stale shared data, low impact.

**Handoff for Codex.** Document the production queue model in the [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas): client-owned per-unit producer, broadcast `queu` token list, per-client `WFBE_C_QUEUE` caps. The two fixes (DR-33a decrement-on-all-paths; DR-33b unique token + reduce broadcast) are concrete code-owner items, not architectural decisions. Note DR-33a propagates to vanilla Takistan verbatim (DR-32) and likely exists in the 3 forks too.

**Outcome:** Factory/purchase row — **Perf and JIP/HC cells filled (DR-33)**. The row's remaining 🟡 (Auth/PV) is the DR-14 client-authoritative-purchase architectural ceiling (economy class, owner decision).

## Round 25 — 2026-06-02 (Claude) — respawn / MASH markers (DR-34): MASH map-marker feature is dead on both ends

Lane `respawn-mash-review`. Reviewed the respawn UI (`Client/Functions/Client_UI_Respawn_Selector.sqf`) and the MASH respawn-marker chain (`Server/Module/MASH/MASHMarker.sqf` ↔ `Client/Module/MASH/receiverMASHmarker.sqf`), with wiring confirmed in `Init_Client.sqf` / `Init_Server.sqf`. Extends the earlier DR-2 note ("MASH markers are dead receive-side") to a full both-ends diagnosis.

### DR-34 — MASH map-marker feature is fully dead (send trigger never broadcast + client receiver commented out); the live server PVEH is orphaned — **Low/Medium (broken/abandoned feature; UX)**

MASH tents are a real deployable officer feature (`Client/Module/Skill/Actions/Officer_Undeploy_MASH.sqf` exists), but the **map marker that should show a team its MASH locations does nothing**, because all three links are broken or orphaned:

1. **Client receiver is commented out.** `Init_Client.sqf:132`: `//WFBE_CL_FNC_ReceiverMASHmarker = Call Compile preprocessFileLineNumbers "Client\Module\MASH\receiverMASHmarker.sqf";` — so no client ever registers the `WFBE_SE_MASH_MARKER_SENT` event handler; the receiver in `receiverMASHmarker.sqf` is never installed.
2. **The trigger PV is never broadcast.** `WFBE_CL_MASH_MARKER_CREATED` appears in the repo **only** as the server's `addPublicVariableEventHandler` registration (`MASHMarker.sqf:1`). No client deploy path ever does `WFBE_CL_MASH_MARKER_CREATED = […]; publicVariable …`, so the server handler can never fire.
3. **The server handler is live but orphaned.** `Init_Server.sqf:70` actively compiles `WFBE_SE_FNC_MASH_MARKER` (= `MASHMarker.sqf`), registering a PVEH for a PV (`WFBE_CL_MASH_MARKER_CREATED`) that nothing emits — harmless dead weight that *looks* active in a grep but does nothing in composition. (Line 92 is a duplicate, commented.)

Net: deployed MASH tents produce **no map markers** for the owning side. Confirms and extends DR-2.

**Latent JIP gap if revived (note for whoever fixes it).** Even with both ends re-enabled, the marker is delivered by `publicVariable "WFBE_SE_MASH_MARKER_SENT"` — a single global **overwritten on each deploy** (not a list) and **not replayed to join-in-progress clients**. So a revived feature would: (a) show JIP joiners no markers for MASH deployed before they joined, and (b) only ever carry the most-recent MASH in the synced value. A correct revival needs a server-held list + a JIP re-send on join (the same pattern the construction/HQ-killed code uses via `Server_HandleSpecial` "set-…" re-sends).

**Secondary (Low):**
- **Respawn selector is a ~33 Hz local loop.** `Client_UI_Respawn_Selector.sqf:19-33` runs `while {!isNil 'WFBE_MarkerTracking'} do { sleep 0.03; … }`, animating a pulsing **local** marker (`setMarkerDirLocal`/`SizeLocal`/`PosLocal`) — network-free and bounded to while the respawn UI is open, but `sleep 0.03` cannot be honored by the SQF scheduler so it effectively runs every frame. Acceptable for a transient UI; flagged for completeness.
- **Non-unique marker name (dead code, DR-33b class).** `receiverMASHmarker.sqf:12` builds the marker name with `round random 50000` (collision-prone) and later deletes a `createMarkerLocal` marker with the global `deleteMarker` (local/global mismatch). Moot while the receiver is disabled; fix if revived.

**Handoff for Codex.** Mark the MASH map-marker feature as **dead/abandoned** in the [Feature status register](Feature-Status-Register) and the relevant marker/respawn docs (Codex's lane), with the revival recipe above (server-held list + JIP re-send + unique names + fix `publicVariable` JIP gap). Owner decision: revive the feature or remove the dead `receiverMASHmarker.sqf` + orphaned `Init_Server.sqf:70` registration.

**Outcome:** Markers/respawn — MASH marker chain reviewed (DR-34): dead both ends + orphaned server PVEH; respawn selector Perf characterized. Markers row PV/JIP-HC cells reference DR-34.

## Round 26 — 2026-06-02 (Claude) — parameters / localization integrity (DR-35): clean, with 2 dead-action confirmations

Lane `params-localization-review`. Reviewed the two never-covered cross-cutting areas: **localization integrity** (do `localize`/`$STR_` references resolve?) and the **mission parameters** system. Result: localization is clean once case-folding and dead-code are accounted for; the params system is live and correctly wired.

### DR-35 — Localization integrity is clean (no live broken strings); parameters system is live and correctly wired; 2 dead WASP actions confirmed — **Informational (reviewed clean + abandoned-code)**

**Method matters (the trap that produces false findings).** Arma 2 OA stringtable lookup is **case-insensitive**, but text-diff tools are not. A naïve case-sensitive set-difference of the 204 static `localize "STR_…"` keys against the 1289 `stringtable.xml` keys reports 4 "missing"; after lowercasing both sides it drops to 3, and after checking each reference site for liveness it drops to **0 live bugs**:
- `STR_WF_UPGRADE_uav_Desc` — **false positive (casing)**: defined as `STR_WF_UPGRADE_UAV_DESC`; resolves at runtime.
- `STR_EP1_UAV_action_exit` (`Client/Module/UAV/uav_interface_oa.sqf:25`, live) — **engine-provided**: the `STR_EP1_*` namespace is supplied by the Arma 2 OA base game's global stringtable, not the mission; resolves at runtime.
- `STR_WASP_actions_OnArmor` and `STR_WF_Gear` — referenced **only in commented-out lines** (`WASP/actions/AddActions.sqf:4,10-12`, the dead "ride-on-armor" and "gear your unit" WASP actions). Dead code; the missing keys are moot.

Config-side `$STR_` references in `.hpp`/`.ext` (excluding engine `STR_EP1_`/`STR_DN_`/`STR_USRACT` prefixes) all resolve. So **no live missing-localization display bug exists.** The stringtable carries ~1085 keys not hit by any static `localize` — a large legacy surface typical of a long-lived WFBE fork, not a defect (some are reached by config `$STR_`, engine, or removed features).

**Parameters system — live and correct.** `Common/Init/Init_Parameters.sqf` iterates `missionConfigFile >> "Params"` and sets each `configName` as a `missionNamespace` variable, taking `paramsArray select _i` in multiplayer and the param's `default` in single-player. Wiring confirmed: `initJIPCompatible.sqf:121` runs it in MP; the parameter-display dialog is loaded via `Rsc/Dialogs.hpp:3136` (`onLoad ExecVM GUI_Display_Parameters.sqf`), defined in `Rsc/Parameters.hpp`. This is the canonical A2 OA pattern. One **fragility note** (not a defect): the `paramsArray select _i` ↔ `Params` iteration is **index-aligned**, so inserting/removing a param without keeping `class Params` order in sync would silently shift every later parameter's value — worth a comment in the config for future editors.

**Abandoned-code inventory (adds to DR-32/DR-34).** `WASP/actions/AddActions.sqf` contains commented-out `OnArmor` (ride-on-tank: `GetOnArmor.sqf`/`GetOnArmorBots.sqf`/`GetOutBots.sqf`) and `GearYourUnit` actions — dead WASP features whose localization keys were never added. Confirms the earlier "WASP OnArmor/KeyDown abandoned" suspicion.

**Handoff for Codex.** Optionally note in the [WASP overlay](WASP-Overlay) page that `AddActions.sqf` carries dead OnArmor/Gear actions, and add a one-line "keep `class Params` order stable (index-aligned to `paramsArray`)" caution to any parameters documentation (Codex's lane). No code defect to fix; the dead WASP actions are an owner cleanup decision (remove vs revive).

**Outcome:** parameters/localization reviewed — **clean**; localization integrity verified (no live broken keys), params system confirmed live/wired, 2 dead WASP actions logged. New ledger row **Parameters / localization** → reviewed-clean (DR-35).

## Round 27 — 2026-06-02 (Claude) — victory/endgame Perf + JIP/HC (DR-36); source mechanism for DR-11/DR-13

Lane `victory-perf-jip-review`. Filled the Victory/endgame Perf + JIP/HC cells by reviewing the loop in `Server/FSM/server_victory_threeway.sqf` (the **sole** victory FSM, `execVM`'d unconditionally at `Server/Init/Init_Server.sqf:528`) and the end-of-match DB-flush tail, and traced the win-condition expression to a source-level root cause for the previously-observed DR-11/DR-13.

### DR-36 — Victory loop Perf clean + JIP/HC server-authoritative; the win-condition guard/precedence is the source of DR-11/DR-13 double-fire — **Low (Perf/JIP clean) + Medium (the confirmed correctness bug)**

**Perf — clean.** The detection loop runs every `_loopTimer = 80` seconds (`:6,46`) with cheap per-side work (`GetSideHQ`/`GetSideStructures`/`GetTownsHeld` + 4× `GetFactories`, `:14-21`). No hot loop, no per-frame churn. Minor: `_innerTimer` is incremented (`:47`) but never read (dead variable); `_miniSleep = 0.05` paces only the one-time end-of-match per-player DB `STORE` (`:60-82`). No perf trap.

**JIP/HC — server-authoritative, one narrow gap.** Detection runs server-only on server-authoritative state; headless clients don't participate (correct). Endgame is pushed to clients via `[nil,"HandleSpecial",["endgame", sideID]] Call WFBE_CO_FNC_SendToClients` (`:24`); `gameOver`/`WFBE_GameOver` are set server-side (`:32-33`) and `WFBE_GameOver` is **not** broadcast. The only gap: a player joining in the brief endgame window (between the broadcast and `failMission "END1"` at `:88`) won't receive the outro, because `SendToClients` is not replayed to JIP joiners — moot in practice since the mission is tearing down.

**Confirmed source mechanism for DR-11 (winner inversion) + DR-13 (duplicate LogGameEnd).** The win check (`:23`):
```
if (!(alive _hq) && _factories == 0 || _towns == _total && !WFBE_GameOver) then {
```
By SQF precedence (`&&` binds tighter than `||`) this is `((!alive _hq) && _factories==0) || (_towns==_total && !WFBE_GameOver)` — so the **`!WFBE_GameOver` guard covers only the "holds-all-towns" clause, not the "HQ-destroyed elimination" clause**. Combined with the enclosing `forEach WFBE_PRESENTSIDES - [WFBE_DEFENDER]` (`:43`) having **no break/exit after a winner is declared**, if two sides are eliminated within the same 80 s tick the elimination clause fires again for the second side: a second `["endgame",…]` broadcast, a second `WFBE_CO_FNC_LogGameEnd` (`:41`), and `WF_Logic setVariable ["WF_Winner", _x]` (`:31`) overwritten with the *opposite* side (the `_side = west; if (_x==west) _side=east` swap at `:35-39` then logs the inverted winner). That is the exact mechanism behind DR-11's inverted persisted winner and DR-13's duplicate game-end. **Fix (one place):** parenthesize and guard both clauses with `!WFBE_GameOver`, and `exitWith`/break the `forEach` (and the `while`) once `gameOver` is set, so only the first-detected winner is recorded.

Also re-confirms **DR-12**: the detection block is gated by `if (_victory == 0)` where `_victory = WFBE_C_VICTORY_THREEWAY` (default 0). When threeway is *enabled* (`_victory != 0`), the entire detection block is skipped and the loop just sleeps — i.e. threeway mode has no victory detection.

**Handoff for Codex.** This is a code-owner fix already tracked under DR-11/DR-13; this round adds the precise `path:line` mechanism + the two-part one-line fix. No new wiki page needed — cross-link from the victory rows of [Feature status register](Feature-Status-Register) to DR-36 for the root cause.

**Outcome:** Victory/endgame row — **Perf and JIP/HC cells filled (DR-36)**: Perf clean, JIP server-authoritative (narrow endgame-join gap noted); DR-11/DR-13 now have a source-level mechanism + fix.

## Round 28 — 2026-06-02 (Claude) — boot/lifecycle Perf + JIP/HC (DR-37): reviewed clean, one robustness note

Lane `boot-lifecycle-perf-jip-review`. Filled the Boot/lifecycle Perf + JIP/HC cells by reviewing the role router (`initJIPCompatible.sqf`) and the client boot chain (`Client/Init/Init_Client.sqf`), with the wait-chain cross-referenced against [Lifecycle wait-chain](Lifecycle-Wait-Chain). Result: boot is well-architected for JIP and Perf-clean; one robustness gap worth a defensive fix.

### DR-37 — Boot Perf clean + JIP state-sync comprehensive; the post-join `waitUntil` chain has no timeouts (a never-set synced var hangs the JIP client) — **Low (reviewed clean + robustness note)**

**Perf — clean.** All boot blocking-waits are bare `waitUntil {cond}`, which the A2 OA scheduler evaluates once per frame and yields between (not a CPU busy-spin like a sleepless `while`), and every condition is cheap (`!isNil`, `!isNull player`, `time>0`, `!isNil {logic getVariable …}`). One wait uses the throttle idiom `waitUntil {sleep 0.5; visibleMap}` (`Init_Client.sqf:248`) — deliberately evaluates every 0.5 s instead of per-frame, a good pattern. The `while {true} { sleep 0.1; … exitWith … }` loops at `Init_Client.sqf:419/444` are **not** perpetual 10 Hz loops — they are bounded join-handshake polls (see below) that exit on ACK. No boot perf trap. (The genuinely long-running client loops — RHUD/marker updaters at `:522/:864` — belong to the UI/Markers rows already covered, each with its own internal `sleep`.)

**JIP/HC — comprehensive and correct.** `initJIPCompatible.sqf` routes roles cleanly: server (`isHostedServer || isDedicated`), client part II (`isHostedServer || (!isHeadLessClient && !isDedicated)`), headless (`isHeadLessClient`). A JIP client:
- syncs time/date via the engine-synced `WFBE_DAYNIGHT_DATE` (or `skipTime (time/3600)` catch-up on the disabled path) — `:189-205`, reviewed clean in Round 17;
- syncs teams by waiting on the synced `WFBE_PRESENTSIDES` then per-side `wfbe_teams` (`:225-234`);
- pulls all remaining client state from broadcast logic-object variables via a serial `waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_…"}}` chain (`Init_Client.sqf:367-502`: structures, commander, radio_hq(+id), startpos, hq, hq_deployed, votetime).
- **Robust join handshake:** the `RequestJoin`→ACK poll (`:416-429`) polls at 10 Hz, **re-sends after a 30 s timeout**, and fails the client back to the lobby on team-stack/swap — a well-defended one-time handshake.

**The one robustness gap.** Unlike the join handshake, the **post-join state-sync `waitUntil` chain has no timeouts**. Each step blocks on a synced `wfbe_*` logic variable; in normal operation all are reliably `setVariable [...,true]` server-side so the chain completes, but if a server-side regression ever fails to set one (e.g. `wfbe_radio_hq_id`, `:397`), the JIP client **hangs forever at that step with no fallback or log past it** — presenting as a "stuck on black screen at join" with no diagnostic. Not a live bug (the variables are set today), but a fragility: consider a `waitUntil {!isNil … || (_t = _t + …; _t > N)}` timeout with a logged warning, mirroring the handshake's own retry discipline.

**Handoff for Codex.** No code defect to fix and no wiki rewrite needed; optionally note in [Lifecycle wait-chain](Lifecycle-Wait-Chain) that the post-join `wfbe_*` waits are timeout-less (a single missed server broadcast = permanent JIP hang) as a known robustness characteristic. Owner decision: add defensive timeouts or accept the current fail-silent behavior.

**Outcome:** Boot/lifecycle row — **Perf and JIP/HC cells reviewed clean (DR-37)**; role routing + JIP state-sync confirmed correct; timeout-less post-join wait-chain logged as a robustness note.

## Round 29 — 2026-06-02 (Claude) — PV/networking dispatch Perf + JIP/HC (DR-38): the per-message recompile = the DR-1 fix

Lane `pv-dispatch-perf-jip-review`. Filled the PV-dispatch Perf + JIP/HC cells by reviewing the dispatch hot path (`Server/Functions/Server_HandlePVF.sqf`, `Client/Functions/Client_HandlePVF.sqf`) and the registration/precompile in `Common/Init/Init_PublicVariables.sqf`. (Auth/PV/RCE already covered by DR-1.)

### DR-38 — PVF dispatch recompiles the command string per inbound message; the lookup that fixes DR-1's RCE also removes the recompile. JIP/HC clean — **Low/Medium (Perf, converges with DR-1) + JIP reviewed clean**

**Perf.** Both dispatchers end with `_parameters Spawn (Call Compile _script)` (`Server_HandlePVF.sqf:14`, `Client_HandlePVF.sqf:22`), so **every inbound PVF message runtime-compiles the sender-provided command string**. This is per-action (build/buy/construct/upgrade/join/server-pushes), not per-frame, so bounded — but it is **avoidable and redundant**: `Init_PublicVariables.sqf` already **pre-compiles every PVFunction once at init** into `SRVFNC<name>`/`CLTFNC<name>` globals (`:44` `CLTFNC%1 = compile preprocessFileLineNumbers …`, `:49` `SRVFNC%1 = …`), and binds the per-command `WFBE_PVF_<name>` channels to the dispatchers (`:45,50`). The dispatcher discards that precompiled work and recompiles the string each message. Resolving the handler by lookup — `call (missionNamespace getVariable _validatedName)` against the known `SRVFNC*`/`CLTFNC*` set — eliminates the per-message `compile` entirely. **This is the same change as the DR-1 remediation**: validating/looking up a name instead of `compile`-ing a sender-chosen string closes the RCE *and* the recompile in one edit. (Secondary: `Spawn` per message creates a scheduled script per message — justified because handlers use `sleep`/`waitUntil`, but it adds scheduler pressure under PVF floods; lower priority.)

**JIP/HC — clean.** The dispatchers are registered via `addPublicVariableEventHandler` on the `WFBE_PVF_<name>` channels in `Init_PublicVariables.sqf` (`:45` client `if (!isServer || local player)`, `:50` server `if (isServer)`), which runs inside `Init_Common` on **every** machine including JIP clients during their own init — so a joiner installs its PVF handlers on join and processes all subsequent messages. PVFs are **transient events, not state**, so nothing needs replaying to joiners (the only replay burden is the separate broadcast-variable state-sync layer, DR-37). The client destination routing (`Client_HandlePVF.sqf:12-15`: nil = broadcast, `SIDE` = `sideJoined` match, `STRING` = `getPlayerUID player` match) resolves correctly for joiners. No JIP gap in the dispatch layer; no headless-specific dispatch issue beyond the AI-delegation locality already covered in DR-21.

**Handoff for Codex.** No new wiki page; fold the Perf observation into the [Networking](Networking-And-Public-Variables) DR-1 remediation note as "the validated-lookup fix also removes a per-message `compile`," so the owner sees the security fix is free on Perf. JIP-clean result can be stated in the same section.

**Outcome:** PV/networking dispatch row — **Perf and JIP/HC cells filled (DR-38)**: Perf = avoidable per-message recompile (fixed by the DR-1 lookup change); JIP/HC reviewed clean. The row's remaining work is the DR-1 owner decision (validate-before-execute), which now also carries a Perf benefit.

## Round 30 — 2026-06-02 (Claude) — supply missions Perf + JIP/HC (DR-39): dead twin loop + pull-based JIP done right

Lane `supply-missions-perf-jip-review`. Filled the Supply-missions Perf + JIP/HC cells by reviewing the server module (`Server/Module/supplyMission/*`) and its client consumers (`Client/Module/supplyMission/*`). (Auth covered by DR-18 cooldown-casing + the PR#1 helicopter review.)

### DR-39 — Dead duplicate `supplyMissionActive.sqf`; live loop scans all objects every 3 s; JIP cooldown status is correctly pull-based — **Low/Medium (abandoned-code + Perf; JIP reviewed clean)**

**Abandoned-code: a dead twin.** Two near-identical supply-mission tracking loops exist. The **live** one is `supplyMissionStarted.sqf` — it self-registers `"WFBE_Client_PV_SupplyMissionStarted" addPublicVariableEventHandler { … }` (`:1`), so compiling it (Init_Server `:68` → `WFBE_SE_FNC_SupplyMissionStarted`) installs the handler. The **dead** one is `supplyMissionActive.sqf` — a plain function body (no PVEH; takes `_this select 0/1/2`, runs `while {alive _truck && !_completed} {sleep 2}`), compiled to `WFBE_SE_FNC_SupplyMissionActive` (Init_Server `:81`) but **never called anywhere** (grep-confirmed: no caller, no self-registration). It is the superseded older twin of `supplyMissionStarted`'s spawn body (same `LastSupplyMissionRun` set, same `SupplyMissionTimerForTown` spawn, same truck-alive poll). **Owner cleanup:** delete `supplyMissionActive.sqf` + its `Init_Server:81` compile, or wire it if a second path was intended. Adds to the abandoned-code inventory (DR-32/DR-34/DR-35 class).

**Perf (live path).** Each active supply mission spawns one server-side `while {alive _associatedSupplyTruck} { sleep 3; … }` loop (`supplyMissionStarted.sqf:20-69`). The per-tick cost is `nearestObjects [(getPos _truck), [], 80]` (`:28`) — an **all-object-types** scan in an 80 m radius every 3 s, just to detect a `Base_WarfareBUAVterminal`. Bounded by the number of concurrent supply missions (usually few), so not severe, but the empty type filter `[]` is wasteful: narrowing to `nearestObjects [pos, ["Base_WarfareBUAVterminal"], 80]` lets the engine cull by type and avoids walking every nearby object. The heavy nested `WFBE_SE_PLAYERLIST × nearestObjects[...,8]` scan (`:31-57`) runs only once at delivery (inside `exitWith`), so it's fine.

**JIP/HC — handled well (the positive counterexample to DR-34).** Supply-mission *cooldown status* uses an **on-demand request/response**, not a fire-and-forget push: a client broadcasts `WFBE_Client_PV_IsSupplyMissionActiveInTown`; the server PVEH (`isSupplyMissionActiveInTown.sqf`) computes the cooldown from `_sourceTown getVariable "LastSupplyMissionRun"` vs `WFBE_CO_VAR_SupplyMissionRegenInterval` and answers via `WFBE_Server_PV_IsSupplyMissionActiveInTown`; the client (`townSupplyStatus.sqf`) stores it per-town. So a **JIP joiner gets correct state simply by asking** — no replay logic needed, unlike the MASH marker (DR-34) which pushed once and missed joiners. The per-mission tracking loop is **server-side** and keyed on the truck object, so it correctly survives the starting player's disconnect (truck ownership migrates to the server, DR-21). Minor: the cooldown answer is broadcast to *all* clients (`publicVariable`, `:18`) rather than targeted to the requester — every client re-stores the town's cooldown on each query (small redundant network; could target the asker). The DR-18 `LastSupplyMissionRun` casing concern lives in this subsystem and is already filed.

**Handoff for Codex.** Note the dead `supplyMissionActive.sqf`/`WFBE_SE_FNC_SupplyMissionActive` in the [Supply mission architecture](Supply-Mission-Architecture) page (Codex's lane) as an abandoned duplicate; record the pull-based cooldown query as the JIP-correct pattern. Code-owner items: remove the dead twin; narrow the `nearestObjects` filter; optionally target the cooldown response.

**Outcome:** Supply missions row — **Perf and JIP/HC cells filled (DR-39)**: Perf = all-object `nearestObjects` poll (narrowable) + dead twin loop; JIP reviewed clean (pull-based status, server-side tracking). The row's Auth 🟡 remains the DR-18 + PR#1 items (owner).

## Continue Reading

Previous: [Agent worklog](Agent-Worklog) | Next: [Implementation plan](Documentation-Implementation-Plan)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

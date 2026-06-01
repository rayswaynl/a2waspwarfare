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

## Continue Reading

Previous: [Agent worklog](Agent-Worklog) | Next: [Implementation plan](Documentation-Implementation-Plan)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

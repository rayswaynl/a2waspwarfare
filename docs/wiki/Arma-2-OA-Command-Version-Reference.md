# Arma 2 OA — SQF command version reference (A3 contrast)

> Independent BIKI-verified **version-evidence companion** to the canonical [External Arma 2 OA reference guide](Arma-2-OA-External-Reference-Guide). That page maps concepts → references and how-to-use; **this page is the dated provenance log**: the *first game / version* of each command this fork touches, so an agent can decide at a glance whether a command is safe for the **Arma 2 OA 1.63 / 1.64** target. Verified read-only against the Bohemia Community Wiki (`community.bistudio.com`) on 2026-06-02 — reading a command's version badge needs no account.

## Why this matters
The fastest way to break OA mission SQF is to "fix" it with Arma 3 reflexes: many everyday A3 commands simply did not exist in 2010–2013 and throw *undefined command* errors on OA. This page is the quick yes/no, with the OA-safe replacement.

## Arma 3-only — do NOT use in OA mission SQF

| Command / form | First game · version | Arma 2 OA replacement |
| --- | --- | --- |
| `params ["_a","_b"]` | Arma 3 · 1.48 | `private ["_a","_b"]; _a = _this select 0; _b = _this select 1;` |
| `setGroupOwner` / `groupOwner` | Arma 3 · 1.40 | **No equivalent** — OA cannot transfer group locality; it follows the group leader's owner. (Impacts DR-21 HC re-delegation: you can redirect *future* spawns to a surviving HC, but cannot transfer live AI.) |
| `array select [start, count]` | Arma 3 · 1.32 | single-index `select N`, or build with `for`/`forEach`. |
| `string select [start, length]` (substring) | Arma 3 · 1.28 | `toArray` / `toString` (no native substring in OA). |
| `array select {expression}` (filter) | Arma 3 · 1.56 | `{ if (cond) then { … } } forEach _arr`. |
| `array apply {expression}` (map) | Arma 3 · 1.56 | `{ _x = f _x } forEach _arr`, or build a new array in a `for`/`forEach` loop. Source has **zero** `apply` array-command uses (only the English word in comments); it previously appeared in a draft doc fix-snippet and is kept here as a regression warning. |
| `isEqualType` | Arma 3 · 1.54 | `typeName _x == "ARRAY"` (etc.). |
| `remoteExec` / `remoteExecCall` | Arma 3 · 1.50 | `publicVariable` + `addPublicVariableEventHandler` (this mission's PVF wrappers). |
| `parseSimpleArray` | Arma 3 · 1.68 | `call compile` — trusted input only (see DR-1 / DR-7 / DR-46). |
| `ext callExtension [fn, args]` (array form) | Arma 3 · 1.68 | string form: `ext callExtension "code,args"`. |
| `private _x = value` (inline-assign) | Arma 3 style | `private "_x"; _x = value;` |

## Confirmed available in Arma 2 OA

| Command / form | First · version | Note |
| --- | --- | --- |
| `obj getVariable ["name", default]` | ArmA 1.00 (obj/group); **OA 1.60** (namespace) | Default-value form is OA-safe on `missionNamespace`. CAVEAT: on `objNull`, A2 returns *undefined*, not the default (A3 fixed this). |
| `obj setVariable ["name", val, true]` | ArmA 1.00 | Public-broadcast 3rd arg is OA-safe. |
| `publicVariableServer` / `publicVariableClient` | **OA 1.62** | client→server / server→one-client targeting. |
| `callExtension` (string form) | **OA 1.60** | Blocking — keep out of hot loops. |
| `diag_tickTime` | **Arma 2 · 1.00** | Real-time, high-precision elapsed seconds; **unscaled** and does not pause with game time. Commonly mis-remembered as A3-only, but it is A2-era and OA-safe — the correct clock for perf instrumentation. Repo uses it as the `PerformanceAudit_Record` stopwatch (~62 files, e.g. `Client/Client_UpdateRHUD.sqf:187`). Do **not** "modernize" it away. |
| `uiSleep` | **Arma 2 · 1.05** (also OA 1.50) | Like `sleep` but **not** scaled by accelerated/skipped game time — suspends on real-time cadence (correct for server housekeeping loops). Also frequently assumed A3-only; it is OA-safe. Repo uses it in the AntiStack loops (`Server/Module/AntiStack/mainLoop.sqf:16`, `flushLoop.sqf`) and `Server/FSM/restorers/buildings_restorer.sqf:26` (7 files). |
| `allGroups`, `call`, `compile`, `preprocessFileLineNumbers`, `typeName`, `isNil`, `format`, `localize`, `hintSilent`, `diag_log`, `diag_fps`, `publicVariable`, `addPublicVariableEventHandler`, `toArray`, `toString` | OFP / ArmA / A2 | All OA-safe. |

## OA-safe but removed in Arma 3 — the inverse trap

These commands **exist and work in OA 1.64** but were **disabled in Arma 3** for security. An agent porting Arma 3 reflexes can fall for the *opposite* of the avoid-list above — assuming they are gone or unsafe and rewriting them — when they are load-bearing in this fork. Keep them.

| Command | First · version | OA status / repo use |
| --- | --- | --- |
| `setVehicleInit` | OFP:Elite / A2 · 1.00 (OA 1.50) | OA-safe; **disabled in Arma 3** (security). Global Effect — the init string is broadcast and runs on every machine. Repo passes only **hardcoded literal** init strings: textures via `Common/Functions/Common_AddVehicleTexture.sqf`, fixed init-script calls (`Client/Module/UAV/uav.sqf:30`, artillery in `Client/Functions/Client_FNC_Special.sqf:202`). Because the strings are constants, this is not a network-derived injection surface beyond the documented PVF dispatcher class (DR-1). 17 files. |
| `processInitCommands` | OFP:Elite / A2 · 1.00 (OA 1.50) | OA-safe; **disabled in Arma 3**. Runs the queued `setVehicleInit` statements once; paired immediately after `setVehicleInit` in `Common_CreateUnit.sqf`/`Common_CreateVehicle.sqf`, construction sites and UAV spawn. 19 files. |

> The MP-safe wrapper `WASP_procInitComm` (`WASP/common/procInitComm.sqf`) is compiled **commented-out** (`initJIPCompatible.sqf:241-245`), so the mission relies on these raw calls directly — the standard A2 pattern. See [WASP overlay](WASP-Overlay).

## Gaps folded into canonical indexes
The [External Arma 2 OA reference guide](Arma-2-OA-External-Reference-Guide) now routes future agents to this page for A3-only command forms such as `params`, `remoteExec`, `parseSimpleArray`, `setGroupOwner` / `groupOwner`, multi-index `select`, filter `select`, `apply`, `isEqualTo` and inline `private _var = value`. The former `apply` snippet in [Deep-review findings](Deep-Review-Findings) has been rewritten as an OA-safe `forEach` loop.

The two **inverse-trap** classes are now represented in the [compatibility audit](Arma-2-OA-Compatibility-Audit#inverse-trap-commands) and `agent-compatibility-audit.json`: (a) OA-safe commands commonly **mis-assumed A3-only** (`diag_tickTime`, `uiSleep` — both verified A2-era above), and (b) OA-safe commands **removed in A3** (`setVehicleInit`, `processInitCommands`). Both classes risk a future agent "fixing" working OA code. Instructions-For-Codex item 48 is canonicalized.

## Continue Reading
Canonical usage map: [External Arma 2 OA reference guide](Arma-2-OA-External-Reference-Guide) · Compatibility audit: [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) · Networking: [Networking and public variables](Networking-And-Public-Variables) · Findings: [Deep-review findings](Deep-Review-Findings) · Code map: [SQF code atlas](SQF-Code-Atlas)

> **Method:** BIKI command pages carry a per-command version badge; that badge — not the usage examples, which often include later Arma 3 notes — is the authority for OA availability. Forum threads are corroboration only, never the version source of truth. Verified 2026-06-02, lane `external-a2-docs-editorial-compression`.

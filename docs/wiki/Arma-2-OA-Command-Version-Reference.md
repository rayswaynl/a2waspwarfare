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
| `allGroups`, `call`, `compile`, `preprocessFileLineNumbers`, `typeName`, `isNil`, `format`, `localize`, `hintSilent`, `diag_log`, `diag_fps`, `publicVariable`, `addPublicVariableEventHandler`, `toArray`, `toString` | OFP / ArmA / A2 | All OA-safe. |

## Gaps to fold into the canonical index
The [External Arma 2 OA reference guide](Arma-2-OA-External-Reference-Guide) avoid-list currently names `params`, `remoteExec`, `parseSimpleArray`, `isEqualTo`, `private _var = value`. It should also name **`setGroupOwner` / `groupOwner`** (A3 1.40, no OA equivalent) and the **`select [start,count]` / substring / filter** forms (A3 1.28–1.56) — both are easy to import by reflex and both appeared in draft fix-snippets for this fork.

## Continue Reading
Canonical usage map: [External Arma 2 OA reference guide](Arma-2-OA-External-Reference-Guide) · Compatibility audit: [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) · Networking: [Networking and public variables](Networking-And-Public-Variables) · Findings: [Deep-review findings](Deep-Review-Findings) · Code map: [SQF code atlas](SQF-Code-Atlas)

> **Method:** BIKI command pages carry a per-command version badge; that badge — not the usage examples, which often include later Arma 3 notes — is the authority for OA availability. Forum threads are corroboration only, never the version source of truth. Verified 2026-06-02, lane `external-a2-docs-editorial-compression`.

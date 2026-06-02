# Self-Host Testing Field Notes

Practical gotchas discovered while smoke-testing WASP missions on a **Windows self-hosted listen server** (Multiplayer → New) with a headless client. Complements the [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow) and the [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit). Every item below cost real debugging time at least once — they are written so the next person (or agent) skips that cost.

## 1. The listen-server mission-pack cache (the #1 time-sink)

A self-host packs the selected mission **folder** into `%LOCALAPPDATA%\ArmA 2 OA\Tmp<PORT>\__cur_mp.pbo` (e.g. `Tmp2302\`) — **not** `MPMissionsCache\`, where people usually look. Arma then **reuses** that pack, and its change-detection is unreliable:

- A server-side edit to the folder may simply not take effect on the next host.
- You can get a **half-stale pack**: e.g. the new `Init_Server.sqf` calls `Init_Defenses.sqf`, but the reused pack is missing the file → `Warning Message: Script Server\Init\Init_Defenses.sqf not found` **for a file that is present in the folder**.

**Fix:** fully exit Arma, then delete **all** `__cur_mp.pbo` recursively under `%LOCALAPPDATA%\ArmA 2 OA` (hits `Tmp<port>\`, `tmp\`, `MPMissionsCache\`), then re-host → forces a fresh, complete pack. Always confirm a server-side edit actually loaded (a marker log line) before trusting any test result.

## 2. "Builds but invisible" → check the spawn coordinate, not locality

Symptom: the server logs `built (N objects)` but nothing appears where you placed it, and walking the spot finds neither visible nor invisible assets.

- It is almost never a locality/sync problem — `createVehicle` (array or simple form) is global and syncs to clients.
- It is almost always a **wrong world coordinate** or a post-build cleanup.

Trap we hit (commander defensive positions, PR #10): a `Land_HelipadEmpty` was spawned as a transform origin via `_o = "Land_HelipadEmpty" createVehicle _pos; _o setPos _pos;`, then children were placed with `_o modelToWorld _relPos`. The helper **stayed at `[0,0,0]`** (the static object never moved), so every composition — player *and* AI — built ~12 km away at the SW map corner.

**Lesson:** don't rely on a spawned static helper for `modelToWorld`. Rotate offsets about the placement point directly (Arma `dir` is clockwise from north):

```sqf
_worldPos = [
    (_pos select 0) + (_rel select 0) * (cos _dir) + (_rel select 1) * (sin _dir),
    (_pos select 1) - (_rel select 0) * (sin _dir) + (_rel select 1) * (cos _dir),
    0
];
```

**Diagnostic recipe:** temporarily log `reqPos`, the first child's `getPos`, and a delayed survival count. `reqPos` garbage = lost input (client side); child far from `reqPos` = bad transform; `survivors < built` = a cleanup is deleting them.

## 3. Supply delivery is proximity-based — there is no "unload" action

The server watches the loaded supply vehicle every few seconds and **auto-deposits** the moment it is within **80 m of a `Base_WarfareBUAVterminal`** (the Command Center). Players load with a scroll action but *deliver simply by arriving* — there is no manual unload.

That 80 m is a true **3-D sphere**, so an aircraft hovering high above the CC never triggers. For air supply (helis, PR #1) the proximity test was changed to **horizontal (2-D) distance** with a widened terminal search; ground vehicles keep the 3-D check.

## 4. Headless client: password symmetry

A client passing `-password=X` to a host that has **no** password is rejected exactly like a wrong password ("you cannot join because of password" on a passwordless host). For a no-password self-host, the HC launcher must pass **no `-password` at all**. Dedicated-server launchers carry a `-password=...`; do not reuse them against a Multiplayer → New self-host.

## 5. RPT forensics — use line numbers, not frameno

`ArmA2OA.RPT` is **appended across launches**, and `frameno` **resets per launch** — so a high frameno can belong to an *older* session. To attribute a frameno-less warning (e.g. `Script ... not found`) to the current session, grep with line numbers and compare against the last `PreInit Started ... isServer=true` line. **Line order is chronological; frameno is not.**

## 6. Folder missions vs hand-rolled PBOs

A single broken PBO in `MPMissions` **poisons the MP-browser scan for every mission** (the browser preprocesses each mission's `description.ext` to build the list) → "Include file ... not found" against unrelated missions, mission shows *Type: Unknown / Summary: empty*, and **Play does nothing**.

- For local testing, host the mission as a **folder** — it resolves `#include` via the filesystem and avoids the whole class of failure.
- If you must pack: A2 OA mission PBOs are **flat** (no `Vers` product entry; uncompressed entries need original-size = `0`). A round-trip-valid packer can still produce a PBO Arma lists but cannot read — only Arma's reader is authoritative.

## 7. Benign local errors to ignore

- `Server\Module\AntiStack\callDatabase*.sqf` throwing `_response` / `_responseCode` / `_teamSkillEast` undefined = the AntiStack anti-teamstacking module POSTing to a remote database that does not exist on a LAN self-host. Harmless locally.
- `coin_interface.sqf` `bis_control_cam` undefined = a commander-camera key/mouse handler firing when the RTS cam is not active. Cosmetic.
- `Common\Functions\Common_SendToClients.sqf: WFBE_CL_FNC_HandlePVF undefined` on HC connect = the headless client has no client-UI functions. Normal.

## 8. Arma 2 OA scripting reminders (bit us this run)

- **No `distance2D`** (Arma 3 only) — compute horizontal distance manually (`sqrt(dx*dx + dy*dy)`, or compare squared distances to avoid the `sqrt`).
- **No `lnbSetTooltip`** — list boxes cannot show per-row hover tooltips; use a click hint instead.
- **No `try`/`catch`** — guard with `isNil` / `isNull` and lazy `&&`/`||` short-circuit blocks.

See the [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) for the full command-availability scan.

## Continue Reading

Previous: [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow) | Next: [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents)

# Wildcard Marker Status - 2026-07-02

## Scope

Lane 149 asked whether wildcard map markers explain themselves. This is a
docs-only status pass against `claude/build84-cmdcon36`; it does not change
mission source, packaging output, or LoadoutManager-maintained files.

## Verdict

The current target already gives wildcard markers a creation-time explanation.
`Client/PVFunctions/WildcardMarker.sqf` receives side-targeted wildcard marker
payloads, creates the marker locally for that side, and shows a short `titleText`
message that names the wildcard and explains the threat in plain language.

This is not a persistent hover tooltip or map-popup system. Arma 2 marker
primitives do not provide that behavior in the existing receiver path. The
current implementation is a low-risk side-local map marker plus a one-time
status message when the marker is created.

## Evidence

| Area | Evidence |
| --- | --- |
| Receiver registration | `Common/Init/Init_PublicVariables.sqf:45` registers `WildcardMarker` as a public-variable receiver and documents it as side-restricted local marker create/delete. |
| Side-local receiver | `Client/PVFunctions/WildcardMarker.sqf:2` documents the feature as the wildcard map-marker receiver, and `WildcardMarker.sqf:45` uses `createMarkerLocal` so the marker exists only on the receiving client. |
| Marker explanation | `Client/PVFunctions/WildcardMarker.sqf:51-59` maps known wildcard labels such as `Airborne Assault`, `Car Bomb`, and the default case to short human-readable details. |
| Player-facing status | `Client/PVFunctions/WildcardMarker.sqf:61` emits `titleText [Format ["Wildcard: %1 - %2.", _label, _detail], "PLAIN"];` after marker creation. |
| Main wildcard sender | `Server/Functions/AI_Commander_Wildcard.sqf:1562-1564` documents the side-targeted local marker contract, `AI_Commander_Wildcard.sqf:1606` sends marker creation payloads, and `AI_Commander_Wildcard.sqf:1613` sends marker deletion payloads. |
| GUER sender | `Server/Functions/AI_Commander_Wildcard_GUER.sqf:183` sends the `Car Bomb` marker creation payload to resistance clients, and `AI_Commander_Wildcard_GUER.sqf:189` sends the matching delete payload. |

## Out Of Scope

- No source behavior change was made in this lane.
- No mission output, PBO, or live-deploy artifact was touched.
- Broader wildcard-deck transparency, next-draw timing, or commander UI work
  belongs in separate wildcard lanes and is not claimed here.

## Validation

- Confirmed the current receiver and sender paths with targeted `rg` searches.
- Confirmed this PR changes only this status document.

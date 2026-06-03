# Paratrooper Marker Revival

This page is the owner handoff for restoring paratrooper drop map markers in Arma 2 OA without importing Arma 3 remote-execution assumptions.

## Current Status

| Surface | Status | Evidence |
| --- | --- | --- |
| Source Chernarus | Patch-ready/current-source-unpatched | `Server/Support/Support_Paratroopers.sqf:117` sends `HandleParatrooperMarkerCreation`; `Client/PVFunctions/HandleParatrooperMarkerCreation.sqf` exists; `_clientCommandPV` in `Common/Init/Init_PublicVariables.sqf:25-41` still omits `HandleParatrooperMarkerCreation`. |
| Generated Vanilla Takistan | Patch-ready/current-source-unpatched | Generated Vanilla mirrors the missing client PVF registration. Patch source first, then propagate or verify generated output. |
| Modded forks | Owner decision | Napf/eden/lingor and abandoned stubs may drift independently. Do not assume source propagation reaches them. |

## Patch Shape

1. Add `HandleParatrooperMarkerCreation` to the client-bound `_clientCommandPV` list in source Chernarus.
2. Keep the existing OA-era PVF/publicVariable path; do not replace it with `remoteExec`, `BIS_fnc_MP` or Arma 3 JIP concepts.
3. Propagate generated Vanilla Takistan with the normal LoadoutManager workflow or explicitly document why a generated copy was patched by hand.
4. Re-check modded forks separately if the owner wants them maintained.

## Smoke Needed

| Smoke | What to prove |
| --- | --- |
| Dedicated server paradrop | Server sends the marker request and clients create the marker. |
| Hosted/listen | Confirm no hosted-only locality or display timing issue appears. |
| JIP | Late joiners see expected marker state or the lack of JIP replay is documented as accepted behavior. |
| Negative path | Bogus/unknown PVF names are rejected once dispatcher hardening lands. |

## Continue Reading

Current truth: [Current source status snapshot](Current-Source-Status-Snapshot) | Channels: [Public variable channel index](Public-Variable-Channel-Index) | Feature register: [Feature status register](Feature-Status-Register)

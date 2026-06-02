# Paratrooper Marker Revival

This lane turns the abandoned-feature note for paratrooper drop markers into a minimal source patch plus a handoff. The paratrooper support itself was already live; the broken edge was the client PVF callback registration.

## Status

| Surface | Status | Evidence |
| --- | --- | --- |
| Source Chernarus mission | Patched | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_PublicVariables.sqf:39` now registers `HandleParatrooperMarkerCreation`. |
| Vanilla Takistan mission | Propagated | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_PublicVariables.sqf:39` now has the same registration after the LoadoutManager propagation run. |
| Modded mission folders | Still drifted / not patched | Napf, eden and lingor register `HandleParatrooperMarkerCreation`, but no `Client/PVFunctions/HandleParatrooperMarkerCreation.sqf` file exists in those folders. Per `AGENTS.md`, direct mission edits should only touch Chernarus; modded propagation needs an owner decision. |
| Runtime validation | Pending hosted/dedicated smoke | Source checks prove the handler now compiles/registers in Chernarus source and maintained Vanilla; Arma 2 OA gameplay smoke is still needed to prove marker visibility and side filtering in-engine. |

## What Was Read

- `AGENTS.md:3-8`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_PublicVariables.sqf:25-46`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Support/Support_Paratroopers.sqf:108-118`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/PVFunctions/HandleParatrooperMarkerCreation.sqf:1-47`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_SendToClient.sqf:13-20`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_HandlePVF.sqf:12-22`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Common_MarkerUpdate.sqf:21-55`
- `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:70-88` and `:246-256`
- `Tools/LoadoutManager/ZipManager.cs:7-10`
- [Abandoned feature revival](Abandoned-Feature-Revival-Review)
- [Networking and public variables](Networking-And-Public-Variables)
- [Public variable channel index](Public-Variable-Channel-Index)

## What The Code Does Now

The server-side paratrooper support flow creates transport aircraft, spawns paratrooper units into cargo, waits until the aircraft reaches the destination, ejects each cargo unit, and sends a targeted client PVF:

- `Support_Paratroopers.sqf:117` calls `[leader _playerTeam, "HandleParatrooperMarkerCreation", [_x, _sideID]] Call WFBE_CO_FNC_SendToClient`.
- `Common_SendToClient.sqf:13-20` rewrites the target player object to UID, rewrites the command name to `CLTFNCHandleParatrooperMarkerCreation`, and sends `WFBE_PVF_HandleParatrooperMarkerCreation` by `publicVariableClient` or local hosted-server spawn.
- `Client_HandlePVF.sqf:12-22` lets only the matching UID client run the payload, then spawns the compiled `CLTFNC...` handler.
- `HandleParatrooperMarkerCreation.sqf:13-18` waits for client init, gives east paratroopers NVGs when needed, and exits on the wrong side.
- `HandleParatrooperMarkerCreation.sqf:29-40` creates a local marker name and spawns `MarkerUpdate`.
- `Common_MarkerUpdate.sqf:21` has an additional same-side/alive/null guard before creating the local marker.

Before this patch, source Chernarus had the sender and handler file but not the registration entry, so `Init_PublicVariables.sqf` never compiled `CLTFNCHandleParatrooperMarkerCreation` and never attached a PVEH for `WFBE_PVF_HandleParatrooperMarkerCreation`. Vanilla Takistan showed the same missing registration before propagation; it is now aligned with source.

## Why It Matters

This is a small revive rather than a redesign:

- It restores a live support-system feedback edge without changing paratrooper authority, costs, upgrade gates or transport behavior.
- It exercises the client-bound PVF path, making it a useful smoke target after the broader PVF dispatcher hardening work.
- It avoids reviving MASH marker networking, which needs server-held/JIP-safe state and is not comparable in size.

This patch does not harden `RequestSpecial` or make paratrooper support server-authoritative. The Tactical menu and `RequestSpecial` trust boundary remains part of the broader server-authority backlog.

## Patch Shape

Applied source change:

```sqf
_l = _l + ["RequestBaseArea"];
_l = _l + ["HandleParatrooperMarkerCreation"];
_l = _l + ["NukeIncoming"];
```

Files changed:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_PublicVariables.sqf`

The maintained Vanilla Takistan mission has been regenerated/propagated and now carries the same registration. The modded folders still show inverse drift: the PVF registration exists, but the handler file is absent.

## Validation

Source/Vanilla checks completed:

- Chernarus source mission now has sender + registered client PVF + handler file.
- Vanilla Takistan now has sender + handler file + registration after the propagation run.
- Diff is scoped to one source `Init_PublicVariables.sqf` insertion plus docs/machine-readable handoff updates.
- Earlier propagation was blocked by the checkout path, but `Tools/LoadoutManager` root discovery and `A2WASP_SKIP_ZIP=1` support were later patched; generation/copy completed for maintained Vanilla Takistan.

Required Arma 2 OA smoke:

1. Dedicated or hosted mission with commander/team able to request paratroopers.
2. Call paratroopers from Tactical menu.
3. Confirm aircraft arrives and units eject.
4. Confirm the requesting/same-side client receives moving drop markers.
5. Confirm opposite side does not see those local markers.
6. Confirm RPT has no missing `WFBE_PVF_HandleParatrooperMarkerCreation` / undefined `CLTFNCHandleParatrooperMarkerCreation` errors.

JIP note: these are transient unit markers, not historical drop records. No explicit JIP replay is needed unless an owner wants late joiners to see already-dropped paratroopers.

## Handoff

Future code owner:

- Smoke the source/Vanilla patch in Arma 2 OA.
- Do not present this as a `RequestSpecial` authority fix.
- If modded missions are revived, propagate both the registration and handler file through the LoadoutManager/modded-terrain maintenance model rather than patching the stale folders by hand.

Claude:

- Contradiction-check whether any other source client-bound PVF sender has an existing handler file but is missing from `_clientCommandPV`.

Codex:

- Keep [Abandoned feature revival](Abandoned-Feature-Revival-Review), [Feature status](Feature-Status-Register), [Networking/PV](Networking-And-Public-Variables) and [Public variable channel index](Public-Variable-Channel-Index) aligned with this lane.

## Continue Reading

Previous: [Abandoned feature revival](Abandoned-Feature-Revival-Review) | Next: [Public variable channel index](Public-Variable-Channel-Index)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

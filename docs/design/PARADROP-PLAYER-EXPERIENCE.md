# Paradrop Player Experience Reference

Base checked: `origin/claude/build84-cmdcon36@6f2fc4bd10c8339fd13be087d327717ff58c85e8`.

This page documents what a player should expect after using Tactical support paradrops. The server internals are
covered in the wiki's `Server-Paradrop-Delivery-Function-Reference`; this source-side page focuses on the visible
flow: request gates, in-flight timing, drop/landing behavior, local markers, cleanup, and the AI-commander reuse path.

## Support entries

The Tactical menu lists three relevant support entries at
`Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_Tactical.sqf:73-76`:

| Entry ID | Fee | Cooldown source | Upgrade gate | Request sent |
|---|---:|---|---|---|
| `Paratroopers` | `8500` | `WFBE_C_PLAYERS_SUPPORT_PARATROOPERS_DELAY` via `_pard` | `WFBE_UP_PARATROOPERS > 0` | `RequestSpecial ["Paratroops", sideJoined, _callPos, clientTeam]` |
| `Paradrop_Ammo` | `9500` | shared `lastSupplyCall`, 800 s list interval | `WFBE_UP_SUPPLYPARADROP > 0` | `RequestSpecial ["ParaAmmo", sideJoined, _callPos, clientTeam]` |
| `Paradrop_Vehicle` | `3500` | shared `lastSupplyCall`, 600 s list interval | `WFBE_UP_SUPPLYPARADROP > 0` | `RequestSpecial ["ParaVehi", sideJoined, _callPos, clientTeam]` |

The menu enables each row only when funds, upgrade level, and the relevant cooldown pass
(`GUI_Menu_Tactical.sqf:354-364`). On map click, the client stamps the cooldown, deducts funds, and sends
`RequestSpecial` (`GUI_Menu_Tactical.sqf:463-475`, `:644-664`). Paratroopers reject water clicks before the send;
ammo and vehicle paradrops do not have that client-side water guard in the current code.

`RequestSpecial` is registered as a PVF at `Common/Init/Init_PublicVariables.sqf:22`, and the server router starts the
three support functions at `Server/Functions/Server_HandleSpecial.sqf:50-59`.

## Paratroopers

Player-called paratroopers use `Server/Support/Support_Paratroopers.sqf`.

What happens:

1. The script detects whether the requesting team leader is a player. Human requests set `_isAI = false`; AI commander
   reuse sets `_isAI = true` (`Support_Paratroopers.sqf:9-15`).
2. The server reads the side's current paratrooper upgrade level and resolves `WFBE_<side>PARACHUTELEVEL<n>` plus
   `WFBE_<side>PARACARGO` (`:36-44`).
3. One or more transport aircraft are created from the map edge, based on cargo capacity, with a `"paradrop"` group,
   pilot, killed handler, side init, and `flyInHeight (300 + random 15)` (`:51-70`).
4. Infantry are created into the requesting player team, loaded into cargo, and the transport group receives an
   `AIMoveTo` order to the clicked destination (`:83-98`).
5. The outbound loop polls once per second. It fails if all transports or pilots die; for human requests it also fails
   if the requesting leader is no longer a player; all requests have a 500 s hard transit cap (`:103-111`).
6. At roughly 300 m from the destination, the drop goes green. Cargo units eject one by one with a 0.35 s delay for
   planes or 0.85 s for helicopters (`:114-126`).
7. Human-called drops send `HandleParatrooperMarkerCreation` per ejected unit. AI-called drops skip that client marker
   send (`:123-125`).
8. The transport flies home and the script deletes transport crews and vehicles. If greenlight was never reached, the
   script deletes the spawned paratroopers (`:130-151`).

Player-visible cues:

- The requesting client gets the normal tactical hint immediately after a valid paratrooper click
  (`GUI_Menu_Tactical.sqf:473-475`).
- Each ejected troop can create a side-filtered local unit marker on the matching client. The marker callback waits for
  client init, exits if the client side does not match, starts `MarkerUpdate`, and can add NVGs to east paratroopers
  if needed (`Client/PVFunctions/HandleParatrooperMarkerCreation.sqf:9-40`).
- The same callback plays one throttled `commanderNotification` sound and creates a local `Paradrop` objective marker
  for 30 seconds (`HandleParatrooperMarkerCreation.sqf:42-61`).

## Ammo Paradrop

Ammo paradrop uses `Server/Support/Support_ParaAmmo.sqf`.

What happens:

1. The server creates one `WFBE_<side>PARAVEHI` transport, one pilot, and a `"paradrop"` group, then sends it to the
   clicked position at `flyInHeight (200 + random 20)` (`Support_ParaAmmo.sqf:28-42`).
2. The outbound loop polls once per second. It aborts if the pilot or transport dies, if the requesting leader is no
   longer a player, or if the 500 s transit cap is reached. The drop point threshold is 100 m (`:45-52`).
3. The payload worker reads `WFBE_<side>PARAAMMO`, expects an array, and spawns each crate with a 0.8 s spacing
   (`:54-63`).
4. Each crate is attached to `WFBE_<side>PARACHUTE`, descends until below 3 m, detaches, is deleted, and is recreated
   at the landed position so the parachute can be removed cleanly (`:65-89`).
5. The transport flies home and the script deletes the pilot, transport, and group (`:96-108`).

Player-visible cues are sparse: the player pays and sends the request from the Tactical menu, then watches for the
transport/crate descent in-world. Unlike paratroopers, the ammo drop does not create the 30-second local `Paradrop`
marker from `HandleParatrooperMarkerCreation`.

## Vehicle Paradrop

Vehicle paradrop uses `Server/Support/Support_ParaVehicles.sqf`.

What happens:

1. The server creates one `WFBE_<side>PARAVEHI` transport, one pilot, and a `"paradrop"` group at
   `flyInHeight (300 + random 75)` (`Support_ParaVehicles.sqf:28-43`).
2. The cargo vehicle is created through `WFBE_CO_FNC_CreateVehicle`, attached under the transport, then registered in
   `emptyQueu` and `WFBE_SE_FNC_HandleEmptyVehicle` before the drop (`:45-49`).
3. The outbound loop aborts if pilot, transport, or cargo dies, if the requesting leader is no longer a player, or if
   the 500 s cap is reached. The drop threshold is 100 m (`:51-58`).
4. The cargo detaches, waits 2 s, receives a `WFBE_<side>PARACHUTE`, descends until below 10 m or destroyed, then
   detaches. The chute is deleted after 10 s (`:60-76`).
5. The transport flies home and the script deletes the pilot, transport, and group (`:78-90`).

The landed cargo vehicle is not deleted and recreated like ammo crates. It stays in place and is already on the empty
vehicle cleanup path.

## AI commander reuse

The AI commander paratroop reinforcement path deliberately reuses the same human support function:
`Server/AI/Commander/AI_Commander_Paratroops.sqf:1-12` describes the intent, and `:107-115` creates an
`aicom_paradrop` group before spawning `KAT_Paratroopers`.

For player expectations, the important difference is visibility. Because the requesting group leader is not a player,
`Support_Paratroopers.sqf` keeps only the 500 s transit timeout and skips `HandleParatrooperMarkerCreation`. Do not
expect the player-only `commanderNotification` sound or local `Paradrop` marker for AICOM-called drops.

## Validation checklist

- Open the Tactical menu with insufficient funds, missing upgrades, and active cooldowns; confirm the rows stay
  disabled according to `GUI_Menu_Tactical.sqf:354-364`.
- Trigger paratroopers on land. Confirm funds/cooldown stamp on click, the immediate hint, transport approach, ejection
  near the clicked point, one throttled notification, a local `Paradrop` marker that deletes after 30 s, and no
  enemy-side marker.
- Trigger ammo paradrop. Confirm the shared supply cooldown blocks the vehicle paradrop row afterward, crates arrive
  under parachutes, and no paratrooper marker/audio path is expected.
- Trigger vehicle paradrop. Confirm the dropped cargo lands under chute, remains in the world, and later follows the
  normal empty-vehicle cleanup behavior if unused.
- For an AICOM paratroop drop, look for the in-world drop and server logs, but do not expect the player-only local
  marker/audio callback.

## Guardrails

- This page does not change Tactical menu behavior, server authority, support fees, cooldowns, payload classes, drop
  timing, AICOM behavior, empty-vehicle cleanup, or generated Takistan output.
- Mission edits still belong in the maintained Chernarus tree first, then `Tools/LoadoutManager` mirrors Takistan.
  This lane is docs-only, so no mirror run is required.

# Carrier Deck Service Point Design
<!-- GUIDE-REV: GR-2026-07-03a -->

Lane: 285

This is a docs-only source PR for the carrier deck service point lane. Runtime edits are deferred
because the needed capture lifecycle is in `Server/FSM/server_town.sqf`, which is hot in active
draft PRs #566, #589 and #643. This note records the Build84 anchors and the intended stacked
implementation shape so a later source owner can add repair and refuel support per LHD without
rediscovering the service menu path.

## Scope

- Target behavior: each captured LHD has an owning-side deck service point for repair and refuel.
- Target base: `claude/build84-cmdcon36`.
- This PR changes documentation only.
- No mission source edits, no mirror generation, no package artifact, no deploy and no live runtime action.

## Current Build84 Anchors

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_NavalHVT.sqf` already initializes
the three LHD logics and stores them in `WFBE_NAVAL_HVT_LOGICS` at line 444. The carrier air-shop
loop starts at line 447. For each LHD, it creates an invisible `HeliHEmpty` on the deck and wires:

- `wfbe_hangar`
- `wfbe_airfield_side`
- `wfbe_is_carrier_hvt`
- `wfbe_airfield_logic_ref`
- `wfbe_airfield_hangar_obj`

Those variables make the captured carrier act like an air buy/sell point, but they do not create
anything that the service GUI can treat as a service point.

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town.sqf` has the carrier capture
block at lines 358-382. It deletes and respawns only the carrier air-shop `HeliHEmpty` for the new
owner. The land-airfield capture block, by contrast, creates a real side service point:

- lines 562-565 choose the side-specific `Base_WarfareBVehicleServicePoint` subclass.
- lines 580-589 remove the old service point from all side `wfbe_structures` lists before deletion.
- lines 597-605 create the new service point, tag `WFBE_RepairTruckServicePoint` and set `wfbe_side`.
- line 605 registers it into the owning side logic `wfbe_structures` list.
- lines 611-617 wire hit/killed handlers and store it as `wfbe_airfield_sp`.

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_Service.sqf` discovers service
supports through the existing side structure path:

- line 233 calls `GetFactories` for the current side's service point type from `wfbe_structures`.
- lines 296-306 add depots and repair trucks.
- lines 311-317 add nearby repair-truck-built service points tagged `WFBE_RepairTruckServicePoint`.

The workers already accept real service points once the GUI includes them in `_supports`.
`Client_SupportRepair.sqf:18` and `Client_SupportRefuel.sqf:19` both set `_nearIsSP` when the
support is the side service point type or `isKindOf "Base_WarfareBVehicleServicePoint"`.

## Gap

The LHD air-shop path uses `HeliHEmpty`, which is deliberately invisible and not a
`Base_WarfareBVehicleServicePoint`. Aircraft can use the carrier as an air buy/sell point, but a
vehicle or aircraft on the deck does not gain normal service-menu repair or refuel support from the
carrier itself.

The missing piece is not a new client worker. It is a server-owned, side-registered service point
object on each carrier, with capture cleanup that mirrors the land-airfield service point lifecycle.

## Proposed Runtime Shape

A later stacked runtime PR should add one helper for carrier deck service points and call it from:

1. The initial LHD air-shop loop in `Init_NavalHVT.sqf`, using the logic's current `sideID`.
2. The carrier recapture block in `server_town.sqf`, using `_hvtNewSide`.

The helper should:

- Respect a new feature flag such as `WFBE_C_NAVAL_CARRIER_SERVICE_POINTS`, default `0`.
- Return without side effects while the flag is `0`, preserving byte-identical flag-off behavior.
- Use the same side-specific service point class switch as `server_town.sqf:562-565`.
- Anchor to `getPosASL _airLogicRef` and `wfbe_naval_deckz`, not sea-level `getPos`.
- Use a small deck offset from the air-shop hangar anchor after in-engine placement testing.
- Store the spawned object as `wfbe_carrier_sp` on the carrier location or naval logic.
- Set `wfbe_side` to the owning side.
- Register the object only in the owning side logic's `wfbe_structures` list.
- On recapture, remove the previous object from all side `wfbe_structures` lists before deletion.

Side gating needs special care. The repair-truck service point scan in `GUI_Menu_Service.sqf:311-317`
adds any nearby `Base_WarfareBVehicleServicePoint` tagged `WFBE_RepairTruckServicePoint`, without an
owner-side check. A carrier deck service point that is already registered in `wfbe_structures` does
not need that tag for normal repair and refuel discovery. Prefer leaving `WFBE_RepairTruckServicePoint`
unset unless the runtime PR also adds a side check to the repair-truck-built service point path.

The carrier air-shop `HeliHEmpty` should stay separate. Reusing it as the service point would fail
the worker-side `Base_WarfareBVehicleServicePoint` checks and would blur the air-shop respawn state
with the service lifecycle.

## Validation Plan For The Runtime PR

- Confirm flag-off mission content is byte-identical to Build84.
- Run `A2WASP_SKIP_ZIP=1` LoadoutManager after any SQF source edit and restore TK/ZG templates if touched.
- Run the standard SQF lint gate from `AGENTS.md`.
- Run focused scans for A2/OA traps, conflict markers, NUL bytes and delimiter deltas on touched files.
- Confirm mirror parity for every edited Chernarus SQF file.
- In game, capture each LHD as WEST/EAST/GUER and verify the old owner's carrier service point is gone.
- Land or park an eligible aircraft/vehicle within support range on deck and verify the Service menu
  offers repair/refuel only for the owning side.
- Recapture the LHD and verify the service point moves to the new owning side with no stale marker,
  no stale `wfbe_structures` reference and no hostile-side service access.

## Open Questions

- Final deck offset must be chosen in engine to avoid the LHD island, elevator geometry and twin-hull bridge props.
- Decide whether the carrier service point should be visible/destructible like land-airfield service
  points or static/invulnerable like the carrier air-shop helper. The low-risk default is static and
  invulnerable because the carrier props themselves are treated that way.
- If EASA should also use carrier service points, verify the EASA button path with side-registered
  service points before adding the side-agnostic repair-truck tag.

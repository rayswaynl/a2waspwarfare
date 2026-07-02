# AICOM Heli Airfield Spawn Status

Fleet lane 95 asks for the AICOM aircraft founding path to move helicopter-founded teams to an owned airfield, not the base factory pad, by widening the relocation gate from `_isJetTeam` to `_isAirTeam`.

Status: already represented in the current `claude/build84-cmdcon36` target source. This note is docs-only; it does not change mission source, mirrors, package output, or live runtime state.

## Current Source Anchors

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:1071-1125`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Teams.sqf:1071-1125`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Teams.sqf:1071-1125`

All three copies carry the same lane-95 behavior:

- `_isJetTeam = ({_x isKindOf "Plane"} count _template) > 0;`
- `_isAirTeam = ({(typeName _x == "STRING") && {_x isKindOf "Air"}} count _template) > 0;`
- `if (_isAirTeam && {_hasAirfield}) then { ... }`

That means a founded template containing any A2-OA `Air` classname enters the owned-airfield relocation block. Helicopters no longer miss the block merely because they are `"Helicopter"` rather than `"Plane"`.

The plane-only behavior remains intentionally separate:

- `_runwayDir` is resolved from airfield logic for runway-heading support.
- The HC delegate payload still sends `_isJetTeam` and `_runwayDir`.
- Non-jet air teams can prefer nearby `HeliH` pads when a hangar object exists, keeping helicopter starts grounded instead of using the fixed-wing FLY air-start path.

## Relationship To Existing Design Notes

`docs/design/AICOM-AIRCRAFT.md` already records this as `Bug 1 is implemented` and keeps the research-gating concern as a separate Bug 2 decision. Lane 95 maps to Bug 1 only.

Lane 96, the AICOM air-research gate, should stay separate. Flipping `WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI` or changing research queue behavior is a balance/research-policy lane, not part of the heli spawn-location fix.

## Follow-Up

No source patch is recommended for lane 95 from this branch. If more proof is desired, the remaining useful work is an in-engine soak where AICOM owns an airfield, founds a helicopter air team, and the spawn position is observed at the held airfield or nearby `HeliH` pad rather than the base pad.

Source-edit follow-ups should coordinate with the open commander-air/AICOM PR stack before touching `AI_Commander_Teams.sqf` again.

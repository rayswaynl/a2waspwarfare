# Road Checkpoint Status - 2026-07-03

## Verdict

Fleet lane 14 is partially current-target present on
`origin/claude/build84-cmdcon36@b1608b096eb4`.

The current target already has an implemented GUER roadblock event: G2 Pop-up Checkpoint in
`AI_Commander_Wildcard_GUER.sqf`. It spawns a road-snapped checkpoint near an occupied
WEST/EAST town, fields a GUER tier vehicle plus a foot fireteam, marks the contested objective,
taxes the occupier while the block stands, pays GUER players a toll, rewards the clearing side
with supply, and grants GUER a tier-scaled FOB factory token when the checkpoint survives.

No duplicate source patch is warranted from this lane. The larger B1 A-Life sketch remains a
separate future design if the owner wants always-on chokepoint checkpoints with sandbags,
night props, hunter responses and area-ownership despawn logic.

## Source Proof

The implemented worker is byte-identical across the three maintained mission roots:

| File family | Maintained roots | SHA-256 |
| --- | --- | --- |
| `Server/Functions/AI_Commander_Wildcard_GUER.sqf` | Chernarus, Takistan, Zargabad | `6C9F1FFF09A5FD2EE5DB223C5F53A4015DB31140356844C93E1A711840E74507` |

Representative Chernarus anchors, mirrored by line-equivalent code in Takistan and Zargabad:

| Area | Current evidence |
| --- | --- |
| Worker compile | `Server/Init/Init_Server.sqf:86` compiles `AI_Commander_Wildcard_GUER.sqf`. |
| Worker boot | `Server/Init/Init_Server.sqf:1292-1294` starts the GUER wildcard worker when `WFBE_C_GUER_WILDCARD` is active and resistance is present. |
| Event definition | `AI_Commander_Wildcard_GUER.sqf:9-21` documents G2 as an interactive occupied-town supply-road checkpoint with tax, toll, clear reward and held-to-timeout FOB token outcomes. |
| Draw weight | `AI_Commander_Wildcard_GUER.sqf:96` keeps G2 in the GUER wildcard deck with weight 8 when occupied towns and GUER soldier classes are available. |
| Road anchor | `AI_Commander_Wildcard_GUER.sqf:198-211` selects an occupied target town, rolls a spawn about 280 m out and snaps to a nearby road. |
| Tiered vehicle | `AI_Commander_Wildcard_GUER.sqf:215-224` reads `WFBE_GUER_VEHICLE_TIER` and maps it to technical, BRDM, T-55 or T-72 checkpoint labels and vehicles. |
| Manning force | `AI_Commander_Wildcard_GUER.sqf:226-244` creates a resistance group, crewed vehicle and 3 + tier foot defenders, then patrols around the block. |
| Contested marker | `AI_Commander_Wildcard_GUER.sqf:248-251` creates a global `mil_warning` marker named `Insurgent Checkpoint (...)`. This is intentionally enemy-visible, unlike the side-local `WildcardMarker.sqf` path used by some other wildcard events. |
| Tax and toll | `AI_Commander_Wildcard_GUER.sqf:264-277` applies the window, tax, toll and clear values, draining the occupier and paying GUER players while defenders remain alive. |
| Clear outcome | `AI_Commander_Wildcard_GUER.sqf:283-285` rewards the occupier with supply and logs `GUERCP_CLEARED` when the manning force is wiped. |
| Held outcome | `AI_Commander_Wildcard_GUER.sqf:291-302` grants a Barracks, Light Factory or Heavy Factory FOB token through `WFBE_GUER_FOB_AVAIL` and logs `GUERCP_HELD` when the checkpoint survives its window. |
| Player announcement | `AI_Commander_Wildcard_GUER.sqf:422-428` broadcasts the G2 wildcard announcement to all clients. |

## Boundary Versus The B1 Sketch

`docs/design/ALIFE-V2-AND-DOCTRINES.md:17-19` describes a broader B1 idea:
frequent road checkpoints at chokepoints between towns, with sandbags, technicals, 4-6 men,
night flair, a hunter response team and despawn when the area is safely owned.

The live G2 checkpoint covers the interactive roadblock/status portion of that idea, but it is
not a full always-on A-Life checkpoint system:

- It is a GUER wildcard draw, not a persistent chokepoint lattice.
- It anchors near occupied town supply roads, not a precomputed road-network chokepoint set.
- It fields a tiered GUER vehicle plus defenders, but does not place sandbags, flares,
  searchlights or static checkpoint compositions.
- It resolves through clear/held outcomes, but does not spawn a hunter response team.
- It is paced by `WFBE_C_GUER_WILDCARD_INTERVAL` and deck eligibility, not by constant player
  road travel encounter checks.

That distinction is useful for backlog hygiene: lane 14 should not spawn a duplicate GUER
checkpoint implementation on the current target, but the broader B1 always-on encounter layer
can remain a fresh design lane if explicitly chosen later.

## Out Of Scope

This pass intentionally does not edit mission source. It also does not retune
`WFBE_C_GUER_WILDCARD`, add lobby parameters, add road-network chokepoint selection,
add composition props, add hunter response teams, alter GUER economy rewards, run
LoadoutManager, package missions, deploy to a live server or touch runtime settings.

## Validation

- Open PR and wiki claim refresh found no active lane 14 build84 PR or active wiki lane before
  claiming this status pass.
- `git grep` verified the G2 checkpoint definition, road anchoring, tiered vehicle selection,
  manning force, marker, tax/toll loop, clear reward, held-to-timeout FOB token and client
  announcement anchors in the current source tree.
- `Get-FileHash` showed `AI_Commander_Wildcard_GUER.sqf` is byte-identical across Chernarus,
  Takistan and Zargabad.
- This PR is docs-only: `JOURNAL.md` plus
  `docs/design/ROAD-CHECKPOINT-STATUS-2026-07-03.md`.

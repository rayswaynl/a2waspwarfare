# Vanilla-Terrain Gameplay Census

Status: READY as design menu, geometry values need in-editor confirmation before implementation  
Lane: 451

## Summary

| Terrain | worldName key | Archetype | Naval potential | CTI fit | Mode twist |
|---|---|---|---|---|---|
| Chernarus | `Chernarus` | mixed forest/coast/urban | Medium | Good | Baseline full CTI. |
| Takistan | `Takistan` | mountains/open desert | Low | Good | Ridge-control economy pressure. |
| Zargabad | `Zargabad` | dense urban/desert edge | Low | Good | Shorter-start urban knife fight. |
| Utes | `Utes` | small island/coast | High | Marginal | Asymmetric amphibious invasion. |
| Desert / Proving Grounds | `Desert_E` / verify | open desert test range | Low | Poor | Vehicle proving-ground duel. |
| Shapur | `Shapur_BAF` / verify | compact industrial/desert | Low | Marginal | Factory raid mode with tight objective count. |
| Bukovina | `Bukovina` / verify | small forest villages | Low | Marginal | Infantry-first forest CTI. |
| Bystrica | `Woodland_ACR` or `Bystrica` / verify | forest valley | Low | Marginal | Convoy corridor control. |

## Chernarus

- Playable area: large mainland South Zagoria plus coast; current maintained source map.
- LoadoutManager status: maintained source terrain.
- AI pathfinding: mixed road network, forests, coast, hills; robust but long travel times.
- Fit: Good.
- Justification: already proven for full WASP loop.
- Mode twist: baseline V2 profile; no special constraint.

## Takistan

- Playable area: large mountainous desert.
- LoadoutManager status: maintained mirror.
- AI pathfinding: roads and valleys matter; long line-of-sight; ridges punish direct routes.
- Fit: Good.
- Justification: full CTI works but needs route-aware commander behavior.
- Mode twist: ridge-control profile where towns on valley routes get higher strategic weight.

## Zargabad

- Playable area: compact city and surrounding desert.
- LoadoutManager status: maintained mirror.
- AI pathfinding: urban turns and short distances; nil map-data failures already taught defensive-read requirement.
- Fit: Good.
- Justification: smaller, faster, more lethal; good for shorter rounds.
- Mode twist: short-start urban escalation with lower travel thresholds.

## Utes

- Playable area: small island with coast, airfield, and limited settlement space.
- LoadoutManager status per roster/wiki note: boundary-only; no CS class or mission folder.
- AI pathfinding: short routes, chokepoints, high amphibious relevance.
- Fit: Marginal for normal CTI, Good for special invasion mode.
- Justification: too small for full symmetric WASP economy, strong for owner-approved asymmetric amphibious concept.
- Mode twist: one side invades from sea/air while defenders start entrenched inland.

## Desert / Proving Grounds

- Playable area: small open desert/testing region; exact worldName must be confirmed in editor/config.
- LoadoutManager status: not maintained.
- AI pathfinding: open, sparse cover, little town texture.
- Fit: Poor.
- Justification: lacks terrain and settlement depth for normal CTI.
- Mode twist: limited-duration armored proving-ground mode with fixed depots.

## Shapur

- Playable area: compact industrial/desert terrain.
- LoadoutManager status: not maintained.
- AI pathfinding: short routes, hard edges, industrial cover.
- Fit: Marginal.
- Justification: useful for raid-sized CTI, too compact for full economy.
- Mode twist: factory raid mode: fewer towns, higher value structures, fast win condition.

## Bukovina

- Playable area: small green/forest terrain; exact CO availability must be confirmed.
- LoadoutManager status: not maintained.
- AI pathfinding: forest and village roads; infantry more reliable than heavy armor.
- Fit: Marginal.
- Justification: plausible infantry CTI if town count and base sites exist.
- Mode twist: infantry-first mode with constrained heavy vehicle availability.

## Bystrica

- Playable area: forest valley / ACR terrain; exact worldName must be confirmed.
- LoadoutManager status: not maintained.
- AI pathfinding: corridor roads, forests, bridges/chokes likely decisive.
- Fit: Marginal.
- Justification: better as convoy/corridor control than open full-map CTI.
- Mode twist: convoy corridor control; supply routes score extra and roadblocks matter.

## Implementation Caveat

This census is a menu only. Before any map build:

1. Confirm `worldName` in A2 OA 1.64 editor/config.
2. Confirm vanilla/no-mod availability on the target server.
3. Add LoadoutManager class/folder support.
4. Build a town/base geometry dataset.
5. Run nil-guarded map-data reads per AGENTS and V2 commandments.

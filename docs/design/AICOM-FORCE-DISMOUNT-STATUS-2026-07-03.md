# AICOM force-dismount status - 2026-07-03

Lane 87 asked for a final escalation after repeated stuck strikes: if an AI commander team still reports moved about 0 after N unstuck strikes, the crew should leave the wedged vehicle and continue to the objective on foot.

Status: the exact lane 87 behavior is not source-present as a dedicated force-dismount-after-N-stuck-strikes branch. The current target already has several adjacent recovery and dismount paths, but a still-mobile wedged hull remains in the recovery ladder instead of being converted to a foot assault by strike count.

## Evidence

The backlog source is `B57-SOAK-PROPOSALS.md:146-154` and `B57-SOAK-PROPOSALS.md:412-417`. It records 21 recurring WEST `ASSAULT_STRANDED` events, the same teams reporting `moved=0`, and a proposal to force-dismount after N unstuck strikes using Arma 2 OA-safe primitives such as `moveOut`, `leaveVehicle`, and `orderGetIn false`.

The current commander watcher does feed no-progress cases into the strike ladder:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:142-158`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_AssignTowns.sqf:142-158`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_AssignTowns.sqf:142-158`

Those copies increment `wfbe_aicom_stuckstrikes`, log `ASSAULT_STRANDED`, and later carry the strike tier into `wfbe_aicom_order`.

The current executor consumes the strike tier in `Common_RunCommanderTeam.sqf:933-1096`. It includes recovery v2 actions such as dead-driver swap, tier-1 reverse pulse plus lane flip, tier-3 road snap for the lead hull, water guard, and foot/dead-hull road snap plus squad reform. That is a recovery ladder, not a forced dismount of a still-mobile wedged vehicle.

The current executor does have dismount and abandon paths, but they fire in narrower contexts:

- `Common_RunCommanderTeam.sqf:1669-1685` always dismounts non-crew infantry for the capture push while crew stays mounted.
- `Common_RunCommanderTeam.sqf:1770-1782` defensively dismounts non-crew infantry still in cargo for camp sweep presence.
- `Common_RunCommanderTeam.sqf:2116-2142` abandons true troop trucks at rally/arrival and retasks their occupants on foot.
- `Common_RunCommanderTeam.sqf:2157-2175` abandons crew from hulls that can no longer move and gives them an unconditional ground move.

Search notes from the lane audit:

- `moveOut` and `leaveVehicle` exist in unrelated MHQ/client-watchdog code, but were not found in the AICOM stuck-strike executor path checked for this lane.
- `orderGetIn false` exists, but only inside the adjacent cargo/capture/truck/immobile-abandon paths above.
- The `!(canMove _cv)` gate in `IMMOBILE-ABANDON` means live but wedged vehicles stay outside that dismount path.

## Coordination

Do not duplicate the hot AICOM source work casually. Nearby open PRs already cover related pieces:

- PR #267 documents the broader stuck-recovery v2 lifecycle and operator tokens.
- PR #378 carries source review for ORBITER_DETECT and STUCK_DECAY flags.
- PR #458 documents lane 85 / F4 stuck ladder and zombie-team recycle status.
- PR #460 documents lane 86 / F3 orbiter detection status.

If lane 87 becomes source work, the smallest coherent owner patch should hook into the existing `wfbe_aicom_stuckstrikes` / order-tier path, after the current recovery ladder has actually failed, and must choose its scope carefully:

- define the strike threshold and whether it is flag-gated;
- only force-dismount AI crew and passengers that are local and safe to retask;
- give every dismounted unit an immediate destination move;
- avoid stealing crew from combat-effective armour during normal capture/camp behavior;
- mirror through LoadoutManager and verify all generated mission copies;
- prove the behavior with RPT tokens, preferably around the original `ASSAULT_STRANDED` pattern.

## Boundary

This page is a status audit only. It changes no SQF/SQM/HPP/EXT mission behavior, constants, route generation, HC/server ownership, generated mirrors, packages, deploy scripts, or live server settings.

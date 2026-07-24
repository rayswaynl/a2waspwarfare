# FPV Drone — AH6 Misclassification Audit + FPV-FOB Gap Spec (2026-07-24)

Owner task 07-24: (1) a normal AH6 (MH6/AH6 littlebird) must NOT count as an FPV drone —
the FPV-detection predicate must use exact classname/allowlist matching, never
`isKindOf`/CfgVehicles-walk. (2) Verify the FPV drone FOB feature is fully implemented
end-to-end (spawn point, resupply, drone launch from FOB, teardown).

## Part 1 — FPV-detection predicate audit (current master)

The FPV drone airframe for every side is `AH6X_EP1` (`WFBE_<side>FPVDRONE`, set in
`Common/Config/Core_Root/Root_{US,USMC,US_Camo,RU,INS,CDF,GUE}.sqf`). The same classname
is also a **normal purchasable littlebird**: AH-6X Scout at the US Aircraft Factory
(`Common/Config/Core_Units/Units_CO_US.sqf:265`) and the AH-6X (M134) armed variant token
(`Units_CO_US.sqf:266`, remapped to the real `AH6X_EP1` hull in
`Client/Functions/Client_BuildUnit.sqf`). AH6J_EP1 / MH6J_EP1 are separate classes.

Predicate inventory (all exact-match; **no `isKindOf`/CfgVehicles-walk exists anywhere in
the FPV path, present or git history**):

| Site | Check | Form |
|---|---|---|
| `Server/Support/Support_FPV.sqf:294-298` | airframe = `WFBE_<side>FPVDRONE` | exact `typeOf _drone != _expectedClass` |
| `Server/Support/Support_FPV.sqf:300` | pilot = `WFBE_<side>PILOT` | exact `typeOf` |
| `Server/Support/Support_FPV_Detonate.sqf:62-127` | detonation authority | exact object identity in per-side server registry + private per-drone capability |
| `Client/Module/FPV/fpv.sqf:10,88` | drone creation class | exact classname read of the same constant |
| `Client/PVFunctions/HandleSpecial.sqf`, `fpv_interface.sqf`, GUER/Tactical menus | drone state | object references only (`playerFPV`) |

Residual gap closed by this PR: exact `typeOf` equality cannot distinguish a fresh
fpv.sqf-created drone from a **factory-bought AH6X_EP1** the player already owns (same
class). The server purchase flow binds any client-supplied, player-owned object of that
class, so a normal AH6X could be registered/armed as an FPV drone. Fix: reject hulls
tagged `wfbe_buyteam` (set only by `Client_BuildUnit.sqf:945` on factory buys, broadcast
server-visible; fpv.sqf drones never pass through Client_BuildUnit) in
`Support_FPV.sqf` right after the exact-class check. AH6J/MH6J were already impossible to
match; a factory AH6X is now refused too. Inert for every legit launch.

## Part 2 — FPV drone FOB: current state

**Not implemented — no FOB integration exists in any form.** The FPV strike drone is a
field launch, not a FOB asset:

- WEST/EAST: Tactical Center menu row "FPV STRIKE DRONE"
  (`Client/GUI/GUI_Menu_Tactical.sqf:128-132,424-530`) → `Client/Module/FPV/fpv.sqf`.
- GUER: Drone Operations menu (`Client/GUI/GUI_Menu.sqf:249-251` →
  `Client/GUI/GUI_Menu_GuerDrones.sqf`, LAUNCH button) → same `fpv.sqf`.
- `fpv.sqf:13-22,88` spawns the drone at the nearest command center (W/E) or at the
  player (GUER) — `createVehicle [_class, getPos _closest, [], 0, "FLY"]`.
- The B75 GUER FOB system (FOB trucks → `Action_BuildFOB.sqf` →
  `Server/PVFunctions/RequestFOBStructure.sqf` → Barracks/Light/Heavy field factories,
  constants `Common/Init/Init_CommonConstants.sqf:177-256`) has **zero drone coupling**.

### Gap map (required capability → state)

| Capability | State | Evidence |
|---|---|---|
| FOB spawn point for drones | MISSING | drone spawns at nearest CC / player position (`fpv.sqf:13-22,88`) |
| Resupply (rearm/rearm-point) at FOB | MISSING | rearm is a per-UID server cooldown only (`WFBE_C_FPV_COOLDOWN`, `Support_FPV.sqf:334-339,442-444`); no structure-bound resupply |
| Drone launch from FOB | MISSING | launch requires only funds + cooldown; no proximity/structure gate (`fpv.sqf:24-40`) |
| FOB teardown (drone cleanup on FOB loss) | MISSING | per-flight watchdog scuttles pilot+drone (`Support_FPV.sqf:430-459`); no FOB-destruction hook |

## Spec — FPV drone FOB (proposed, flag-gated `WFBE_C_FPV_FOB` default 0)

Phase A (server + common):
1. Register a drone-station logical type per side (reuse FOB idiom:
   `WFBE_C_GUER_FOB_STRUCTS`-style constant + `WFBE_GUER_FPV_FOB_AVAIL` token count).
2. Server tracks live FPV-FOB structures in a per-side registry (object list), stamped
   `wfbe_fpv_fob = true`; entry removed on structure death (`Server_BuildingKilled` hook).

Phase B (client):
3. Launch gate: when `WFBE_C_FPV_FOB > 0`, `fpv.sqf` requires a live friendly FPV-FOB
   within `WFBE_C_FPV_FOB_RANGE` (default 50 m) of the operator; drone spawns on the FOB
   pad, not at the player. Field launch stays when flag is 0 (byte-identical).
4. Resupply action on the FOB ("Rearm FPV launcher"): clears nothing server-side but
   pays `WFBE_C_FPV_DRONE_COST` and resets the per-UID rearm stamp via a new
   RequestSpecial mode — server-revalidated, same capability pattern as `auth/purchase`.

Phase C (teardown):
5. FOB destroyed → server denies new launches at that FOB and (owner decision needed)
   either scuttles in-flight drones launched from it or lets them finish the flight.
6. Teardown of the structure itself reuses the existing construction/destruction flow
   (no new GC path).

Open owner decisions: which side(s) get FPV-FOBs (GUER-first vs all), FOB token source
(factory kill like B75 vs depot purchase), in-flight scuttle on teardown (punitive vs
grace), whether the FOB also rearms GUER SCUD (Phase-2 card).

Security notes: keep every new mode on the existing private-capability bus
(`WFBE_PVF_FPVPrivate`); never trust client position for the launch gate — re-derive
FOB proximity server-side from the registry object position; exact-class checks only.

## Test plan (when implemented)

- Flag 0: mission byte-identical; field launch unchanged on all three terrains.
- Flag 1: launch denied away from FOB (hint), allowed in range; drone spawns on pad.
- Factory-bought AH6X_EP1 (scout/M134) standing next to a FOB is never accepted as a
  drone hull (Part-1 guard).
- FOB destroyed mid-rearm: launch denied; teardown path logs one INFORMATION line.
- Mirrors: TK/ZG byte-identical to CH after LoadoutManager run; per-map templates restored.

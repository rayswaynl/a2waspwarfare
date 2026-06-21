# GUER VBIED Detonate Action

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The GUER "Insurgents" playable faction (Feature B, added by Ray 2026-06-16) gives the resistance player a driver-detonated car bomb. A buyable covered civilian pickup carries a red **Detonate VBIED** player action that, after a two-step confirm and a short arm countdown, asks the server to blow up the truck and pay the driver's team cash-for-kills. The whole feature is gated behind `WFBE_C_GUER_PLAYERSIDE > 0` and defaults OFF, so with the gate off no action is added and the server case is never reached — byte-for-byte today's behaviour. This page traces the action wiring (where the addAction is attached), the two-step gate (the client-side safety + confirm UX), and the detonation mechanic (the server blast that mirrors AI wildcard W21).

## Where the action is attached

The action is a local `addAction` attached on the buyer's client only, alongside the lock/unlock actions, inside the per-vehicle local-init block of `Client_BuildUnit.sqf`.

| Item | Detail | Source |
|------|--------|--------|
| Gate | `WFBE_C_GUER_PLAYERSIDE > 0` **and** vehicle `typeOf` equals `WFBE_C_GUER_VBIED_TYPE` | `Client/Functions/Client_BuildUnit.sqf:338` |
| addAction title | `<t color='#ff3333'>Detonate VBIED</t>` (HTML red) | `Client/Functions/Client_BuildUnit.sqf:339` |
| Handler script | `Client\Action\Action_GuerVbiedDetonate.sqf` | `Client/Functions/Client_BuildUnit.sqf:339` |
| Priority / radius flags | priority `6`, `showWindow false`, `hideOnUse true` | `Client/Functions/Client_BuildUnit.sqf:339` |
| Action condition | `driver _target == _this && {side _this == resistance}` (driver-only, resistance-only) | `Client/Functions/Client_BuildUnit.sqf:339` |

Because `addAction` is local, only the client that built (bought) the truck attaches the action — the same locality as the lock/stealth actions immediately above it (`Client_BuildUnit.sqf:330-331`). On the gate-off / non-VBIED path the `if` at line 338 is false and no action is added.

The VBIED chassis is a tier-0 "always available" entry in the GUER buy pool: `hilux1_civil_2_covered` on Chernarus (`Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:61`) and `datsun1_civil_2_covered` on Takistan, where the overlay also repoints `WFBE_C_GUER_VBIED_TYPE` so the client gate and the server guard both match the TK truck (`Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:71,75`).

## The two-step client gate

`Action_GuerVbiedDetonate.sqf` receives `_this = [target(vehicle), caller(player), actionId, args]` and runs entirely on the activating client. It enforces three guards, then implements a press-twice confirm before it spawns the arm countdown.

| Stage | Logic | Source |
|-------|-------|--------|
| Sanity guard | `isNull _veh || {!alive _veh}` → exit | `Client/Action/Action_GuerVbiedDetonate.sqf:18` |
| Driver guard | `driver _veh != _player` → exit (belt-and-braces vs the action condition) | `Client/Action/Action_GuerVbiedDetonate.sqf:19` |
| Re-entry lock | `_veh getVariable ["wfbe_vbied_arming", false]` → exit (already counting down) | `Client/Action/Action_GuerVbiedDetonate.sqf:20` |
| Step 1 — arm window | if `time > wfbe_vbied_confirm` (no/expired window): set `wfbe_vbied_confirm = time + 5`, `titleText` "VBIED ARMED — select 'Detonate VBIED' again within 5s to confirm.", then exit. Nothing detonates. | `Client/Action/Action_GuerVbiedDetonate.sqf:22-29` |
| Step 2 — confirm | second selection inside the 5s window: set `wfbe_vbied_arming = true`, read `WFBE_C_GUER_VBIED_ARM_DELAY` (default 3), then `spawn` the countdown | `Client/Action/Action_GuerVbiedDetonate.sqf:31-35` |

The arm/confirm state is stored as plain (local) object variables on the truck: `wfbe_vbied_confirm` (the `time +5` deadline, default `-1`) and `wfbe_vbied_arming` (the re-entry lock, default `false`). Neither is broadcast — they only need to be consistent on the activating client, which is the same machine for every selection of a local addAction.

The countdown loop (`Action_GuerVbiedDetonate.sqf:35-48`) is a `spawn`ed thread: it counts `_armDelay` down to 1 with a one-second `titleText` tick ("VBIED detonating in %1..."), bails if the truck dies or goes null mid-countdown, and only on a still-alive truck sends the request to the server:

```
["RequestSpecial", ["guer-vbied-detonate", _veh, _player]] Call WFBE_CO_FNC_SendToServer;
```

This is the standard request convention used across the codebase (e.g. `Common/Functions/Common_RunCommanderTeam.sqf:71`): `WFBE_CO_FNC_SendToServer` hands `["guer-vbied-detonate", _veh, _player]` to the server's `Server_HandleSpecial.sqf`, which switches on the tag (`_args select 0`, `Server/Functions/Server_HandleSpecial.sqf:5`).

## The server detonation mechanic

The server re-validates everything (it cannot trust the client) and only then runs the blast, in the `guer-vbied-detonate` case of `Server_HandleSpecial.sqf`.

| Step | Logic | Source |
|------|-------|--------|
| Unpack | `_veh = _args select 1`, `_driver = _args select 2` | `Server/Functions/Server_HandleSpecial.sqf:485-487` |
| Re-validate | `!isNull _veh && alive _veh && WFBE_C_GUER_PLAYERSIDE > 0 && driver _veh == _driver && side _driver == resistance && typeOf _veh == WFBE_C_GUER_VBIED_TYPE` | `Server/Functions/Server_HandleSpecial.sqf:488` |
| Capture group | `_drvGrp = group _driver` (snapped before the blast — the suicide driver dies in it) | `Server/Functions/Server_HandleSpecial.sqf:493` |
| Victim snapshot | living `east`/`west` units of class `Man`/`LandVehicle`/`Air`/`Ship` within `WFBE_C_GUER_VBIED_BLAST_RADIUS` (default 30 m) of the truck | `Server/Functions/Server_HandleSpecial.sqf:495-501` |
| Blast | `_veh setDamage 1`, then `"Sh_122_HE" createVehicle _p` **three times** at the truck position | `Server/Functions/Server_HandleSpecial.sqf:503-506` |
| Resolve + pay | `sleep 4`, then for each snapshot victim now dead, add `round(unitPrice * WFBE_C_GUER_KILL_BOUNTY_COEF)` to the driver's team funds via `WFBE_CO_FNC_ChangeTeamFunds` | `Server/Functions/Server_HandleSpecial.sqf:508-521` |

The re-validation at line 488 makes the request safe to receive: it re-checks the gate, that `_driver` still drives `_veh`, that the driver is resistance, and that the vehicle is the configured VBIED type — so a forged request for a non-VBIED vehicle or a non-resistance caller is a no-op. The comment notes that because the client only sends this for a GUER VBIED driver, gate-off is a byte-for-byte no-op (`Server_HandleSpecial.sqf:483`).

The blast is the AI wildcard W21 idiom **exactly**: pop the truck with `setDamage 1` (so the engine's killed event handler still fires for kill credit) then stack three `Sh_122_HE` (122mm HE) at its position for a large lethal crater. Compare the W21 watcher's on-arrival detonation, which uses the identical three lines (`Server/Functions/AI_Commander_Wildcard.sqf:1235-1238`). `Sh_122_HE` is chosen because it is the only HE round confirmed loaded on both maps via the artillery configs (`Server_HandleSpecial.sqf:477-478`).

### Cash-for-kills payout

The payout mirrors the GUER kill-bounty already paid through the killed-event pipeline. For each victim that was alive in the snapshot and is dead after the HE resolves, the server looks up the unit's price record (`missionNamespace getVariable (typeOf _x)`) and credits `round((price select QUERYUNITPRICE) * _coef)` to `_drvGrp` (`Server_HandleSpecial.sqf:511-518`). `QUERYUNITPRICE` is the price index `2` into a unit's config-query array (`Common/Init/Init_CommonConstants.sqf:8`), and `_coef` is `WFBE_C_GUER_KILL_BOUNTY_COEF` (default 0.5). This is the same formula and the same `WFBE_CO_FNC_ChangeTeamFunds` sink as the normal GUER kill-bounty block (`Server/PVFunctions/RequestOnUnitKilled.sqf:92-99`). The two never double-pay: the createVehicle HE shells have no instigator, so the killed-event path never attributes the blast kills to the driver (`Server_HandleSpecial.sqf:481-482`).

## Configuration variables

All VBIED constants are `isNil`-guarded defaults in `Init_CommonConstants.sqf`, so MP mission parameters can override them without being clobbered.

| Variable | Default | Role | Source |
|----------|---------|------|--------|
| `WFBE_C_GUER_PLAYERSIDE` | `0` | master gate (0 = off, byte-for-byte today's behaviour) | `Common/Init/Init_CommonConstants.sqf:76` |
| `WFBE_C_GUER_VBIED_ARM_DELAY` | `3` | client arm countdown, in seconds | `Common/Init/Init_CommonConstants.sqf:77` |
| `WFBE_C_GUER_VBIED_BLAST_RADIUS` | `30` | server victim-snapshot radius, in metres | `Common/Init/Init_CommonConstants.sqf:78` |
| `WFBE_C_GUER_VBIED_TYPE` | `"hilux1_civil_2_covered"` | the suicide-truck classname the action gate + server guard match (overridden to `"datsun1_civil_2_covered"` on Takistan) | `Common/Init/Init_CommonConstants.sqf:79`, `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:71` |
| `WFBE_C_GUER_KILL_BOUNTY_COEF` | `0.5` | fraction of victim unit price paid per blast kill | `Common/Init/Init_CommonConstants.sqf:80` |

## A2-OA coding notes

The handler's header (`Action_GuerVbiedDetonate.sqf:9-10`) records the A2 OA-safe constraints it follows: array-form `private [...]` only (no inline typed `private _x =`), `_arr + [x]` rather than `pushBack`, no `params` / `select`-with-code / `isEqualType`, `titleText` instead of A3 hint structures, and lazy `&& {}` short-circuit. The server case follows the same rules — note the capitalized `Private [...]` declarations (`Server_HandleSpecial.sqf:485,490`), the `_victims = _victims + [_x]` accumulation (`Server_HandleSpecial.sqf:500`), and `nearestObjects` rather than any A3-only collection call (`Server_HandleSpecial.sqf:501`).

## Continue Reading

- [Support Specials And Tactical Modules Atlas](Support-Specials-And-Tactical-Modules-Atlas) — other RequestSpecial tags and their server cases
- [Kill and Score Pipeline](Kill-And-Score-Pipeline) — the OnUnitKilled flow and GUER kill-bounty routing the VBIED payout mirrors
- [Faction Unit and Vehicle Roster Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — the GUER buy pool the VBIED truck belongs to
- [Gameplay Systems Atlas](Gameplay-Systems-Atlas) — GUER Insurgents branch overview
- [Feature Status Register](Feature-Status-Register) — Feature B (GUER player-side) status

# GUER Insurgents Branch Audit

This page deep-audits the GUER Insurgents playable faction as merged source truth, not pending-branch evidence. Unlike the other branch audits, this feature is already merged to `master` at `9af83596` and is live on Chernarus.

## What this branch is

The GUER Insurgents work adds a third playable side (RESISTANCE) to the source Chernarus mission as a gated, harass-only faction. It is merged, not pending. The feature is parked behind a master lobby gate and was enabled live by forcing that gate's default on at build time.

- Merged head: `9af83596` (GUER Insurgents playable faction, merged to `master`)
- Live status: enabled on Chernarus, clean boot with `ErrInExpr=0`
- Master gate: `WFBE_C_GUER_PLAYERSIDE` lobby param (`Rsc/Parameters.hpp`), default `0` = no GUER slots and the mission plays as a normal 2-side game; any value `>0` enables the faction
- Live enable: the param default was forced to `1` at build time, so the deployed mission ships with GUER on while the source default stays `0`
- Scope: source Chernarus mission only; Takistan is a dormant server-mirror no-op, not a player faction yet

## Where it lives

| Area | Source evidence |
| --- | --- |
| Master gate param | `Rsc/Parameters.hpp` `WFBE_C_GUER_PLAYERSIDE` (default `0`, build-time forced `1` live) |
| GUER slot suppression | `WFBE_C_GUER_PLAYERSIDE = 0` suppresses the 4 RESISTANCE slots (gate-OFF suppression) |
| HC reseat slots | 2 dedicated `forceHeadlessClient` slots so HCs reseat to CIV, not Blufor |
| VBIED detonate action (client) | `Client/Action/Action_GuerVbiedDetonate.sqf` |
| VBIED detonate handler (server) | `Server/Functions/Server_HandleSpecial.sqf` case `"guer-vbied-detonate"` |
| Ka-137 EASA loadouts | `Client/Module/EASA/EASA_Init.sqf` |
| GUER economy / stipend | `Server/Server_GuerStipend.sqf` |
| GUER side-patrol cap | `server_side_patrols.sqf:33` |
| Low-pop AI-commander teams tuning | `WFBE_C_AICOM_TEAMS_PC_LOW` (5 -> 7) |
| Skin selector (disabled) | `WFBE_C_SKIN_SELECTOR = 0` + `CA_Skin_Button` hidden |

## How it runs

The gate decides everything. With `WFBE_C_GUER_PLAYERSIDE = 0` the mission keeps its original 2-side slot layout and no RESISTANCE slots appear. With the gate `>0` the slot layout changes:

- WEST/EAST playable slots are cut `27 -> 14` (a safe de-slot to make room).
- 4 GUER RESISTANCE slots are added: 2 Insurgent Engineer, 1 Sniper, 1 Medic.
- 2 dedicated `forceHeadlessClient` slots reseat HCs to CIV instead of Blufor, so HC presence does not consume a Blufor player slot.

When the gate is off, the 4 GUER slots are suppressed so the mission is byte-compatible with the legacy 2-side experience.

### Buyable VBIED

GUER's signature weapon is a buyable vehicle-borne IED:

- Vehicle: `hilux1_civil_2_covered`, available at any GUER-owned town-center depot from tick 1 (it is in the `WFBE_GUERDEPOTUNITS` tier-0 pool).
- Driver-only action: "Detonate VBIED" (`Client/Action/Action_GuerVbiedDetonate.sqf`), a 2-step confirm plus an arm delay of `WFBE_C_GUER_VBIED_ARM_DELAY = 3s`.
- Server handler: `Server/Functions/Server_HandleSpecial.sqf` case `"guer-vbied-detonate"` applies `setDamage 1` plus `3x Sh_122_HE`, with blast radius `WFBE_C_GUER_VBIED_BLAST_RADIUS = 30m`.
- Reward: cash-for-kills back to the driver's GUER team, scaled by `WFBE_C_GUER_KILL_BOUNTY_COEF = 0.5`.
- Authority: a server-side auth guard validates the request (driver is the driver of the vehicle, side is `resistance`, chassis type matches) before detonation.

### Ka-137 gunship

`Ka137_MG_PMC` is buyable at a town depot with three EASA loadouts (`Client/Module/EASA/EASA_Init.sqf`):

| Loadout | Weapons |
| --- | --- |
| `[MR]` | MG |
| `[AG]` | Konkurs AT-5 (`AT5Launcher` + `5Rnd_AT5_BRDM2`) + S-5 rockets |
| `[AA]` | Igla |

Playtest-pending caveat: the Ka-137 is a recon airframe with no weapon-pylon proxy, so ATGM fire-from-origin must be verified in-engine. The 57mm rockets are the proven fallback if the AT-5 fire geometry does not hold.

### Economy

`Server/Server_GuerStipend.sqf` is the GUER economy anchor. GUER is funds-only (no supply economy). The stipend is tier-scaled and town-deficit-scaled, and the script iterates `playableUnits` to pay GUER players. WEST/EAST kills credited to GUER pay kill-funds back to the team.

### Tuning shipped with it

| Tuning | Change | Source |
| --- | --- | --- |
| GUER side-patrol cap | `2 -> 3` (effective = `min(cap, Patrols research level)`) | `server_side_patrols.sqf:33` |
| Low-pop AI-commander teams | `WFBE_C_AICOM_TEAMS_PC_LOW` `5 -> 7` (more action at low pop) | constant |

### Skin selector disabled

The skin selector is shipped off: `WFBE_C_SKIN_SELECTOR = 0` and `CA_Skin_Button` is hidden. This is a separate feature, intentionally off until it works, and is not part of the GUER faction contract.

## No-command-center guard pattern

GUER has no base, HQ or commander, so any code that walks all present sides and assumes each one owns a command center had to be made resistance-safe. The shipped pattern is:

- `basearea.sqf` and `updateresources.sqf` exclude resistance from their side loops with `forEach (WFBE_PRESENTSIDES - [resistance])`, so neither tries to resolve a GUER base/HQ.
- `Common_GetCommanderTeam.sqf` returns an `objNull` default, so a GUER caller gets a safe null commander team instead of erroring.
- `Server_GuerStipend.sqf` pays GUER players via `playableUnits` rather than via a commander team roster.

The broad audit found all other `GetCommanderTeam`, `GetFactories` and `COMMANDCENTERTYPE` call-sites already null-safe, so no further command-center hardening was required for the gate-on path. This is consistent with the clean `ErrInExpr=0` boot.

## What is risky or incomplete

| Risk | Evidence | Why it matters |
| --- | --- | --- |
| Live default differs from source default | Source `WFBE_C_GUER_PLAYERSIDE` default `0`; deployed build forces `1` | A fresh source build is GUER-off by default; live-on depends on the build-time force. Keep the build step explicit so a rebuild does not silently ship GUER off. |
| Ka-137 ATGM is playtest-pending | Recon airframe, no weapon-pylon proxy; AT-5 fire-from-origin unverified in-engine | The `[AG]` AT-5 may not fire correctly; 57mm rockets are the proven fallback and should remain available until verified. |
| Takistan is mirror-only, not a faction | Takistan ships the server-mirror as a dormant no-op | "GUER is in the game" is Chernarus-only. Takistan player parity is a tracked follow-up (~150-250 LOC). |
| Skin selector off | `WFBE_C_SKIN_SELECTOR = 0`, `CA_Skin_Button` hidden | GUER players cannot reskin yet; do not advertise skin choice until the selector works. |
| VBIED is high-impact and player-driven | `setDamage 1` + `3x Sh_122_HE`, 30m radius, bounty `0.5` | Treat as a balance-sensitive gameplay weapon. Smoke for grief potential, friendly-fire credit and reward scaling. |
| De-slot reduces WEST/EAST capacity | Player slots `27 -> 14` when gate on | High-pop nights lose Blufor/Opfor slots when GUER is enabled; owner should confirm the slot trade is acceptable for the target pop. |

## Remaining gates (runtime / balance / parity)

This feature is already merged to `master` at `9af83596` and live on Chernarus with `ErrInExpr=0`, so the standard "promote the branch" step is complete. The remaining gates are runtime/balance and parity, not merge:

1. Keep the build-time gate force (`WFBE_C_GUER_PLAYERSIDE` default `1` in the deployed package) documented so rebuilds stay GUER-on.
2. Verify the Ka-137 `[AG]` AT-5 fire-from-origin in-engine; keep 57mm rockets as the fallback until proven.
3. Smoke the VBIED end to end: buy at a GUER-owned depot, 2-step confirm, 3s arm delay, blast/kill credit and the server auth guard rejecting forged requests.
4. Smoke gate-off: confirm `WFBE_C_GUER_PLAYERSIDE = 0` fully suppresses the 4 GUER slots and restores the 2-side layout.
5. Smoke HC reseat: confirm HCs land on CIV via the `forceHeadlessClient` slots, not Blufor.
6. Decide and schedule Takistan player parity (~150-250 LOC) versus leaving the server-mirror dormant.

## Development lesson

A gated faction has two truths that must not drift: the source default and the deployed default. Here the source ships `WFBE_C_GUER_PLAYERSIDE = 0` for legacy safety while the live build forces it on. Future agents must state the gate value for both source and deploy before claiming the faction is "on" or "off", and must keep the gate-off path byte-compatible with the legacy 2-side experience. The no-command-center guard is the structural lesson: adding a side with no HQ means every side-walking loop and every `GetCommanderTeam`/`GetFactories`/`COMMANDCENTERTYPE` reader must be resistance-safe before the gate goes on.

## Continue Reading

Main map: [Home](Home) | Status row: [Feature status register](Feature-Status-Register) | Related: [Zargabad branch audit](Zargabad-Branch-Audit) | Build/deploy: [Testing, debugging and release workflow](Testing-Debugging-And-Release-Workflow)

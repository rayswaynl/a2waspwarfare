# Design: EASA on AI aircraft + richer AI squad equipment (Ray wish; implement after cmdcon41)

Fleet design `a6d49f9` (read-only, verified). Ray: "allow AI squads better equipment, and use EASA on
helis/jets once unlocked."

## Key facts (verified)
- EASA data (`WFBE_EASA_Vehicles/Default/Loadouts`) is built CLIENT-ONLY (`Client\Module\EASA\EASA_Init.sqf:685`)
  — nil on server/HC. **Never call EASA_Equip server/HC-side.**
- **The proven precedent:** `Server\Server_GuerAirDef.sqf:295-311` already applies EASA kits to AI aircraft
  server-side by HARDCODED classnames + the turret/hull add/remove idiom. Copy that pattern.
- AICOM air hulls are LOCAL TO THE HC for life (founded via delegate → `Common_RunCommanderTeam.sqf`); the swap
  must run there, right after `_vehicles` is built (insert after ~L295, before the air-insert block).
- Unlock gate = `WFBE_UP_EASA (=15) >= 1` (menu gate `GUI_Menu_Service.sqf:243`; dep `[[WFBE_UP_AIR,1]]`).
  EASA is ~31st in the AI research order → normally never researched; the new ECON_SINK research loop WILL
  eventually pick it up when rich ("endgame air" — thematically right). Optional flag
  `WFBE_C_AICOM_EASA_AI_REQUIRE_UPGRADE=0` to gate on airfield ownership instead.
- Turret-path airframes: ONLY `AW159_Lynx_BAF` + `Ka137_MG_PMC` (`EASA_Equip.sqf:28`); all jets + other helis
  use hull addWeapon/addMagazine.

## (a) `WFBE_C_AICOM_EASA_AI` (default 1)
Ship a DEFAULT-kit table `WFBE_C_AICOM_EASA_KITS` in Init_CommonConstants (rows
`[class, stockW, stockM, kitW, kitM, turretBool]`, values copied verbatim from EASA_Init rows — e.g.
AH64D_EP1 +StingerLauncher_twice, AH1Z +Sidewinder, Ka52/Mi24_P +Igla_twice, AW159 +Stinger [TURRET]).
At founding on the HC, per local alive Air hull: remove stock W/M, add kit W/M (turret variants for turret rows).
**Do NOT set `WFBE_EASA_Setup` on AI hulls** — a non-index value breaks `Common_RearmVehicle.sqf`'s loadout
indexing for players. JIP-safe (weapon state replicates with the vehicle).

## (b) `WFBE_C_AICOM_RICH_GEAR` (default 1)
No AI-gear hook exists today (WFBE_UP_GEAR only gates the PLAYER gear menu). Add a tiny post-create pass on the
HC after CreateTeam: tier = `GetSideUpgrades select WFBE_UP_GEAR` (+1 when `wfbe_aicom_econ_surge`); below
`WFBE_C_AICOM_RICH_GEAR_MIN_TIER (2)` do nothing. Delta per side (`WFBE_C_AICOM_GEAR_DELTA_<side>`): leader
rifle → sighted variant (remove+add + MATCHING mags) + 1-2 extra squad mags/AT round. `selectWeapon
(primaryWeapon _x)` after. **Hard rule: every added weapon needs its matching magazine classname** (A2 addWeapon
gives an empty weapon); author per faction on BOTH maps (CH: USMC/RU/CDF/GUE/INS · TK: US/TKA/TKGUE).

## Risks
R1 locality (HC-local only, `local _x` gate) · R3 don't touch WFBE_EASA_Setup · R4 unlock rarity (econ-sink
solves) · R5 ammo compat = the main hazard, keep deltas tiny · R7 turret-list completeness · R8 GUER untouched
(its air is already kitted by Server_GuerAirDef; no AICOM).

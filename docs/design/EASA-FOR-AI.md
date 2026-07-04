# Design/status: EASA on AI aircraft + richer AI squad equipment

Fleet design `a6d49f9` (read-only, verified). Ray: "allow AI squads better equipment, and use EASA on
helis/jets once unlocked."

## Live lane status - 2026-07-02
- **Implemented on `origin/claude/build84-cmdcon36@6f2fc4b`.** The live source now runs the founding-time
  EASA/rich-gear pass in `Common_RunCommanderTeam.sqf:320-469`, immediately after `_vehicles` is split and
  before the air-insert block.
- **Config/defaults:** `Init_CommonConstants.sqf:865-867` registers `WFBE_C_AICOM_EASA_AI = 1`,
  `WFBE_C_AICOM_RICH_GEAR = 1`, and `WFBE_C_AICOM_RICH_GEAR_MIN_TIER = 2`.
- **Telemetry:** successful EASA kits log `EASA_AI_KIT`; rich gear logs `RICH_GEAR` with tier, extra magazine
  count, and AT-magazine detail.
- **Intentional live deviations from this proposal:** the EASA kit table is inline in `Common_RunCommanderTeam`
  rather than hoisted into constants, and rich gear is the safer magazine-only bump rather than per-faction weapon
  swaps. The airfield-ownership shortcut flag proposed below was not added; the live path keeps the hard
  researched-upgrade gate.
- **Remaining work:** owner/playtest smoke only. Confirm the RPT tokens after the side actually researches EASA
  or reaches the configured gear tier, and watch for ammo/class compatibility errors.

## Key facts (verified)
- EASA data (`WFBE_EASA_Vehicles/Default/Loadouts`) is built CLIENT-ONLY (`Client\Module\EASA\EASA_Init.sqf:685`)
  — nil on server/HC. **Never call EASA_Equip server/HC-side.**
- **The proven precedent:** `Server\Server_GuerAirDef.sqf:295-311` already applies EASA kits to AI aircraft
  server-side by HARDCODED classnames + the turret/hull add/remove idiom. Copy that pattern.
- AICOM air hulls are LOCAL TO THE HC for life (founded via delegate → `Common_RunCommanderTeam.sqf`); the swap
  now runs there, right after `_vehicles` is built and before the air-insert block.
- Unlock gate = `WFBE_UP_EASA (=15) >= 1` (menu gate `GUI_Menu_Service.sqf:243`; dep `[[WFBE_UP_AIR,1]]`).
  EASA is ~31st in the AI research order; the ECON_SINK research loop can eventually pick it up when rich
  ("endgame air" — thematically right). The live implementation keeps this hard research gate.
- Turret-path airframes: ONLY `AW159_Lynx_BAF` + `Ka137_MG_PMC` (`EASA_Equip.sqf:28`); all jets + other helis
  use hull addWeapon/addMagazine.

## (a) `WFBE_C_AICOM_EASA_AI` (default 1) - live
The live implementation keeps the default-kit table inline in `Common_RunCommanderTeam.sqf:341-371` as
`[class, stockW, stockM, kitW, kitM, turretBool]` rows copied from EASA_Init. Examples include
`AH64D_EP1` + `StingerLauncher_twice`, `AH1Z` + `SidewinderLaucher_AH1Z`, `Ka52`/`Mi24_P` + `Igla_twice`,
and `AW159_Lynx_BAF` as the turret row.

At founding on the HC, per local alive Air hull, the code removes stock weapons/magazines and adds the kit
weapons/magazines. Turret variants use the `[-1]` turret path; jets and non-turret helis use hull add/remove.
**Do NOT set `WFBE_EASA_Setup` on AI hulls** — a non-index value breaks `Common_RearmVehicle.sqf`'s loadout
indexing for players. JIP-safe (weapon state replicates with the vehicle). Success logs `EASA_AI_KIT`.

## (b) `WFBE_C_AICOM_RICH_GEAR` (default 1) - live
The live implementation is intentionally smaller and ammo-safer than the original weapon-swap proposal. The
founding pass in `Common_RunCommanderTeam.sqf:409-469` reads the side's actual `WFBE_UP_GEAR` level, adds one
virtual tier while `wfbe_aicom_econ_surge` is true, caps at tier 5, and does nothing below
`WFBE_C_AICOM_RICH_GEAR_MIN_TIER`.

Instead of side-specific weapon swaps, each local live infantry unit receives extra magazines for its own current
primary weapon's first configured magazine type. Tier 2-3 gives +1 magazine; tier 4+ gives +2 magazines and the
leader gets one extra AT round copied from an AT soldier in the same team when available. Success logs
`RICH_GEAR`.

## Risks
R1 locality (HC-local only, `local _x` gate) · R3 don't touch WFBE_EASA_Setup · R4 unlock rarity (econ-sink
solves) · R5 ammo compat = the main hazard, keep deltas tiny · R7 turret-list completeness · R8 GUER untouched
(its air is already kitted by Server_GuerAirDef; no AICOM).

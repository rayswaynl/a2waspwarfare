# AICOM Air Research Status - 2026-07-03

## Scope

Fleet lane 96 asked for the AICOM air-research gap:

- add `WFBE_UP_AIR` to the AICOM research queue;
- set `WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI` appropriately;
- keep it flag-gated/default-off;
- verify the research-queue insertion point.

This pass is docs-only. `AI_Commander.sqf`, `AI_Commander_Teams.sqf`, and
`Init_CommonConstants.sqf` are hot AICOM source surfaces, and open draft PR #374 already carries
the source implementation for `WFBE_C_AICOM_RESEARCH_AIR` plus adjacent AICOM effectiveness work.

Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`.

## Verdict

Lane 96 is partially stale on the current target.

The AICOM does not literally "never research air": every maintained root has `WFBE_UP_AIR`
entries in all 11 faction `WFBE_C_UPGRADES_%1_AI_ORDER` arrays. However, the current target still
lacks the explicit/default-off `WFBE_C_AICOM_RESEARCH_AIR` feature, and the prepended doctrine
research program does not add AIR when the side builds or holds an Aircraft Factory. AIR remains in
the later faction tail order, while helicopters can already bypass the AIR tier through the
Aircraft Factory structure waiver.

So the live status is:

- **Not absent:** AIR research exists in the faction AI-order tail.
- **Still not strict:** A held Aircraft Factory can make heli templates AIR-tier eligible while
  `WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI` stays default-on.
- **Not implemented on target:** no `WFBE_C_AICOM_RESEARCH_AIR` flag or AF-conditioned AIR research
  insertion exists in `claude/build84-cmdcon36`.
- **Covered elsewhere:** open draft PR #374 implements the source lane and should be reviewed or
  split rather than duplicated here.

## Evidence

### Current heli waiver remains default-on

`Common/Init/Init_CommonConstants.sqf:395` in Chernarus, Takistan, and Zargabad:

```sqf
if (isNil "WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI") then {WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI = 1};
```

`Server/AI/Commander/AI_Commander_Teams.sqf:302-323` documents and computes the waiver:

- root-cause comment says the doctrine program does not prepend AIR;
- `_hasAirFactory` is true when a live Aircraft Factory structure exists;
- `_airHeliWaive = _hasAirFactory && {WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI > 0}`.

The waiver is then consumed at:

- `AI_Commander_Teams.sqf:338` for `_airTierWaive`;
- `AI_Commander_Teams.sqf:343` for the template AIR track check;
- `AI_Commander_Teams.sqf:353` for per-unit `QUERYUNITUPGRADE` AIR checks;
- `AI_Commander_Teams.sqf:433` for the early air-roster strip.

### AIR is present in the faction tail order

Example: `Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:153-187` includes:

- `[WFBE_UP_AIR,1]` at `:176`;
- `[WFBE_UP_AIR,2]` at `:178`;
- `[WFBE_UP_AIR,3]` at `:182`;
- `[WFBE_UP_AIRAAM,1]` at `:187`.

Count check across maintained roots:

| Root | Upgrade files | Files with `[WFBE_UP_AIR,1]` in AI order |
| --- | ---: | ---: |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus` | 11 | 11 |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` | 11 | 11 |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad` | 11 | 11 |

This is why "never researches air" is no longer a precise description of the target branch. The
remaining gap is that AIR is not in the doctrine accelerator and is not tied to Aircraft Factory
availability.

### The doctrine accelerator does not add AIR

`Server/AI/Commander/AI_Commander.sqf:68-91` prepends a doctrine program before the faction order.
The program rushes Barracks, the chosen Light/Heavy factory, Gear, Supply Rate, and Patrols:

- `[WFBE_UP_BARRACKS,1]`;
- chosen factory levels 1-3;
- `[WFBE_UP_GEAR,1..3]`;
- `[WFBE_UP_SUPPLYRATE,1..2]`;
- `[WFBE_UP_PATROLS,1..3]`.

There is no `WFBE_UP_AIR` entry in that prepended program, and `rg` found no
`WFBE_C_AICOM_RESEARCH_AIR` symbol anywhere under the maintained mission roots.

### Aircraft production is established-town gated, not research inserted

`Server/AI/Commander/AI_Commander_Produce.sqf:47-57` adds the Aircraft factory refill path only
after the side owns enough towns:

```sqf
if (_ownTowns >= (missionNamespace getVariable ["WFBE_C_AICOM_AIR_MIN_TOWNS", 4])) then {
    _facDefs = _facDefs + [["Aircraft","AIRCRAFTUNITS",WFBE_UP_AIR]];
};
```

That controls whether Aircraft production/refill is considered. It does not insert AIR research
earlier in the upgrade queue.

## Relationship To Existing Docs And PRs

`docs/design/AICOM-AIRCRAFT.md` already records the policy shape: do not flip
`WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI` alone, because a strict heli gate must be paired with an
AIR research path and soak validation. Its historical "NEVER queues" wording should be read as "the
prepended doctrine accelerator does not queue AIR"; the current faction tail orders do include AIR.

Open draft PR #374, `feat(aicom-effectiveness-pack2): RESEARCH_AIR + STRIKE_AT_BONUS + MHQ_RING_CLEAR`,
is the current source implementation lane. Its metadata says it adds `WFBE_C_AICOM_RESEARCH_AIR`
default-off and appends `[WFBE_UP_AIR,1]` / `[WFBE_UP_AIR,2]` when an Aircraft Factory is present.
It touches the hot AICOM source files and generated roots, so this status lane should not duplicate
that code path.

## Recommendation

Treat lane 96 as covered by open PR #374 for source work. If the air-research fix needs to ship
independently, split only the `WFBE_C_AICOM_RESEARCH_AIR` portion out of #374, keeping these
constraints:

- pair any `WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI = 0` strict-gate experiment with an explicit AIR
  research insertion;
- keep the behavior default-off until boot/soak proves AICOM still flies;
- decide separately whether captured-airfield `WFBE_C_AICOM_AIRFIELD_FREE_AIR` should remain a
  different "hold the airfield, may fly" policy;
- avoid touching HC architecture, enrollment/JIP, antistack, ACR content, or combat-AI
  sim/distance gates.

## Validation Notes

- `rg --fixed-strings WFBE_C_AICOM_RESEARCH_AIR` under maintained mission roots: 0 hits.
- `WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI` hits: one constant and two Teams refs per root.
- `_airHeliWaive` hits: four refs per maintained `AI_Commander_Teams.sqf`.
- `AI_Commander.sqf` doctrine program hits: one per maintained root.
- `[WFBE_UP_AIR,1]` is present in all 11 `Upgrades_*.sqf` AI-order files per maintained root.
- Reference hashes from Chernarus:
  - `Init_CommonConstants.sqf`: `0259B5AFC676AEC0397EE962AD6E4C8C9F72BB70329C6C0E6E4BC00138D7F29C`
  - `AI_Commander.sqf`: `007676A61D52CFFDC3A01456A79F02CE0C3E184F04FD3B67A1DE5A80789B0F2D`
  - `AI_Commander_Teams.sqf`: `F5AAED93EEEFA5F46D581358D7728962C8E9DFD168CA34964D851DB66A7029F6`
  - `Upgrades_CO_US.sqf`: `5B3832423C9332FE4A8D3505C36F08FF89EE0F4C4C81E4CA72ED788D6856F1D4`

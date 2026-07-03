# AICOM D1 Assault Choreography Status - 2026-07-03

## Scope

Fleet lane 100 asks for the ALIFE-V2 D1 assault choreography package:

- armor forms an overwatch line about 300 m out;
- infantry dismounts and bounds in first;
- 2-3 artillery prep rounds land on the town during staging;
- the assault is then released;
- behavior is flag-gated/default-off.

This pass is docs-only. The relevant source surfaces are hot AICOM files:
`AI_Commander_Strategy.sqf`, `AI_Commander_AssignTowns.sqf`, and
`Common_RunCommanderTeam.sqf`. They were read for anchors only.

Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`.

## Verdict

Lane 100 is not implemented as the requested bundled D1 feature on the current target.

Several primitives already exist:

- HQ-strike staging mass can rally multiple strike teams short of the enemy HQ and release them by
  body count or timeout.
- Town assault arrival already applies approach smoke and a tight assault SAD.
- Town capture already dismounts non-crew infantry, sweeps camps first, then pushes foot soldiers
  to the depot/town center.
- AICOM artillery systems exist separately.

But those primitives are not wired together as "D1 assault choreography at the staging point":

- no default-off D1 flag exists;
- no town-assault staging/release phase exists;
- no 300 m armor overwatch line exists;
- no D1-coupled artillery prep fire exists;
- no infantry-bounds-first release gate exists.

## Proposal Anchor

`docs/design/ALIFE-V2-AND-DOCTRINES.md:52-55` is the source proposal:

> Assault choreography at the staging point: armor forms an overwatch line about 300 m out,
> infantry dismounts and bounds in first, 2-3 artillery prep rounds land on the town during
> staging, then release.

The proposal says the primitives exist. This audit agrees on the primitives, but not on a complete
D1 orchestration feature.

## Current Primitives

### HQ-strike staging mass exists, but only for HQ strikes

`Common/Init/Init_CommonConstants.sqf:848-852` defines the HQ-strike staging tunables:

- `WFBE_C_AICOM_STRIKE_STAGE = 1`;
- `WFBE_C_AICOM_STRIKE_STAGE_BODIES = 14`;
- `WFBE_C_AICOM_STRIKE_STAGE_TIMEOUT = 240`;
- `WFBE_C_AICOM_STRIKE_STAGE_DIST = 800`;
- `WFBE_C_AICOM_STRIKE_STAGE_ARRIVE = 400`.

`Server/AI/Commander/AI_Commander_Strategy.sqf:735-796` implements the staging-mass behavior for
the enemy-HQ strike. It computes a rally point `WFBE_C_AICOM_STRIKE_STAGE_DIST` short of the enemy
HQ, counts bodies within `WFBE_C_AICOM_STRIKE_STAGE_ARRIVE`, and releases the strike once enough
bodies gather or the timeout expires.

`AI_Commander_Strategy.sqf:861-864` points newly recruited strikers at the rally while massing and
at the enemy HQ once released. This is useful precedent, but it is not town-assault D1: the target is
the enemy HQ and the mode is the HQ-strike `goto` path, not a town objective staging point.

### Town assault arrival already has smoke and SAD behavior

`Common_RunCommanderTeam.sqf:1363-1474` handles the towns-target arrival latch:

- `:1365-1369` computes the arrival gate and logs `CAPTURE_TRACE|ARRIVAL_GATE`;
- `:1415-1451` optionally spawns two faction smoke shells on the assault approach axis via
  `WFBE_C_AICOM_SMOKE`;
- `:1471` lays the arrival SAD using `WFBE_C_AICOM_ASSAULT_SAD`.

`Init_CommonConstants.sqf:883-884` defaults smoke discipline on:

- `WFBE_C_AICOM_SMOKE = 1`;
- `WFBE_C_AICOM_SMOKE_COOLDOWN = 120`.

This covers smoke discipline, not the D1 staging/release package.

### Town capture already dismounts infantry and clears camps first

`Common_RunCommanderTeam.sqf:1669-1692` always dismounts alive non-crew infantry for the capture
phase while keeping drivers/gunners in their hulls.

`Common_RunCommanderTeam.sqf:1694-1857` runs the camp-first behavior:

- foot infantry moves to camps;
- live enemies near each camp are revealed;
- in AllCamps mode, camp grinding stays bounded by `WFBE_C_AICOM_ASSAULT_HOLD`;
- the plant is released before the center hold so units are not frozen.

`Common_RunCommanderTeam.sqf:1859-1895` then pushes the on-foot soldiers to the depot/town center
and lays a LINE formation SAD for the capture hold.

These are important D1 building blocks, but the armor is not placed into a 300 m overwatch line
outside the objective. Existing comments say crew stay mounted so hulls remain driveable and parked;
that is not the same as outward overwatch.

### Artillery exists, but is not D1-coupled prep fire

Current AICOM artillery paths are separate:

- `Common_RunCommanderTeam.sqf:2204-2209` describes SPG fire missions gated by
  `WFBE_C_AICOM_ARTY_ENABLED`;
- `AI_Commander_Strategy.sqf:1027-1083` handles autonomous/player-request artillery targeting;
- `AI_Commander_PlayerArty.sqf` handles player-requested fire missions.

The D1 request is specifically "2-3 artillery prep rounds land on the town during staging." This
audit found no `ARTY_PREP`/`PREP_ARTY`/D1 staging hook coupling artillery to a town assault release.

## Missing Feature Surface

Target-wide source scan found 0 hits for likely D1 feature symbols:

- `WFBE_C_AICOM_ASSAULT_CHOREOGRAPHY`;
- `WFBE_C_AICOM_ASSAULT_STAGE`;
- `WFBE_C_AICOM_ASSAULT_OVERWATCH`;
- `WFBE_C_AICOM_ARTY_PREP`.

Maintained-root primitive counts:

| Root | `STAGING-MASS` hits | `CAMP-FIRST GATE` hits | `WFBE_C_AICOM_SMOKE` constant hits |
| --- | ---: | ---: | ---: |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus` | 3 | 1 | 2 |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` | 3 | 1 | 2 |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad` | 3 | 1 | 2 |

## Relationship To Nearby AICOM PRs

Do not confuse D1 with nearby open lanes:

- PR #285 covers D3 armor screens during capture;
- PR #307 covers D4 target-aware team compositions;
- PR #363 covers the D7 feint dispatch piece;
- PR #374 covers unrelated RESEARCH_AIR / strike AT bonus / MHQ ring-clear work.

Those may affect the same hot AICOM surface area, but they do not ship D1's town-assault staging,
armor-overwatch, artillery-prep, infantry-first release bundle.

## Recommendation

Keep lane 100 as a future source lane, not a stale/already-done lane.

If implemented later, keep it behind a new default-off flag and compose it deliberately from the
existing pieces:

- reuse the `WFBE_C_AICOM_STRIKE_STAGE` rally/release idiom, but target town-assault orders rather
  than the enemy-HQ strike path;
- reuse existing capture dismount behavior, but decide whether the infantry-first bound happens
  before camp-first or as the first step of camp-first;
- keep armor overwatch distinct from D3's capture-ring outward screen, because D1's line is a
  staging/prep posture about 300 m out;
- treat artillery prep as optional and bounded, never as an unbounded loop or a requirement for
  release;
- require boot/soak validation before enabling, because this would coordinate multiple AICOM
  systems that already have several open PRs.

## Validation Notes

- `rg --fixed-strings WFBE_C_AICOM_ASSAULT_CHOREOGRAPHY` under maintained roots: 0 hits.
- `rg --fixed-strings WFBE_C_AICOM_ASSAULT_STAGE` under maintained roots: 0 hits.
- `rg --fixed-strings WFBE_C_AICOM_ASSAULT_OVERWATCH` under maintained roots: 0 hits.
- `rg --fixed-strings WFBE_C_AICOM_ARTY_PREP` under maintained roots: 0 hits.
- `STAGING-MASS` exists in all maintained `AI_Commander_Strategy.sqf` copies.
- `CAMP-FIRST GATE` exists in all maintained `Common_RunCommanderTeam.sqf` copies.
- Reference hashes from Chernarus:
  - `Init_CommonConstants.sqf`: `0259B5AFC676AEC0397EE962AD6E4C8C9F72BB70329C6C0E6E4BC00138D7F29C`
  - `AI_Commander_Strategy.sqf`: `BEC4C40780D8C3440A7170C4059CFA741F581720F600BB91F652829DF57F8806`
  - `Common_RunCommanderTeam.sqf`: `8BF85FAC37DE04DC6355B5C930B5BD5769A527114A175377BA57F49ACE2F6CCD`
  - `AI_Commander_AssignTowns.sqf`: `852DE78475B26F01C6EB2A4956B2C99AD4B4E72A49943A02B342200F0934ED1D`

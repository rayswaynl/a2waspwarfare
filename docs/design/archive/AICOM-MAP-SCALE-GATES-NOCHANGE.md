# AICOM map-scale gates no-change audit

Lane 367 asked whether the AICOM ENGAGE and HQ-strike town gates still use Chernarus-scaled
absolute thresholds on small maps, especially Zargabad. Current Build84 already contains a
Zargabad-specific pre-set block that prevents that failure mode, so this lane does not change
mission source.

## Verdict

No source patch is warranted for the lane-367 premise on `claude/build84-cmdcon36`.

The live consumers still read absolute constants:

- `AI_Commander_Allocate.sqf` reads `WFBE_C_AICOM_ENGAGE_MIN_TOWNS`.
- `AI_Commander_Strategy.sqf` reads `WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS`.

But current `Init_CommonConstants.sqf` pre-sets the Zargabad values before the later Chernarus/Takistan
`isNil` defaults can run:

- `WFBE_C_AICOM_ENGAGE_MIN_TOWNS = 4` on `worldName == "Zargabad"`;
- `WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS = 5` on `worldName == "Zargabad"`;
- the later defaults of 10 and 12 are skipped on Zargabad because the variables are no longer nil.

The result is intentionally map-specific: Chernarus/Takistan retain their current defaults, while
Zargabad gets reachable gates for its smaller mission.

## Source evidence

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:75-98`
contains the Zargabad-scoped pre-set block. Its comments state that the block runs before the
`isNil`-guarded Chernarus/Takistan defaults, and the block sets the two lane-367 gate constants to
5 and 4.

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:599-600`
still defines the Chernarus/Takistan HQ-strike default as 12 if the variable is nil. On Zargabad it
is already set by the pre-set block, so this default does not override it.

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:700`
still defines the expansion-first ENGAGE default as 10 if the variable is nil. On Zargabad it is
already set by the pre-set block, so this default does not override it.

The maintained Takistan and Zargabad constants mirrors match the Chernarus source exactly. SHA256 for
all three `Init_CommonConstants.sqf` files is
`2BEB0448A1C03CC11D8238ECCA9C2AA7C84D752EE0ACD2C6492DCFFA544DCB04`.

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:38-49`
is the live expansion-first gate consumer. It reads `WFBE_C_AICOM_ENGAGE_MIN_TOWNS` from
`missionNamespace`, so it receives 4 on Zargabad and 10 on the current Chernarus/Takistan path.

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Strategy.sqf:688-690`
is the live HQ-strike gate consumer. It reads `WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS` from
`missionNamespace`, so it receives 5 on Zargabad and 12 on the current Chernarus/Takistan path.

Mission metadata confirms the scale contrast:

- Chernarus `mission.sqm:3332` sets `totalTowns` to 46.
- Takistan `mission.sqm:61` sets `totalTowns` to 31.
- Zargabad `mission.sqm:1559` sets `totalTowns` to 10.

The repo handbook already documents the same Zargabad-specific constant block in
`docs/AGENT-HANDBOOK.md:76-94`.

## No-change rationale

Changing `AI_Commander_Allocate.sqf`, `AI_Commander_Strategy.sqf`, or `Init_CommonConstants.sqf` for
this lane would be a source edit against hot files, and the specific Zargabad bug named by the lane is
already handled on the current base.

Future AICOM map-scaling work should stay separate:

- lane 368 / PR #515 covers distance-band scaling and is not the same as these town-count gates;
- a future lobby-parameter lane could expose these gates for live tuning, but that would be a feature
  change rather than a no-change verification;
- any change to Chernarus or Takistan defaults needs soak evidence because their current 10/12 gates are
  intentional balance values, not accidental Zargabad bleed-through.

## Verification

- Refreshed the Game PC prompt/brain, GitHub wiki, open PR board, remote branches, and Build84 source
  base before claiming lane 367.
- Exact duplicate scan found no lane367 / map-scale gate owner in wiki, Game PC brain, open PRs, or
  remote branches.
- Source anchor reads confirmed the Zargabad pre-set block, the later `isNil` defaults, and the live
  Allocate/Strategy consumers.
- Mission metadata reads confirmed `totalTowns` values of 46, 31, and 10 for Chernarus, Takistan, and
  Zargabad respectively.
- Docs-only validation: no SQF edited, no LoadoutManager run, no package artifact, no deploy, and no
  live runtime action.

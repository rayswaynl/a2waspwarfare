# Client RPT Error-Family Audit - 2026-07-02

Lane 49 scope on `claude/build84-cmdcon36`: classify current client-RPT error families and only ship
tiny source fixes where the evidence still maps to maintained source.

## Evidence Used

- Brain/wiki references: B74.6/B751 client-RPT guard clusters, JIP enrollment notes, testing workflow
  RPT routing, and lane-49 claim context in `Agent-Worklog.md`.
- Current client log sample: `C:\Users\Game\wasp-rpt-reap\client-main.rpt`, modified
  `2026-07-02T20:14:00Z`, size 4.7 MB.
- Local analyzer result: 29,196 error-like trigger lines, 76 grouped families.
- After filtering optional addon blocks, the log contained 125 mission-hinted trigger lines, 29,022
  addon trigger lines, and 49 other trigger lines.

## Current Family Classification

### Optional Addon Noise

The dominant active family is outside the mission source:

- `JSRS_Distance\scripts\...\*.sqf` undefined `_source` blocks.
- `warfxpe\ParticleEffects\...` generic expression blocks.

These make the raw client RPT look far worse than the mission signal. They should be routed through
optional-mod/loadout guidance, not mission source fixes.

### Already Covered In Current Source

Several mission errors in the sampled RPT are from packages older than the current target branch:

- Skin selector apply/copy/join errors are already covered in current Chernarus/Takistan source by
  `SkinSelector_CopyGear.sqf`, A2-safe `[_newUnit] join _oldGrp`, selectPlayer readiness checks, and
  respawn restore guards.
- Respawn menu `WFBE_DeathLocation`, `WFBE_RespawnTime`, and stale marker-id cascades are already
  guarded in current `Client\GUI\GUI_RespawnMenu.sqf`.
- Vote roster nil-slot risk is already owned by lane 66 and should stay there.

### Fixed In This Lane

Three observed client-RPT families still mapped to maintained source and were small enough to fix here:

1. `Client\Functions\Client_TipRotation.sqf` compared feature-gate values with `< 1` before proving
   the missionNamespace value was numeric. A string contamination in the client RPT produced
   `Error <: Type String, expected Number`. The fix type-checks the master/cadence values and per-tip
   gate values; non-scalar gated tips are skipped for that tick instead of throwing.
2. `Common\Init\Init_TownMode.sqf` waited on `WFBE_Parameters_Ready` before proving the variable
   existed. The RPT showed `Undefined variable in expression: wfbe_parameters_ready`. The fix waits
   until the variable exists, then returns the existing boolean.
3. `Client\Module\CM\CM_Set.sqf` expected `_this select 0`, but maintained call sites invoke it as
   `(_unit) execVM ...`, so `_this` is an object. The RPT showed `Error select: Type Object, expected
   Array`. The fix accepts either object payloads or legacy array payloads and exits quietly on anything
   else.

Each fix was made in source Chernarus first, then mirrored to maintained Takistan through
`Tools\LoadoutManager`.

## Routing Notes

- Client/UI/JIP failures require the player's client RPT. Server-only smoke can be clean while the
  client path is broken.
- HC-delegated AICOM team-driver telemetry belongs in HC RPTs, not server RPTs.
- For capture verification, grep `CAPTURED \[`; the older plain-text pattern missed the real line.
- Optional mod noise should be filtered before mission triage so mission-owned families are not buried.

## Verification

- `A2WASP_SKIP_ZIP=1 dotnet run -c Release`
- `A2WASP_SKIP_ZIP=1 dotnet run -c Release -- --check`
- `git diff --check`
- `git diff --cached --check`
- A3-command scan on touched files for `isEqual`, `params`, `pushBack`, `selectRandom`,
  `forEachIndex`, and `findIf`: no source hits.

LoadoutManager emitted existing nullable warnings and the existing "specified content was not found"
message, then completed; `_MISSIONS.7z` was not produced.

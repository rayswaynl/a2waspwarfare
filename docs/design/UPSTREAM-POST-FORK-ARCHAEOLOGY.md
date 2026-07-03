# Upstream Post-Fork Archaeology

Lane: 307

Date: 2026-07-03

Target branch: `claude/build84-cmdcon36`

This report classifies the upstream tree delta between the local upstream
snapshots `upstream/v31072024` and `upstream/v24042025`, then compares the
actionable Chernarus/LoadoutManager paths against Build84. It is intentionally
report-only: no mission runtime, LoadoutManager, packaging, or live-server
files are changed by this lane.

## Reference Points

Local mirror used for upstream refs:

`C:\Users\Game\a2waspwarfare`

Source checkout used for Build84:

`C:\Users\Game\Documents\Codex\work\a2wasp-lane203-tk-version-template-fix-2`

Refs:

| Ref | SHA |
| --- | --- |
| `upstream/v31072024` | `436abf83805de42484db9d041c19b4228f91b285` |
| `upstream/v24042025` | `407c2d2d8411cf1f0824adc15639e9d3f5ea33c1` |
| `github/claude/build84-cmdcon36` | `33cab11c165fc82dfc9082a02cb7e2c672242c53` |

Important repository note:

The local upstream mirror is shallow. In this mirror,
`upstream/v24042025` behaves as a parentless snapshot even though its commit
message is `Merge branch 'LoadoutManagerFix7zPath' into dev_24042025`.
`git merge-base --is-ancestor upstream/v31072024 upstream/v24042025` returns
false. Treat the analysis below as a bounded tree-diff archaeology pass, not a
full ancestry audit.

Visible endpoint commit:

```text
407c2d2d8 2025-04-25 Miksuu Merge branch 'LoadoutManagerFix7zPath' into dev_24042025
```

Whole-tree delta in the local mirror:

```text
137 files changed, 2801 insertions(+), 2728 deletions(-)
```

The delta is mostly repeated mission-file edits across terrain copies:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`
- several `Modded_Missions/*` terrain copies
- `Tools/LoadoutManager`

Build84 in the current source checkout carries only the Chernarus mission plus
tooling, so this report compares the upstream Chernarus/LoadoutManager subset
against Build84.

## Reproduction Commands

From the source checkout:

```powershell
git rev-parse github/claude/build84-cmdcon36
git -C C:\Users\Game\a2waspwarfare rev-parse upstream/v31072024 upstream/v24042025
git -C C:\Users\Game\a2waspwarfare rev-parse --is-shallow-repository
git -C C:\Users\Game\a2waspwarfare merge-base --is-ancestor upstream/v31072024 upstream/v24042025
git -C C:\Users\Game\a2waspwarfare diff --shortstat upstream/v31072024..upstream/v24042025
git -C C:\Users\Game\a2waspwarfare diff --name-status upstream/v31072024..upstream/v24042025
```

Blob comparison for Chernarus/LoadoutManager:

```powershell
$mirror = 'C:\Users\Game\a2waspwarfare'
$target = 'github/claude/build84-cmdcon36'
$paths = git -C $mirror diff --name-only upstream/v31072024..upstream/v24042025 -- "Missions/[55-2hc]warfarev2_073v48co.chernarus" "Tools/LoadoutManager"
foreach ($p in $paths) {
  $up = git -C $mirror rev-parse "upstream/v24042025:$p" 2>$null
  $cur = git rev-parse "$target`:$p" 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($cur)) { $state = 'missing-in-build84' }
  elseif ($up -eq $cur) { $state = 'exact-upstream-blob' }
  else { $state = 'present-diverged' }
  "$state`t$p"
}
```

Result:

```text
exact-upstream-blob  Client/Module/Nuke/ICBM_Init.sqf
exact-upstream-blob  Common/Functions/Common_AutomaticViewDistance.sqf
present-diverged     all other changed Chernarus/LoadoutManager paths
```

## Changed Chernarus/Tool Paths

Upstream changed these Chernarus and tool paths:

| Path | Build84 state |
| --- | --- |
| `Client/FSM/updateclient.sqf` | Present, diverged |
| `Client/Functions/Client_RequestFireMission.sqf` | Present, diverged |
| `Client/GUI/GUI_Menu_Tactical.sqf` | Present, diverged |
| `Client/Init/Init_Client.sqf` | Present, diverged |
| `Client/Module/Nuke/ICBM_Init.sqf` | Exact upstream blob |
| `Client/Module/Nuke/damage.sqf` | Present, diverged |
| `Client/Module/Nuke/radzone.sqf` | Present, diverged |
| `Common/Functions/Common_AdjustViewDistance.sqf` | Present, diverged |
| `Common/Functions/Common_AutomaticViewDistance.sqf` | Exact upstream blob |
| `Common/Functions/Common_HandleIncomingMissile.sqf` | Present, diverged |
| `Common/Functions/Common_UpdateMarker.sqf` | Present, diverged |
| `Server/Functions/Server_MHQRepair.sqf` | Present, diverged |
| `Server/Functions/Server_OnHQKilled.sqf` | Present, diverged |
| `Server/Init/Init_Defenses.sqf` | Present, diverged |
| `stringtable.xml` | Present, diverged |
| `Tools/LoadoutManager/README.md` | Present, diverged |
| `Tools/LoadoutManager/ZipManager.cs` | Present, diverged |

## Classification

| Theme | Upstream change | Build84 classification | Recommended action |
| --- | --- | --- | --- |
| Automatic view-distance tolerance | Widened target band from +/-2 FPS to +/-4 FPS; avoided adjusting while map is open. | Already integrated. `Common_AutomaticViewDistance.sqf` is an exact upstream blob. `Common_AdjustViewDistance.sqf` and `updateclient.sqf` contain the +/-4 messaging and map-visible guard, plus later Build84 AFK/diagnostic work. | No raw port. Keep Build84 version. |
| HQ wreck marker | Reintroduced allied HQ wreck marker state with `IS_WEST_HQ_ALIVE`, `IS_EAST_HQ_ALIVE`, and marker info public variables. | Integrated under Build84 guardrails. Current Build84 avoids global enemy-visible marker creation, deletes local wreck markers after repair, validates marker-info array size, checks the wreck object for null, and tracks `_wreckObject` after deployed HQ replacement. | No raw port. Future work should modify the Build84 marker flow only. |
| ICBM radius constants | Added `ICBM_DAMAGE_RADIUS = 800` and `ICBM_RADIATION_RADIUS = 900`, then used those variables in damage/radiation/marker code. | Mostly integrated. `ICBM_Init.sqf` is exact. Build84 also uses the variables in `damage.sqf`, `radzone.sqf`, and tactical map ellipse markers, but those files diverge because Build84 has later nuke/UI changes. | No raw port. Treat Build84 as canonical. |
| Artillery ready sound | Changed `playSound "ARTY_cooldown_over"` to `playSound ["ARTY_cooldown_over",true]`. | Already present in Build84 `Client_RequestFireMission.sqf`, with additional marker-cleanup comments around the same file. | No action. |
| Dumb-bomb incoming-missile workaround | Treats `Bo_FAB_250` and `Bo_Mk82` as IR-locked when `_irLock == 0`. | Already present in Build84 `Common_HandleIncomingMissile.sqf`. Build84 also has later VBIED/air-strike uses of `Bo_FAB_250`, so this should be considered part of current behavior, not a free-standing upstream patch. | No action unless a dedicated countermeasure QA lane proves a regression. |
| Factory wall obstruction reduction | Removed selected `Land_HBarrier_large` pieces from factory wall templates. | Superseded. Build84 has a later Ray-approved factory wall design with legacy arrays plus optional `WFBE_C_WALLS_V3` concrete slab overlays, and comments documenting the revert from an earlier wall ladder. | Do not cherry-pick the upstream wall removals. Any wall work should target the Build84 `WFBE_C_WALLS_V3` design. |
| LoadoutManager 7-Zip path | Added a README and changed `ZipManager.cs` from hardcoded `7za.exe` to a resolved `sevenZipPath`. | Superseded and expanded. Build84 resolves the `7za` env var, standard 7-Zip install locations, and PATH; supports `A2WASP_SKIP_ZIP`; skips packing when 7-Zip is missing; writes a temp archive before replacing `_MISSIONS.7z`; and hides the 7-Zip process window. | No action. Do not run packaging from this lane. |
| German stringtable changes | Broad German translation edits, including tactical/nuke strings. | Manual-review only. Build84 stringtable diverges and lane 209 already has a stringtable audit PR open. The upstream stringtable patch is broad churn and contains text that should be reviewed in a localization lane rather than source-ported blindly. | Route to a stringtable/localization lane if desired. |
| Terrain-copy replication | Same mission edits repeated across Takistan and modded terrain copies in upstream. | Not directly applicable to Build84 source checkout, which currently carries only `Missions/[55-2hc]warfarev2_073v48co.chernarus` plus generation tooling. | Do not add terrain copies by hand. Use LoadoutManager/generation workflow lanes if terrain propagation is needed. |

## Practical Takeaway

The upstream snapshot does not expose a clean list of replayable commits in the
local shallow mirror, but the tree delta is still useful. Against Build84, the
major functional ideas from the Chernarus subset are already present, either as
exact blobs or as later WASP-specific implementations.

The main risk is not missing an upstream port. The main risk is a future agent
reapplying the raw upstream diff over Build84 and losing the newer WASP fixes:

- HQ wreck marker safety and deployed-HQ wreck tracking.
- AFK/performance diagnostics in `updateclient.sqf`.
- The Build84 factory wall V3 design.
- LoadoutManager skip/resolve/temp-archive safeguards.
- Current nuke marker and radius integrations.

## Future Work

Good follow-up lanes, if the fleet needs more archaeology:

1. Deepen or refresh the upstream mirror so `upstream/v24042025` has its parent
   history, then produce a commit-by-commit upstream chronology.
2. Review only the German stringtable changes manually against lane 209's audit,
   with native-speaker or owner review before any source PR.
3. Smoke-test `WFBE_C_WALLS_V3` factory egress in-game instead of revisiting the
   older upstream wall-removal patch.
4. If countermeasures behave oddly with FAB/Mk82 air strikes, test the current
   Build84 dumb-bomb incoming-missile workaround in isolation.

## Verification

Performed for this report:

- Confirmed the source branch is based on `github/claude/build84-cmdcon36`.
- Confirmed the upstream mirror is shallow.
- Confirmed `upstream/v31072024` is not an ancestor of `upstream/v24042025` in
  the local mirror.
- Listed the upstream tree delta and Chernarus/LoadoutManager changed paths.
- Compared upstream endpoint blobs to Build84 blobs for all changed
  Chernarus/LoadoutManager paths.
- Searched Build84 for the core upstream tokens:
  `ICBM_DAMAGE_RADIUS`, `ICBM_RADIATION_RADIUS`, `ARTY_cooldown_over`,
  `Bo_FAB_250`, `Bo_Mk82`, `IS_WEST_HQ_ALIVE`, `HQ_WEST_MARKER_INFOS`,
  `Common_UpdateMarker`, `A2WASP_SKIP_ZIP`, and `sevenZipPath`.
- No packaging, deployment, generated mission archive, or live-server action was
  run for this lane.

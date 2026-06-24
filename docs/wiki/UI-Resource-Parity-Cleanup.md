# UI Resource Parity Cleanup

Status: docs-ready UI cleanup lane. No gameplay source changed by this page.

Use this page when deciding whether the current UI/Rsc issues are broken live features, safe cleanup, or branch-only fixes. It consolidates the stale upgrade dialog, Economy IDC drift, and duplicate IDD findings so future work does not re-audit them separately.

Canonical owner pages:

- Runtime map: [Client UI systems atlas](Client-UI-Systems-Atlas)
- Duplicate IDD repair details: [UI IDD collision repair](UI-IDD-Collision-Repair)
- Risk register: [Feature status register](Feature-Status-Register)
- Stale-code evidence: [Dead code and stale code register](Dead-Code-And-Stale-Code-Register)

Current docs/source note: 2026-06-24 refreshes rechecked the repo docs branch source tree for both the stale-upgrade and Economy-control rows. `HEAD@208062b4e` is unchanged from `427346b0d`, `0fdd5602` and `d4cfef80` for checked stale upgrade dialog/controller paths, and unchanged from `21f0d53b`, `d2a3f995` and `b5219d47` for checked Economy controller/resource paths. The duplicate-IDD row still uses the 2026-06-23 `HEAD@edbd341e` check, unchanged from `b5219d47`. Other matrix rows still preserve their named branch snapshot unless a row says otherwise.

## Current Parity Matrix

| Item | Docs checkout Chernarus | Maintained Vanilla Takistan | Current stable / branch-fixed refs | Miksuu `b8389e748243` / perf `0076040f` | Historical release / older proof | Development meaning |
| --- | --- | --- | --- | --- | --- | --- |
| Stale `RscMenu_Upgrade` | Repo docs branch `HEAD@208062b4e` remains source-unchanged from `427346b0d`, `0fdd5602` and `d4cfef80` for checked upgrade dialog/controller paths. Present at `Rsc/Dialogs.hpp:2425`; `onLoad` points to missing `Client/GUI/GUI_Menu_Upgrade.sqf` at `:2428`; old `wf_*.paa` icons are referenced at `:2634-2821`, and no matching `Client/Images/wf_*.paa` files exist in either maintained root. | Same stale class, missing controller and icon block. | Current stable/B74.1 `origin/master@f8a76de34`, previous B74.2 `d472da6a`, current B74.2 `origin/claude/b74.2-aicom@21b62b04`, current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` have no checked maintained-root `RscMenu_Upgrade` / `GUI_Menu_Upgrade.sqf` hits; only live `WFBE_UpgradeMenu` remains at `Rsc/Dialogs.hpp:4-7`, opened from `GUI_Menu.sqf:190` on stable/B74-shaped refs. Checked `d472da6a..21b62b04`, `origin/master..origin/claude/b74.2-aicom`, `origin/claude/b69..origin/claude/b74-aicom-spend`, `0139a3468609..origin/master` and `427346b0d..HEAD` diffs are empty for checked upgrade dialog/controller paths. | Same stale class in Chernarus and Vanilla (`Dialogs.hpp:2435`, `:2438`), with the old icon block at `:2644-2831`; no checked `Client/Images/wf_*.paa` icon files exist. | Historical `a96fdda2` also removes the old class in both maintained roots and keeps the live route at `GUI_Menu.sqf:182`, `Rsc/Dialogs.hpp:4-7`; historical upgrade-queue `b061c905` remains older proof for the same deletion route. | Treat the old class as stale on docs/Miksuu/perf-style targets. Preserve or port the current stable/B74-shaped/release deletion, or add an explicit compatibility alias, then smoke live `WFBE_UpgradeMenu`. |
| Economy stale control writes | Docs branch `HEAD@427346b0d` remains source-unchanged from `21f0d53b` / `d2a3f995` / `b5219d47` for checked Economy controller/resource paths. `GUI_Menu_Economy.sqf:7-8` writes `23004`, `23005`, `23006`, but `RscMenu_Economy` declares `23002`, `23003`, `23008`-`23016` and no `23020` (`Dialogs.hpp:3327,3339,3346`; zero `23004`/`23005`/`23006`/`23020` IDC declarations in the Economy class). | Same stale writes and declared-control shape. | Current stable/B74.1 `origin/master@f8a76de34`, current B74.2 `origin/claude/b74.2-aicom@21b62b04`, current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` remove the stale writes in both maintained roots, use display controls `23002` and `23020` (`GUI_Menu_Economy.sqf:4,25`) and declare `23020` (`Rsc/Dialogs.hpp:3070`). Checked `d472da6a..21b62b04`, `origin/master..origin/claude/b74.2-aicom` and B69..B74 Economy diffs are empty; `0139a3468609..origin/master` only changes source-Chernarus dashboard label text at `GUI_Menu_Economy.sqf:229`. | Same stale writes in both maintained roots (`GUI_Menu_Economy.sqf:7-8`), with no declared `23020` and line-drifted Economy declarations at `Dialogs.hpp:3383,3395,3402`. | Historical `a96fdda2` matches the current stable/B74-shaped controller/resource shape in both maintained roots (`GUI_Menu_Economy.sqf:4,25`; `Rsc/Dialogs.hpp:3006`). | Preserve/port the stable/B74-shaped/release `23020` repair where the target still carries old-shape writes; smoke Economy disabled state, income controls, sell mode and supply-truck respawn. |
| EASA/Economy duplicate dialog IDD | Docs `HEAD@edbd341e` remains source-unchanged from `b5219d47` for checked Dialogs/Titles IDD paths. `RscMenu_EASA` and `RscMenu_Economy` both use `idd = 23000` (`Dialogs.hpp:3209-3211`, `:3287-3289`). | Same duplicate. | Distinct in both maintained roots: current stable `origin/master@0139a346`, B69 `origin/claude/b69@8d465fce` and B74 `origin/claude/b74-aicom-spend@b23f557f` move EASA to `idd = 24000` (`Dialogs.hpp:2926-2928`) and keep Economy on `23000` (`:3004-3006`). | Same duplicate in both maintained roots (`Dialogs.hpp:3265-3267`, `:3343-3345`). | Historical `a96fdda2` carries the distinct split in both maintained roots: EASA `idd = 24000` (`Dialogs.hpp:2862-2864`), Economy `23000` (`:2940-2942`). | Preserve/port the stable/B69/B74/release dialog IDD split for target branches still duplicating `23000`. No checked maintained root has a `findDisplay 23000` or `findDisplay 24000` caller, but future dialog work should not rely on duplicated display IDs. |
| `RscOverlay`/`OptionsAvailable` duplicate title IDD | Both use `10200` (`Rsc/Titles.hpp:44-46`, `:164-165`). | Same duplicate. | Current stable/B69/B74 keep the same duplicate with line drift (`Rsc/Titles.hpp:44-46`, `:168-169`). | Same duplicate. | Historical `a96fdda2` keeps the same duplicate with stable line drift. | Keep separate from EASA/Economy. Fix only with RHUD/action-icons/endgame display-handle smoke because title ownership also shares `uiNamespace["currentCutDisplay"]`. |

## Source Evidence

- Live upgrade path: docs/source `WFBE_UpgradeMenu` loads `Client/GUI/GUI_UpgradeMenu.sqf` (`Rsc/Dialogs.hpp:4-7`), and the main menu opens it with `createDialog "WFBE_UpgradeMenu"` (`Client/GUI/GUI_Menu.sqf:165`). Current stable/B74.1 `f8a76de34`, current B74.2 `21b62b04`, B69 `8d465fce`, B74 `b23f557f` and historical `a96fdda2` keep the same live dialog/controller route in both maintained roots, with stable/B74-shaped main-menu line drift to `GUI_Menu.sqf:190` and historical `:182`.
- Old upgrade path: no `Client/GUI/GUI_Menu_Upgrade.sqf` exists in any checked maintained root. Docs/source keeps the stale `RscMenu_Upgrade` class in both maintained roots at `Rsc/Dialogs.hpp:2425,:2428`; current Miksuu `b8389e748243` and perf `0076040f` keep it at line-drifted `Dialogs.hpp:2435,:2438`; current stable/B74.1 `f8a76de34`, previous B74.2 `d472da6a`, current B74.2 `21b62b04`, B69 `8d465fce`, B74 `b23f557f`, historical `a96fdda2` and historical upgrade-queue `b061c905` have no checked maintained-root stale-class hits. No checked `Client/Images/wf_*.paa` icon files exist under docs/source, Miksuu or perf maintained roots.
- Economy declared controls: docs/source `RscMenu_Economy` declares `23002`, `23003`, `23008`, `23009`, `23010`, `23011`, `23012`, `23013`, `23014`, `23015`, `23016`, not `23004`-`23006` or `23020`. Current stable/B74.1 `f8a76de34`, current B74.2 `21b62b04`, B69 `8d465fce`, adjacent B74 `b23f557f` and historical `a96fdda2` add the read-only dashboard control as `23020` in both maintained roots, so old-shape targets should preserve or port that declared-control repair rather than reopening current stable/B74.2.
- Display lookup caveat: the 2026-06-23 maintained-root search found no `findDisplay 23000`, `findDisplay 24000` or `findDisplay 10200` caller in docs checkout `edbd341e` (unchanged from `b5219d47` for checked Dialogs/Titles paths), current stable `0139a346`, B69 `8d465fce`, B74 `b23f557f`, current Miksuu `b8389e748243`, perf `0076040f` or historical `a96fdda2`, so duplicate IDD cleanup is maintenance/future-proofing rather than a proven live lookup bug.

## Recommended Patch Order

1. Remove or explicitly alias stale `RscMenu_Upgrade` across old-shape source Chernarus and maintained Vanilla targets; current stable/B74.1/B74.2/B69/B74 and historical release/upgrade-queue refs already provide deletion comparisons.
2. Normalize Economy controller/control-map parity across old-shape source Chernarus and maintained Vanilla targets, using current stable/B74.1/B74.2/B69/B74 or historical release as comparison evidence.
3. Give EASA and Economy distinct dialog IDDs across both maintained roots, or record a deliberate waiver; stable/release already use the split in both maintained roots.
4. Handle title IDD/display ownership as a separate patch: `RscOverlay`, `OptionsAvailable`, RHUD/action icons and `EndOfGameStats` must be smoked together.

Do not combine this lane with Economy authority, EASA balance generation, upgrade-request authority, or commander-economy redesign. Those are behavior/security lanes; this one is UI resource parity and smoke.

## Validation

Source checks:

- No stale `RscMenu_Upgrade` class remains, or it is explicitly an alias to the live `WFBE_UpgradeMenu`.
- Economy controller writes only declared controls.
- EASA/Economy have distinct dialog `idd` values, or the waiver is documented.
- No new hard-coded `findDisplay 23000` / `findDisplay 24000` / `findDisplay 10200` assumptions are introduced.

Arma smoke:

- Live upgrade menu opens, lists upgrades, and sends `RequestUpgrade` as before.
- Economy opens as commander and non-commander; disabled state, income slider, sell mode and supply-truck respawn controls behave as expected.
- EASA opens from service menu and applies/returns correctly.
- RHUD/FPS HUD, action icons and endgame stat bars still display without title-handle flicker.

## Continue Reading

Previous: [Client UI systems atlas](Client-UI-Systems-Atlas) | Next: [UI IDD collision repair](UI-IDD-Collision-Repair)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-feature-status.jsonl`](agent-feature-status.jsonl)

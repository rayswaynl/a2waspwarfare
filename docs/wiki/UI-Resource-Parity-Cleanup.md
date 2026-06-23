# UI Resource Parity Cleanup

Status: docs-ready UI cleanup lane. No gameplay source changed by this page.

Use this page when deciding whether the current UI/Rsc issues are broken live features, safe cleanup, or branch-only fixes. It consolidates the stale upgrade dialog, Economy IDC drift, and duplicate IDD findings so future work does not re-audit them separately.

Canonical owner pages:

- Runtime map: [Client UI systems atlas](Client-UI-Systems-Atlas)
- Duplicate IDD repair details: [UI IDD collision repair](UI-IDD-Collision-Repair)
- Risk register: [Feature status register](Feature-Status-Register)
- Stale-code evidence: [Dead code and stale code register](Dead-Code-And-Stale-Code-Register)

Current docs/source note: 2026-06-23 stale-upgrade refresh rechecked docs checkout `docs/developer-wiki-index` `0fdd5602`; the checked Chernarus and maintained Vanilla `Rsc/Dialogs.hpp`, live `GUI_Menu.sqf` / `GUI_UpgradeMenu.sqf`, and missing `GUI_Menu_Upgrade.sqf` paths are unchanged from `d4cfef80` and the earlier `b5219d47` / `2fef1e3d` resource-parity snapshots. Other matrix rows still preserve their named 2026-06-14 branch snapshot unless a row says otherwise.

## Current Parity Matrix

| Item | Docs checkout Chernarus | Maintained Vanilla Takistan | Current stable / branch-fixed refs | Miksuu `b8389e74` / perf `0076040f` | Historical release / older proof | Development meaning |
| --- | --- | --- | --- | --- | --- | --- |
| Stale `RscMenu_Upgrade` | Docs `HEAD@0fdd5602` remains source-unchanged from `d4cfef80` for checked upgrade dialog/controller paths. Present at `Rsc/Dialogs.hpp:2425`; `onLoad` points to missing `Client/GUI/GUI_Menu_Upgrade.sqf` at `:2428`; old `wf_*.paa` icons are referenced at `:2634-2821`. | Same stale class, missing controller and icon block. | Current stable `origin/master@0139a346`, current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` have no checked maintained-root `RscMenu_Upgrade` / `GUI_Menu_Upgrade.sqf` hits; only live `WFBE_UpgradeMenu` remains at `Rsc/Dialogs.hpp:4-7`. | Same stale class in Chernarus and Vanilla (`Dialogs.hpp:2435`, `:2438`). | Historical `a96fdda2` and upgrade-queue `b061c905` also remove the old class in both maintained roots. | Treat the old class as stale on docs/Miksuu/perf-style targets. Preserve or port the stable/B69/B74/release deletion, or add an explicit compatibility alias, then smoke live `WFBE_UpgradeMenu`. |
| Economy stale control writes | `GUI_Menu_Economy.sqf:7-8` writes `23004`, `23005`, `23006`, but `RscMenu_Economy` declares `23002`, `23003`, `23008`-`23016` (`Dialogs.hpp:3327-3408`). | Same stale writes and declared-control shape. | Rewritten away from the stale writes in both maintained roots; uses display controls `23002` and `23020` (`GUI_Menu_Economy.sqf:4,25`). | Same stale writes in both maintained roots (`GUI_Menu_Economy.sqf:7-8`). | Same stable shape in both maintained roots (`GUI_Menu_Economy.sqf:4,25`). | Port/compare the stable/release shape or remove/update stale writes consistently across target roots. Smoke Economy disabled state, income controls, sell mode and supply-truck respawn. |
| EASA/Economy duplicate dialog IDD | `RscMenu_EASA` and `RscMenu_Economy` both use `idd = 23000` (`Dialogs.hpp:3209-3211`, `:3287-3289`). | Same duplicate. | Distinct in both maintained roots: EASA `idd = 24000` (`Dialogs.hpp:2887-2889`), Economy `23000` (`:2965-2967`). | Same duplicate in both maintained roots (`Dialogs.hpp:3265-3267`, `:3343-3345`). | Distinct in both maintained roots: EASA `idd = 24000` (`Dialogs.hpp:2862-2864`), Economy `23000` (`:2940-2942`). | Port or preserve the stable/release dialog IDD split for target branches still duplicating `23000`. No checked maintained root has a `findDisplay 23000` caller, but future dialog work should not rely on duplicated display IDs. |
| `RscOverlay`/`OptionsAvailable` duplicate title IDD | Both use `10200` (`Rsc/Titles.hpp:44-46`, `:164-165`). | Same duplicate. | Same duplicate with line drift (`Rsc/Titles.hpp:44-46`, `:168-169`). | Same duplicate. | Same duplicate with stable line drift. | Keep separate from EASA/Economy. Fix only with RHUD/action-icons/endgame display-handle smoke because title ownership also shares `uiNamespace["currentCutDisplay"]`. |

## Source Evidence

- Live upgrade path: docs/source `WFBE_UpgradeMenu` loads `Client/GUI/GUI_UpgradeMenu.sqf` (`Rsc/Dialogs.hpp:4-7`), and the main menu opens it with `createDialog "WFBE_UpgradeMenu"` (`Client/GUI/GUI_Menu.sqf:165`). Current stable/B69/B74 keep the same live dialog/controller route in both maintained roots.
- Old upgrade path: no `Client/GUI/GUI_Menu_Upgrade.sqf` exists in any checked maintained root. Docs/source keeps the stale `RscMenu_Upgrade` class in both maintained roots, current Miksuu `b8389e748243` and perf `0076040f` keep it at line-drifted `Dialogs.hpp:2435,:2438`, while current stable `0139a346`, B69 `8d465fce`, B74 `b23f557f`, historical `a96fdda2` and `b061c905` have no checked maintained-root stale-class hits. No `Client/Images/wf_*.paa` files exist under current Chernarus `Client/Images`.
- Economy declared controls: current `RscMenu_Economy` declares `23002`, `23003`, `23008`, `23009`, `23010`, `23011`, `23012`, `23013`, `23014`, `23015`, `23016`, `23020`, not `23004`-`23006`.
- Display lookup caveat: the 2026-06-14 maintained-root search found no `findDisplay 23000` or `findDisplay 10200` caller in docs checkout `b5219d47` (unchanged from `2fef1e3d` for these paths), stable `cf2a6d6a`, Miksuu `b8389e74`, perf `0076040f` or release `a96fdda2`, so duplicate IDD cleanup is maintenance/future-proofing rather than a proven live lookup bug.

## Recommended Patch Order

1. Remove or explicitly alias stale `RscMenu_Upgrade` across old-shape source Chernarus and maintained Vanilla targets; current stable/B69/B74 and historical release/upgrade-queue refs already provide deletion comparisons.
2. Normalize Economy controller/control-map parity across source Chernarus and maintained Vanilla, using stable/release as comparison evidence.
3. Give EASA and Economy distinct dialog IDDs across both maintained roots, or record a deliberate waiver; stable/release already use the split in both maintained roots.
4. Handle title IDD/display ownership as a separate patch: `RscOverlay`, `OptionsAvailable`, RHUD/action icons and `EndOfGameStats` must be smoked together.

Do not combine this lane with Economy authority, EASA balance generation, upgrade-request authority, or commander-economy redesign. Those are behavior/security lanes; this one is UI resource parity and smoke.

## Validation

Source checks:

- No stale `RscMenu_Upgrade` class remains, or it is explicitly an alias to the live `WFBE_UpgradeMenu`.
- Economy controller writes only declared controls.
- EASA/Economy have distinct dialog `idd` values, or the waiver is documented.
- No new hard-coded `findDisplay 23000` / `findDisplay 10200` assumptions are introduced.

Arma smoke:

- Live upgrade menu opens, lists upgrades, and sends `RequestUpgrade` as before.
- Economy opens as commander and non-commander; disabled state, income slider, sell mode and supply-truck respawn controls behave as expected.
- EASA opens from service menu and applies/returns correctly.
- RHUD/FPS HUD, action icons and endgame stat bars still display without title-handle flicker.

## Continue Reading

Previous: [Client UI systems atlas](Client-UI-Systems-Atlas) | Next: [UI IDD collision repair](UI-IDD-Collision-Repair)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-feature-status.jsonl`](agent-feature-status.jsonl)

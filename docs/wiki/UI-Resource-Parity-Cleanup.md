# UI Resource Parity Cleanup

Status: docs-ready UI cleanup lane. No gameplay source changed by this page.

Use this page when deciding whether the current UI/Rsc issues are broken live features, safe cleanup, or branch-only fixes. It consolidates the stale upgrade dialog, Economy IDC drift, and duplicate IDD findings so future work does not re-audit them separately.

Canonical owner pages:

- Runtime map: [Client UI systems atlas](Client-UI-Systems-Atlas)
- Duplicate IDD repair details: [UI IDD collision repair](UI-IDD-Collision-Repair)
- Risk register: [Feature status register](Feature-Status-Register)
- Stale-code evidence: [Dead code and stale code register](Dead-Code-And-Stale-Code-Register)

## Current Parity Matrix

| Item | Current docs/source Chernarus | Maintained Vanilla Takistan | `origin/master` / `miksuu/master` | `origin/release/2026-06-feature-bundle` Chernarus | Release Vanilla | Development meaning |
| --- | --- | --- | --- | --- | --- | --- |
| Stale `RscMenu_Upgrade` | Present at `Rsc/Dialogs.hpp:2425`; `onLoad` points to missing `Client/GUI/GUI_Menu_Upgrade.sqf` at `:2428`; old `wf_*.paa` icons are referenced at `:2634-2821`. | Same stale class and missing controller. | Same stale class in Chernarus (`Dialogs.hpp:2435`) and Vanilla. | Removed; only live `WFBE_UpgradeMenu` remains. | Still present at `Dialogs.hpp:2435`. | Treat the old class as stale. Prefer consistent removal or explicit compatibility alias, then smoke live `WFBE_UpgradeMenu`. |
| Economy stale control writes | `GUI_Menu_Economy.sqf:7-8` writes `23004`, `23005`, `23006`, but `RscMenu_Economy` declares `23002`, `23003`, `23008`-`23016` (`Dialogs.hpp:3327-3408`). | Same stale writes and declared-control shape. | Same stale writes (`GUI_Menu_Economy.sqf:7-8`). | Rewritten away from the stale writes; uses display controls `23002` and `23020` (`GUI_Menu_Economy.sqf:4,23`). | Still uses stale writes at `:7-8`. | Port/compare the release Chernarus shape or remove/update the stale writes consistently across maintained roots. Smoke Economy disabled state, income controls, sell mode and supply-truck respawn. |
| EASA/Economy duplicate dialog IDD | `RscMenu_EASA` and `RscMenu_Economy` both use `idd = 23000` (`Dialogs.hpp:3209-3211`, `:3287-3289`). | Same duplicate. | Same duplicate in Chernarus (`Dialogs.hpp:3265-3267`, `:3343-3345`) and Vanilla. | Chernarus EASA moved to `idd = 24000` (`Dialogs.hpp:2860-2862`); Economy remains `23000` (`:2938-2940`). | Still duplicate (`Dialogs.hpp:3294-3296`, `:3372-3374`). | Parity cleanup or formal waiver. No current source `findDisplay 23000` caller was found, but future dialog work should not rely on duplicated display IDs. |
| `RscOverlay`/`OptionsAvailable` duplicate title IDD | Both use `10200` (`Rsc/Titles.hpp:44-46`, `:164-165`). | Same duplicate. | Same duplicate. | Same duplicate. | Same duplicate. | Keep separate from EASA/Economy. Fix only with RHUD/action-icons/endgame display-handle smoke because title ownership also shares `uiNamespace["currentCutDisplay"]`. |

## Source Evidence

- Live upgrade path: `WFBE_UpgradeMenu` loads `Client/GUI/GUI_UpgradeMenu.sqf` (`Rsc/Dialogs.hpp:4-7`), and the main menu opens it with `createDialog "WFBE_UpgradeMenu"` (`Client/GUI/GUI_Menu.sqf:165`).
- Old upgrade path: no `Client/GUI/GUI_Menu_Upgrade.sqf` exists in current Chernarus or maintained Vanilla, and no `Client/Images/wf_*.paa` files exist under current Chernarus `Client/Images`.
- Economy declared controls: current `RscMenu_Economy` declares `23002`, `23003`, `23008`, `23009`, `23010`, `23011`, `23012`, `23013`, `23014`, `23015`, `23016`, not `23004`-`23006`.
- Display lookup caveat: current source searches found no `findDisplay 23000` or `findDisplay 10200` caller under `Missions` / `Missions_Vanilla`, so duplicate IDD cleanup is maintenance/future-proofing rather than a proven live lookup bug.

## Recommended Patch Order

1. Remove or explicitly alias stale `RscMenu_Upgrade` across source Chernarus and maintained Vanilla.
2. Normalize Economy controller/control-map parity across source Chernarus and maintained Vanilla, using release Chernarus as comparison evidence.
3. Give EASA and Economy distinct dialog IDDs across both maintained roots, or record a deliberate waiver.
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

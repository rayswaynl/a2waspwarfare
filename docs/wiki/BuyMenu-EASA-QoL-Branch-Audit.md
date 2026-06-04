# BuyMenu EASA QoL Branch Audit

This page deep-audits `origin/feat/buymenu-easa-qol` as branch evidence, not stable-master source truth.

## What this branch is

`origin/feat/buymenu-easa-qol` head `a66d4691` is a narrow client-UI quality-of-life branch. It changes Buy Units affordability display, factory-tab queue labels and EASA current-loadout selection.

- Head: `a66d4691` (`feat(easa): highlight and pre-select the loadout currently equipped on the vehicle`)
- Merge base versus stable `origin/master`: `2cdf5fb8`
- Diff versus `origin/master`: 3 files, +42/-6
- Scope: 3 files under `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- Maintained Vanilla scope: no `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` files are touched
- Static cleanup gate: `git diff --check origin/master..origin/feat/buymenu-easa-qol` is clean

## Commit Breakdown

| Commit | Message | Meaning |
| --- | --- | --- |
| `43a7849e` | `feat(buymenu): tint a unit's price red when you can't afford its base cost` | Adds a current-funds check to the Buy Units list and colors unaffordable base prices red. |
| `6aacf0c9` | `feat(buymenu): show full purchase cost (incl. crew) in the price field + live queue count on factory tabs` | Adds queue counts to factory tabs and aligns the selected-unit cost formula with purchase/list cost modifiers. |
| `a66d4691` | `feat(easa): highlight and pre-select the loadout currently equipped on the vehicle` | Reads `WFBE_EASA_Setup` from the current vehicle, colors that EASA row green and selects it if present. |

## Where it Lives

| Area | Branch evidence |
| --- | --- |
| Buy Units affordability tint | `Client/Functions/Client_UIFillListBuyUnits.sqf:1,61-62,104` adds `_funds/_price`, computes the displayed base price once and colors price column `[_i,0]` red when `_price > _funds` |
| Factory-tab queue labels | `Client/GUI/GUI_Menu_BuyUnits.sqf:201-210` reads `WFBE_C_QUEUE_<factory>` and `WFBE_C_QUEUE_<factory>_MAX`, appends `(<q>/<max>)` to tab base labels and only writes changed labels |
| Selected-unit price formula | `GUI_Menu_BuyUnits.sqf:280,335,388,444,487` uses the unit-cost upgrade/attack-wave modifier, adds crew cost for selected crew slots and writes idc `12034` |
| EASA current loadout selection | `Client/GUI/GUI_Menu_EASA.sqf:29-40` reads `(vehicle player) getVariable ["WFBE_EASA_Setup", -1]`, colors the matching loadout row green and selects it |
| Vanilla absence | `git diff --name-only origin/master..origin/feat/buymenu-easa-qol -- Missions_Vanilla` returns no changed files |

## How it Runs

This branch changes existing dialogs only:

- `Client_UIFillListBuyUnits.sqf` fills the Buy Units list after factory/faction changes.
- `GUI_Menu_BuyUnits.sqf` keeps the buy dialog loop alive while the player is near factories and refreshes funds, queue label text, selected-unit details and purchase actions.
- `GUI_Menu_EASA.sqf` fills the aircraft loadout list once when the EASA dialog opens, then handles purchase action `MenuAction == 101`.

No server logic, economy authority, gear generation or EASA generated data is changed.

## What Depends On It

- Buy-menu UX depends on the list price, detail price and purchase cost staying understandable. The branch improves display, but it does not move purchase authority server-side.
- Factory queue visibility depends on `WFBE_C_QUEUE_<factory>` and `WFBE_C_QUEUE_<factory>_MAX` being meaningful client-visible missionNamespace variables.
- EASA current-loadout highlighting depends on `EASA_Equip.sqf` setting public vehicle state `WFBE_EASA_Setup`, and on the loadout row still being visible after AA-missile filtering.
- Maintained Vanilla release claims depend on explicit propagation because the branch touches only Chernarus.

## What Is Risky Or Incomplete

| Risk | Evidence | Required gate |
| --- | --- | --- |
| Chernarus-only scope | No `Missions_Vanilla` files are changed | Propagate maintained Vanilla or explicitly mark the branch Chernarus-only before release wording. |
| UI-only, not authority | Purchase/debit paths remain client-side; this branch only changes display and selection | Keep DR-28 gear/EASA/service authority work separate from this QoL branch. |
| Base-price color can differ from full purchase affordability | `Client_UIFillListBuyUnits.sqf:61-62,104` colors by displayed base price; crew cost is added later in `GUI_Menu_BuyUnits.sqf:335,388` | Smoke infantry, crewless vehicles, full-crew vehicles and unit-cost upgrade levels so red/normal price meaning is clear. |
| Queue labels may stale if queue globals are not updated/public where expected | `GUI_Menu_BuyUnits.sqf:205-208` reads missionNamespace queue variables every dialog loop | Smoke queue count increment/decrement while tab labels are visible and check for flicker/label loss. |
| EASA selected row may be hidden by loadout filters | `GUI_Menu_EASA.sqf:15-20` can filter AA rows before current-loadout matching at `:29-40` | Smoke current loadout visible, filtered, default and unset `WFBE_EASA_Setup = -1` cases. |
| Redundant price-field write remains | `GUI_Menu_BuyUnits.sqf:444` writes `12034`, and `:487` writes it again after the long-description block | Smoke final displayed price after selecting infantry, vehicle, locked/unlocked crew slots and units with library text. |

## Promotion Gates

1. Decide whether to merge as UI-only QoL or bundle with broader UI work.
2. Propagate maintained Vanilla or label the branch Chernarus-only.
3. Smoke Buy Units with low funds, exact funds, high funds, unit-cost upgrades and attack-wave price modifiers.
4. Smoke infantry, crewless vehicles, vehicles with driver/gunner/commander crew slots and lock toggles.
5. Smoke queue labels while queue counts change and while switching tabs/factions.
6. Smoke EASA with current loadout visible, current loadout filtered by AA settings/upgrades, and no current loadout set.
7. Keep DR-28 authority and EASA exact-funds/stale-context issues separate unless this branch is expanded.

## Development Lesson

Small UI branches need final-control smoke, not just hunk review. Here, the code computes improved values, but the visible result depends on later writes, row filtering and live missionNamespace values. Future agents should trace the UI control lifecycle from list-fill to final per-loop display before declaring a UX branch proven.

## Continue Reading

- [Client UI systems atlas](Client-UI-Systems-Atlas#branch-only-ui-theme-work)
- [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas)
- [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas)
- [UI IDD collision repair](UI-IDD-Collision-Repair)
- [Pending owner decisions](Pending-Owner-Decisions#branch-only-feature-promotion-decisions)
- [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack)

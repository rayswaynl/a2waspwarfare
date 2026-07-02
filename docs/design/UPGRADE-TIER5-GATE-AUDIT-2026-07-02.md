# Upgrade tier-5 gate audit - ICBM / Build Ammo

Lane: 40 / AUDIT-60 item 10
Scope: Chernarus source mission only, docs/proposal only. No retune in this PR.
Date: 2026-07-02

## Bottom line

The `WFBE_UP_AIR` / `WFBE_UP_GEAR` tier-5 gates in `Upgrades_CO_US.sqf` and `Upgrades_CO_RU.sqf` are real, but they are not a confirmed unreachable bug.

Both CO factions define `Air` max level 5 and `Gear` max level 5, with matching costs/times arrays and normal player-command validation. The issue is a parity/balance divergence:

- `CO_US` and `CO_RU` require `Air 5` for both ICBM/SCUD levels and `Gear 5` for Build Ammo.
- The other nine faction upgrade files require `Air 3` for ICBM/SCUD and `Gear 2` for Build Ammo.
- `CO_US` and `CO_RU` do not hand-author `Air 4`, `Air 5`, `Gear 5`, `ICBM`, or `Build Ammo` in their AI upgrade order. `Check_Upgrades.sqf` appends missing enabled levels, so the gates are still reachable for AI, but the ordering is implicit and very late.

## Evidence table

All 11 Chernarus upgrade files use the same upgrade ids from `Common/Init/Init_CommonConstants.sqf`: `WFBE_UP_AIR = 3`, `WFBE_UP_ICBM = 11`, `WFBE_UP_GEAR = 13`, `WFBE_UP_AMMOCOIN = 14`.

| Upgrade file | Air max | Gear max | ICBM air prerequisite | Build Ammo gear prerequisite | Handwritten AI order contains required prerequisite levels? | Finding |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| `Upgrades_CDF.sqf` | 5 | 5 | 3 | 2 | air: yes / gear: yes | Normal faction pattern |
| `Upgrades_CO_GUE.sqf` | 5 | 5 | 3 | 2 | air: yes / gear: yes | Normal faction pattern |
| `Upgrades_CO_RU.sqf` | 5 | 5 | 5 | 5 | air: no / gear: no | Late CO-only gate, implicit AI ordering |
| `Upgrades_CO_US.sqf` | 5 | 5 | 5 | 5 | air: no / gear: no | Late CO-only gate, implicit AI ordering |
| `Upgrades_GUE.sqf` | 5 | 5 | 3 | 2 | air: yes / gear: yes | Normal faction pattern |
| `Upgrades_INS.sqf` | 5 | 5 | 3 | 2 | air: yes / gear: yes | Normal faction pattern |
| `Upgrades_OA_TKA.sqf` | 5 | 5 | 3 | 2 | air: yes / gear: yes | Normal faction pattern |
| `Upgrades_OA_TKGUE.sqf` | 5 | 5 | 3 | 2 | air: yes / gear: yes | Normal faction pattern |
| `Upgrades_OA_US.sqf` | 5 | 5 | 3 | 2 | air: yes / gear: yes | Normal faction pattern |
| `Upgrades_RU.sqf` | 5 | 5 | 3 | 2 | air: yes / gear: yes | Normal faction pattern |
| `Upgrades_USMC.sqf` | 5 | 5 | 3 | 2 | air: yes / gear: yes | Normal faction pattern |

Line references:

- `Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:60-85` and `Upgrades_CO_RU.sqf:60-85` set max levels: Air 5, ICBM 2, Gear 5, Build Ammo 1.
- `Upgrades_CO_US.sqf:104,109` and `Upgrades_CO_RU.sqf:104,109` set the divergent tier-5 links.
- The other nine files use `[[WFBE_UP_AIR,3],[WFBE_UP_AIR,3]]` at line 104 and `[[WFBE_UP_GEAR,2]]` at line 109.
- `Upgrades_CO_US.sqf:153-198` and `Upgrades_CO_RU.sqf:153-198` hand-author AI order through `Air 3` and `Gear 4`, but not `Air 4`, `Air 5`, `Gear 5`, `ICBM`, or `Build Ammo`.
- `Common/Config/Core_Upgrades/Check_Upgrades.sqf:30-40` appends all missing enabled upgrade levels to the AI order.

## Reachability notes

Player commander requests are bounded by configured max level, costs/times, and links in `Server/PVFunctions/RequestUpgrade.sqf:90-132`. For the CO factions, the required `Air 5` and `Gear 5` levels exist and have corresponding cost/time entries, so the server-side request path can legally reach the gates.

The queued upgrade path also checks max level and current link requirements in `Server/FSM/upgradeQueue.sqf:52-74`.

The AI commander direct program scan in `Server/Functions/Server_AI_Com_Upgrade.sqf:26,55-100` chooses from `WFBE_C_UPGRADES_%1_AI_ORDER` and does not perform a separate `LINKS` prerequisite check there. That makes program order important. Since `Check_Upgrades.sqf` appends missing levels in upgrade-id order, the missing CO dependency levels are appended as:

1. `WFBE_UP_AIR` levels 4 and 5
2. `WFBE_UP_ICBM` levels 1 and 2
3. `WFBE_UP_GEAR` level 5
4. `WFBE_UP_AMMOCOIN` level 1

That ordering keeps the CO AI path reachable, but it means the late gates rely on auto-completion instead of the authored program order.

## Factory / roster cap check

AUDIT-60 item 10 described the tier-5 gates as "where factories cap lower." The upgrade configs do not cap Air or Gear below 5: all 11 upgrade files set Air max 5 and Gear max 5.

Unit purchase roster gating is separate from upgrade prerequisites. `Client/Functions/Client_UIFillListBuyUnits.sqf:97-105` compares each unit row's `QUERYUNITUPGRADE` against the current upgrade level selected by the factory tab. `QUERYUNITUPGRADE` is index 5 in `Common/Init/Init_CommonConstants.sqf:6-15`.

For the two divergent CO factions:

- `Units_CO_US.sqf:264-291` aircraft roster includes tier-5 aircraft metadata such as `AH1Z`, `AV8B2`, and `F35B`.
- `Units_CO_RU.sqf:184-224` aircraft roster includes tier-5 aircraft metadata such as `Ka52Black`, `Su34`, and `Su39`.

So the "factory cap lower" claim is not supported by the Chernarus aircraft roster data. The clearer issue is that SCUD and Build Ammo are gated at the absolute final Air/Gear research level only for `CO_US` and `CO_RU`.

## Proposal options

Recommended for this lane: do not change balance automatically. Treat this as a Ray balance call.

Option A: Keep the CO-only late-game gate.

- Use if `CO_US` and `CO_RU` are intentionally meant to delay SCUD and Build Ammo until final Air/Gear tech.
- Follow-up should add a short comment in both upgrade files explaining the intended asymmetry.
- Consider hand-authoring `Air 4`, `Air 5`, `Gear 5`, `ICBM`, and `Build Ammo` in the CO AI order so the behavior is visible instead of implicit.

Option B: Normalize CO factions to the other nine faction files.

- Change `CO_US` / `CO_RU` ICBM links from `Air 5` to `Air 3`.
- Change `CO_US` / `CO_RU` Build Ammo link from `Gear 5` to `Gear 2`.
- This is a real behavior/balance retune and should be done in a separate flagged/balance PR, not as part of this docs-only audit.

Option C: Keep the tier-5 prerequisites, but tune AI order explicitly.

- Add the currently auto-appended CO levels into the handwritten AI order at deliberate positions.
- This does not change human commander prerequisites, but it can change AI timing, so it is still a balance-affecting change.

## Verification performed

- Compared all 11 `Common/Config/Core_Upgrades/Upgrades_*.sqf` files.
- Checked player commander validation in `Server/PVFunctions/RequestUpgrade.sqf`.
- Checked queued upgrade validation in `Server/FSM/upgradeQueue.sqf`.
- Checked AI commander upgrade selection and auto-completed AI order behavior in `Server/Functions/Server_AI_Com_Upgrade.sqf` and `Common/Config/Core_Upgrades/Check_Upgrades.sqf`.
- Checked CO aircraft roster max unit unlock tiers against `Common/Config/Core_Units/Units_CO_US.sqf`, `Units_CO_RU.sqf`, and core unit metadata rows.

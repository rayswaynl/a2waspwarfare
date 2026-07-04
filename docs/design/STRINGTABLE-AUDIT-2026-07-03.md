# Stringtable Audit - 2026-07-03

Lane: 209 - Stringtable audit
Base: `github/claude/build84-cmdcon36@c76f3e007457c410ee624461e364d3de8a7a2670`

## Scope

This is a report-only pass over the maintained Chernarus source mission stringtable. It does not mass-edit
`stringtable.xml`, mission source, generated Takistan output, package artifacts or live-server files.

## Commands

```powershell
python Tools\Lint\check_stringtable_refs.py --exit-zero
python Tools\Lint\check_stringtable_refs.py --orphans --exit-zero
python Tools\Lint\check_stringtable_refs.py --ru-gaps --exit-zero
rg -n 'hint(Silent)?\s+"|systemChat\s+"|vehicleChat\s+"|GroupChatMessage\s*"|titleText\s*\[\s*"|cutText\s*\[\s*"' 'Missions\[55-2hc]warfarev2_073v48co.chernarus\Client' 'Missions\[55-2hc]warfarev2_073v48co.chernarus\Server' -g '*.sqf'
```

## Summary

| Check | Result | Notes |
| --- | --- | --- |
| Referenced STR_ keys missing from `stringtable.xml` | 0 | The default checker scanned 770 files, found 521 referenced keys and reported no missing key findings. |
| Duplicate key IDs | 1 | `STR_WF_TOOLTIP_HeadBugFix` at `stringtable.xml:2214`; open PR #401 already owns the lane-4 duplicate fix. |
| Russian coverage gaps | 0 new gaps | `--ru-gaps` only repeats the duplicate-key finding; no missing or blank Russian rows were reported by the checker. |
| Orphan candidates | 854 | No deletion recommended from this audit; many are dynamic or catalog-style keys that the static scanner cannot prove dead. |

## Orphan Shape

The orphan pass reported 854 keys that are defined but not referenced by scanned source files. Categorized by key family:

| Category | Count | Examples | Recommendation |
| --- | ---: | --- | --- |
| Faction catalog keys | 429 | `STR_WF_US_B*`, `STR_WF_US_L*`, `STR_WF_ALL_CF*` | Keep until a faction/catalog owner proves these are not dynamically addressed or legacy-compatible rows. |
| UI/parameter/info keys | 90 | `STR_WF_PARAMETER_*`, `STR_WF_TOOLTIP_*`, `STR_WF_TACTICAL_*` | Triage in small UI-specific batches; do not prune during gameplay lanes. |
| Dormant action/module families | 46 | `STR_ACT_*`, `STR_HINT_*`, `STR_UAV_*` | Candidate cleanup once dormant feature ownership is known. |
| Legacy WASP/CoIn/action keys | 11 | `str_coin_*`, `STR_BECTI2_*`, `STR_WASP_*` | Keep until CoIn/WASP module owners confirm no runtime string construction. |
| Other | 278 | Briefing/menu/history leftovers | Good follow-up backlog, but still needs per-key provenance before deletion. |

## Wave 1-3 Coverage Notes

The newer Build86 families are present in the stringtable with Russian rows:

- SCUD/TEL tactical text has keys at `stringtable.xml:5892-5920`, including `STR_WF_SCUD_ACTION`, no-funds, target, launch, cooldown and oil-platform requirements.
- Command-console labels/tooltips start at `stringtable.xml:5921`, including claim, posture, move/defend/patrol/release, artillery and all-push/all-hold labels.
- Skin selector labels are present around `stringtable.xml:5871-5888`.
- The targeted checker run over tactical menu, skin selector, command menu and victory FSM source found no missing keys; it only repeats the existing `STR_WF_TOOLTIP_HeadBugFix` duplicate.

## Hardcoded Visible Text Backlog

The literal-string grep found several player-visible English messages still outside the stringtable. These should be separate small follow-up lanes, not part of this report-only pass:

| Area | Examples | Suggested follow-up |
| --- | --- | --- |
| Gear/menu UI | `GUI_BuyGearMenu.sqf:72`, `:257`, `:258`, `:483`, `:490`; `GUI_Menu.sqf:297`, `:299`, `:313`, `:317`; `GUI_Menu_EASA.sqf:96`, `:114` | Localize compact gear/main-menu feedback strings. Coordinate with GUI hot-file guidance before editing. |
| Optional QOL/onboarding hints | `Client_QOL_Advisor.sqf:70`, `:94`, `:106`, `:131`, `:133` | If the advisor lane continues, add `STR_WF_QOL_*` rows alongside the hint text. |
| GUER/support actions | `Action_GuerMortarStrike.sqf:40`, `:48`; `Action_BuildFOB.sqf:32`, `:42`; `Client_SupportRefuel.sqf:9` | Localize feature-specific action feedback in the owning feature lanes. |
| Legacy modules/debug | `Zeta_Hook.sqf:26-27`, `CM_Countermeasures.sqf:11`, `Init_Client.sqf:311`, `Client_HandleMapSingleClick.sqf:180` | Triage separately; some are debug or legacy module text rather than current UX. |

## Fix-Lane Proposals

1. Keep PR #401 as the owner for `STR_WF_TOOLTIP_HeadBugFix`; do not open a duplicate duplicate-key PR.
2. Add a narrow "localized visible feedback" lane for `GUI_BuyGearMenu.sqf` and the main-menu GPS/earplug hints after checking the current GUI avoid list.
3. Add a QOL-advisor localization follow-up if the advisor feature is still expected to ship; its strings are coherent as a family and easy to key as `STR_WF_QOL_*`.
4. Treat orphan removal as a future owner-reviewed pruning pass. Start with non-faction/non-dynamic-looking families only, and prove each deletion with source grep plus in-game menu smoke.

# TKGUE Patrol Depth Status - 2026-07-03

## Verdict

Fleet lane 39 is current-target present on
`origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`.

The stale `MISSION-AUDIT-60.md` row says TKGUE patrol tiers were near-empty and the
`Units_OA_TKGUE.sqf` air pool had no helicopter. Current target no longer matches that
finding. The maintained roots already carry the `cmdcon41-w3e` TKGUE patrol diversity fill,
including vehicle-bearing LIGHT, MEDIUM and HEAVY patrol templates, and TKGUE already has a
`UH1H_TK_GUE_EP1` air row in the core and units configuration.

No duplicate source patch is warranted from this lane. A future balance retune can still exist
as a separate explicit lane, but it should start from the current populated tables rather than
from the old near-empty audit row.

## Source Proof

The relevant TKGUE data and patrol consumer are byte-identical across Chernarus, Takistan and
Zargabad:

| File family | Maintained roots | SHA-256 |
| --- | --- | --- |
| `Common/Config/Core_Root/Root_TKGUE.sqf` | Chernarus, Takistan, Zargabad | `B9CE8EB17A1CA1E1A39A61DFDD947D6B95F0A97126B00899582C5001E68049EC` |
| `Common/Config/Core/Core_TKGUE.sqf` | Chernarus, Takistan, Zargabad | `5A57E7341576F7DE440050695774255ACA4C5100BCC4F30585DCBCD3175A30AD` |
| `Common/Config/Core_Units/Units_OA_TKGUE.sqf` | Chernarus, Takistan, Zargabad | `ACC4385026975F868E5ADE53B959D532CC310245D4071718F24A8628BBC9243B` |
| `Common/Config/Core_Upgrades/Upgrades_OA_TKGUE.sqf` | Chernarus, Takistan, Zargabad | `3C5BF4FAEB49B2C62AFA1741DC96A41A30CF351FFC2014FC9585D596FE356D9E` |
| `Server/FSM/server_side_patrols.sqf` | Chernarus, Takistan, Zargabad | `02F376EEAB6C6BE2F72476D72073EB81B4518D5C8E7F3FA06F5470D206D9A7BE` |

Representative Chernarus anchors, mirrored by line-equivalent code in Takistan and Zargabad:

| Area | Current evidence |
| --- | --- |
| Stale audit row | `docs/design/MISSION-AUDIT-60.md:39` is the old finding that says TKGUE patrol/air tiers were near-empty. |
| Patrol fill header | `Root_TKGUE.sqf:36-44` documents the `cmdcon41-w3e` diversity fill and explicitly says the old pools were near-empty and foot-only. |
| LIGHT patrol pool | `Root_TKGUE.sqf:45-54` defines four LIGHT templates, including DSHKM/SPG-9 technicals and a PK pickup mixed with AT/MG infantry. |
| MEDIUM patrol pool | `Root_TKGUE.sqf:56-67` defines five MEDIUM templates, including MANPADS, BTR-40 MG, Ural ZU-23 and BRDM scout variants. |
| HEAVY patrol pool | `Root_TKGUE.sqf:69-78` defines four HEAVY templates, including T-55/T-34 armor, BTR-40 MG, Ural ZU-23/BRDM AA and an elite foot AT/sniper team. |
| Air vehicle core row | `Core_TKGUE.sqf:106-108` registers `UH1H_TK_GUE_EP1` as the TKGUE air vehicle row. |
| Air units pool | `Units_OA_TKGUE.sqf:70-79` seeds the aircraft buy-list with `UH1H_TK_GUE_EP1`, optional PMC Ka-60s and An-2s. |
| Airport units pool | `Units_OA_TKGUE.sqf:82-87` keeps the airport pool on An-2s, so the helicopter is in the air-factory path rather than the airport-only list. |
| Root air support | `Root_TKGUE.sqf:27` and `Root_TKGUE.sqf:32` use `UH1H_TK_GUE_EP1` for paratrooper and supply paradrop vehicles. |
| OA units import | `Root_TKGUE.sqf:154-160` compiles `Units_OA_TKGUE.sqf` in the OA branch. |
| Patrol upgrade enabled | `Upgrades_OA_TKGUE.sqf:24-29` enables Patrols for OA TKGUE. |
| Patrol ladder | `Upgrades_OA_TKGUE.sqf:57`, `:85`, `:121` and `:149` define four Patrols cost/level/dependency/time rows. |
| Patrol upgrade index | `Init_CommonConstants.sqf:60` defines `WFBE_UP_PATROLS = 23`. |
| Road-biased pick defaults | `Init_CommonConstants.sqf:881-882` default road-biased, motorized side patrol picking on, with a full-pool fallback for foot-only pools. |
| GUER fallback level | `Init_CommonConstants.sqf:1666` defaults `WFBE_C_GUER_PATROLS_LEVEL` to 2 because resistance has no normal upgrade system. |
| Patrol level read | `server_side_patrols.sqf:130-142` reads `WFBE_UP_PATROLS` and applies the GUER fallback level when needed. |
| GUER tier force | `server_side_patrols.sqf:219-223` forces GUER patrols to MEDIUM or HEAVY based on owned-town count before reading the `WFBE_%1_PATROL_%2` pool. |
| Motorized preference | `server_side_patrols.sqf:225-234` prefers vehicle-containing entries when road bias is enabled, falling back to the full pool only if no vehicle entry exists. Current TKGUE pools now have vehicle entries, so they exercise the preferred path. |
| Dispatch | `server_side_patrols.sqf:270-277` dispatches the selected patrol through the least-loaded HC when available or locally otherwise. |

## Boundary Versus Future Balance Work

This status pass does not claim the current TKGUE balance is final. It only closes the stale
"near-empty patrol tiers / no helo pool" diagnosis against the current target.

Future source work, if selected by the owner, should be framed as a balance retune or default-off
variant lane with fresh evidence. It should not treat `Root_TKGUE.sqf` as empty, should not touch
lane 31 WAVE rows, and should account for the existing GUER comeback-force behavior in
`server_side_patrols.sqf`.

## Out Of Scope

This pass intentionally does not edit mission source. It does not change TKGUE classnames, add or
remove patrol templates, retune Patrols upgrade costs, alter GUER comeback levels, add lobby
parameters, run LoadoutManager, package missions, deploy to a live server or touch runtime
settings.

## Validation

- Open PR, wiki claim and prompt refresh found no active lane 39 build84 PR for this exact
  TKGUE patrol/air status lane. The old lane 39 PR #184 was diagnostic string cleanup, not this
  TKGUE patrol finding.
- `git grep` verified the stale `MISSION-AUDIT-60.md` row and the current TKGUE patrol, air,
  upgrade and side-patrol consumer anchors listed above.
- `Get-FileHash` showed the TKGUE root, core, units, upgrade and patrol driver files are
  byte-identical across Chernarus, Takistan and Zargabad.
- This PR is docs-only: `JOURNAL.md` plus
  `docs/design/TKGUE-PATROL-DEPTH-STATUS-2026-07-03.md`.

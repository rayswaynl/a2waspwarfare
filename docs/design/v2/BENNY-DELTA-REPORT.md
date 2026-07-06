# Benny Warfare 2.073+ Delta Report

Status: DRAFT, changelog-level reconstruction ready for source verification  
Lane: 448

## Source Basis

Required sources:

- `E:\arma2-cache` Jerry/Armaholic archive and reports
- BI forums and surviving web pages
- wiki:Upstream-Mining-Ledger
- wiki:Upstream-Changelog-Feature-Leads

Local archive root was reachable, but full changelog extraction was blocked by intermittent sandbox command failures. This report therefore classifies changelog-level leads for a builder/miner to verify before implementation.

## Comparison Table

| Benny feature/fix area | WASP status | Gap rating | Notes |
|---|---|---|---|
| Economy parameterization | Partially absorbed | Design lead only | WASP has owner-tuned economy and supply multiplier history; do not port numbers blindly. |
| Town capture flow | Absorbed/customized | Skip | WASP town hardness and GUER pressure are owner intent; avoid softening towns. |
| Factory production queues | Partially absorbed | Worth porting if UX-only | Inspect for queue visibility and admin observability, not mechanics churn. |
| Construction placement helpers | Partially absorbed | Design lead only | Use for UI clarity only; avoid deploy/box scripts and live runtime changes. |
| Gear store categories/prices | Partially absorbed | Design lead only | WASP has GUER gear fixes; compare category labels, not prices. |
| HC support and delegation | Absorbed/customized | Skip | Owner constraints say never touch HC architecture in this sprint. |
| Supply system | Custom WASP | Design lead only | Compare player guide clarity and route feedback; no raw value import. |
| Respawn flow | Custom WASP | Skip | JIP/join saga makes this high-risk; no V2 prep changes. |
| Scoring/stat categories | Partially absorbed | Worth porting | Use as naming cross-check for Stats V2, but WASPSTAT is authoritative. |
| Parameters UI | Partially absorbed | Design lead only | Audit labels/default descriptions for player-facing clarity. |
| Commander voting/admin | Existing/custom | Context | Only useful for admin hub read-only observability. |
| End-of-round summary | Recently extended | Worth porting if display-only | Compare victory screen concepts against Bot V2 match report. |
| Vehicle servicing | Existing/custom | Context | Use for guide wording and EASA naming only. |
| Artillery/support menus | Existing/custom | Context | Keep owner shelved munitions constraints. |

## Owner-Rejected / Skip Filters

Do not revive:

- TPWCAS
- AI supply trucks
- satchel AI
- EMP/WP/DECOY SCUD munitions
- doctrine personalities
- antistack touch
- ACR content
- `WFBE_C_SIM_GATING`

## Worth-Porting Leads

1. End-of-round display ideas: only if they improve Bot V2 embeds or public match history.
2. Scoring label normalization: use to confirm `CombatRecord` labels and bot field names.
3. Queue/status visibility: only for read-only admin hub cards.

## Design Lead Only

- Economy pacing
- Gear category structure
- Supply route feedback
- Parameter descriptions

These must be interpreted through current WASP owner constraints and recent B57/B84 behavior, not copied.

## Completion Gap

The "full changelog reconstructed" done criterion needs another pass over archive/web changelog material. This draft gives the comparison matrix and decision rules but does not claim exhaustive version stamps.

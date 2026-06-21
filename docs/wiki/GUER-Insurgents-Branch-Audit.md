# GUER Insurgents Branch Audit

This page is the current source-facing audit for the playable RESISTANCE / GUER Insurgents work. The original `origin/feat/guer-insurgents-faction@41550bd33` intake is now historical branch-review evidence; current `origin/master@0139a346` contains that merge lineage and later Takistan parity work.

Use this page to separate three facts:

- `9af83596` is an ancestor of current `origin/master`.
- Current `origin/master@0139a346` has GUER source in both maintained mission roots.
- Runtime/balance smoke is still separate evidence; do not call the feature release-complete from source presence alone.

## Current Source Status

| Area | Current evidence | Status |
| --- | --- | --- |
| Merge lineage | `git merge-base --is-ancestor 9af83596 origin/master` passes; current checked head is `origin/master@0139a346`. | Merged lineage, not a pending branch. |
| Maintained roots | `git grep` on `origin/master` finds `WFBE_C_GUER_PLAYERSIDE`, `Root_GUE_PlayerOverlay`, `Server_GuerStipend`, `Action_GuerVbiedDetonate` and `"guer-vbied-detonate"` in both `Missions/[55-2hc]warfarev2_073v48co.chernarus` and `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`. | Current source parity exists in both maintained roots. |
| Gate and constants | Both roots define the lobby gate at `Rsc/Parameters.hpp:587`; default fallbacks live at `Common/Init/Init_CommonConstants.sqf:76-79`; `initJIPCompatible.sqf:129-134` re-reads the mission param for dedicated MP. | Gate-controlled feature. Source default still matters. |
| Hostility and three-way mode | Both roots gate reciprocal WEST/EAST hostility in `Server/Init/Init_Server.sqf:11` and set `WFBE_ISTHREEWAY` from `WFBE_C_GUER_PLAYERSIDE` at `Common/Init/Init_Common.sqf:293`. | Gate-on changes side relations; gate-off should preserve normal two-side behavior. |
| Economy loop | Both roots register GUER teams/economy in `Server/Init/Init_Server.sqf:584-612`; `Server/Server_GuerStipend.sqf:14,30` gates startup and logs the server economy loop. | Source-present; still needs long-match economy smoke. |
| Depot pool and map-specific VBIED type | `Root_GUE.sqf:129-130` and `Root_TKGUE.sqf:102-104` load `Root_GUE_PlayerOverlay.sqf`; the overlay seeds `WFBE_GUERDEPOTUNITS` at `:47`, switches Takistan VBIED type to `datsun1_civil_2_covered` at `:69-71`, and rebuilds the pool from tier at `:82`. | Shared overlay with map-specific branch. |
| VBIED action and server authority | `Client/Action/Action_GuerVbiedDetonate.sqf:33,46` applies the arm delay and sends `RequestSpecial`; `Server/Functions/Server_HandleSpecial.sqf:484-495` checks gate, driver, side and chassis before damage/blast handling. | Source-present; high-impact balance and forge-rejection smoke still required. |
| Ka-137 / EASA support | `Client/Module/EASA/EASA_Init.sqf:672-673` adds `Ka137_MG_PMC` when the GUER gate is on; `Root_GUE_PlayerOverlay.sqf:47,62,76` keeps it in the player-facing depot pool. | Source-present; in-engine weapon geometry still needs smoke before balance claims. |
| UI and service integration | `GUI_Menu_BuyUnits.sqf:62,615`, `Client_UIFillListBuyUnits.sqf:145-146`, `Client_BuildUnit.sqf:338` and `GUI_Menu_Service.sqf:262` carry GUER-specific buy/service behavior. | Source-present; menu smoke should cover both Chernarus and Takistan. |
| HC slot caution | Current source still contains `forceHeadlessClient=1` mission slots, but `Headless/Init/Init_HC.sqf:20` notes that attribute is A3-only/inert in A2 OA. | Do not document HC reseating as an A2 OA guarantee without runtime proof. |

## Current Interpretation

The feature is no longer just a broad Chernarus-first review branch. It is current master source with maintained-root parity, including the Takistan VBIED type switch and shared player overlay. The older branch-intake matrix remains useful as history because it records the original blast radius, economy, hostility and branch-size review risks, but future status wording should point here first.

Source parity does not settle runtime quality. The still-open gates are:

1. Gate-off smoke: `WFBE_C_GUER_PLAYERSIDE = 0` should suppress playable GUER behavior and preserve the two-side match.
2. Gate-on Chernarus smoke: slots/JIP, depot pool, stipend cadence, kill-funds, no-base menu flow, town capture/harass stats and WEST/EAST AI return fire.
3. Gate-on Takistan smoke: map-specific depot pool, datsun VBIED type, town-center EASA/service access and maintained Vanilla generated metadata.
4. VBIED smoke: buy, two-step confirm, arm delay, blast/kill credit, friendly-fire behavior and forged `RequestSpecial` rejection.
5. Ka-137 smoke: EASA loadouts, ATGM/rocket fire geometry and fallback balance.
6. HC smoke: actual A2 OA headless-client seating/delegation behavior, not `forceHeadlessClient` assumptions.

## Owner Routes

| Need | Canonical route |
| --- | --- |
| Economy and stipend behavior | [GUER insurgent player economy](GUER-Insurgent-Player-Economy) |
| VBIED action and server handler | [GUER VBIED detonate action](GUER-VBIED-Detonate-Action) |
| Historical branch intake | [Gameplay systems atlas](Gameplay-Systems-Atlas#merged-guer-insurgents-source-status-and-historical-intake) |
| Current risk/readiness row | [Feature status register](Feature-Status-Register) |
| Smoke planning | [Testing, debugging and release workflow](Testing-Debugging-And-Release-Workflow) |

## Development Lesson

A gate-controlled third side has two independent contracts: source presence and configured runtime state. For GUER, future docs and release notes must name the source ref, the target mission root, the `WFBE_C_GUER_PLAYERSIDE` value and whether the claim is source review or Arma 2 OA smoke. Treat Takistan as source-present on current `origin/master@0139a346`, but keep runtime parity provisional until its gate-on smoke is recorded.

## Continue Reading

Main map: [Home](Home) | Status row: [Feature status register](Feature-Status-Register) | Economy: [GUER insurgent player economy](GUER-Insurgent-Player-Economy) | Action: [GUER VBIED detonate action](GUER-VBIED-Detonate-Action)

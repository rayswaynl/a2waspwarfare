# Client-UI and Server-Loop Performance Findings (June 2026)

A June-2026 sweep of client/UI refresh loops and recurring server-side collector/score loops, complementing the [Performance opportunity sweep](Performance-Opportunity-Sweep). All findings are source-verified against the Chernarus source mission (`Missions/[55-2hc]warfarev2_073v48co.chernarus/`), Arma 2 OA 1.64.

> **Status: logged, NOT patched — owner reviewed and declined (not a current priority).** Recorded so these are not re-discovered cold. Every item is **measurement-led**: most of these loops already self-instrument to the server RPT (next section), so pull that data before revisiting — do not patch on estimate alone.

## Ground truth lives in the RPT — these loops are already instrumented

The recurring server loops below end with a `PerformanceAudit_Record [...]` call that writes their **actual elapsed time + scale** to the server RPT each cycle. The authoritative cost is therefore a grep on a populated-server RPT, not an estimate:

- `Server/FSM/server_collector_garbage.sqf:28` → `["server_garbage_collector", <ms>, "dead:N;tracked:M;spawned:K", "SERVER"]`
- `Server/FSM/emptyvehiclescollector.sqf:26` → `["emptyvehiclescollector", <ms>, "queued:N;handled:K", "SERVER"]`
- `Server/Module/AntiStack/updateScoreInternal.sqf:31` → `["antistack_update_score", <ms>, "allUnits:N;players:K", "SERVER"]`

Gate `PerformanceAuditEnabled` (default true) controls emission. Read these before changing any loop cadence.

## Scheduler model (why "server FPS" is the wrong metric)

All items here are `sleep`/`uiSleep` loops, i.e. the **scheduled** SQF environment, which shares a small per-frame time budget across all scripts. A heavy scheduled loop does not drop the FPS counter — it delays *other* scripts (town AI, supply, capture), surfacing as gameplay latency. Each item's real question is "how much scheduler budget per cycle", which the RPT audit `<ms>` answers directly.

## Findings (honest ranking)

| # | Opportunity | Source | Real impact | Note |
| --- | --- | --- | --- | --- |
| 1 | Buy-list recomputes 7 constant arrays per unit row | `Client/Functions/Client_UIFillListBuyUnits.sqf:67,71,78,83,89,94,98` (inside `forEach _listNames` `:35-105`) | Client hitch on every buy-tab / faction switch | Loop-invariant: 7 `format`+`getVariable`+`in` per row, ~50 rows. The arrays (REPAIRTRUCKS/AMMOTRUCKS/LIFTVEHICLE/AMBULANCES/SALVAGETRUCK/ARTYVEHICLE/SUPPLYTRUCKS) are constant per side. Hoist the 7 reads above the loop. ~12 LOC, low risk. |
| 2 | Service menu rebuilds all batch prices at 10 Hz while open | `Client/GUI/GUI_Menu_Service.sqf:237` (loop), `:246-248` (three `_martyServiceBuildBatch` rebuilds) | Service-menu sluggishness near a vehicle cluster | Prices only change on purchase; the rebuild runs every 100 ms. Dirty-flag + `sleep 0.2`. ~15 LOC, low risk. Client-only, scoped to that menu being open. |
| 3 | Garbage collector is O(allDead x gc_collector) every 0.5 s | `Server/FSM/server_collector_garbage.sqf:17` (`_x in gc_collector`), `:21` (`gc_collector + [_x]`), `:32` (`sleep 0.5`) | Grows with match length — verify via RPT | Late match allDead and gc_collector both reach the hundreds; O(n) membership + array realloc each cycle. Use an O(1) `setVariable` flag for membership + `set [count,_x]` + a slower sleep. ~20 LOC, low-med (Marty owns and already audits this loop — coordinate). Sub-item: dead `_town = ... GetClosestLocation` in `Common/Functions/Common_TrashObject.sqf:10` (a town scan per corpse, result never used). |
| 4 | AntiStack score sampling walks `allUnits` per interval | `Server/Module/AntiStack/updateScoreInternal.sqf:26` | **Low** | Gated off entirely when AntiStack disabled (`:9`). When on: cheap `isPlayer`+`setVariable`. `playableUnits` + a slower interval is correct but the payoff is small. Skip unless the RPT says it is hot. |
| 5 | `compareTeamScores` walks `allUnits` twice | `Server/Module/AntiStack/compareTeamScores.sqf:20-24,26-30` | **Negligible** | Runs once per joining player, not in a loop. A code smell (one pass could count both sides), not a perf issue. |
| 6 | Empty-vehicle collector: per-vehicle PV broadcast | `Server/FSM/emptyvehiclescollector.sqf:15` (redundant inner read), `:19` (`setVariable [...,true]`), `:30` (`sleep 0.5`) | **Low** | Loop body only runs for *new* vehicles; steady state is a cheap membership scan. Real cost is one network broadcast per newly-abandoned vehicle (bursts during mass abandonment). |
| 7 | Respawn menu polls at 100 Hz | `Client/GUI/GUI_RespawnMenu.sqf:34,113` (`sleep .01`) | **Low** | The expensive spawn/marker work is already 1 Hz-gated (`:44`); the 100 Hz only re-runs cheap checks. Trivial `.01 -> .1` is harmless QoL, not a real win. |
| 8 | Team menu polls at 20 Hz | `Client/GUI/GUI_Menu_Team.sqf` (`sleep 0.05`) | **Unverified** | Flagged by an earlier pass; income display already 2 s-gated. Not re-confirmed this pass — verify before acting. |

## Owner decision

Owner reviewed this batch (2026-06-02) and **declined to patch** — not aligned with current priorities. Items 1 and 2 are the cleanest (behaviour-preserving, client-side, low risk) if ever revisited; items 4-7 are not worth the change-risk on their own. Revisit only with RPT `PerformanceAudit` evidence, consistent with the [Performance opportunity sweep](Performance-Opportunity-Sweep) "measurement-first" stance.

## Continue Reading

Sibling: [Performance opportunity sweep](Performance-Opportunity-Sweep) | Runtime context: [AI, headless and performance](AI-Headless-And-Performance)

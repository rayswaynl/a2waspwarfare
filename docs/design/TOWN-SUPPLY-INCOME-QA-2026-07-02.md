# Town Supply and Income QA - 2026-07-02

Lane 61 scope: source-backed QA sweep for town `supplyValue`, side-supply authority,
income distribution/display, supply missions, JIP supply sync, and adjacent bank/oilfield
income hooks on `claude/build84-cmdcon36`.

This pass is docs-only. No economy retune, AICOM spending behavior, GUI/menu rewrite,
live deploy, package artifact, or generated mirror output is included here.

## Current Model

| Surface | Current live behavior | Source anchors |
| --- | --- | --- |
| Town SV initialization | Each active town stores `startingSupplyValue`, `maxSupplyValue`, `supplyValue`, and per-camp SV server-side. | `Common/Init/Init_Town.sqf:31-36`, `:90-92`, `:120-123` |
| Town SV growth | Automatic supply mode grows owned, uncontested, non-GUER towns toward max SV on the configured delay. | `Server/FSM/server_town.sqf:23-24`, `:99-117` |
| Town capture decay | Attackers reduce town SV by force, camp ratio, capture rate, and camp cap multiplier; when SV drops below 1, the town flips and SV resets to starting SV. | `Server/FSM/server_town.sqf:198-223`, `:234-243` |
| Resource tick | Every income interval, WEST/EAST town SV is summed and converted into player/team funds, AI commander funds, and side supply where currency mode uses supply. GUER is excluded from this side-supply commander economy. | `Server/FSM/updateresources.sqf:3-18`, `:65-96`, `:101-123`, `:153` |
| Side supply authority | Client/common callers only publish temp-channel requests. The server validates payload shape, side/channel match, scalar amount, floors overdrafts to zero, caps to the configured supply limit, and broadcasts the authoritative value. | `Common/Functions/Common_ChangeSideSupply.sqf:8-26`, `Server/Functions/Server_ChangeSideSupply.sqf:1-49` |
| JIP supply reads | WEST/EAST clients request missing supply with a bounded wait and fall back to zero instead of hanging forever. Resistance reads a nonblocking zero default because it is funds-only in this economy. | `Common/Functions/Common_GetSideSupply.sqf:9-55`, `Client/Init/Init_Client.sqf:851-857`, `Server/Functions/Server_PV_RequestSupplyValue.sqf:1-8` |
| Supply missions | Supply vehicles carry a server-visible amount/source town, enforce cooldown, pay side supply or cash-run rewards, clear vehicle state on completion, and prevent enemy interdiction from rewarding same-side self-destruction. | `Client/Module/supplyMission/supplyMissionStart.sqf:53-89`, `Server/Module/supplyMission/supplyMissionStarted.sqf:10-32`, `Server/Module/supplyMission/supplyMissionCompleted.sqf:22-58` |
| Bank income | Bank income is a fixed pool split among living owning-side players, skipped while that side has no deployed HQ. | `Server/Functions/Server_BankIncome.sqf:27-43` |
| Oilfield income | Takistan-only oilfield income reuses `ChangeSideSupply` with the no-player stagnation coefficient, is capped per round, and halts while sabotaged. | `Server/Server_Oilfields.sqf:19-24`, `:735-748` |

## Findings

### Low-Med: income system 4 display still has a JIP team-count gap

`Client_GetIncome.sqf` already guards `WFBE_Client_Teams_Count` for income system 3, because
a slow JIP join can temporarily have zero or unsynced client teams. The system 4 branch still
uses `WFBE_Client_Teams_Count` raw when computing the commander display value:

- `Client/Functions/Client_GetIncome.sqf:13-14` guards system 3 with a local fallback of `1`.
- `Client/Functions/Client_GetIncome.sqf:21-30` does not reuse that guard for system 4.
- `Client/GUI/GUI_Menu_Economy.sqf:66-73` has the same split: guarded system 3, raw system 4.

Impact is limited to client display/RPT risk when income system 4 is selected during the
early JIP team-sync window. Server payouts are still authoritative in `updateresources.sqf`.

Recommendation: when the `GUI_Menu*.sqf` in-flight PRs are clear, apply the same local
team-count fallback to both system 4 display sites. This should not change the server economy
or any actual payout; it only prevents the display path from reading an unsynced count.

### Context: two similarly named supply limits are easy to confuse

The live source intentionally separates the banked supply clamp from the town-SV income gate:

- `WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT` is the actual banked side-supply cap used by
  `Server_ChangeSideSupply.sqf:35-41`.
- `WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT` gates the resource tick while summed owned-town SV is
  below the threshold in `updateresources.sqf:65-96`.
- `Init_CommonConstants.sqf:1171-1177` already warns that the production banked cap comes from
  `Rsc/Parameters.hpp`, not the SQF fallback.
- `Init_CommonConstants.sqf:1186-1191` documents that `WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT`
  is not the banked supply cap.

No code change is recommended here. Future economy PRs should name both values explicitly in
PR bodies and smoke reports to avoid retuning the wrong one.

## Checked But Not Changed

- The SG3 side-supply underflow is fixed on this target: overdrafts now floor at zero in
  `Server_ChangeSideSupply.sqf:37-41`.
- The lane 37 `publicVariable format[...]` concern is not a bug in the current path. The server
  sets and broadcasts the same dynamic variable name in `Server_ChangeSideSupply.sqf:47-49`.
- The old supply mission cooldown casing drift is fixed by `LastSupplyMissionRun` being set and
  read consistently in `Init_Town.sqf:35`, `supplyMissionStarted.sqf:12`, and
  `isSupplyMissionActiveInTown.sqf:8-17`.
- Supply mission completion now rejects null/empty cargo, clears cargo/source/heli/loading state,
  and routes no-commander cash-run supply to the side pool instead of dropping it.
- The RHUD supply row mirrors the resource tick's town-SV gate and supply multiplier for WEST/EAST
  only, and hides a supply-rate suffix for GUER as expected.
- Bank and oilfield income are adjacent income sources but do not bypass the town side-supply
  authority path: bank pays players through `BankPayout`, while oilfield uses `ChangeSideSupply`.

## Smoke Checklist

1. Dedicated boot: confirm `wfbe_supply_west` and `wfbe_supply_east` publish before normal clients
   leave the JIP supply wait, and that a resistance/GUER client does not request side supply.
2. Town capture: capture an owned town, watch `supplyValue` decay, flip side, and reset to the
   town starting SV.
3. Resource tick: after an income interval, check `Server_ChangeSideSupply.sqf` logs for
   `Update tick (town supply income)` and verify no side-supply value exceeds the parameter cap.
4. No-player stagnation: leave one side empty long enough to see
   `StagnateSupplyIncomeNoPlayers.sqf` reduce positive side-supply income.
5. Supply mission truck: load from a `[+SUPPLY]` town, deliver at a Command Center, confirm side
   supply and player reward, then confirm the vehicle cargo variables are cleared.
6. Supply mission helicopter: load at Air level 3+, cancel once during load, then complete a run;
   at Air level 4+ confirm cash-run behavior and commander/no-commander routing.
7. Interdiction: destroy an enemy loaded supply vehicle and confirm only the enemy-kill path pays
   the interdiction cut.
8. Income system 4 follow-up: after the GUI-menu in-flight work clears and the team-count guard is
   patched, JIP into a system-4 round and open RHUD plus Economy menu before team sync; client RPT
   should stay clean.

## Out Of Scope

- No supply/funds values, intervals, caps, or multipliers were retuned.
- No AICOM income, spending, funds-sink, or production behavior was changed.
- No GUI-menu source was edited while menu files are in flight on the Claude lane.
- No Takistan mirror or LoadoutManager run was needed because this is docs-only.

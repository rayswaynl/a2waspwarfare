# B765 / AUDIT-60 Backlog Triage - 2026-07-02

- Lane: 41, AUDIT-60 / B765 backlog triage
- Base checked: `origin/claude/build84-cmdcon36@b2dbab5f3`
- Scope: re-check stale/unclaimed audit rows against the live lane, open PRs, remote branches, source grep, and file history. This is a duplicate-guard report only; no mission behavior changed.

## Summary

Most concrete AUDIT-60 and B765 rows that looked claimable from the fleet prompt are already live, merged, or intentionally rejected. The useful lane-41 output is therefore a refreshed verdict table, so future fleet passes do not reopen closed rows just because the prompt still mentions them.

## AUDIT-60 Current Verdicts

| Row | Current verdict | Evidence |
| --- | --- | --- |
| #3 gear price double-count | Live done | Old PR #169 is closed, but commit `0fdfc1c53` and lane-65 gear/loadout QA removed the stale container-addition repeat. Current `Client_UI_Gear_UpdatePrice.sqf` has the expected `_gear_new` loop once, then closes the backpack/vehicle pass with `forEach [_gear_bp, _gear_veh]`. |
| #4 US/USMC GER/BAF garrison infantry | Live done | PR #176 merged on 2026-07-02; commit `c3a239546` swapped the cited infantry rows. Current maintained `Groups_US.sqf` / `Groups_USMC.sqf` have no `GER_Soldier*` or `BAF_Soldier*` entries. Remaining `BAF_*` matches are vehicle group rows, not the cited garrison infantry defect. |
| #6 TKGUE patrol/air depth | Live done | Current `Root_TKGUE.sqf` contains 4 LIGHT, 5 MEDIUM, and 4 HEAVY patrol templates with TK_GUE infantry, technicals, armor, and AA. Current `Units_OA_TKGUE.sqf` exposes `UH1H_TK_GUE_EP1`, An-2s, and PMC Ka-60 variants when PMC is enabled. `TK-DEEP-PARITY.md` now records TKGUE faction depth as fine. |
| #7 supply dynamic publicVariable | Rejected / not real | Existing `MISSION-AUDIT-60.md` follow-up trace verifies `publicVariable format [...]` is the valid dynamic-name idiom and matches the JIP supply pull chain. |
| #8 respawn-camp `isNil {code}` | Rejected / not real | The code-block form is valid in A2 OA; the separate `Private [...],;` issue is already fixed on the live lane. |
| #9 town `handleDamage` return | Rejected / not real | Existing follow-up verifies the handler returns an absolute damage expression, matching the event-handler contract. |
| #10 ICBM / Build-Ammo tier-5 gates | Covered by separate audit | `ICBM-BUILD-AMMO-TIER5-GATE-AUDIT-2026-07-02.md` already contains the cross-faction evidence table and leaves retune as a balance-owner decision. |
| #11 double starved-inf fallback | Do not blind-patch | Current `AI_Commander_Teams.sqf` has multiple starvation-safety and owned-factory comments around founding. History includes prior starved-infantry fallback fixes. Treat cleanup here as a dedicated AICOM owner/review lane, not an opportunistic deletion. |

## Extra Prompt Rows Rechecked

| Prompt lane | Current verdict | Evidence |
| --- | --- | --- |
| 116 dead patrol loops | Live done | Current `server_town_patrol.sqf` uses `while {!WFBE_GameOver && _aliveTeam}` and recomputes `_aliveTeam`; both maintained roots match. |
| 117 dead-truck salvage loop | Live done | Current `updatesalvage.sqf` uses `while {!gameOver && (alive _vehicle)}` with a `wiki-wins` comment explaining the old `||` bug. |
| 118 ghost defenders | Live done | File history contains `207e539e9 [lane118] Stop ghost defenders re-manning base statics after area changes hands`. |
| 121 MHQ cash repair one-shot | Live done | Current `Server_MHQRepair.sqf` resets `_logik setVariable ['cashrepaired', false, true]` after repair completion. |
| 123 patrol switch gap | Live done | Current `Server_GetTownPatrol.sqf` includes `case (_sv >= 60): {"HEAVY"}` with a `wiki-wins` note for the old exact-60 gap. |
| 127 player list bloat | Live done | Current `playerObjectsList.sqf` initializes `_i = 0` before `forEach WFBE_SE_PLAYERLIST`, not inside it. |
| 128 player-count sampled once | Live done | Current `MonitorPlayerCount.sqf` wraps the count in `while {true}` and sleeps 300 seconds between samples. |
| 132 commander reassign payload | Live done | Current `RequestNewCommander.sqf` sends `[_side, _assigned_commander]` to `Server_AssignNewCommander.sqf`, and the server function reads `_this select 0/1` as side/team. |
| 133 HC delegate random | Live done | Current `Server_DelegateAITownHeadless.sqf` calls `WFBE_CO_FNC_PickLeastLoadedHC` once, then round-robins live HCs from that seed. |
| 153 W20 cache text | Live done | File history contains `784a439c9 Name W20 cache support tier in wildcard text`; current wildcard detail includes `support_tier=%1 new_level=%2`. |
| 155 GUER FOB-token RHUD row | Live done | Current `Client_UpdateRHUD.sqf` has GUER-only `Tech Kills:` and `FOB:` rows and displays `B %1 | LF %2 | HF %3` from `WFBE_GUER_FOB_AVAIL`. |
| 158 QOL advisor expansion | Live done | File history contains `67004a99c Merge PR #232: expand QOL advisor nudges` and `ec9823ee1 Expand QOL advisor nudges`. |
| 159 dialog tooltips | Live done | File history contains `a0bbb6f96 Lane 159: add dialog tooltips`. |
| 77 HQ-kill point exploit | Live done | Current `Server_OnHQKilled.sqf` computes `_teamkill` before scoring and awards the canonical `_points` only when `!_teamkill`; the duplicate 900 block is removed. |
| 90 near-target allocation bias | Live done | File history contains `56f6b33a0 [fable] AICOM F5: near-target allocation band bonus (flag, default 0=inert)`. |

## Recommendations

- Do not reclaim lanes whose only evidence is stale prompt text if the live file already carries a `wiki-wins`, `laneNN`, `cmdcon41`, or matching history commit.
- Keep `MISSION-AUDIT-60.md` as the canonical AUDIT-60 summary, but use this file as the lane-41 duplicate guard for the rows above.
- If another fleet pass wants code, the remaining safe options are not in this table: pick a fresh active-claims/open-PR-checked lane and verify against current source first.

# 60-agent mission audit — morning-patch suggestions (2026-07-02)

Fleet `w2mcwe481`: 60-agent sweep of the Chernarus mission — **756 files, 59 audit agents, 367 raw issues**,
skeptically synthesized. **Headline caveat: ~40-50% of the raw "A2-OA syntax" flags are FALSE POSITIVES.**
Everything in TOP below was read directly or is a high-confidence pattern; verify data/classnames before shipping.

## Status refresh - live lane 2026-07-02

- **Live on `origin/claude/build84-cmdcon36@11736873a`:** #1 and #2 HQ killed-EH casing now send `_MHQ` in both maintained roots; #5 `RequestStructure` now exits on `_index < 0` before selecting the structure array.
- **Draft PRs open:** #4 US/USMC GER/BAF garrison classnames are routed through clean draft PR #176 (`fable/lane35-garrison-classnames`). Do not duplicate that branch.
- **PR #169 SHELVED:** `codex/gear-price-double-count` (gear price double-count fix) was shelved and is no longer open. See `wiki/Shelved-PR-*.md`. Do not reopen or duplicate.
- **Fresh false-positive verdicts:** follow-up fable verification closed #7, #8, and #9 as not-real: dynamic `publicVariable format [...]` is valid and matches the supply JIP pull chain; `isNil { ... }` is valid A2 OA syntax; `Init_Town.sqf` returns absolute damage math from the `handleDamage` EH.

## ⛔ REJECTED — false positives / already handled (do NOT patch)
- **"Inverted `alive _hq`"** (`Action_RepairMHQ.sqf:6`, `Action_RepairMHQDepot.sqf:8`) — correct: you repair a DEAD HQ.
- **"`getDammage` typo for `getDamage`"** — `getDammage`/`setDammage` (two m's) is the CORRECT A2-OA command; `getDamage` is A3. Reversed.
- **"Case-sensitive command bug"** (`getvariable`/`isnull`/`typeof`/`and` lowercase) — SQF command names are CASE-INSENSITIVE. Only variable names + string literals are case-sensitive.
- **"Double semicolon `;;` = parse error"** — `;;` is an empty statement, parses fine.
- **"A3 lazy-eval `&& {…}` parse errors"** (WASP/actions/*, server_heli_terrain_guard) — A2-OA DOES short-circuit `&& {code}`; these files ship live.
- **`Construction_SmallSite.sqf:99` `+` vs `-`** — already fixed (`-`, with a `wiki-wins` comment).
- **`AI_Commander_HCTopUp.DRAFT.sqf`** — header says not-wired/default-OFF/inert. Not patch scope.
- **Supply PVF `publicVariable format [...]` no-op claim** — false positive. `format` builds the dynamic variable name used by the matching `missionNamespace setVariable`, and the JIP pull path is intact (`Common_GetSideSupply` -> `REQUEST_SUPPLY_VALUE` -> `Server_PV_RequestSupplyValue` -> `SUPPLY_VALUE_REQUESTED` -> `Client_ReceiveSupplyValue`).
- **`isNil {code}` respawn-camp syntax claim** — false positive. The code-block form is valid in A2 OA; the separate `Private [...],;` parse issue is already fixed on the live lane.
- **`Init_Town.sqf` `handleDamage` return claim** — false positive. The handler returns the new absolute damage expression (`getDammage + hit/coef`), which is the expected `handleDamage` return contract.
> Skeptic's note: treat any un-verified "lowercase command" / "getDammage typo" raw item as noise.

## ✅ TOP confirmed / high-value items

**1. HQ killed-EH never wires on a repaired HQ — `_mhq` vs `_MHQ`** (CONFIRMED, LIVE DONE)
`Server/Functions/Server_MHQRepair.sqf:43` now sends `["set-hq-killed-eh", _MHQ]` in both maintained roots. Do not reopen unless new runtime evidence shows the repaired-HQ killed EH still fails.

**2. Same bug on the mobilized-HQ path** (CONFIRMED, LIVE DONE) — `Server/Construction/Construction_HQSite.sqf:104` now sends `_MHQ` in both maintained roots.

**3. Gear price counted twice** (CONFIRMED, PR #169 OPEN) — `Client/Functions/Client_UI_Gear_UpdatePrice.sqf:74-88`: a `for..do {…} forEach _gear_new` runs the whole block N extra times → inflated price. Routed through clean draft PR #169; smoke-test after that PR is folded.

**4. US garrison teams spawn German/British units** (CONFIRMED, PR #176 OPEN) — `Common/Config/Groups/Groups_US.sqf:118-121` (`GER_Soldier_MG_EP1`), `:134,139-141` (`BAF_Soldier_AT/AAT_DDPM`); same BAF pattern exists in `Groups_USMC.sqf`. Routed through clean draft PR #176, which swaps the GER/BAF infantry rows to role-matched US/USMC equivalents and regenerates the Takistan mirror.

**5. `RequestStructure` find→-1→picks LAST element** (CONFIRMED, LIVE DONE) — `Server/PVFunctions/RequestStructure.sqf:10-12` now computes `_index`, exits on `_index < 0`, then selects `_structures select _index` in both maintained roots.

**6. TKGUE patrol/air tiers near-empty** (needs data verify) — `Root_TKGUE.sqf:39-51` (PATROL tiers 1-2 entries), `Units_OA_TKGUE.sqf:70,82-87` (no Mi17/UH1H/Mi24 pool). GUER is live → repeated/missed patrols, no mech/air TKGUE. **Fix: mirror EAST/WEST tier structure with TK_GUE vehicles; balance-sensitive.**

**7. Supply PVF: `publicVariable(format[...])` no-op + maybe-disabled persist** (REJECTED) — follow-up trace verified `publicVariable format [...]` is the valid dynamic-name idiom here, `format` coerces SIDE consistently with the set/read variable names, and the commented `:43` line is the retired object-storage path rather than the active supply store.

**8. `isNil {code-block}` in respawn-camp filter** (REJECTED) — the code-block form is valid in A2 OA and is used broadly in the live codebase. The claimed `Private [...],;` trailing comma is already fixed.

**9. `handleDamage` return contract** (REJECTED) — `Common/Init/Init_Town.sqf:109` returns the absolute damage value after mitigation math, not a Boolean/truthy guard.

**10. ICBM / Build-Ammo gates reference tier level 5** (balance) — `Upgrades_CO_RU.sqf:104,109`, `Upgrades_CO_US.sqf:104,109` require `[WFBE_UP_AIR/GEAR,5]` where factories cap lower → possibly unreachable vs other factions. **Ray balance call; data-verify vs other factions.**

**11. Double starved-inf fallback** (known cleanup) — `AI_Commander_Teams.sqf` inert 2nd fallback (cmdcon33/PR#129 leftover). Delete; touch AICOM carefully.

## QUICK WINS (safe near-one-liners)
- `Server_MHQRepair.sqf:43` `_mhq`→`_MHQ` (#1 ✅ live) · `Construction_HQSite.sqf:104` `_mhq`→`_MHQ` (#2 ✅ live)
- `Client_UI_Gear_UpdatePrice.sqf:88` drop `forEach _gear_new` (#3 — PR #169 SHELVED; propose a new PR if re-taking)
- `Server/PVFunctions/RequestStructure.sqf:10-12` `_index < 0` guard (#5 ✅ live)
- `Core_MVD.sqf:50` log says `Core_RU`→`Core_MVD` · `Squads_GetFactionGroups.sqf:58` wrong file in error string
- `Groups_US.sqf` / `Groups_USMC.sqf` GER/BAF→US classnames (#4 routed via PR #176) · `Artillery_OA_TKA/TKGUE.sqf:14` de-dup illum ammo (verify alt class)
- Getter defaults `Common_GetTeamType/Autonomous/Respawn/MovePos.sqf:3` → `getVariable ["key", default]` (match Common_GetTeamMoveMode)

## NEEDS CARE (verify/balance before patch)
TKGUE arrays (#6) · tech-tree gates (#10) · security/anti-forge UID validation (`Server_ChangeSideSupply`/`RequestStructure`/`RequestDefense`
→ fold into the flag-gated `WFBE_C_SEC_HARDENING` lane, not a hotfix) · `Init_Towns.sqf:82,84` ellipse math
(`_posy` uses `select 0`, `_e = sqrt(_size^2-_size^2)=0` — verify consumed before fixing; may be dead).

> Recommended next order after this refresh: PR #169 is SHELVED; if re-taking #3, open a new branch. Wait for PR #176 to fold #4, then data-verify #6 as faction-roster/balance work and #10 as a balance-owner decision. Skip the whole REJECTED list.

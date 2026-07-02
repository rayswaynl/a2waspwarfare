# 60-agent mission audit — morning-patch suggestions (2026-07-02)

Fleet `w2mcwe481`: 60-agent sweep of the Chernarus mission — **756 files, 59 audit agents, 367 raw issues**,
skeptically synthesized. **Headline caveat: ~40-50% of the raw "A2-OA syntax" flags are FALSE POSITIVES.**
Everything in TOP below was read directly or is a high-confidence pattern; verify data/classnames before shipping.

## Status refresh - live lane 2026-07-02

- **Live on `origin/claude/build84-cmdcon36@b2dbab5f3` (lane-41 refresh):** #1 and #2 HQ killed-EH casing now send `_MHQ` in both maintained roots; #3 gear price double-count is fixed in the live lane via the lane-65 gear/loadout QA work; #4 US/USMC GER/BAF garrison infantry classnames are fixed by merged PR #176; #5 `RequestStructure` now exits on `_index < 0` before selecting the structure array; #6 TKGUE patrol/air depth is no longer near-empty after the cmdcon41/TKGUE diversity fills.
- **Stale draft references:** old PR #169 (`codex/gear-price-double-count`) is closed, but its fix is present on the live lane; PR #176 (`fable/lane35-garrison-classnames`) merged on 2026-07-02. Do not duplicate either branch.
- **Fresh false-positive verdicts:** follow-up fable verification closed #7, #8, and #9 as not-real: dynamic `publicVariable format [...]` is valid and matches the supply JIP pull chain; `isNil { ... }` is valid A2 OA syntax; `Init_Town.sqf` returns absolute damage math from the `handleDamage` EH.
- **Detailed lane-41 follow-up:** see `docs/design/B765-BACKLOG-TRIAGE-2026-07-02.md` for the current duplicate-guard table and extra B765 row checks.

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

**3. Gear price counted twice** (CONFIRMED, LIVE DONE) — `Client/Functions/Client_UI_Gear_UpdatePrice.sqf:74-88`: the stale trailing `forEach _gear_new` that repeated the container-addition pass has been removed in the live lane. PR #169 is closed, but the fix is present via the lane-65 gear/loadout QA work and documented in `GEAR-LOADOUT-SAVE-LOAD-QA-2026-07-02.md`.

**4. US garrison teams spawn German/British units** (CONFIRMED, LIVE DONE) — merged PR #176 (`fable/lane35-garrison-classnames`) swapped the cited GER/BAF infantry rows to role-matched US/USMC equivalents and regenerated the Takistan mirror. Current maintained roots have no `GER_Soldier*` or `BAF_Soldier*` entries in `Groups_US.sqf` / `Groups_USMC.sqf`.

**5. `RequestStructure` find→-1→picks LAST element** (CONFIRMED, LIVE DONE) — `Server/PVFunctions/RequestStructure.sqf:10-12` now computes `_index`, exits on `_index < 0`, then selects `_structures select _index` in both maintained roots.

**6. TKGUE patrol/air tiers near-empty** (CONFIRMED, LIVE DONE) — `Root_TKGUE.sqf` now has varied LIGHT/MEDIUM/HEAVY patrol pools using known-good TK_GUE infantry, technicals, armor, and AA; `Units_OA_TKGUE.sqf` now exposes `UH1H_TK_GUE_EP1`, An-2s, and PMC Ka-60 variants when PMC is enabled. `TK-DEEP-PARITY.md` also records TKGUE faction depth as fine. Do not reopen the old "near-empty" row without fresh runtime evidence.

**7. Supply PVF: `publicVariable(format[...])` no-op + maybe-disabled persist** (REJECTED) — follow-up trace verified `publicVariable format [...]` is the valid dynamic-name idiom here, `format` coerces SIDE consistently with the set/read variable names, and the commented `:43` line is the retired object-storage path rather than the active supply store.

**8. `isNil {code-block}` in respawn-camp filter** (REJECTED) — the code-block form is valid in A2 OA and is used broadly in the live codebase. The claimed `Private [...],;` trailing comma is already fixed.

**9. `handleDamage` return contract** (REJECTED) — `Common/Init/Init_Town.sqf:109` returns the absolute damage value after mitigation math, not a Boolean/truthy guard.

**10. ICBM / Build-Ammo gates reference tier level 5** (balance) — `Upgrades_CO_RU.sqf:104,109`, `Upgrades_CO_US.sqf:104,109` require `[WFBE_UP_AIR/GEAR,5]` where factories cap lower → possibly unreachable vs other factions. **Ray balance call; data-verify vs other factions.**

**11. Double starved-inf fallback** (known cleanup) — `AI_Commander_Teams.sqf` inert 2nd fallback (cmdcon33/PR#129 leftover). Delete; touch AICOM carefully.

## QUICK WINS (safe near-one-liners)
- `Server_MHQRepair.sqf:43` `_mhq`→`_MHQ` (#1 ✅ live) · `Construction_HQSite.sqf:104` `_mhq`→`_MHQ` (#2 ✅ live)
- `Client_UI_Gear_UpdatePrice.sqf:88` drop stale trailing `forEach _gear_new` (#3 live via lane-65 QA)
- `Server/PVFunctions/RequestStructure.sqf:10-12` `_index < 0` guard (#5 ✅ live)
- `Core_MVD.sqf:50` log says `Core_RU`→`Core_MVD` · `Squads_GetFactionGroups.sqf:58` wrong file in error string
- `Groups_US.sqf` / `Groups_USMC.sqf` GER/BAF→US classnames (#4 live via merged PR #176) · `Artillery_OA_TKA/TKGUE.sqf:14` de-dup illum ammo (verify alt class)
- Getter defaults `Common_GetTeamType/Autonomous/Respawn/MovePos.sqf:3` → `getVariable ["key", default]` (match Common_GetTeamMoveMode)

## NEEDS CARE (verify/balance before patch)
Tech-tree gates (#10) · security/anti-forge UID validation (`Server_ChangeSideSupply`/`RequestStructure`/`RequestDefense`
→ fold into the flag-gated `WFBE_C_SEC_HARDENING` lane, not a hotfix) · `Init_Towns.sqf:82,84` ellipse math
(`_posy` uses `select 0`, `_e = sqrt(_size^2-_size^2)=0` — verify consumed before fixing; may be dead).

> Recommended next order after this refresh: skip #3/#4/#6 as live-done, keep #10 as a balance-owner decision, and treat #11 as a dedicated AICOM cleanup only if runtime evidence or owner direction warrants touching the founding path. Skip the whole REJECTED list.

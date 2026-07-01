# 60-agent mission audit — morning-patch suggestions (2026-07-02)

Fleet `w2mcwe481`: 60-agent sweep of the Chernarus mission — **756 files, 59 audit agents, 367 raw issues**,
skeptically synthesized. **Headline caveat: ~40-50% of the raw "A2-OA syntax" flags are FALSE POSITIVES.**
Everything in TOP below was read directly or is a high-confidence pattern; verify data/classnames before shipping.

## ⛔ REJECTED — false positives / already handled (do NOT patch)
- **"Inverted `alive _hq`"** (`Action_RepairMHQ.sqf:6`, `Action_RepairMHQDepot.sqf:8`) — correct: you repair a DEAD HQ.
- **"`getDammage` typo for `getDamage`"** — `getDammage`/`setDammage` (two m's) is the CORRECT A2-OA command; `getDamage` is A3. Reversed.
- **"Case-sensitive command bug"** (`getvariable`/`isnull`/`typeof`/`and` lowercase) — SQF command names are CASE-INSENSITIVE. Only variable names + string literals are case-sensitive.
- **"Double semicolon `;;` = parse error"** — `;;` is an empty statement, parses fine.
- **"A3 lazy-eval `&& {…}` parse errors"** (WASP/actions/*, server_heli_terrain_guard) — A2-OA DOES short-circuit `&& {code}`; these files ship live.
- **`Construction_SmallSite.sqf:99` `+` vs `-`** — already fixed (`-`, with a `wiki-wins` comment).
- **`AI_Commander_HCTopUp.DRAFT.sqf`** — header says not-wired/default-OFF/inert. Not patch scope.
> Skeptic's note: treat any un-verified "lowercase command" / "getDammage typo" raw item as noise.

## ✅ TOP confirmed / high-value items

**1. HQ killed-EH never wires on a repaired HQ — `_mhq` vs `_MHQ`** (CONFIRMED)
`Server/Functions/Server_MHQRepair.sqf:43` sends `["set-hq-killed-eh", _mhq]` but the var is `_MHQ` (case-sensitive → nil). A repaired HQ won't fire the round-ender when destroyed. **Fix: `_mhq`→`_MHQ`.**

**2. Same bug on the mobilized-HQ path** (CONFIRMED) — `Server/Construction/Construction_HQSite.sqf:104` (declared `_MHQ` L78, sends `_mhq`). **Fix: `_mhq`→`_MHQ`.**

**3. Gear price counted twice** (CONFIRMED) — `Client/Functions/Client_UI_Gear_UpdatePrice.sqf:74-88`: a `for..do {…} forEach _gear_new` runs the whole block N extra times → inflated price. **Fix: delete the trailing `forEach _gear_new`; smoke-test the price display.**

**4. US garrison teams spawn German/British units** (CONFIRMED) — `Common/Config/Groups/Groups_US.sqf:118-121` (`GER_Soldier_MG_EP1`), `:134,139-141` (`BAF_Soldier_AT/AAT_DDPM`); same in `Groups_USMC.sqf`. Spawn fails if those DLCs absent + faction break. **Fix: swap to US equivalents — VERIFY each target classname exists in the loaded config.**

**5. `RequestStructure` find→-1→picks LAST element** (real, separate) — `Server/PVFunctions/RequestStructure.sqf:10`: `_i = names find type; select _i` with `_i=-1` selects the last. **Fix: `if (_i<0) exitWith {…}` guard.**

**6. TKGUE patrol/air tiers near-empty** (needs data verify) — `Root_TKGUE.sqf:39-51` (PATROL tiers 1-2 entries), `Units_OA_TKGUE.sqf:70,82-87` (no Mi17/UH1H/Mi24 pool). GUER is live → repeated/missed patrols, no mech/air TKGUE. **Fix: mirror EAST/WEST tier structure with TK_GUE vehicles; balance-sensitive.**

**7. Supply PVF: `publicVariable(format[...])` no-op + maybe-disabled persist** (verify — high impact) — `Server/Functions/Server_ChangeSideSupply.sqf:49` broadcasts a formatted string as if a var name (no-op in OA); `:43` persist `setVariable` may be commented → supply desync across JIP. **Read + fix; supply desync is high-impact.**

**8. `isNil {code-block}` in respawn-camp filter** (plausible, verify) — `Common/Functions/Common_GetRespawnCamps.sqf:40,67`: A2 `isNil` wants a STRING; the code-block form can bypass camp side filtering. Also a claimed `Private [...],;` trailing-comma (real parse error IF present). **Read to confirm; fix to `((_x getVariable ["sideID", objNull]) != objNull)`.**

**9. `handleDamage` return contract** (needs care) — `Common/Init/Init_Town.sqf:109` may return an always-truthy arithmetic expr instead of the damage → defeats camp-health mitigation. **Read + test; damage handlers break easily.**

**10. ICBM / Build-Ammo gates reference tier level 5** (balance) — `Upgrades_CO_RU.sqf:104,109`, `Upgrades_CO_US.sqf:104,109` require `[WFBE_UP_AIR/GEAR,5]` where factories cap lower → possibly unreachable vs other factions. **Ray balance call; data-verify vs other factions.**

**11. Double starved-inf fallback** (known cleanup) — `AI_Commander_Teams.sqf` inert 2nd fallback (cmdcon33/PR#129 leftover). Delete; touch AICOM carefully.

## QUICK WINS (safe near-one-liners)
- `Server_MHQRepair.sqf:43` `_mhq`→`_MHQ` (#1 ✅) · `Construction_HQSite.sqf:104` `_mhq`→`_MHQ` (#2 ✅)
- `Client_UI_Gear_UpdatePrice.sqf:88` drop `forEach _gear_new` (#3 ✅)
- `Core_MVD.sqf:50` log says `Core_RU`→`Core_MVD` · `Squads_GetFactionGroups.sqf:58` wrong file in error string
- `Groups_US.sqf` GER→US MG classnames (#4 ✅, verify class) · `Artillery_OA_TKA/TKGUE.sqf:14` de-dup illum ammo (verify alt class)
- Getter defaults `Common_GetTeamType/Autonomous/Respawn/MovePos.sqf:3` → `getVariable ["key", default]` (match Common_GetTeamMoveMode)

## NEEDS CARE (verify/balance before patch)
TKGUE arrays (#6) · supply PVF (#7) · respawn-camp isNil + Private comma (#8) · handleDamage (#9) ·
tech-tree gates (#10) · security/anti-forge UID validation (`Server_ChangeSideSupply`/`RequestStructure`/`RequestDefense`
→ fold into the flag-gated `WFBE_C_SEC_HARDENING` lane, not a hotfix) · `Init_Towns.sqf:82,84` ellipse math
(`_posy` uses `select 0`, `_e = sqrt(_size^2-_size^2)=0` — verify consumed before fixing; may be dead).

> Recommended morning order: land the 3 CONFIRMED quick wins (#1,#2,#3) + #5 guard first (each isolated, low-risk),
> then the data-verified faction fixes (#4,#6), then the verify-first items. Skip the whole REJECTED list.

# SCUD/Scout Investigation (V2 §8.4)

Date: 2026-07-07
Base checked: `origin/claude/build84-cmdcon36` @ `218f878a2fc38715cb768a0c367cbf3352a3c8b5` (fetched 2026-07-07)
Repo: `rayswaynl/a2waspwarfare`, worktree `C:\Users\Steff\a2wasp-ctl-build`
Scope: read-only recon (`git show origin/claude/build84-cmdcon36:<path>`, `git grep`). No mission SQF/SQM/config changed by this doc.

## Owner report (verbatim intent, voice)

> A vehicle "not drivable on Chernarus"; could not fire munitions from the Tactical Center after the first upgrade; wants it possibly in the artillery menu.

## TL;DR

- **Asset = SCUD, not "Scout."** There is no "Scout" vehicle anywhere near this system. The only "Scout"-named asset in the whole Chernarus mission is the unrelated `AH6X_EP1` **AH-6X Scout** unarmed FLIR Little Bird (US air factory, `Core_US.sqf:228`, `Units_CO_US.sqf:265`) — a helicopter with zero connection to the Tactical Center munition list or the "first upgrade" gate the owner described. "Scud" and "Scout" are one syllable apart in speech; the voice note almost certainly got mis-transcribed. All evidence below points at the SCUD/TEL system.
- **Two SCUD-shaped things exist, and the owner's two complaints map to two different ones, both confirmed in code:**
  1. **"Not drivable on Chernarus"** → the *purchasable/crewed* SCUD launcher (`MAZ_543_SCUD_TK_EP1` bought from the Heavy Factory) is **intentionally restricted to `worldName == "Takistan"`** in five places. It is never offered for purchase on Chernarus, so there is nothing to drive. This is documented, deliberate design (see `Init_CommonConstants.sqf:1107`), not a bug — but it means the owner's expectation ("I should be able to buy and drive a SCUD here like on Takistan") is currently false on Chernarus by design.
  2. **"Could not fire munitions from Tactical Center after first upgrade"** → this **is a genuine bug**, and it is **not Chernarus-specific** — it reproduces on every map, for every side, at every research level. The client-side enable-check for all 5 conventional TEL munitions (SATURATION/RECON/FASCAM/STEELRAIN/BUSTER) reads two `missionNamespace` variables that the server only ever writes locally (missing the `true` broadcast flag on setVariable), so they never reach any client and the rows stay permanently disabled regardless of research level, on every map.
- **Artillery-menu integration**: today SCUD/TEL fire lives exclusively inside the Tactical Center's flat action list (`GUI_Menu_Tactical.sqf`), not the separate, mechanically distinct "Artillery" panel (owned tube-artillery tracking/ranging via `GetTeamArtillery`). The old war-room Artillery-adjacent SCUD buttons were deliberately removed in the same feature pass that built the current system. Folding SCUD into the Artillery panel is a real, actionable UX option but is architecturally a different list (owned-unit range tracker vs. flat paid-action list) — see recommendation 3.

---

## 1. Exact asset identified

| Name in code | Classname | Where defined | Role |
|---|---|---|---|
| "Land ICBM TEL" / "SCUD TEL" | `MAZ_543_SCUD_TK_EP1` | `Init_CommonConstants.sqf:1111` (`WFBE_C_TK_SCUD_HF_TYPE`); auto-spawned via `Server/Init/Init_IcbmTel.sqf:89` | Free, auto-spawned once per side at SCUD research L1. **Empty + `setVehicleLock "LOCKED"`, never crewed** (`Init_IcbmTel.sqf:88-98`, explicit comment "Do NOT crew it"). Destroyable counterplay target, not a player-driven vehicle by design, on any map. |
| "Producible SCUD" / "SCUD Launcher (conventional)" | `MAZ_543_SCUD_TK_EP1` (same classname, different lifecycle) | Buy-row: `Common/Config/Core/Core_TKA.sqf:158-161`; registration: `Server/Init/Init_IcbmTel.sqf:180-227` (`WFBE_SE_FNC_TkScudRegister`) | Bought at the Heavy Factory like any other vehicle — spawned crewed/enterable, driver seat included, normal purchase mechanics. **This is the only SCUD variant a player can actually drive.** |
| "Carrier SCUD" | (payload only, no drivable hull) | `Server/Support/Support_ScudStrike.sqf`; menu entry `SCUD_Carrier` in `GUI_Menu_Tactical.sqf:96-100` | Unrelated third system: capturing a Naval HVT carrier (Chernarus-only feature, `Init_NavalHVT.sqf`) unlocks a map-click saturation strike. No drivable hull at all. |
| "AH-6X Scout" | `AH6X_EP1` | `Core_US.sqf:228`, `Units_CO_US.sqf:265` | Unarmed FLIR Little Bird, US Aircraft Factory. **Confirmed unrelated** — no code path connects it to Tactical Center munitions or SCUD research. |

Confirmed by direct read of `origin/claude/build84-cmdcon36:Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_IcbmTel.sqf:89`:
```sqf
_tel = createVehicle ["MAZ_543_SCUD_TK_EP1", [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
```
and `Core_TKA.sqf:158-160` for the buy-row registration of the identical classname as a purchasable unit.

---

## 2. "Not drivable on Chernarus" — root cause

**Root cause: intentional `worldName == "Takistan"` gate on the only crewable SCUD variant. Not a bug in the sense of broken logic — it is a scope restriction, confirmed in five independent places, all consistent:**

1. `Common/Config/Core/Core_TKA.sqf:158` — the buy-row itself is never appended to the TKA faction's purchasable-unit arrays unless `worldName == "Takistan"`:
   ```sqf
   if ((missionNamespace getVariable ["WFBE_C_TK_SCUD_HF", 1]) > 0 && {worldName == "Takistan"}) then {
       _c = _c + [missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_TYPE", "MAZ_543_SCUD_TK_EP1"]];
       _i = _i + [['SCUD Launcher (conventional)', ...]];
   };
   ```
   On Chernarus this `if` is false, so the SCUD **never appears in the factory buy list at all** — there is nothing to purchase, hence nothing to drive.
2. `Client/Functions/Client_BuildUnit.sqf:804` — even if a SCUD hull somehow existed client-side, the platform-registration/fire-action wiring is itself gated `{worldName == "Takistan"}`.
3. `Client/GUI/GUI_Menu_BuyUnits.sqf:146` — the pre-purchase live-cap check (which also implicitly gates the purchase flow) is `{worldName == "Takistan"}`.
4. `Server/Init/Init_IcbmTel.sqf:189` (`WFBE_SE_FNC_TkScudRegister`) — server-authoritative belt-and-braces: `if (worldName != "Takistan") exitWith {false};`. Even a manually spawned/admin-placed SCUD could never register as a fireable platform off Takistan.
5. `Common/Init/Init_CommonConstants.sqf:1107` — the constant's own comment states the design intent plainly:
   ```sqf
   if (isNil "WFBE_C_TK_SCUD_HF") then {WFBE_C_TK_SCUD_HF = 1}; //--- master: producible SCUD at HF on Takistan (all behaviour also worldName-gated to "Takistan").
   ```

The **only** SCUD-shaped object that can legitimately exist on Chernarus is the free, auto-spawned research TEL (`Init_IcbmTel.sqf:59-153`), and that one is deliberately `setVehicleLock "LOCKED"` + never crewed, on **every** map, by design (side-safety: an empty vehicle reads as side CIVILIAN so it doesn't paint a hostile blip on friendly HUDs — `Init_IcbmTel.sqf:9-10` comment). So on Chernarus a player who goes looking for "the SCUD" will either find nothing purchasable, or find the locked TEL and correctly conclude it's "not drivable" — both outcomes match the owner's report exactly, and both are the current, intended behavior of the code as written.

**This is a design/scope question for the owner, not a code defect**: the SCUD purchase feature was built and labelled "Takistan" throughout (comments, buy-row text "SCUD Launcher (conventional)", cmdcon42-j changelog entries). If the intent is for Chernarus to also field a drivable/purchasable SCUD, that requires a deliberate scope decision + new work (see Recommendation 1), not a one-line fix.

---

## 3. Munition-unlock root cause (confirmed bug)

**Root cause: the client-side "is a launch platform alive" check reads `missionNamespace` variables that the server only ever sets locally (missing the `true` global-broadcast argument on `setVariable`), so those variables never replicate to any client. The Tactical Center's 5 conventional TEL munition rows are consequently disabled forever, on every map, at every research level — independent of the Chernarus/Takistan question above.**

### The gate that fails

`Client/GUI/GUI_Menu_Tactical.sqf:184-213`, `WFBE_CL_FNC_TelMuniEnable` — shared enable predicate for all 5 conventional TEL rows (`TEL_Saturation`, `TEL_Recon`, `TEL_Fascam`, `TEL_SteelRain`, `TEL_Buster`, wired at lines 354-358):

```sqf
_telObj = missionNamespace getVariable [format ["WFBE_ICBM_TEL_%1", str sideJoined], objNull];   -- line 197
_telAlive = (!isNull _telObj && {alive _telObj});
_platformAlive = _telAlive;
if (!_platformAlive && {...WFBE_C_TK_SCUD_HF...} && {worldName == "Takistan"}) then {
    _scuds = missionNamespace getVariable [format ["WFBE_TK_SCUD_PLATFORMS_%1", str sideJoined], []];   -- line 205
    { if (!isNull _x && {alive _x}) exitWith {_platformAlive = true} } forEach _scuds;
};
...
if (_lvl >= 1 && _cmd && _platformAlive && _fnd >= _fee) then {true} else {false}
```

Both `WFBE_ICBM_TEL_<side>` and `WFBE_TK_SCUD_PLATFORMS_<side>` are **client-local reads of `missionNamespace`** — on a client that never received a broadcast, `missionNamespace getVariable [...]` silently returns the supplied default (`objNull` / `[]`), so `_platformAlive` is always `false` unless something on that specific client set the variable itself.

### Where those variables are actually written (server only, never public)

`Server/Init/Init_IcbmTel.sqf`, all confirmed missing the third `setVariable` argument (`true`) that makes a value globally replicate to every client:

| Line | Code | Variable |
|---|---|---|
| 105 | `missionNamespace setVariable [_key, _tel];` | `WFBE_ICBM_TEL_<side>` — set on spawn |
| 121 | `missionNamespace setVariable [Format ["WFBE_ICBM_TEL_%1", _dSideText], objNull];` | same, cleared on TEL death |
| 173 | `missionNamespace setVariable [_key, _live];` | `WFBE_TK_SCUD_PLATFORMS_<side>` — compaction write in `WFBE_SE_FNC_TkScudPlatforms` |
| 209 | `missionNamespace setVariable [_key, _arr];` | same, on a fresh bought-SCUD registration in `WFBE_SE_FNC_TkScudRegister` |
| 221 | `missionNamespace setVariable [_dKey, _dLive];` | same, on bought-SCUD death |

None of these five calls carries the `true` broadcast flag. `missionNamespace setVariable [name, value]` (2-arg form) is **local to the machine that runs it** — here, always the server. A2-OA has no implicit replication for `missionNamespace` variables; only `setVariable [name, value, true]` (3-arg, on a networked object) or explicit `publicVariable`/side-scoped custom sends propagate a value to clients.

The one client-side touchpoint that *does* reach the owning side — `Client/PVFunctions/HandleSpecial.sqf`, case `"icbm-tel-marker"` (~line 148-165), delivered via the side-scoped `WFBE_CO_FNC_SendToClients` call at `Init_IcbmTel.sqf:148` — receives the TEL object reference (`_args select 0`) and uses it only to draw a local map marker (`createMarkerLocal`). **It never does `missionNamespace setVariable ["WFBE_ICBM_TEL_<side>", _tel]` on the client.** That is the missing link: the payload carrying the live TEL reference to the client already exists and already fires at the right time (every spawn/respawn), but nothing stores it into the variable `WFBE_CL_FNC_TelMuniEnable` later reads. Same story for the bought-SCUD registry: there is no equivalent client-side broadcast/store at all for `WFBE_TK_SCUD_PLATFORMS_<side>`, despite the code's own comment at `GUI_Menu_BuyUnits.sqf:145` calling it "the server-broadcast platform array" — the broadcast half was never implemented.

### Why this exactly matches the owner's report

- The NUKE row (`case "ICBM"`, `GUI_Menu_Tactical.sqf:341-350`) has an **independent** enable check that does *not* depend on `_telAlive` client-side — only `_currentLevel >= 2 && _commander && _funds >= _currentFee` — so at SCUD research **L2** the NUKE button correctly shows enabled (and the server re-validates platform-alive at fire time, `Init_IcbmTel.sqf:350-360`).
- But the 5 **conventional** rows (the only things unlocked at the "first upgrade," L1 — see `GUI_Menu_Tactical.sqf:354-358` and the design comment "L1 deploys the conventional land TEL platform, while L2 unlocks the classic nuclear shot") are gated by the broken `_platformAlive` check and are **permanently disabled** no matter what level the side has researched, on any map.
- A disabled Tactical Center list entry cannot be selected/fired client-side, so the "RequestSpecial"/"icbm-tel-fire" send to the server (`Server_HandleSpecial.sqf:155` → `WFBE_SE_FNC_IcbmTelFire`) never happens — the owner never even reaches the server-side refusal messages; the row is simply inert. That is precisely "could not fire munitions from Tactical Center after first upgrade."

---

## 4. Artillery-menu integration — current state and options

There is a real, separate "Artillery" feature in the Tactical Center today (`GUI_Menu_Tactical.sqf`, flag `WFBE_C_ARTILLERY`): a listbox (idc `17008`) of the side's *owned, crewed* tube-artillery pieces, built from `GetTeamArtillery`, with live range/in-range status (`_maxRange`/`_distance` around lines 998-1099), ammo-type loading, and a minimap toggle. This is mechanically a **unit tracker**, not a flat paid-action list.

SCUD/TEL fire, by contrast, lives in the flat special-action listbox built at `GUI_Menu_Tactical.sqf:78-100` (`_addToList`/`_addToListID`/`_addToListFee` arrays: `"SCUD: SATURATION"`, `"SCUD: RECON FLASH"`, `"SCUD: FASCAM (mines)"`, `"SCUD: STEEL RAIN (anti-inf)"`, `"SCUD: BUNKER BUSTER (point)"`, `"SCUD STRIKE (carrier)"`) alongside Fast Travel, Paratroopers, UAV, FPV strike, etc. This is exactly where the old war-room Artillery-adjacent SCUD buttons used to live before they were deliberately consolidated here — see `Client/GUI/GUI_Menu_Command.sqf:92-93` and `:508-509`:
```
//--- cmdcon41-w3i (Ray 2026-07-02) UI CONSOLIDATION: the SCUD (14631) + TEL SATURATE/RECON (14632/14633) war-room buttons
//--- were REMOVED — all SCUD/TEL fire now lives in the Tactical menu (GUI_Menu_Tactical.sqf) beside the classic ICBM/NUKE.
```

So "put it in the artillery menu" is a legitimate but non-trivial UX ask: SCUD is not an owned/crewed tube the range-tracker list can represent as-is (no player-crewed hull to range-check against on the TEL path; the range check today is platform-to-target, computed server-side per munition). Two realistic paths, for the owner to pick between — this doc does not choose one:

- **(a) Cosmetic regroup only**: keep the flat-list mechanics, but visually separate the SCUD/TEL rows under their own header/section inside the same Tactical Center dialog (distinct from Fast Travel/UAV/FPV), so it *reads* like an artillery sub-panel without touching `GetTeamArtillery` plumbing. Lowest risk, addresses the "why is my strategic weapon buried in a grab-bag list" complaint.
- **(b) True Artillery-panel integration**: extend the `17008` artillery listbox to also enumerate the side's TEL/bought-SCUD platforms (using `[_side] Call WFBE_SE_FNC_TkScudAllPlatforms`, `Init_IcbmTel.sqf:231-240`, already exists server-side) with their own range/cooldown columns, and route "fire" through the existing `icbm-tel-fire` RequestSpecial. Bigger lift: the artillery list's range math and ammo-loading UI are shaped around player-crewed guns, and SCUD is fire-and-forget from an unmanned platform, so several UI assumptions would need reconciling.

Either option is orthogonal to the section-3 bug fix — moving disabled buttons to a new location does not re-enable them.

---

## 5. Recommended fixes (file:line — investigation only, not applied)

### 5.1 Munition-unlock bug (do this regardless of the Chernarus scope decision)

Add the missing client-side store so `WFBE_CL_FNC_TelMuniEnable` can ever see a live platform:

- **`Client/PVFunctions/HandleSpecial.sqf`, case `"icbm-tel-marker"` (~line 148-165)** — immediately after `if (isNull _tel) exitWith {};`, add:
  ```sqf
  missionNamespace setVariable [Format ["WFBE_ICBM_TEL_%1", _sideText], _tel];
  ```
  and in the existing death-watch `[_tel, _mkr] spawn {...}` block (waits for `isNull _t || {!alive _t}`), also clear it:
  ```sqf
  missionNamespace setVariable [Format ["WFBE_ICBM_TEL_%1", _sideText], objNull];
  ```
  (pass `_sideText` into the spawn's argument list alongside `_tel`/`_mkr`, since it is currently not captured there).

  This mirrors the codebase's own established pattern of side-scoped delivery via `WFBE_CO_FNC_SendToClients` rather than a raw public `setVariable [..., true]` broadcast (which would leak the live TEL's object reference to enemy clients' `missionNamespace` — the marker itself is already correctly friendly-only per the code comment at `Init_IcbmTel.sqf:146`). Using the existing side-scoped case to also populate the variable keeps that invariant.

- **Bought-SCUD platform registry** (`WFBE_TK_SCUD_PLATFORMS_<side>`, Takistan-only today per §2) — needs the equivalent: either add a new side-scoped `HandleSpecial` case fired alongside `Init_IcbmTel.sqf:200`/`:224` registration events, or piggyback on the existing `"tk-scud-register"` acknowledgment path (`Server_HandleSpecial.sqf`) to push the compacted array back to the owning side's clients. Server writes to fix in lockstep with the client store: `Init_IcbmTel.sqf:173`, `:209`, `:221` (all currently 2-arg `setVariable`, local-only).

- Cross-check the AI-commander read path (`Server_AI/Commander/AI_Commander.sqf:1035-1036`) is unaffected — it reads the TEL object server-side, not through the broadcast variable, so it is already correct and should not be touched by this fix.

### 5.2 Chernarus SCUD availability (owner decision required — not a defect to silently "fix")

If the owner wants a drivable/purchasable SCUD on Chernarus: the change is to relax the `worldName == "Takistan"` condition at the five sites in §2 (items 1-4) to also permit `worldName == "Chernarus"` (or replace with a config array of enabled worlds), plus decide the buy-row cost/tier/faction on Chernarus (today's row is filed under the TKA faction block in `Core_TKA.sqf`, which may or may not be the faction the owner wants fielding SCUDs on Chernarus). This is new scope, not a bug fix, and should be scoped as its own V2 ticket rather than bundled with 5.1.

### 5.3 Artillery-menu integration (owner decision required)

Pick (a) cosmetic regroup or (b) true panel integration per §4, then scope separately. Neither should be attempted until 5.1 is fixed, since a correctly-labelled but still-disabled SCUD row does not resolve the owner's core complaint.

---

## Evidence index

All citations verified against `origin/claude/build84-cmdcon36` (commit `218f878a`) via `git show <ref>:<path>` / `git grep` from `C:\Users\Steff\a2wasp-ctl-build`:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_IcbmTel.sqf` — full TEL/SCUD server logic (spawn, fire, cooldown, platform registry). Lines cited: 8-10, 59-153, 89, 96, 98, 105, 120-121, 163-227, 231-240, 269-360.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_Tactical.sqf` — Tactical Center menu build + enable gates. Lines cited: 78-100, 184-213, 341-358, 364-372.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_BuyUnits.sqf` — purchase-time SCUD cap check. Lines cited: 143-156.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_BuildUnit.sqf` — post-spawn SCUD platform tagging + fire-mission action. Lines cited: 798-858.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/PVFunctions/HandleSpecial.sqf` — client-side SCUD/TEL presentation cases. Lines cited: 87-118, 123-165.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_Command.sqf` — UI-consolidation comments (war-room buttons removed). Lines cited: 92-93, 508-509, 543-544.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core/Core_TKA.sqf` — Takistan-only buy-row registration. Lines cited: 154-161.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core/Core_US.sqf`, `Common/Config/Core_Units/Units_CO_US.sqf` — AH-6X "Scout" (confirmed unrelated). Lines cited: `Core_US.sqf:228`, `Units_CO_US.sqf:265`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf` — SCUD/TEL flag defaults + design-intent comments. Lines cited: 1074-1075, 1107, 1109-1111.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_HandleSpecial.sqf` — `"icbm-tel-fire"` / `"ScudStrike"` server routing. Lines cited: 91, 152-155.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf` — AI-side TEL read (unaffected by the bug). Lines cited: 1035-1036.
- Prior doc `docs/design/SCUD-WARHEAD-CLASSNAME-SMOKE.md` (2026-07-02) — independently confirms `WFBE_C_TK_SCUD_HF_TYPE = "MAZ_543_SCUD_TK_EP1"` and the general SCUD/TEL constant map; consistent with all findings above.

## Open questions for the owner

1. Should Chernarus (and/or Zargabad) get a purchasable/drivable SCUD, or is Takistan-exclusivity intentional and permanent? (§2, §5.2)
2. For the artillery-menu ask: cosmetic regroup inside the existing Tactical Center list, or true integration into the owned-artillery tracker panel? (§4, §5.3)
3. Confirm whether the owner tested on Takistan and found conventional TEL munitions *working* there — if so, that would be surprising given §3's finding that the bug is world-independent, and would be worth a follow-up repro to make sure no other broadcast path was missed.

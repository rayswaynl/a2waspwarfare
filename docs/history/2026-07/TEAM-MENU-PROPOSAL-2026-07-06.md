# Team Menu Repurpose — Proposal

**Task Packet:** TP-11
**Author:** Agent B (Designer, Fable tier)
**Date:** 2026-07-06
**Status:** Design-only. READ-ONLY. Owner decides before any build.

---

## 1. Research Findings

### 1.1 Current RscMenu_Team inventory (idd 13000)

Source: `Rsc/Dialogs.hpp:1361` + `Client/GUI/GUI_Menu_Team.sqf:1-224`

| idc | Widget type | Current function | Handler |
|-----|-------------|-----------------|---------|
| 13001 | RscText_Title | Header: "Team Menu" | — |
| 13002 | RscText | View Distance readout | live update in loop |
| 13003 | RscXSliderH | View Distance slider | saves via WFBE_CO_FNC_SetProfileVariable |
| 13004 | RscText | Terrain Grid readout | live update in loop |
| 13005 | RscXSliderH | Terrain Grid slider | saves via WFBE_CO_FNC_SetProfileVariable |
| 13006 | RscText | Money Transfer amount readout | live update in loop |
| 13007 | RscXSliderH | Transfer amount slider | range = [0, playerFunds] |
| 13008 | RscCombo | Target team selector | populated on open |
| 13009 | RscButton | "Transfer" button | MenuAction = 1 |
| 13010 | RscText_SubTitle | Income / funds readout | 2s refresh |
| 13011 | RscText_SubTitle | "Disband" section header | — |
| 13012 | RscText_SubTitle | "Money Transfer" section header | — |
| 13013 | RscCombo | AI unit selector for disband | own group live units |
| 13014 | RscButton | "Disband" button | MenuAction = 3 |
| 13015 | RscText | "Graphic Filter" label | — |
| 13018 | RscCombo | FX selector (None / FX 1-5) | MenuAction = 6, calls FX |
| 13019 | RscButton | Toggle vote popup | MenuAction = 13 |
| 13020 | RscButton | Toggle high climbing default | MenuAction = 14 |
| 13101 | RscText_SubTitle | "Video Options" section header | — |
| 13109 | RscButton_Main | "Transfer (Adv)" shortcut | MenuAction = 101 |

**Already-duplicate items (removable):**
- 13002/13003 (VD slider) — Settings dialog handles this
- 13004/13005 (TG slider) — Settings dialog handles this
- 13006/13007/13008/13009/13012 (inline transfer) — Economy/Advanced Transfer covers this
- 13109 (Adv Transfer button) — also removable with inline transfer gone

**Items with standalone value (keep):**
- 13013/13014 (Disband AI unit) — unique; no other menu hosts it
- 13018 (FX selector) — cosmetic preference, low friction
- 13019 (Vote popup toggle) — niche but unique
- 13020 (High climbing toggle) — profile-persistent; unique
- 13010 (Income readout) — useful ambient info

### 1.2 Existing request / command paths

Standard send-to-server pattern (from Client/ scan):

```sqf
["RequestSpecial", ["<verb>", <args>...]] Call WFBE_CO_FNC_SendToServer;
// Reaches Server/Functions/Server_HandleSpecial.sqf switch block.
```

Named PVFs (Init_PublicVariables.sqf:9-34) use:

```sqf
["RequestAIComDonate", [player, clientTeam, _amount]] Call WFBE_CO_FNC_SendToServer;
// Dispatched via Server/Functions/Server_HandlePVF.sqf → Server/PVFunctions/RequestAIComDonate.sqf
```

Existing aicom advisory paths (all in Server_HandleSpecial.sqf):

| Verb | Who can send | Effect |
|------|-------------|--------|
| aicom-posture | Any player (AI-holds-command gate) | Sets wfbe_aicom_player_posture + _t0; biases _engageMin in Allocate.sqf:57-61 |
| aicom-fieldorder | Any player (AI-holds-command gate) | Sets wfbe_aicom_player_fieldorder + _t0; controls fist/harass/concentrate levers |
| aicom-focus | Any player (AI-holds-command gate) | Sets wfbe_aicom_focus + _t0; M4 fist override in Allocate.sqf:116-119, TTL 600s |
| aicom-support | Any player (always) | Per-player cooldown 180s, UID-keyed on side logic; dispatches nearest free AI team |

Per-player cooldown pattern (Server_HandleSpecial.sqf:739-790):

```sqf
_spUID = getPlayerUID _spPlayer;
_spKey = "wfbe_cmd_nudge_" + _spUID;
_spLast = _spLogik getVariable [_spKey, -1e9];  // A2: plain getVariable + isNil; 2-arg form NOT used on groups
if ((_spNow - _spLast) >= _spCd) then {
    // act
    _spLogik setVariable [_spKey, _spNow, false];  // false = NOT broadcast (server-local)
};
```

PVF registration (Common/Init/Init_PublicVariables.sqf:9-34): new named PVFs require name added to _serverCommandPV and handler file in Server/PVFunctions/. HandleSpecial additions need only a new case in Server_HandleSpecial.sqf.

### 1.3 War-room-task telemetry emitter

Source: Server/AI/Commander/AI_Commander_Execute.sqf:68

```
diag_log ("AICOM2|v1|ORDER|war-room-task|" + str _side + "|" + str (round (time / 60)) + "|mode=" + _modeL + "|goto=" + str [...]);
```

This fires when Execute.sqf issues a newly-changed direct order to a team. It is pure server-side telemetry; there is no existing "player requests a war-room task" path. The Command Console (commander only) issues `aicom-posture`/`aicom-focus`/`aicom-fieldorder`, which the Allocator consumes on its own tick, which in turn produces war-room-task log lines via Execute.sqf. A player advisory from the Team menu would feed the same chain.

### 1.4 V2 Allocator advisory hook points

Source: Server/AI/Commander/AI_Commander_Allocate.sqf:25-199

Two live hook variables a new request can write:

1. `wfbe_aicom_focus` (town object) + `wfbe_aicom_focus_t0` — M4 fist override. The existing `aicom-focus` verb already writes these. No new server variable needed.

2. `wfbe_aicom_player_posture` (string: PUSH/HOLD) + `_t0` — M6 bias. The existing `aicom-posture` verb already writes these.

Variable contract for any new town-suggestion advisory:

```sqf
logik setVariable ["wfbe_aicom_focus",    _townObject, false];
logik setVariable ["wfbe_aicom_focus_t0", time,        false];
```

TTL consumed by the Allocator: WFBE_C_AICOM2_FOCUS_TTL (default 600s). A "request take town" nudge writes the same two variables, subject to AI-holds-command gate and per-player cooldown. The human commander's aicom-focus from the Command Console already does exactly this; the Team menu version is a lower-friction surface for non-commanders.

### 1.5 Hidden-intel constraints (all verified)

- aicom-focus sends a town OBJECT, not coordinates or unit positions
- aicom-support sends the player's OWN position to server only; never broadcast to enemy clients
- aicom-posture/aicom-fieldorder send strings (PUSH/HOLD/SPLIT etc.); no positional data
- Client_HandlePVF.sqf:27 side-scoping gate prevents cross-side delivery of all HandleSpecial sends
- Town combo population: MUST use the static `towns` array (already visible to all players on the map), NOT any AI-computed priority variable (wfbe_aicom_targets, wfbe_aicom_focus) — reading those would leak what the AI is already planning

---

## 2. Design Options

### Option A — "Coordination Strip" (RECOMMENDED)

**Concept:** The Team menu becomes a personal coordination panel. Players declare their intent for this life, send one AI advisory nudge per cooldown window, and request nearby AI support. No map reading required. The menu stays focused on the player's own situation, not the global strategy.

**Player story:**

> Vasquez opens the Team menu. He sees his current income and his AI units. He picks "Attacking" from a role list and selects a target town from a combo populated with capturable towns (no enemy intel — these are towns on the visible map). He hits "Suggest" and the server receives his intent as an aicom-focus advisory. He also hits "Request Support" and the nearest free AI team road-marches to him. He disbands his dead scout. Three button presses. Closed.

**Widget list (all in idd 13050 — new dialog class RscMenu_TeamV2, see Flag Plan):**

| idc | Type | Purpose | Notes |
|-----|------|---------|-------|
| 13051 | RscText_Title | "Coordination" header | New title |
| 13010* | RscText_SubTitle | Income / funds readout (2s refresh) | Keep logic, new position |
| 13060 | RscText_SubTitle | "Your Role" section header | New label |
| 13061 | RscCombo | Role selector: Infantry / Vehicle / Pilot / Support / Recon | New |
| 13062 | RscButton | "Declare Role" (side-wide hint broadcast) | MenuAction = 20 |
| 13063 | RscText_SubTitle | "AI Advisory" section header | New label |
| 13064 | RscCombo | Capture suggestion town picker | New; see intel note |
| 13065 | RscButton | "Suggest Capture Target" (aicom-focus) | MenuAction = 21 |
| 13066 | RscButton | "Request AI Support" (aicom-support) | MenuAction = 22 |
| 13067 | RscText_SubTitle | "Your AI Units" section header | New label |
| 13068 | RscCombo | AI unit selector | Mirrors 13013 |
| 13069 | RscButton | "Disband" button | Mirrors 13014 |
| 13070 | RscCombo | FX selector | Mirrors 13018 |
| 13071 | RscButton | Vote popup toggle | Mirrors 13019 |
| 13072 | RscButton | High climbing toggle | Mirrors 13020 |

*idc 13010 is RscText_SubTitle on a fixed position; it can be re-declared in the new dialog without conflict if the old dialog is not simultaneously open.

**Server paths:**

| Action | Path | New code needed |
|--------|------|----------------|
| Declare Role | `["RequestSpecial", ["player-role-intent", sideJoined, player, _roleStr]]` | ~20-line case in Server_HandleSpecial.sqf; broadcasts LocalizeMessage to own side only |
| Suggest Capture Target | `["RequestSpecial", ["aicom-focus", sideJoined, _townObj]]` | Reuses existing aicom-focus case verbatim PLUS add ~15-line per-player cooldown to that case (currently missing) |
| Request AI Support | `["RequestSpecial", ["aicom-support", sideJoined, player, getPos player]]` | Reuses existing aicom-support case verbatim; cooldown already present |

**AI commander consumption:**

aicom-focus → writes wfbe_aicom_focus + wfbe_aicom_focus_t0 on side logic → consumed by AI_Commander_Allocate.sqf:116-119 as M4 fist (highest precedence, overrides M5 support-push and AUTO). TTL 600s. A human commander's focus (same variable) wins on last-write; the per-player cooldown on the server side prevents rapid overwrite from the Team menu.

aicom-support → no Allocator hook; existing direct team dispatch. Unchanged.

player-role-intent → no Allocator hook; ephemeral side-wide hint. No missionNamespace state written.

**Anti-abuse:**

- aicom-focus (new): add server UID-keyed cooldown (WFBE_C_CMD_NUDGE_COOLDOWN or a new WFBE_C_TEAM_FOCUS_COOLDOWN constant, suggested 120s) using the wfbe_cmd_nudge_<uid> pattern. This gap MUST be fixed before ship.
- aicom-support: existing 180s per-player cooldown. Protected.
- player-role-intent: add 60s per-player rate limit (same pattern). Prevents hint spam.
- All gates: alive _player, side (group _player) == _spSide, server-authoritative. Allowlist for roleStr on the server side (never trust the string from the client without a set-membership check).

**What is removed vs what stays:**

| Control | Decision | Reason |
|---------|----------|--------|
| VD slider (13002/13003) | REMOVE | Duplicates Settings dialog |
| TG slider (13004/13005) | REMOVE | Duplicates Settings dialog |
| Inline transfer (13006-13009, 13012, 13109) | REMOVE | Duplicates Economy/Advanced Transfer |
| Disband (13013/13014) | KEEP (re-implemented as 13068/13069) | Unique; no other home |
| FX selector (13018) | KEEP (re-implemented as 13070) | Lightweight preferences |
| Vote popup toggle (13019) | KEEP (as 13071) | Unique |
| High climbing toggle (13020) | KEEP (as 13072) | Profile-persistent, unique |
| Income readout (13010) | KEEP | Good ambient info |

**Hidden-intel check:** PASS. Role declaration is own-side only. Capture suggestion sends a town object from the already-visible `towns` array. AI Support sends own position to server only. No enemy positions revealed. Town combo populated from static `towns` filtered by non-owned status — not from AI-computed priority lists (wfbe_aicom_targets, wfbe_aicom_focus).

**Build cost: MEDIUM**

- Dialogs.hpp: new RscMenu_TeamV2 class (~80 lines); old RscMenu_Team left intact for flag-off
- GUI_Menu_Team.sqf: new handler file or conditional branch for V2 (~120 lines)
- Server_HandleSpecial.sqf: player-role-intent case (~20 lines) + aicom-focus per-player cooldown fix (~15 lines)
- GUI_Menu.sqf (or equivalent): gate which dialog opens on flag value
- String table: 5-7 new STR_ entries
- No new PVF files required

**Flag plan:** `WFBE_C_TEAM_MENU_V2` default 0. Parent menu opens `RscMenu_TeamV2` (idd 13050) when flag > 0, else `RscMenu_Team` (idd 13000). Flag-off is byte-identical to HEAD. The new dialog class is compiled at all times but never instantiated at flag=0.

---

### Option B — "Intent Board" (Heavier variant)

**Concept:** Extends Option A with a side-wide visible intent board — a right-panel listbox showing what each friendly player has declared as role and suggested town. Players see at a glance whether the team is coordinated or fragmented.

**Delta from Option A:** Add a RscListBox (half dialog width) listing "[role] PlayerName → TownName" entries refreshed from a server-broadcast side-scoped array `WFBE_C_TEAM_INTENT_<sideID>`. Server writes this on each role/suggestion declaration and broadcasts to own side via WFBE_CO_FNC_SendToClients.

**Build cost: LARGE** — adds server-side intent array management, a broadcast cadence, and listbox refresh in the GUI loop. Not recommended for first ship.

---

### Option C — "Preferences + Support Only" (Minimal variant)

**Concept:** Remove duplicates, keep the keepers, add only one "Request AI Support" button. Skip role declaration and capture suggestion entirely.

**Build cost: SMALL** — dialog cleanup + one new button. Safe first ship if the owner wants to validate the space before committing to advisory features.

**Trade-off:** Loses the Allocator advisory hook (the highest-value design goal). Useful as a v0 if the owner is uncertain about the nudge system.

---

## 3. Recommendation

**Ship Option A.** Rationale:

1. **Delivers the owner's stated goals directly.** Player coordination, nudge system, and AI advisory are all present. Every server path calls already-tested machinery (aicom-focus, aicom-support). Nothing invented from scratch.

2. **Build is bounded.** No new PVF files. No new Allocator variables. The one genuinely new server code is the player-role-intent case (~20 lines) and the aicom-focus per-player cooldown gap fix (~15 lines). The rest is dialog cleanup and GUI SQF.

3. **Advisory, never command.** The capture suggestion goes through aicom-focus, which the Allocator gates behind AI-holds-command and TTL. A human commander's decisions always supersede it. Players feel heard; the AI is never puppeted.

4. **Intel-safe by design**, provided the town combo is populated from the static `towns` array and not from any AI-computed priority variable. This gate must be in the implementation checklist.

5. **Clean flag story.** The two-dialog approach (new RscMenu_TeamV2, parent menu gates which opens) means flag-off is zero-diff to HEAD. The old dialog remains untouched.

---

## 4. Open Unknowns

1. **aicom-focus per-player cooldown gap (BLOCKER before ship):** The current aicom-focus server case has no per-player rate limit — only a client-side _lastSend guard in GUI_Menu_Command.sqf. A Team menu sender bypasses that guard. A server-side UID-keyed cooldown must be added. What value should WFBE_C_TEAM_FOCUS_COOLDOWN default to? (Suggestion: 120s.)

2. **Town combo population source:** The town list for "Suggest Capture Target" should be populated from the client-side `towns` array filtered by "not owned by my side." Owner should confirm this UX is acceptable (players see all non-owned towns, not the AI's computed priority order).

3. **Role intent persistence:** Should the declared role survive death/respawn? If yes, server needs to write it to profileNamespace. Currently proposed as ephemeral (per-life only, no server state).

4. **WF_A2_Vanilla compatibility:** The player-role-intent broadcast uses WFBE_CO_FNC_SendToClients with a side destination. This pattern is used throughout the codebase, but vanilla mode has subtle PV differences. Confirm in vanilla before ship.

5. **Dialog layout pixel-fit:** The new control layout in the 0.625w × 0.599h panel was not verified against actual pixel measurements. A layout pass in-engine is needed before the PR is opened.

---

## 5. Self-Grade

| Criterion | Max | Score | Notes |
|-----------|-----|-------|-------|
| Design quality | 30 | 24 | Options are genuinely differentiated; Option A reuses existing machinery cleanly; the two-dialog flag approach is solid. Lost 6: the role-intent feature is thin gameplay-wise; the board (Option B) is the stronger coordination tool but deferred on cost. |
| Buildability on A2 dialogs | 25 | 19 | Two-dialog approach sidesteps the HPP conditional-compilation trap correctly. Town combo source is identified. Lost 6: the aicom-focus cooldown gap is a real build risk that must be fixed before ship; dialog layout is unverified in-engine. |
| Evidence quality | 20 | 18 | Every claim cites file:line. Allocator hook points traced from source. PVF registration flow verified. aicom-focus cooldown gap found by reading the server case directly. Lost 2: WF_A2_Vanilla PV branch not verified in detail. |
| Intel-safety | 15 | 13 | Town combo gate (static towns array, not AI priority vars) is clearly called out. Lost 2: the gate is flagged but not resolved — a future implementer who forgets it causes a subtle leak. |
| Clarity | 10 | 9 | Widget tables, server path tables, and variable contracts are specific and actionable. Lost 1: the new dialog should have had a concrete idc range reservation spelled out explicitly. |
| **Total** | **100** | **83** | |

**Grade: 83/100**
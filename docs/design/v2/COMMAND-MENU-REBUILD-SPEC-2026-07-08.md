# Command Menu (War Room) Rebuild Spec

<!-- GUIDE-REV: GR-2026-07-03a; base: origin/claude/build84-cmdcon36@218f878a2fc38715cb768a0c367cbf3352a3c8b5 -->

Docs-only spec. No code changes. Scope: `Client/GUI/GUI_Menu_Command.sqf` (`WF_Menu` `MenuAction == 5`)
and its dialog, `RscMenu_Command` in `Rsc/Dialogs.hpp`. This is the player↔AI-commander console — the
in-mission name is "COMMAND" (STATE A) / "WAR ROOM" (STATE B); the source calls it the Command Console.
All paths below are `Missions/[55-2hc]warfarev2_073v48co.chernarus/` unless noted; the same controller
runs on the Takistan/Zargabad mirrors via LoadoutManager.

## Scope And Source Snapshot

| Item | Value |
| --- | --- |
| Target branch/base | `origin/claude/build84-cmdcon36@218f878a2` |
| Guide revision | `GR-2026-07-03a` |
| Controller | `Client/GUI/GUI_Menu_Command.sqf` (776 lines) |
| Dialog class | `RscMenu_Command`, `Rsc/Dialogs.hpp:2474-3014` (idd 14000) |
| Entry point | `WF_Menu` `MenuAction == 5` → `Client/GUI/GUI_Menu.sqf:199-203` → `closeDialog 0; createDialog "RscMenu_Command"` |
| Live flags read | `WFBE_C_CMD_MENU_V2` (default **1**, `Init_CommonConstants.sqf:1004`), `WFBE_C_AICOM_PLAYER_ARTY` (default 0), `WFBE_C_AI_COMMANDER_LOCK` (default 0) |

## 1. What The Menu Is FOR — Wiki Cross-Check

Two wiki pages describe this menu, and they disagree because one is stale:

- **`AICOM-Command-Verbs-Reference.md`** (source-verified 2026-07-02 against this same
  `origin/claude/build84-cmdcon36` base) is **current and accurate**. It correctly documents `RALLY` /
  `REFIT` / `HOLD` as the three steering-verb sends (MenuAction 727/728/729 below) and the
  posture-vs-waypoint distinction. Trust this page for AICOM-verb semantics.
- **`Client-UI-Systems-Atlas.md § "Command Menu Interaction Model"`** is **stale**. It describes an
  older icon-tab, multi-select-teams, "Objective Ping"/`SetTask` era of this menu (three icon
  tabs/modes, `Dialogs.hpp:2100-2123`, `GUI_Menu_Command.sqf:111-170`) that predates the 2026-06-28
  "production rework" (STATE A / STATE B two-state controller) documented in the current file's own
  header comment (`GUI_Menu_Command.sqf:3-34`). None of the icon-tab/multi-select/Objective-Ping
  behavior it describes exists in the current controller. **Any rebuild PR should also file a wiki
  fix** replacing that section with a description of the current two-state model — do not use it as a
  design input.
- **`Player-UI-Workflow-Map.md:53`** is accurate and narrow: it correctly notes the map-click capture
  (arm → click → `SetTeamMovePos`/`SetTeamMoveMode` → marker feedback) is local to this controller and
  distinct from the spawned-unit follow-up helper.

**What the menu is actually FOR (grounded in the current source, not the stale wiki page):** it is the
single console where a player either (a) *advises* the still-autonomous AI commander without taking
its seat, or (b) *becomes* the commander and drives AI-led teams directly while the AI keeps founding/
refilling them as a quartermaster. The header comment in the .sqf (lines 3-34) is the best up-to-date
design statement that exists for this feature; this spec treats it as authoritative alongside the
source below.

## 2. Full Control Inventory

### STATE A — NOT commander ("COMMAND" title, advisory console)

Shown when `commanderTeam != group player`. Visible control set = `_adviseCtrls`
(`GUI_Menu_Command.sqf:101-102`) + `14670`.

| idc | Dialog class @ line | Control | MenuAction / wire | Gate |
| --- | --- | --- | --- | --- |
| 14605 | `CA_Cmd_IntentTitle` :2572 | Title text ("AI COMMANDER" static; retitled "COMMAND"/"WAR ROOM" at runtime) | n/a | always |
| 14600 | `CA_Cmd_Intent` :2579 | Explainer body (seat-empty / locked / human-commands-already copy) | n/a | always |
| 14670 | `CA_Cmd_Claim` :2597 | **TAKE COMMAND** button | `MenuAction=750` → `RequestClaimCommander` server call | shown only if seat empty & not locked |
| 14606 | `CA_Cmd_IntentTitleA` :2613 | "Live AI intent" sub-title | n/a | shown in STATE A |
| 14607 | `CA_Cmd_IntentA` :2620 | Live AI-INTENT readout: reads `WFBE_AICOM_INTENT_<sid>` / `OBJNAME_<sid>` / `ACTIVE_<sid>` / `FOCUS_NAME_<sid>` broadcast vars | n/a (read-only) | shown in STATE A |
| 14608 | `CA_Cmd_PostureTitle` :2628 | "Posture" sub-title | n/a | shown in STATE A |
| 14609 | `CA_Cmd_PosturePush` :2635 | **PUSH** button | `MenuAction=760` → `RequestSpecial ["aicom-posture", side, "PUSH", player]` | `_postureBites` = AI runs the side (seat empty or lock on) |
| 14612 | `CA_Cmd_PostureHold` :2648 | **HOLD** button | `MenuAction=761` → `RequestSpecial ["aicom-posture", side, "HOLD", player]` | same as 14609 |
| 14613 | `CA_Cmd_NudgeSplit` :2661 | **SPLIT UP** | `MenuAction=762` → `aicom-fieldorder` `"SPLIT"` | same |
| 14614 | `CA_Cmd_NudgeMass` :2673 | **PUSH TOGETHER** | `MenuAction=763` → `aicom-fieldorder` `"MASS"` | same |
| 14615 | `CA_Cmd_NudgeHarass` :2685 | **HARASS** | `MenuAction=764` → `aicom-fieldorder` `"HARASS"` | same |
| 14616 | `CA_Cmd_NudgeFallback` :2697 | **FALL BACK** | `MenuAction=765` → `aicom-fieldorder` `"FALLBACK"` | same |
| 14617 | `CA_Cmd_Focus` :2715 | **AI: FOCUS TOWN (click map)** | `MenuAction=766` arms; next map click resolves nearest town → `aicom-focus` | same; server-side cooldown `WFBE_C_TEAM_FOCUS_COOLDOWN=120` mirrored client-side |
| 14618 | `CA_Cmd_ReqSupport` :2732 | **REQUEST AI SUPPORT (to me)** | `MenuAction=767` → `RequestSpecial ["aicom-support", side, player, getPos player]` | gated on `WFBE_C_CMD_MENU_V2>0` only — **works even under a human commander** (the one STATE-A control that is NOT gated on `_postureBites`) |
| 14650 | `CA_Cmd_Help` :2958 | Bottom status/hint line | n/a | shared with STATE B |

Also live in STATE A: `MenuAction == 4` (Back → `WF_Menu`) and the always-on Back/Exit buttons
(unlabeled idc, `Rsc/Dialogs.hpp` end of class).

### STATE B — commander ("WAR ROOM" title)

Shown when `commanderTeam == group player`. Visible control set = `_warCtrls`
(`GUI_Menu_Command.sqf:90-91`).

| idc | Dialog class @ line | Control | MenuAction / wire | Gate |
| --- | --- | --- | --- | --- |
| 14605 | shared :2572 | Title (retitled "WAR ROOM") | n/a | — |
| 14600 | shared :2579 | Economy header: funds/supply/income/towns-held | n/a (read-only, `GetTeamFunds`/`wfbe_supply_<sid>`/`GetIncome`/`GetTownsHeld`) | — |
| 14660 | `CA_Cmd_RosterTitle` :2746 | "Roster" sub-title | n/a | war-room |
| 14661 | `CA_Cmd_Roster` :2754 | Roster listbox: one row per AI-led team, `TYPE \| Target \| Alive/Total [ \| verb ]` | selection read via `lbCurSel`; `onLBDblClick → MenuAction=726` (VIEW TEAM → opens `RscMenu_UnitCamera` on the leader) | war-room |
| 14620 | `CA_Cmd_Move` :2778 | **Move** (arm) | `MenuAction=720` arms `"move"`; next map click → `SetTeamMovePos`+`SetTeamMoveMode`+pin | war-room |
| 14621 | `CA_Cmd_Defend` :2793 | **Defend** (arm) | `MenuAction=721` arms `"defense"` | war-room |
| 14622 | `CA_Cmd_Patrol` :2804 | **Patrol** (arm) | `MenuAction=722` arms `"patrol"` | war-room |
| 14624 | `CA_Cmd_Release` :2815 | **Release** | `MenuAction=724` → `SetTeamMoveMode "towns"` + `SetTeamAutonomous true` + clear manual pin | war-room; needs `_selTeam` |
| 14623 | `CA_Cmd_Arty` :2826 | **Artillery** (arm) | `MenuAction=723` arms `"arty"`; next map click → `RequestSpecial ["aicom-arty-here", ...]` | needs `WFBE_C_AICOM_PLAYER_ARTY>0` |
| 14625 | `CA_Cmd_AICmd` :2842 | Squad-command mode toggle (text = current mode) | `MenuAction=730` → `RequestSpecial ["aicom-ai-command", side, "ON"/"OFF"]` (delegate maneuver to AI vs direct) | war-room |
| 14610 | `CA_Cmd_Push` :2863 | **ALL PUSH** | `MenuAction=710` → bulk `SetTeamMoveMode "towns"` + autonomous + clear pin, every team | war-room, `_directCool` gate |
| 14611 | `CA_Cmd_Hold` :2874 | **ALL HOLD** | `MenuAction=711` → bulk road-snapped `SetTeamMovePos`+`"defense"`+pin, every team | war-room, `_directCool` gate |
| 14642 | `CA_Cmd_ReqLabel` :2883 | "Build priority:" caption | n/a | war-room |
| 14640 | `CA_Cmd_ReqCombo` :2893 | Request-Unit type combo (Infantry/Armor/Air) | selection read on 14641 press | war-room |
| 14641 | `CA_Cmd_ReqBtn` :2901 | **Build** button | `MenuAction=740` → `RequestSpecial ["aicom-request-unit", side, type]` | war-room |
| 14628 | `CA_Cmd_Rally` :2917 | **RALLY** (selected team) | `MenuAction=727` → `RequestSpecial ["aicom-rally", side, teamIdx]` | `WFBE_C_CMD_MENU_V2>0`, needs `_selTeam` |
| 14629 | `CA_Cmd_Refit` :2929 | **REFIT** (selected team) | `MenuAction=728` → `RequestSpecial ["aicom-refit", side, teamIdx]` | same |
| 14630 | `CA_Cmd_HoldTown` :2940 | **HOLD** (selected team) | `MenuAction=729` → `RequestSpecial ["aicom-hold", side, teamIdx]` | same |
| 14626 | `CA_Cmd_Disband` :2971 | **DISBAND AI TEAMS** (all, 2-click confirm) | `MenuAction=745` → `RequestSpecial ["aicom-team-disband", side]` | commander-only; server ~15-min cooldown |
| 14627 | `CA_Cmd_DisbandSel` :2989 | **DISBAND SELECTED** (2-click confirm) | `MenuAction=746` → `RequestSpecial ["aicom-team-disband", side, teamIdx]` | commander-only; needs `_selTeam` |
| 14650 | shared :2958 | Bottom status/hint (cooldown / armed-order readout) | n/a | shared |
| — | `WF_MiniMap` idc 14002 | Embedded map, the order-designation surface for every "arm → click" order | `onMouseMoving`/`onMouseButtonUp` write shared globals `mouseX`/`mouseY`/`mouseButtonUp` | both states |

**Removed since the last wiki-documented pass (cmdcon41-w3i, 2026-07-02):** the SCUD-carrier button
(was idc 14631, `MenuAction=770`) and the two TEL munition buttons (were 14632/14633, `MenuAction=
771/772`) were deleted from this console; that fire path now lives entirely in
`GUI_Menu_Tactical.sqf`. **idc 14631/14632/14633 and MenuAction 770/771/772 are free** — do not reuse
without checking `Client/GUI/GUI_Menu_Tactical.sqf` doesn't also claim them.

### Shared / cross-cutting mechanics worth naming in a rebuild

- **Two independent cooldowns**, not one: `_lastSend`/`_cool` (`WFBE_C_AICOM_ORDER_COOLDOWN`=8s) gates
  every `RequestSpecial` brain-send (posture, field-order, focus, arty, request-unit, ai-command,
  rally/refit/hold, disband); `_lastDirect`/`_directCool` (`WFBE_C_AICOM_DIRECT_COOLDOWN`=1.5s) gates
  the pure-local group-setVariable orders (Move/Defend/Patrol/Release/ALL-PUSH/ALL-HOLD). RALLY/REFIT/
  HOLD stamp *both* clocks even though they are brain-sends, because they act on a single selected team
  and are meant to feel responsive.
- **Manual-pin TTL** (`WFBE_C_AICOM_MANUALPIN_TTL`=600s): every direct team order stamps
  `wfbe_aicom_manualpin` so `AssignTowns` won't re-grab the team; RELEASE and ALL-PUSH clear it.
- **Enemy-base intel clamp** (`GUI_Menu_Command.sqf:365-372`): the roster's Target column renders a
  server/HC-published *display* clamp (`wfbe_teamgoto_disp`) instead of the true destination when that
  destination is inside an enemy base, so the roster never leaks a hidden base's coordinates while still
  showing the player their team is "advancing." **Any new roster/telemetry surface in the rebuild must
  reuse this same clamp, never the raw `wfbe_teamgoto`.**
- **STATE gate itself is a UX seam**: `_stateNow` flips the *entire* control set via `ctrlShow`, with a
  hard `diag_log` probe on every transition (`GUI_Menu_Command.sqf:142`). Any visual rework that adds a
  third visual mode (see §3) must decide whether it is a third `ctrlShow` set or a sub-state of B —
  recommend the latter (see §3).

## 3. Visual Rework Proposal

Constraints: A2-OA IDD dialogs, no A3 controls, existing `WFBE_Background_Color_Sub` panel idiom
already used for 3 sub-panels (header/roster/orders, `Dialogs.hpp` `controlsBackground` block). Keep
the embedded minimap at its current geometry (`14002`, right 53%) — it is load-bearing for every
map-click order across both states and touched by nothing else in this rebuild.

1. **Un-flatten the STATE-B order-button grid.** Right now Move/Defend/Patrol/Release/Arty/AI-Cmd sit
   in one 2-column, 3-row grid (y 0.660–0.804) with no visual grouping cue beyond color. Split into two
   *labeled* sub-panels using the existing `WFBE_Background_Color_Sub` idiom the header/roster panels
   already use: **"MANEUVER"** (Move/Defend/Patrol/Release, the four map-click orders) and **"SUPPORT"**
   (Artillery, AI-Cmd toggle, and the new steering-verb row RALLY/REFIT/HOLD folded up from the current
   detached row at y=0.872). This turns four visually-identical rows into two purpose-grouped clusters
   and removes the current dead gap between the order grid (ends 0.804) and the steering-verb row
   (starts 0.872) that currently has nothing in it but the separator + bulk/build row.
2. **Promote the roster to a real status table, not a delimiter-joined string row.** `CA_Cmd_Roster`
   (14661) is a single-column `RscListBox` where each row is a manually `" | "`-joined string
   (`GUI_Menu_Command.sqf:415/417`). A2-OA supports `RscListNBox` (multi-column list box, used
   elsewhere in this mission — see `GUI_VoteMenu.sqf`'s `lnb*` calls) which would let TYPE / TARGET /
   ALIVE / VERB render as aligned columns instead of a manually-padded string, and would let a future
   pass color a column (e.g. red ALIVE ratio under 50%) without re-building the whole label string.
   This is a bigger lift than the rest of the visual pass — flag it as **phase 2**, not required to ship
   the rest of this rebuild.
3. **STATE-A gets the same panel treatment STATE-B already has.** STATE-B has 3 `WFBE_Background_Color_Sub`
   backer panels; STATE-A currently renders its intent readout, posture row, field-order grid, focus
   button, and support-request button on bare background with no grouping. Add 2 backer panels mirroring
   the STATE-B pattern: **"AI INTENT"** (14606/14607) and **"STEER THE AI"** (14608 through 14618). This
   is a pure `controlsBackground` addition — zero controller logic changes, zero MenuAction changes.
4. **Fix the color-coding blind spot for colorblind players.** Every order button is color-coded
   (blue=move, green=defend, orange=patrol, grey=release, red=arty) with no icon or letter cue — the
   existing `RscButton_Main`-derived buttons already carry a `text` field, so this is a text-prefix fix,
   not a new control: e.g. `text = "[M] MOVE"` instead of `text = $STR_WF_CMD_Move`. Cheap, and it also
   makes the marker-color legend (which currently exists only as a code comment,
   `GUI_Menu_Command.sqf:336-341` "Order-button color-coding: match the map marker") legible to the
   player instead of tribal knowledge.
5. **Bottom status line (14650) is currently the only feedback surface for both cooldown state AND
   armed-order state, and it silently overwrites whichever fired last.** Widen it to two lines (it
   already reserves h=0.040, only using one visual line of that budget) so an armed order
   ("MOVE armed - click the map") and an active cooldown ("Orders ready in 4s") can co-exist instead of
   racing each other, matching what `GUI_Menu_Command.sqf:748-767` already computes but currently
   crams into one line.
6. **Do NOT touch:** the minimap geometry, the STATE gate mechanism, the Back/Exit button positions
   (owner convention, shared across every WF menu), or the header/footer color bands
   (`Background_M`/`_H`/`_F`, shared WFBE theme constants).

## 4. Functional Additions / Removals

All additions below are grounded in **existing server-side primitives already wired to this console**
(no new server handler required) unless explicitly marked "new server handler needed." All read-only
additions reuse the enemy-base intel clamp (§2) — nothing here exposes a raw coordinate the current
roster doesn't already clamp.

### Additions — reuse existing primitives (low lift)

1. **STATE-A field-order/posture "current setting" readout.** The intent panel already renders
   `_posture` inline in the AI-intent text (`GUI_Menu_Command.sqf:187-189`) but only for the session's
   *last-sent* nudge, and it is silently overwritten by the field-order nudges (both write the same
   `_posture` local var, `:216` vs `:223`). Split into two independent last-sent trackers (posture vs.
   field-order) so a player who sent HARASS doesn't lose visibility the moment they also nudge PUSH.
   Zero server change — purely a client-local bookkeeping split.
2. **STATE-B: show the manual-pin TTL countdown per roster row.** The roster already resolves
   `wfbe_aicom_manualpin` indirectly (via `_hg`/`_rg`/`_sg`/`_mg` verb resolution,
   `GUI_Menu_Command.sqf:400-412`) but never surfaces *when* a manual order expires and the team reverts
   to AI control. Reading `wfbe_aicom_manualpin` directly (already broadcast, `:577`/`:601`/`:616`) and
   showing `(auto in Ns)` in the verb column when a pin is active tells the commander which teams are
   about to slip back to autonomous — currently invisible.
3. **Confirmation echo for RALLY/REFIT/HOLD parity with the older order set.** Move/Defend/Patrol/Arty
   all get map-drop marker feedback (`MarkerAnim` calls, e.g. `:538`, `:578`); RALLY/REFIT/HOLD
   (`:734-737`) only get a `hintSilent` text line, no map marker, despite acting on a specific team with
   a resolvable position (`getPos (leader _selTeam)`). Add the same `TempAnim`/`MarkerAnim` spawn used
   elsewhere so all seven order types have consistent map feedback.
4. **STATE-A: surface `WFBE_C_AI_COMMANDER_LOCK` server config, not just the locked message.** Already
   partially done (`_msg` branches on `_lockOn`, `:154-156`) — extend the same branch to also show the
   posture/field-order/focus panel in a visibly disabled (greyed, not hidden) state when locked, instead
   of the current behavior where the whole "STEER THE AI" cluster still renders active-looking buttons
   whose `ctrlEnable` is false but whose color/text give no visual "why is this disabled" cue. Ties into
   visual item 4 (icon/text cue) — same fix serves both.

### Additions — "someday" ideas already scoped by the owner (do NOT build now)

The wiki's `Shelved-AICOM-Concepts.md` (owner-shelved 2026-07-03, explicitly **not rejected**, "someday"
list) names two concepts that live directly in this console's territory:

- **#1 Chief-of-Staff mode** — "Human commander seated → AICOM becomes staff: runs rear garrisons/
  logistics, radios recommendations, accepts sector delegation." The wiki entry itself notes "Team modes
  + command menu... all exist" as feasibility grounding — i.e. this rebuild's roster/steering-verb
  plumbing is exactly the substrate that idea would sit on. **Not in scope for this pass**; flagging so
  a future revival doesn't have to re-derive that the console is ready for it.
- **#7 Commander cam** — "Spectator/admin overlay drawing the brain's live intent." Same note: "Intent
  vars... exist; marker/overlay tech trivial." The STATE-A intent readout (14607) already sources the
  exact vars this would consume. **Not in scope.**

Both require explicit owner revival per the wiki's house rule; this spec does not propose building
either. Listed here only so the visual/wiring choices above (readout split, panel grouping) don't
foreclose them.

### Explicitly NOT proposed (owner-rejected, do not re-open)

- **Any always-on (unflagged) AI-team listbox / spectate surface.** `Shelved-PR-531-unit-camera-ai-
  teams.md` records the owner declining this **twice** (once at PR #383, again at #531) — both times
  specifically about a *read-only AI-team roster/camera row*. This console already has a read-only
  AI-team roster (14661) for the commander only; do not propose extending equivalent read visibility to
  non-commander players or to the separate unit-camera dialog. If a future spec revisits this, it must
  come with a default-0 flag from the start (the #531 shelf's stated reason for rejection was partly
  "always-on with no flag," partly the standing "no" from #383).
- **TPWCAS, AI supply trucks, satchel AI, EMP/WP/DECOY SCUD munitions, doctrine personalities, antistack
  touch, ACR content** — none of these intersect the Command Menu directly, listed only for completeness
  against the owner's standing do-not-re-propose list (`CLAUDE.md`).

### Removals / consolidation

- **None of the current 33 controls are dead** — every idc in §2 has a live `ctrlShow`/`MenuAction`
  wire-up and a server-side or local consumer. This console was already through one consolidation pass
  (cmdcon41-w3i removed the SCUD/TEL buttons 2026-07-02); there is no further dead weight to cut.
- **Consolidation candidate, not a removal:** ALL PUSH (14610) and Release (14624) both terminate in
  `SetTeamMoveMode "towns"` + `SetTeamAutonomous true` — the only difference is scope (all teams vs.
  selected team) and that Release also explicitly clears the manual pin while ALL PUSH clears it in the
  loop. Recommend leaving both (different scope is a real UX distinction, "release this one" vs "let
  everyone go") but noting the shared code path so a rebuild doesn't accidentally diverge their
  semantics — the pin-clear step is what has to stay identical, not the button.

## 5. Wiring Cleanup

1. **Dead MenuAction IDs to reclaim explicitly in a rebuild PR body:** 770/771/772 (SCUD/TEL, removed
   2026-07-02, superseded by `GUI_Menu_Tactical.sqf`). Confirm `GUI_Menu_Tactical.sqf` doesn't already
   use 770-772 before reassigning — grep the whole mission tree for `MenuAction == 77` / `MenuAction =
   77` before picking new IDs for any new controls in a rebuild, this project's convention is manual
   MenuAction numbering with no central registry.
2. **`_posture` local variable is overloaded** (§4.1) — it's both the display cache for the posture nudge
   AND the field-order nudge, and both handlers null it via `_lastIntent = ""` to force a repaint. A
   rebuild should split this into `_lastPosture` / `_lastFieldOrder` to remove the overwrite bug, not
   just to improve the readout (functional §4.1 and wiring here are the same fix, listed twice
   deliberately — one is the symptom, one is the code smell).
3. **Two different "resolve selected team's server-matching index" blocks are duplicated verbatim**
   between DISBAND SELECTED (`:678-684`) and RALLY/REFIT/HOLD (`:721-727`) — both walk
   `WFBE_Client_Logic getVariable "wfbe_teams"` and `forEach` to find `_forEachIndex` matching
   `_selTeam`. A rebuild should factor this into a local helper (or a `Common_*` function if it's
   useful outside this controller) rather than a third copy when the next steering verb is added.
4. **STATE transition log line is a debug leftover, not instrumentation** — `diag_log (format
   ["CMDCON-DBG state=...` (`:142`) fires on every state flip with a hardcoded `CMDCON-DBG` tag that
   doesn't match this project's `WFBE_CO_FNC_LogContent`/`WF_LOG_CONTENT` gating convention documented
   in `CLAUDE.md` ("Debug lines... gated by the WF_LOG_CONTENT define"). Recommend either removing it
   (the STATE gate has been stable since the 2026-06-29 root-cause fix its comment describes) or
   converting it to the standard gated helper — not both a code-smell AND missing the project's own
   logging convention.
5. **Event-flow note, not a bug:** the STATE gate re-evaluates and re-applies `ctrlShow`/`ctrlEnable` to
   every control **every single loop iteration** (both the `_warCtrls`/`_adviseCtrls` `forEach` and the
   four `ctrlEnable` calls at `:136-139`), not just on the `_stateNow != _lastState` edge. This is
   almost certainly intentional defensive coding (the 2026-06-29 fix comment at `:120-126` explains a
   prior bug where display-scoped `ctrlShow` silently no-op'd), but it means every visual addition in
   §3 that needs a `ctrlShow` toggle must be added to the per-loop block, not just the edge-triggered
   block, or it will inherit the old bug class. Call this out explicitly in the rebuild PR's review
   checklist.

## 6. Rebuild Recommendation Summary

Ship as **one flag-gated PR**, default OFF, per the project's flag policy (`CLAUDE.md` "Feature
additions: flag-gate... default 0. With the flag at 0 the mission must be byte-identical to HEAD."):
new constant e.g. `WFBE_C_CMD_MENU_V3` in `Common/Init/Init_CommonConstants.sqf`, following the exact
pattern `WFBE_C_CMD_MENU_V2` already establishes (registered once, never changing an existing default).

Phasing:

- **Phase 1 (visual + wiring, this rebuild's core):** §3 items 1/3/4/5/6, §5 items 2/3/4/5. No new
  MenuAction IDs, no new server sends — pure layout/grouping/readability + code-quality pass on the
  existing 33 controls.
- **Phase 2 (functional, same PR if small):** §4 additions 1-4. All reuse existing broadcast vars and
  existing `RequestSpecial` verbs; the only "new" wiring is client-local (split trackers, extra
  `MarkerAnim` calls, extra `ctrlEnable` cue).
- **Phase 3 (deferred, needs its own spec + owner sign-off):** §3 item 2 (`RscListNBox` roster) — larger
  lift, touches the roster's row-building loop (`:340-423`) and its selection-by-identity logic
  (`:425-442`), worth its own smoke-test pass rather than folding into this rebuild.
- **Out of scope entirely:** the two owner-shelved "someday" concepts (§4) and the twice-rejected
  unit-camera AI-team listbox (§4) — noted for context only, not proposed.
- **Companion action, not code:** file a wiki correction PR for `Client-UI-Systems-Atlas.md`'s stale
  "Command Menu Interaction Model" section (§1) so the next person doing this kind of read doesn't start
  from the wrong mental model again.

## 7. Files A Build PR Would Touch

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_Command.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp` (`RscMenu_Command` class only)
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf` (new flag)
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/stringtable.xml` (new/changed `STR_WF_CMD_*` keys —
  note the button-text icon-cue change in §3.4 touches existing keys, does not add new ones)
- Mirror propagation to Takistan/Zargabad via `Tools/LoadoutManager` (`dotnet run -c RELEASE`) per
  `CLAUDE.md`; `mission.sqm` is not touched by this menu so no per-map manual edit is expected beyond
  the standard template-drift restore.
- Companion (separate PR, docs-only): wiki page `Client-UI-Systems-Atlas.md`.

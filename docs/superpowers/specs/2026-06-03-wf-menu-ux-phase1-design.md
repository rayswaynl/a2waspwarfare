# WF Menu UX Overhaul — Phase 1: Foundation Polish + Hub Redesign

- **Date:** 2026-06-03
- **Branch / worktree:** `feat/wf-menu-ux-phase1` @ `C:\Users\Steff\a2waspwarfare-uxphase1` (off `origin/master` 2cdf5fb8)
- **Status:** Approved design, pending spec review
- **Part of:** a 4-phase UX overhaul (P1 foundation+hub · P2 consistency sweep+fixes · P3 SafeZone responsiveness · P4 heavy-dialog flows). This spec is **Phase 1 only.**
- **Companion index:** `C:\Users\Steff\wasp-wf-menu-ui-index.md`

## 1. Goal

Make the Warfare menu a much nicer UI/UX **while keeping the original WFBE visual style** (sky-blue
accent `#42b6ff`, black panels, gold/bone text, Zeppelin32). Phase 1 delivers the two highest-leverage,
lowest-risk wins: safe template-level polish that lifts every dialog, and a reorganized, responsive
main hub.

## 2. Constraints (hard)

1. **Original style preserved.** No palette change, no font change, no brand marks. This is the
   explicit reversal of the (parked) orange reskin in PR #15.
2. **No behavior change.** All `MenuAction` codes, IDCs, dialog IDDs, and `.sqf` logic unchanged.
3. **No performance cost.** Static `.hpp` only; no new per-frame work, no custom fonts.
4. **No template *geometry* changes in Phase 1.** Changing default control heights/row-heights/sizes
   ripples into all 18 dialogs and silently breaks layouts not yet revisited. Geometry consistency is
   Phase 2's per-dialog job. Phase 1 touches only colour/affordance at the template layer.
5. **Splash untouched** (`b2zgroup` / `loadScreen.jpg`).

## 3. Non-goals (Phase 1)

- No SafeZone conversion of dialogs other than the hub (that's Phase 3).
- No layout changes to the other 17 dialogs (Phase 2).
- No per-button icons yet (deferred — see §6).
- No idd-collision fix yet (Phase 2).

## 4. Part A — Foundation polish (`Rsc/Ressources.hpp`, non-geometric)

Lifts every dialog at once; safe because nothing changes size.

### 4.1 Fix the red scrollbar
`RscListBox` sets `colorScrollbar[] = {0.95, 0, 0, 1}` — a jarring red scrollbar on every list in the
mission. Change to a quiet blue-grey `{0.6, 0.7, 0.8, 1}` consistent with the blue identity.

### 4.2 Real button hover feedback
`RscButton.colorFocused[] = {0.5882, 0.5882, 0.3529, 0.7}` equals its own `colorBackground` → hovering a
default button gives **no** visual response. Change `colorFocused` to a brighter state
`{0.72, 0.72, 0.45, 1}` (same hue, lifted) so buttons respond to the cursor. (`RscButton_Main` already
has a proper focused colour — leave it.)

### 4.3 Disabled clarity
`RscButton.colorDisabled[] = {0.5, 0.5, 0.5, 0.8}` is fine; ensure `colorBackgroundDisabled` reads as
clearly inert (`{0,0,0,0.6}` is acceptable — no change needed). No geometry touched anywhere in Part A.

## 5. Part B — Hub redesign (`Rsc/Dialogs.hpp` → `WF_Menu`, idd 11000)

Behavior identical (same 15 `MenuAction` codes, same button IDCs → `GUI_Menu.sqf` untouched). Visual /
layout rework only.

### 5.1 Logical grouping (replaces the arbitrary 2×5 grid)
Two columns, each with quiet blue section-header labels (new `RscText` controls, `idc = -1`):

- **Left — PURCHASE:** Purchase Units (1), Purchase Gear (2)
- **Left — GENERAL:** Team Menu (3), Support Menu (9), Help Menu (13)
- **Right — COMMAND:** Command Menu (5), Tactical Menu (6), Upgrade Menu (7), Economy Menu (8), Voting Menu (4)

(Numbers = existing `MenuAction` codes, unchanged.)

### 5.2 Hierarchy & spacing
- Header: existing title (`TitleMenu`, idc 11015) + a thin blue accent rule under the header band
  (reuse the existing `Background_L` border element, restyled for position).
- Even vertical rhythm: consistent button heights and gaps within each column; columns aligned.
- The two columns balance (left: 2 headers + 5 buttons; right: 1 header + 5 buttons) by tuning button
  height/gap **within the hub dialog only** (allowed — this is per-dialog geometry, not template).

### 5.3 "Tools" footer
Group the four utility icons (unflip 10, headbug 11, HUD 16, FPS 19) into a labeled "Tools" cluster on
the footer-left with even spacing, and the Exit (`closeDialog 0`) at footer-right. Same IDCs/actions.

### 5.4 SafeZone-aware
Express the hub's panel + all controls in SafeZone coordinates
(`x = <frac> * SafeZoneW + SafeZoneX`, `y = <frac> * SafeZoneH + SafeZoneY`) so the hub stays centered
and correctly sized on ultrawide / 4:3 instead of the current absolute 0–1 coords. (Hub only this phase.)

## 6. Icons — deferred (with rationale)

The approved mockup showed per-button icons. Shipping them now would violate the agreed
"no-patchy-mix" rule: the mission's existing `Client\Images` art cleanly covers only ~5/10 buttons
(Units→`icon_wf_building_barracks`, Gear→`icon_wf_building_gear`, Command→`icon_wf_building_cc`,
Tactical→`icon_wf_support_artilery`, Support→`icon_wf_building_repair`); Upgrade/Economy are weak
proxies and **Team/Voting/Help have no fitting icon**. Producing a uniform custom set needs `.paa` with
alpha (icons must sit transparently on the textured shortcut buttons), and there is **no ImageToPAA /
PAA converter** in `Tools/` (a `.jpg` icon would carry an opaque background that clashes with the button
texture). **Decision: ship Phase 1 text-only** (grouping + hierarchy already deliver the scannability
win) and pursue a uniform icon set as a fast-follow once a `.paa` pipeline is available (e.g. BI Tools
ImageToPAA). Flagged at the spec-review gate.

## 7. Verification & ship

- **Static:** delimiter/quote lint on edited `.hpp`; `WF_Menu` `MenuAction` count unchanged (15);
  every button IDC preserved; SafeZone expressions parse (balanced quotes/braces).
- **Visual reference:** an updated HTML mockup (text-only, original style) so the look is confirmable
  without the game.
- **In-engine smoke (user-run):** UI is client-side — host + join to verify the hub renders centered on
  the target resolution and the scrollbar/hover changes look right. Assistant reads RPT for parse errors.
- **Multi-mission:** mirror the two edited files to Takistan (both are verbatim twins — copy is safe;
  neither is LoadoutManager-content-modified).
- **PR:** draft PR on `rayswaynl/a2waspwarfare`, base `master`, via `gh --repo rayswaynl/a2waspwarfare`.

## 8. File change inventory

| File | Change | Risk |
|---|---|---|
| `Rsc/Ressources.hpp` | scrollbar colour + button focus colour (no geometry) | low |
| `Rsc/Dialogs.hpp` (WF_Menu) | regroup buttons, section headers, Tools footer, SafeZone coords | med |
| `Missions_Vanilla/…takistan/…` (both files) | verbatim mirror | low |

## 9. Risks & open questions

1. **SafeZone math** — converting the hub to SafeZone must keep it visually centered; verify the panel
   isn't clipped on extreme aspect ratios. Mitigation: derive coords from the current absolute layout ×
   a SafeZone reference, eyeball in the mockup, confirm in smoke.
2. **`PuristaBold`/mono fonts** — N/A this phase (original Zeppelin32 kept).
3. **Icons deferred** (§6) — confirm the user is OK shipping text-only now.
4. **No assistant in-engine check** — user owns the visual sign-off.
5. **Section-balance** — left column has 2 section headers + 5 buttons vs right's 1 + 5; tune button
   height/gap so both columns end at the same baseline.

## 10. Out-of-scope (later phases — note, don't do)
Consistency sweep + idd-collision fixes (P2), SafeZone for all other dialogs (P3), heavy-dialog flow
reworks (P4), per-button icon set (fast-follow).

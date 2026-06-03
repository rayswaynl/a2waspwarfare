# WF Menu "Ops-Console" Reskin + Hero Hub — Design Spec

- **Date:** 2026-06-03
- **Branch / worktree:** `feat/wf-menu-ops-console` @ `C:\Users\Steff\a2waspwarfare-opsconsole` (off `origin/master` 2cdf5fb8)
- **Status:** Approved design, pending spec review
- **Companion index:** `C:\Users\Steff\wasp-wf-menu-ui-index.md` (full UI inventory)

## 1. Goal

Build a visually distinct, brand-aligned alternative to the ~20-year-old WFBE Warfare menu — a
"solid contender" players notice — by applying the **Miksuu's Warfare "ops-console" brand** (cold-war
gunmetal/steel with a single orange hot-accent + the Stacked-Arrows chevron) across the entire in-game
UI, **with zero measurable runtime cost** and **without changing any menu behavior**.

## 2. Constraints (hard)

1. **No performance impact.** No custom font packaging (`.pbo` fonts), no per-frame work added, no new
   polling loops. Bundled fonts + static `.hpp` only, plus color-literal edits in a few `.sqf` panels.
2. **No behavior change.** All `MenuAction`/`WFBE_MenuAction` codes, IDCs, dialog IDDs, and `.sqf`
   control logic stay identical. This is presentation-only.
3. **Branding is loose, not plastered.** Chevron mark + palette where genuinely useful; one subtle
   `miksuu.com` pointer at most. No personal-name wordmark, no "WASP" (community-sensitivity: the brand
   is mid-rename; the chevron + palette are the name-agnostic survivors).
4. **Keep the current splash intro.** `RscTitles >> b2zgroup` / `loadScreen.jpg` is untouched.

## 3. Non-goals (YAGNI)

- No re-architecture of the `MenuAction` polling input bus (that's a separate, larger effort).
- No SafeZone responsive re-layout of all dialogs (only where the hub redesign naturally uses it).
- No new menu features, screens, or controls beyond the hero hub's chevron/header.
- No change to the semantic green/red "affordable / too-expensive" signal colors in purchase panels.
- No edit to the splash, the `Params` lobby screen, or any gameplay/server code.

## 4. Approach — token-layer reskin

The entire WFBE UI sources its colors from ~25 `#define` macros in `Rsc\Styles.hpp`, and its control
look from a handful of base templates in `Rsc\Ressources.hpp`. Rewriting those two files re-themes all
18 dialogs + 6 HUD overlays at once. The hero hub and chevron are surgical additions on top.

**Rejected alternatives:** parallel `Rsc*_Brand` classes (10× the diff, same result); per-dialog
hardcoded colors (unmaintainable, defeats the token system).

## 5. Brand → Arma color map

Source of truth: `miksuus-warfare/brand/tokens.css`. Arma RGBA = hex/255 as 0–1 floats; alpha kept from
the macro being replaced.

| Brand token | Hex | Arma RGB | Replaces (current) | Role |
|---|---|---|---|---|
| gunmetal | `#14171B` | `0.078,0.090,0.106` | black `{0,0,0,0.7}` | dialog body background |
| steel | `#2A2F36` | `0.165,0.184,0.212` | black `{0,0,0,0.4}` | header/footer/panel bands |
| **orange** | `#D9763C` | `0.851,0.463,0.235` | **sky-blue `#42B6FF` = `0.2588,0.7137,1`** | titles, selection, focus, accent rules |
| orange-deep | `#B85F2A` | `0.722,0.373,0.165` | — | hover / active state |
| olive | `#5C6536` | `0.361,0.396,0.212` | green sub `0.388,0.925,0.494` | secondary buttons |
| olive-dark | `#474E2A` | `0.278,0.306,0.165` | — | secondary button rest/border |
| bone | `#E7E3D6` | `0.906,0.890,0.839` | warm-gold `0.933,0.898,0.545` | all body/label text |
| chalk | `#F2EFE8` | `0.949,0.937,0.910` | — | chevron logo only |

**Felt change:** blue → orange accent, black → gunmetal, gold → bone, green-sub → olive.

### 5.1 Intent: dark and gritty — orange is sparing (locked)

The overall impression **must stay dark to match the grit of the game.** Backgrounds remain near-black
(gunmetal bodies, steel bands); **orange is a hot accent only** — used on titles, selection highlights,
focus states, and thin accent rules, never as a large background fill. Button *rest* state = dark steel;
*focus/hover* = orange. If a choice is ever between "more orange" and "darker," choose darker. The result
should read as a dim ops-console with orange embers, not an orange UI.

## 6. Typography (bundled fonts only — zero cost)

| Surface | Font | Rationale |
|---|---|---|
| Body / labels | `Zeppelin32` (unchanged) | Safe workhorse; already everywhere |
| HUD numeric readouts (money/FPS/supply/AI) | monospace bundled (`EtelkaMonospacePro`, fallback `LucidaConsoleB`) | "tactical stats console" feel; mirrors brand JetBrains Mono |
| Dialog titles | `PuristaBold` (condensed) | Closest bundled match to brand Oswald display |

All three are stock Arma 2 OA `CfgFontFamilies` entries — **availability to be verified in implementation**;
if a name is invalid, fall back to `Zeppelin32` (no visual regression, just less differentiation).

## 7. Component-level changes

### 7.1 `Rsc\Styles.hpp` — the palette (primary lever)
Rewrite all color macros to the brand map in §5. This alone re-themes every dialog + HUD overlay.
Pure `#define` text; no structural change.

### 7.2 `Rsc\Ressources.hpp` — base control templates
Restyle the templates that carry literal colors (not pulled from macros): `RscText*` default text →
bone; `RscButton*` rest/active/disabled → steel/orange; `RscButton_Exit` keeps a (brand-toned) red;
`RscListBox*` select background → orange; `RscShortcutButtonMain` `color[]`/focused → orange/steel via
**re-tint of existing textures** (no new button art). Title templates → `PuristaBold`. HUD numeric
templates (`RscStructuredTextB` / the RUBHUD `RscText` rows) → mono font.

### 7.3 `Rsc\Titles.hpp` — always-on HUD
Restyle RUBHUD (`OptionsAvailable` idc 1345–1367): bone labels, mono orange values, orange/steel accent
bar. Capture bar (`CaptureBar`), construction reticle (`WFBE_ConstructionInterface`), end-of-game stats
(`EndOfGameStats`) inherit the palette. Runtime threshold colors set by `Client_UpdateRHUD.sqf`
(FPS green/yellow/red, health gradient, side-color bar) **stay** — they're functional, not branding.

### 7.4 `Rsc\Dialogs.hpp` — hero hub redesign (`WF_Menu`, idd 11000)
Visual rework only; same 10 buttons, same IDCs, same `MenuAction` codes → `GUI_Menu.sqf` untouched.
- New steel header band with the **chevron** (RscPicture) + a `PuristaBold` title and an orange accent
  underline rule.
- Buttons re-tinted to orange-focus / steel-rest via `color[]`/`colorFocused[]` (no new textures).
- Tighter, visually grouped grid; bone labels.
- Subtle `miksuu.com` in mono in a footer corner — low-key, single line, trivially removable.

All **other dialogs** re-theme automatically from §7.1–7.2 with no per-dialog edits (the win of the
token approach). Targeted per-dialog polish only if a dialog hardcodes an off-palette literal.

### 7.5 `.sqf` structured-text color swaps (presentation-only)
Several GUI scripts build `parseText` panels with inline hex `#42b6ff` (blue). Swap those accent-blue
literals → orange (`#d9763c`) so panels don't clash with the new accent. **Color strings only — no logic
touched.** Keep `#76F563` green / `#F56363` red (semantic). Scope: grep the `Client\GUI\*.sqf` set for
`42b6ff`/`42B6FF` and replace.

## 8. Assets (minimal)

- **Chevron texture:** `miksuus-warfare\brand\logo\mark-on-orange.svg` (or `mark.svg`) → rasterize via
  headless Chrome (per the doc-generation pipeline) to a transparent PNG at power-of-two size (e.g.
  256×256) → convert to `.paa` (via `Tools\` ImageToPAA/TexView if present; else ship `.jpg`, proven
  in-engine by the existing `Client\Images\fps_hud.jpg`) → `Client\Images\brand_chevron.paa`.
- No other new art — buttons/HUD are re-tints.

## 9. Multi-mission propagation

`Missions\[55-2hc]…chernarus` is the source of truth; `Missions_Vanilla\[61-2hc]…takistan` has its **own
copy** of `Rsc\` + `Client\GUI\` + `Client\Images\`. Plan: edit Chernarus, then determine whether
`Tools\LoadoutManager` regenerates these UI files for Takistan or leaves them as hand-copied twins
(open question §11). Net: **both** mission folders must end with identical UI files — by regen or by copy.

## 10. Verification & ship

- **Static:** delimiter/brace/quote-balance lint on every edited file; confirm no `Styles.hpp` macro is
  left referenced-but-undefined; confirm all class/IDC references still resolve.
- **Visual reference:** an HTML mockup of the intended hub + a representative sub-dialog so the user knows
  the target look without launching the game.
- **In-engine smoke (user-run):** UI is client-side — a dedicated server won't render dialogs. The user
  hosts + joins locally and eyeballs the menus; assistant reads RPT for config-parse errors.
- **PR:** **draft** PR on `rayswaynl/a2waspwarfare` (private fork), base `master`, via
  `gh --repo rayswaynl/a2waspwarfare`. Never to upstream `Miksuu`.

## 11. Risks & open questions

1. **LoadoutManager vs UI twins** (open): does the generator touch `Rsc/`+`Client/GUI/`? Resolve before
   finalizing Takistan; default to manual file copy if it doesn't.
2. **Font name validity**: `EtelkaMonospacePro`/`PuristaBold` must be real `CfgFontFamilies` entries in
   A2 OA 1.63; fall back to `Zeppelin32` if not.
3. **`.paa` toolchain**: if no ImageToPAA/TexView in `Tools\`, fall back to `.jpg` chevron.
4. **Contrast**: orange-on-gunmetal and bone-on-steel must stay legible at small `sizeEx`; verify against
   the busiest panels (BuyGear, BuyUnits) in the mockup before committing.
5. **No in-engine visual check by assistant** — the user owns the final look sign-off.

## 12. File change inventory (Chernarus; mirror to Takistan)

| File | Change | Risk |
|---|---|---|
| `Rsc\Styles.hpp` | Rewrite ~25 color macros to brand palette | low |
| `Rsc\Ressources.hpp` | Restyle base templates (colors, fonts, re-tint) | low |
| `Rsc\Titles.hpp` | HUD/overlay palette + mono numerics | low |
| `Rsc\Dialogs.hpp` | Hub redesign (chevron, header, re-tint, footer) | med (largest) |
| `Client\GUI\*.sqf` | Swap `#42b6ff` accent literals → orange (string-only) | low |
| `Client\Images\brand_chevron.paa` (new) | Chevron texture | low |
| `Missions_Vanilla\…takistan\…` | Mirror all of the above | low |

## 13. Out-of-scope follow-ups (note, don't do)

- Event-driven rewrite of the `MenuAction` polling bus.
- SafeZone responsive re-layout across all dialogs.
- Fixing the latent idd collisions (23000 EASA/Economy; 10200 RscOverlay/OptionsAvailable) — flag in PR
  description as known pre-existing, not introduced here.

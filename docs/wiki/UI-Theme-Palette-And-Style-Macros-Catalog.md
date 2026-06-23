# WFBE Theme Palette and Style Macros (Styles.hpp RGBA catalog)

> Source-verified 2026-06-23 against master f8a76de3. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`Rsc/Styles.hpp` is WASP Warfare's central UI palette. It is a flat list of 24 `#define` macros — RGBA color arrays and a few scalar border-thickness values — that the dialog and overlay resources reference by name instead of inlining raw color literals. Changing one macro re-themes every control that references it. The dominant brand color is the cyan accent `{0.2588, 0.7137, 1, 1}` (used for borders, separators, listbox-select, the OA icon tint, and the EOGS bars); backgrounds are black at varying opacities; menu sub-buttons use a green accent.

This page catalogs every macro, its literal value, and what it themes. The tables are generated from `grep -n "#define" Rsc/Styles.hpp`, so the line numbers are mechanically correct.

---

## Include Order

`Styles.hpp` is `#include`d early in the resource graph so its macros are defined before any dialog or overlay that uses them is parsed. From `description.ext`, the `Rsc/` include block runs in this order:

| Order | File | description.ext line |
|------:|------|----------------------|
| 1 | `Rsc/Header.hpp` | `description.ext:45` |
| 2 | `Rsc/Styles.hpp` | `description.ext:48` |
| 3 | `Rsc/Parameters.hpp` | `description.ext:51` |
| 4 | `Rsc/Ressources.hpp` | `description.ext:53` |
| 5 | `Rsc/Dialogs.hpp` | `description.ext:55` |
| 6 | `Rsc/Titles.hpp` | `description.ext:57` |

`Styles.hpp` (2nd) precedes `Dialogs.hpp` (5th), so every palette macro is in scope by the time the dialogs that consume them are parsed. (`description.ext:48`, `description.ext:55`)

---

## Palette Macros

The "Dialogs.hpp refs" column is the count of `grep -cw "<macro>" Rsc/Dialogs.hpp` — how many lines in the dialog resource reference that macro by name. A `0` means the macro is defined but not referenced from `Dialogs.hpp` (it is either referenced from another resource file — overlays/titles — or currently unused).

### Background / EOGS group

Section comment `/* Background */` (`Rsc/Styles.hpp:1`).

| Macro | Value | Themes | Dialogs.hpp refs |
|-------|-------|--------|-----------------:|
| `WFBE_OA_Icon` | `{0.2588, 0.7137, 1, 1}` | OA-icon tint (cyan accent applied to the Arrowhead icon) | 0 |
| `WFBE_EOGS_Background` | `{0, 0, 0, 0.7}` | End-Of-Game-Stats panel background (black, 70% opacity) | 0 |
| `WFBE_EOGS_SRVBBar` | `{0.2588, 0.7137, 1, 1}` | EOGS score/value bar — "SRVB" bar (cyan) | 0 |
| `WFBE_EOGS_SLVLBar` | `{0.2588, 0.7137, 1, 1}` | EOGS level bar — "SLVL" bar (cyan) | 0 |

Source lines: `Rsc/Styles.hpp:2,4,5,6`. These four are referenced from the EOGS overlay/title resources, not from `Dialogs.hpp`, which is why all four count 0 there.

### Coloration group (main panel backgrounds + border)

Section comment `//---Coloration` (`Rsc/Styles.hpp:9`).

| Macro | Value | Themes | Dialogs.hpp refs |
|-------|-------|--------|-----------------:|
| `WFBE_Background_Color` | `{0, 0, 0, 0.7}` | Main dialog panel background (black, 70%) | 19 |
| `WFBE_Background_Color_Header` | `{0, 0, 0, 0.4}` | Header strip background (black, 40%) | 20 |
| `WFBE_Background_Color_Footer` | `{0, 0, 0, 0.3}` | Footer strip background (black, 30%) | 12 |
| `WFBE_Background_Color_Sub` | `{0, 0, 0, 0.3}` | Sub-panel / nested-section background (black, 30%) | 8 |
| `WFBE_Background_Color_Gear` | `{0.5, 0.5, 0.5, 0.15}` | Gear-grid cell background (grey, 15%) | 0 |
| `WFBE_Background_Border` | `{0.2588, 0.7137, 1, 1}` | Panel border color (cyan) | 12 |
| `WFBE_Background_Border_Thick` | `0.001` | Panel border thickness (scalar, not a color) | 12 |

Source lines: `Rsc/Styles.hpp:10,11,12,13,14,15,17`. `WFBE_Background_Color_Header` (20 refs) and `WFBE_Background_Color` (19 refs) are the two most-referenced macros in the file. `WFBE_Background_Color_Gear` is defined but not referenced from `Dialogs.hpp` (0).

### ListBox group

Section comment `/* ListBox */` (`Rsc/Styles.hpp:20`).

| Macro | Value | Themes | Dialogs.hpp refs |
|-------|-------|--------|-----------------:|
| `WFBE_LBC_Select_Color` | `{0.2588, 0.7137, 1, 1}` | Listbox selected-row highlight (cyan) | 0 |

Source line: `Rsc/Styles.hpp:22`. Note this is the *generic-control* listbox-select macro (LBC = ListBox Coloration); the menu-specific listbox select is `WFBE_Menu_ListBox_Select_Color` below. This one is not referenced from `Dialogs.hpp` (0).

### Separator group

Section comment `/* Separator */` (`Rsc/Styles.hpp:25`). `SPC` = SeParator Color, `SPT` = SeParator Thick.

| Macro | Value | Themes | Dialogs.hpp refs |
|-------|-------|--------|-----------------:|
| `WFBE_SPC1` | `{0.2588, 0.7137, 1, 1}` | Separator-line color, primary (cyan) | 6 |
| `WFBE_SPC2` | `{0.543, 0.5742, 0.4102, 1}` | Separator color, secondary — **marked `//unused`** | 0 |
| `WFBE_SPT1` | `0.001` | Separator thickness, primary (scalar) | 6 |
| `WFBE_SPT2` | `0.0005` | Separator thickness, secondary — **marked `//unused`** | 0 |

Source lines: `Rsc/Styles.hpp:27,28,30,31`. The `WFBE_SPC2` and `WFBE_SPT2` definitions carry literal `//unused` trailing comments in the source (`Rsc/Styles.hpp:28`, `Rsc/Styles.hpp:31`), and both count 0 in `Dialogs.hpp`, confirming they are dead palette entries.

### Menu-button / menu-text group

No section header; these run from `Rsc/Styles.hpp:33` to the end of file (line 40).

| Macro | Value | Themes | Dialogs.hpp refs |
|-------|-------|--------|-----------------:|
| `WFBE_Menu_Button_Color` | `{0.258823529, 0.713725490, 1, 0.7}` | Menu button background, idle (cyan, 70%) | 0 |
| `WFBE_Menu_Button_Text_Color` | `{1, 1, 1, 0.8}` | Menu button label text (white, 80%) | 0 |
| `WFBE_Menu_Button_Focused_Color` | `{0.258823529, 0.713725490, 1, 1}` | Menu button background, focused/hover (cyan, 100%) | 0 |
| `WFBE_Menu_Button_Sub_Color` | `{0.388235294, 0.925490196, 0.494117647, 0.7}` | Menu sub-button background, idle (green, 70%) | 4 |
| `WFBE_Menu_Button_Sub_Focused_Color` | `{0.388235294, 0.925490196, 0.494117647, 1}` | Menu sub-button background, focused (green, 100%) | 2 |
| `WFBE_Menu_ListBox_Select_Color` | `{0.258823529, 0.713725490, 1, 1}` | Menu listbox selected-row highlight (cyan) | 5 |
| `WFBE_Menu_Text_Color` | `{0.258823529, 0.713725490, 1, 1}` | Menu generic text color (cyan) | 8 |
| `WFBE_Menu_Title_Color` | `{0.258823529, 0.713725490, 1, 1}` | Menu title text color (cyan) | 6 |

Source lines: `Rsc/Styles.hpp:33,34,35,36,37,38,39,40`. The menu-button *primary*-state macros (`_Button_Color`, `_Button_Text_Color`, `_Button_Focused_Color`) count 0 in `Dialogs.hpp` — they are consumed elsewhere or reserved — while the *sub*-button and menu-text/title macros are referenced. The sub-button green pair gives sub-menu buttons a distinct green accent vs the cyan of primary controls. The full-precision cyan `{0.258823529, 0.713725490, 1, …}` in this group is the same color as the truncated `{0.2588, 0.7137, 1, …}` used in the upper groups, just written to more decimal places.

---

## Where Applied

`grep -c "WFBE_" Rsc/Dialogs.hpp` returns **168** — that is the count of lines in the dialog resource that reference a palette macro (the `grep -o` occurrence count is also 168, i.e. roughly one macro reference per matching line). The dialogs do not redefine colors; they pull them by macro name, e.g. `colorBackground[] = WFBE_Background_Color;`. So a single edit to `Rsc/Styles.hpp` propagates to all 168 reference sites.

The EOGS bar/background macros and the `WFBE_OA_Icon` tint count 0 in `Dialogs.hpp` because the End-Of-Game-Stats panel and the OA icon live in the overlay/title resources (`Rsc/Titles.hpp`, included 6th per the table above), not in the dialog resource.

---

## Correction to the Client UI Systems Atlas

The row in [Client UI Systems Atlas](Client-UI-Systems-Atlas) that describes `Rsc/Styles.hpp` is inaccurate. That row reads:

`| Rsc/Styles.hpp | UI constants such as ST_*, CT_* and style values. | description.ext:49 |` (`Client-UI-Systems-Atlas.md:60`)

`Styles.hpp` does **not** define any `ST_*` or `CT_*` constants. `grep -nE "ST_|CT_" Rsc/Styles.hpp` returns **zero matches** (exit code 1, no output). `ST_*` (static styles, e.g. `ST_LEFT`, `ST_PICTURE`) and `CT_*` (control types, e.g. `CT_STATIC`, `CT_BUTTON`) are Arma 2 OA engine config constants that live in the game's base config, not in this mission file. What `Rsc/Styles.hpp` actually defines is the 24-macro `WFBE_*` color/thickness palette catalogued above (`Rsc/Styles.hpp:2-40`). The Atlas row also cites `description.ext:49` for the include, but the actual `#include "Rsc\Styles.hpp"` directive is at `description.ext:48` (line 47 is the `//--- Styles` comment).

---

## Continue Reading

- [Client-UI-Systems-Atlas](Client-UI-Systems-Atlas) — the resource-graph overview these palette macros feed into (and the page whose `Styles.hpp` row this catalog corrects)
- [UI-Control-Class-Library-Reference](UI-Control-Class-Library-Reference) — the `Ressources.hpp` base control classes whose `colorBackground`/`colorText`/border properties resolve to these macros
- [Map-Control-Template-And-Minimap-Embed-Reference](Map-Control-Template-And-Minimap-Embed-Reference) — map/minimap controls that share the dialog resource graph
- [UI-IDD-Collision-Repair](UI-IDD-Collision-Repair) — dialog IDD allocation across the same `Rsc/Dialogs.hpp` resource

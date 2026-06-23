# UI Control Class Library Reference

> Source-verified 2026-06-21 against master f8a76de. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`Rsc/Ressources.hpp` is the mission's **shared control-class library**: the reusable `Rsc*` base controls that every dialog in `Rsc/Dialogs.hpp` and every HUD resource in `Rsc/Titles.hpp` inherits from. `Rsc/Styles.hpp` supplies the shared colour/border macros those controls reference. This page catalogs the base classes, the control-type / style constants they use, and the theme macros — the styling backbone of the whole UI.

Include order (from `description.ext:45-57`): `Header.hpp` → `Styles.hpp` → `Parameters.hpp` → `Ressources.hpp` → `Dialogs.hpp` → `Titles.hpp` (then `Identities.hpp` only when not `VANILLA`, `description.ext:61`). So `Styles.hpp` macros and `Ressources.hpp` base classes are defined **before** the dialogs that consume them.

## Control-type constants (`CT_*`)

`Ressources.hpp:3-11` defines the A2-OA control-type ids used as each class's `type`:

| Constant | Value | Used by |
| --- | --- | --- |
| `CT_STATIC` | 0 | `RscText`, `RscPicture`, `RscFrame`, `IGUIBack` |
| `CT_BUTTON` | 1 | `RscButton` |
| `CT_EDIT` | 2 | `RscEdit` |
| `CT_COMBO` | 4 | `RscCombo` |
| `CT_LISTBOX` | 5 | `RscListBox` |
| `CT_CLICKABLETEXT` | 11 | `RscClickableText` |
| `CT_STRUCTUREDTEXT` | 13 | `RscStructuredText`, `RscStructuredTextB` |
| `CT_CONTROLS_GROUP` | 15 | `RscControlsGroup` |
| `CT_LISTNBOX` | 102 | `RscListnBox`, `RscListBoxA` |

Three more A2-OA engine type ids appear inline without a `CT_` alias: `16` (shortcut button, `RscShortcutButton:174`), `43` (horizontal slider, `RscXSliderH:488`), and `101` (map control, `RscMapControl:564`).

## Style constants (`ST_*`)

`Ressources.hpp:13-26` defines the bitwise style flags:

| Constant | Value | Meaning |
| --- | --- | --- |
| `ST_POS` / `ST_HPOS` / `ST_VPOS` | 0x0F / 0x03 / 0x0C | position masks |
| `ST_LEFT` / `ST_RIGHT` / `ST_CENTER` | 0x00 / 0x01 / 0x02 | horizontal text align |
| `ST_DOWN` / `ST_UP` / `ST_VCENTER` | 0x04 / 0x08 / 0x0c | vertical text align |
| `ENABLE_SHADOW` | `shadow = 2` | drop-shadow macro |
| `ST_PICTURE` | 48 | picture style |
| `ST_TEXT_BG` | 128 | text-background fill |

## Theme + sound macros

`Ressources.hpp:29-43` switches the accent colour and UI sounds on the `VANILLA` build flag:

| Macro | `VANILLA` (base game) | else (Arrowhead/CO) |
| --- | --- | --- |
| `subcolor1` (accent) | `{0.7,1,0.7,1}` green | `{1,1,0.7,1}` yellow |
| `WFBE_SoundClick` | `ui\ui_ok` | `\ca\ui\data\sound\onclick` |
| `WFBE_SoundEnter` | `ui\ui_over` | `\ca\ui\data\sound\onover` |
| `WFBE_SoundEscape` | `ui\ui_cc` | `\ca\ui\data\sound\onescape` |

`Rsc/Styles.hpp` (40 lines) defines the menu palette macros the controls and dialogs share, e.g. `WFBE_Menu_Button_Color = {0.2588,0.7137,1,0.7}` (`Styles.hpp:33`), `WFBE_Menu_Button_Focused_Color` (`:35`), `WFBE_Menu_Button_Text_Color` (`:34`), `WFBE_Background_Color = {0,0,0,0.7}` (`:10`), and the `0.2588,0.7137,1` "OA blue" reused as `WFBE_OA_Icon` (`:2`) across selects/titles. (RGB channels are shown rounded to 4 dp here; the source defines use full precision, e.g. `{0.258823529, 0.713725490, 1, 0.7}`.)

## Base control classes

All defined in `Rsc/Ressources.hpp`. `idc` defaults to `-2` (or `-1` for non-interactive containers) so inheriting controls set their own.

| Class | Parent | `type` | Notable defaults | Line |
| --- | --- | --- | --- | --- |
| `RscControlsGroup` | — | `CT_CONTROLS_GROUP` (15) | `idc=-1`, `style=ST_MULTI`, V/H scrollbars + `Controls{}` | `Ressources.hpp:46` |
| `RscPicture` | — | 0 | `style=48`, `w=0.275 h=0.04`, WFBE sounds | `Ressources.hpp:81` |
| `RscPictureKeepAspect` | `RscPicture` | 0 | `style=0x30+0x800` (keep aspect); "Coin Menu" | `Ressources.hpp:97` |
| `IGUIBack` | — | `CT_STATIC` (0) | `idc=124`, `style=ST_TEXT_BG`, 0.6-alpha black fill | `Ressources.hpp:101` |
| `RscButton` | — | 1 | `style=0x02+0x100`, `h=0.036`, Zeppelin32, mouse sounds | `Ressources.hpp:117` |
| `RscButton_Main` | `RscButton` | 1 | recolours to `WFBE_Menu_Button_Color` family | `Ressources.hpp:147` |
| `RscButton_Back` | `RscButton` | 1 | `0.04²`, `text="<<"` | `Ressources.hpp:153` |
| `RscButton_Exit` | `RscButton` | 1 | `0.04²`, `text="X"`, red background | `Ressources.hpp:160` |
| `RscShortcutButton` | — | 16 | textured IGUI button, `HitZone`/`ShortcutPos`/`TextPos`/`Attributes` | `Ressources.hpp:173` |
| `RscIGUIShortcutButton` | `RscShortcutButton` | 16 | `style=2`, igui textures | `Ressources.hpp:234` |
| `RscShortcutButtonMain` | `RscShortcutButton` | 16 | wider, blue, custom `Client\Images` over/focus/down textures | `Ressources.hpp:274` |
| `RscListBox` | — | 5 | `style=0+0x10`, 4-col `columns[]`, igui scrollbar | `Ressources.hpp:330` |
| `RscListnBox` | `RscListBox` | 102 | `style=16`, `rowHeight=0.03`, no side arrows | `Ressources.hpp:361` |
| `RscListBoxA` | `RscListBox` | 102 | `style=16`, `rowHeight=0.03` (keeps side arrows) | `Ressources.hpp:373` |
| `RscText` | — | 0 | `style=256`, `h=0.037`, sand text `{0.93,0.90,0.55,0.9}` | `Ressources.hpp:384` |
| `RscText_Title` | `RscText` | 0 | OA-blue, `sizeEx=0.045`, `shadow=1` | `Ressources.hpp:399` |
| `RscText_SubTitle` | `RscText` | 0 | OA-blue, `sizeEx=0.035` | `Ressources.hpp:405` |
| `RscText_Small` | `RscText` | 0 | `sizeEx=0.025` | `Ressources.hpp:411` |
| `RscEdit` | `RscText` | `CT_EDIT` (2) | `autocomplete=true`, OA-blue selection | `Ressources.hpp:418` |
| `RscStructuredText` | — | 13 | `style=0`, `colorText=subcolor1`, `Attributes` block | `Ressources.hpp:428` |
| `RscFrame` | — | `CT_STATIC` (0) | `style=64` (frame), `idc=-1` | `Ressources.hpp:447` |
| `RscStructuredTextB` | — | 13 | white text; "for valhalla hud" | `Ressources.hpp:461` |
| `RscXSliderH` | — | 43 | `style=0x400+0x10`, ui slider textures | `Ressources.hpp:486` |
| `RscCombo` | — | 4 | `style=1`, OA-blue select, igui combo arrows | `Ressources.hpp:504` |
| `RscClickableText` | — | 11 | `style=48+0x800`, WFBE click/enter/escape sounds | `Ressources.hpp:541` |
| `RscMapControl` | — | 101 | full map renderer + `Task`/`CustomMark`/`Legend` + 25 map-icon subclasses (Bunker, Hospital, Church, Waypoint, …) | `Ressources.hpp:563` |

## How dialogs consume the library

Every control inside the `RscMenu_*` dialog roots in `Rsc/Dialogs.hpp` inherits one of these base classes rather than redefining style. Examples: `CA_Background : RscText` (`Dialogs.hpp:10`), `CA_Menu_Title : RscText_Title` (`Dialogs.hpp:32`), `CA_Quit_Button : RscButton_Main` (`Dialogs.hpp:39`), `CA_Icon : RscPicture` (`Dialogs.hpp:87`), `CA_UpgradeDetails : RscStructuredText` (`Dialogs.hpp:95`). The dialog roots themselves (`RscMenu_Team`, `RscMenu_BuyUnits`, `RscMenu_Command`, `RscMenu_Tactical`, `RscMenu_Service`, `RscMenu_EASA`, `RscMenu_Economy`, `RscMenu_Help`, `RscMenu_UnitCamera`, `RscDisplay_Parameters`) live at `Dialogs.hpp:1296` onward and are documented per-dialog in the UI pages below.

## A2-OA notes

- These are **Arma 2 OA control-type ids**, not Arma 3 IGUI/CT values: `RscListnBox`/`RscListBoxA` use the OA `type=102` (`CT_LISTNBOX`); the shortcut button is `type=16`; the map control is `type=101`; the slider is `type=43`. Reusing A3 control templates here would mismatch the engine.
- `style` values are bitfields combined with `+` (e.g. `RscClickableText` `style=48+0x800` = picture | keep-aspect). The `ST_*` aliases (`Ressources.hpp:13-26`) cover the common position/align bits; numeric literals are used where no alias exists.
- `RscControlsGroup` sets `style=ST_MULTI` (`Ressources.hpp:54`), an **engine-provided** constant (from the Bohemia base config) — not one of the locally `#define`d `ST_*` aliases at `:13-26`.
- The `colorText[] = subcolor1` / `Attributes color = subcolor1hex` on `RscStructuredText` (`Ressources.hpp:438-441`) means structured-text accent colour follows the green/yellow theme switch automatically.

## Continue Reading

- [UI IDD Collision Repair](UI-IDD-Collision-Repair) — the dialog `idd`/`idc` ranges these controls populate, and how collisions were resolved
- [Client UI Systems Atlas](Client-UI-Systems-Atlas) — the runtime UI controllers that drive the dialogs built from these classes
- [UI HUD And Dialogs](UI-HUD-And-Dialogs) — the dialog/HUD inventory (`Rsc/Dialogs.hpp`, `Rsc/Titles.hpp`)
- [Gear Buy Menu Render And Price Function Reference](Gear-Buy-Menu-Render-And-Price-Function-Reference) — a worked example of a dialog populating `RscListnBox`/`RscText` controls at runtime
- [Player UI Workflow Map](Player-UI-Workflow-Map) — how players reach each dialog in game

# WF Menu "Ops-Console" Reskin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-theme the entire WFBE Warfare in-game UI (18 dialogs + 6 HUD overlays + hero hub) to the dark "ops-console" brand — near-black gunmetal bodies, steel panels, a single sparing orange hot-accent, bone text, the Stacked-Arrows chevron — with zero runtime cost and no behavior change.

**Architecture:** Token-layer reskin. Rewrite the ~25 color macros in `Rsc\Styles.hpp` (every dialog/overlay inherits) + restyle the base control templates in `Rsc\Ressources.hpp`; mechanically substitute the same color tuples in `Rsc\Titles.hpp`, the hub block of `Rsc\Dialogs.hpp`, and `Client\GUI\*.sqf` structured-text panels; add one chevron texture. Edit Chernarus (source of truth), mirror to Takistan.

**Tech Stack:** Arma 2 OA mission config (`.hpp` dialog/control classes, `.sqf` UI logic), bundled engine fonts only, headless-Chrome SVG rasterize for the chevron, `gh` for the draft PR.

**Worktree:** `C:\Users\Steff\a2waspwarfare-opsconsole` (branch `feat/wf-menu-ops-console` off `origin/master` 2cdf5fb8).

**Mission paths (relative to worktree):**
- Chernarus (source): `Missions\[55-2hc]warfarev2_073v48co.chernarus`
- Takistan (mirror): `Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan`

---

## The Substitution Table (single source of truth)

All color edits use these exact tuple replacements. Alpha is **preserved** from the original (only RGB changes for backgrounds; accent tuples replace the blue family entirely).

| # | Meaning | OLD (find) | NEW (replace) |
|---|---|---|---|
| S1 | accent blue → orange (short form) | `0.2588, 0.7137, 1` | `0.851, 0.4627, 0.2353` |
| S2 | accent blue → orange (long form) | `0.258823529, 0.713725490, 1` | `0.850980392, 0.462745098, 0.235294118` |
| S3 | body text gold → bone | `0.9333, 0.8980, 0.5451` | `0.9059, 0.8902, 0.8392` |
| S4 | green-sub → olive (long form) | `0.388235294, 0.925490196, 0.494117647` | `0.360784314, 0.396078431, 0.211764706` |
| S5 | dialog body black → gunmetal | `{0, 0, 0, 0.7}` | `{0.0784, 0.0902, 0.1059, 0.7}` |
| S6 | header black → steel | `{0, 0, 0, 0.4}` | `{0.1647, 0.1843, 0.2118, 0.4}` |
| S7 | footer/sub black → steel | `{0, 0, 0, 0.3}` | `{0.1647, 0.1843, 0.2118, 0.3}` |
| S8 | khaki button rest → steel | `0.5882, 0.5882, 0.3529` | `0.1647, 0.1843, 0.2118` |
| S9 | accent hex (SQF) blue → orange | `#42b6ff` / `#42B6FF` | `#d9763c` |

**Fonts (bundled, zero cost):** HUD numeric value rows → `EtelkaMonospacePro` (fallback `Zeppelin32`); hub title → `PuristaBold` (fallback `Zeppelin32`). Everything else stays `Zeppelin32`.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `C:\Users\Steff\wasp-ui-lint.py` (scratch, NOT committed) | Delimiter/quote-balance + token-presence checker, reused by every task | 0 |
| `Client\Images\brand_chevron.paa` (or `.jpg`) | New chevron texture for the hub header | 0 |
| `Rsc\Styles.hpp` | The palette macros — primary lever, re-themes all dialogs/HUD | 1 |
| `Rsc\Ressources.hpp` | Base control templates (button/list/text/combo colors + fonts) | 2 |
| `Rsc\Titles.hpp` | Always-on HUD overlays (RUBHUD, capture bar, EOGS, construction) | 3 |
| `Rsc\Dialogs.hpp` (WF_Menu block, lines ~1019-1231) | Hero hub: chevron, title font, footer pointer (no behavior change) | 4 |
| `Client\GUI\*.sqf` | Structured-text accent hex swap (S9) — string-only | 5 |
| `Missions_Vanilla\…takistan\…` | Byte-identical mirror of all the above | 6 |
| `docs/superpowers/` + PR | Mockup, static verification, draft PR | 7 |

**Verification model (no unit-test harness exists for Arma config):** each task's "test" is (a) `wasp-ui-lint.py` passing on every edited file — balanced `{}`/`()`/`[]` and even `"` count — and (b) `grep` assertions that the NEW tokens are present and OLD tokens are gone where intended. In-engine visual confirmation is a **user-run gate** at the end (UI is client-side; a dedicated server can't render it).

---

## Task 0: Tooling + chevron asset

**Files:**
- Create: `C:\Users\Steff\wasp-ui-lint.py` (scratch, outside repo — not shipped, not committed)
- Create: `Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\Images\brand_chevron.paa` (or `.jpg` fallback)
- Source asset: `C:\Users\Steff\miksuus-warfare\brand\logo\mark-on-orange.svg`

- [ ] **Step 1: Write the lint helper**

Create `C:\Users\Steff\wasp-ui-lint.py`:

```python
import sys
def check(path):
    s = open(path, encoding="utf-8", errors="replace").read()
    pairs = {'{':'}', '(':')', '[':']'}
    stack, bad = [], []
    for i,c in enumerate(s):
        if c in '{([': stack.append((c,i))
        elif c in '})]':
            if not stack or pairs[stack[-1][0]] != c:
                bad.append((c,i)); 
            else: stack.pop()
    quotes = s.count('"')
    ok = not stack and not bad and quotes % 2 == 0
    print(f"{'OK ' if ok else 'FAIL'} {path}  unclosed={len(stack)} stray={len(bad)} quotes={quotes}")
    return ok
if __name__ == "__main__":
    results = [check(p) for p in sys.argv[1:]]
    sys.exit(0 if all(results) else 1)
```

- [ ] **Step 2: Verify the lint helper runs on an untouched file (expect OK)**

Run:
```bash
python C:\Users\Steff\wasp-ui-lint.py "C:\Users\Steff\a2waspwarfare-opsconsole\Missions\[55-2hc]warfarev2_073v48co.chernarus\Rsc\Styles.hpp"
```
Expected: `OK ...Styles.hpp  unclosed=0 stray=0 quotes=...`

- [ ] **Step 3: Detect a PAA toolchain**

Run (PowerShell):
```powershell
Get-ChildItem "C:\Users\Steff\a2waspwarfare-opsconsole\Tools" -Recurse -Include ImageToPAA.exe,*TexView* -ErrorAction SilentlyContinue | Select-Object FullName
(Get-Command ImageToPAA.exe -ErrorAction SilentlyContinue).Source
```
Expected: a path if a converter exists, else empty. Record which branch applies in Step 4.

- [ ] **Step 4: Produce the chevron texture**

Rasterize the SVG to a 256×256 transparent PNG via headless Chrome, then convert:

```powershell
$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$svg = "C:\Users\Steff\miksuus-warfare\brand\logo\mark-on-orange.svg"
$png = "C:\Users\Steff\brand_chevron_256.png"
& $chrome --headless --disable-gpu --force-device-scale-factor=1 --default-background-color=00000000 --screenshot="$png" --window-size=256,256 "$svg"
```

- **If ImageToPAA exists (Step 3):** convert PNG → PAA:
  ```powershell
  & "<ImageToPAA path>" "C:\Users\Steff\brand_chevron_256.png" "C:\Users\Steff\a2waspwarfare-opsconsole\Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\Images\brand_chevron.paa"
  ```
  Hub references `Client\Images\brand_chevron.paa`.
- **Else (.jpg fallback — no alpha):** the chevron will sit on the steel header, so flatten onto steel `#2A2F36` instead of transparency:
  ```powershell
  & $chrome --headless --disable-gpu --force-device-scale-factor=1 --default-background-color=2A2F36 --screenshot="C:\Users\Steff\a2waspwarfare-opsconsole\Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\Images\brand_chevron.jpg" --window-size=256,256 "$svg"
  ```
  Hub references `Client\Images\brand_chevron.jpg` (proven format — `fps_hud.jpg` already loads in a control). Update Task 4's `text=` path to match whichever was produced.

- [ ] **Step 5: Verify the asset exists and is non-trivial**

Run (PowerShell):
```powershell
Get-ChildItem "C:\Users\Steff\a2waspwarfare-opsconsole\Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\Images\brand_chevron.*" | Select-Object Name,Length
```
Expected: one file, Length > 1KB.

- [ ] **Step 6: Commit the asset** (lint helper is scratch, not committed)

```bash
cd "C:\Users\Steff\a2waspwarfare-opsconsole"
git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Images/brand_chevron.paa" 2>$null
git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Images/brand_chevron.jpg" 2>$null
git commit -m "feat(ui): add brand chevron texture for hub header"
```

---

## Task 1: Palette macros — `Rsc\Styles.hpp`

**Files:**
- Modify (full rewrite): `Missions\[55-2hc]warfarev2_073v48co.chernarus\Rsc\Styles.hpp`

- [ ] **Step 1: Replace the entire file** with the brand palette (RGB→brand, alpha preserved; accent blue→orange):

```c
/* Background */
#define WFBE_OA_Icon 						{0.851, 0.4627, 0.2353, 1}

#define WFBE_EOGS_Background 				{0.0784, 0.0902, 0.1059, 0.7}
#define WFBE_EOGS_SRVBBar 					{0.851, 0.4627, 0.2353, 1}
#define WFBE_EOGS_SLVLBar 					{0.851, 0.4627, 0.2353, 1}


//---Coloration
#define WFBE_Background_Color 				{0.0784, 0.0902, 0.1059, 0.7}
#define WFBE_Background_Color_Header 		{0.1647, 0.1843, 0.2118, 0.4}
#define WFBE_Background_Color_Footer 		{0.1647, 0.1843, 0.2118, 0.3}
#define WFBE_Background_Color_Sub			{0.1647, 0.1843, 0.2118, 0.3}
#define WFBE_Background_Color_Gear 			{0.5, 0.5, 0.5, 0.15}
#define WFBE_Background_Border 				{0.851, 0.4627, 0.2353, 1}
//---Thick
#define WFBE_Background_Border_Thick 		0.001


/* ListBox */
//---ListBox Coloration
#define WFBE_LBC_Select_Color 		{0.851, 0.4627, 0.2353, 1}


/* Separator */ 
//---Coloration
#define WFBE_SPC1 		{0.851, 0.4627, 0.2353, 1}
#define WFBE_SPC2 		{0.543, 0.5742, 0.4102, 1} //unused
//---Thick
#define WFBE_SPT1 		0.001
#define WFBE_SPT2 		0.0005 //unused

#define WFBE_Menu_Button_Color					{0.164705882, 0.184313725, 0.211764706, 0.7}
#define WFBE_Menu_Button_Text_Color				{0.905882353, 0.890196078, 0.839215686, 0.85}
#define WFBE_Menu_Button_Focused_Color			{0.850980392, 0.462745098, 0.235294118, 1}
#define WFBE_Menu_Button_Sub_Color				{0.360784314, 0.396078431, 0.211764706, 0.7}
#define WFBE_Menu_Button_Sub_Focused_Color		{0.486274510, 0.533333333, 0.286274510, 1}
#define WFBE_Menu_ListBox_Select_Color			{0.850980392, 0.462745098, 0.235294118, 1}
#define WFBE_Menu_Text_Color					{0.850980392, 0.462745098, 0.235294118, 1}
#define WFBE_Menu_Title_Color					{0.850980392, 0.462745098, 0.235294118, 1}
```

- [ ] **Step 2: Lint + assert no leftover blue, accent present**

Run:
```bash
python C:\Users\Steff\wasp-ui-lint.py "C:\Users\Steff\a2waspwarfare-opsconsole\Missions\[55-2hc]warfarev2_073v48co.chernarus\Rsc\Styles.hpp"
```
Expected: `OK`. Then grep the file for `0.2588, 0.7137` and `0.258823529` → expect **zero** matches; grep for `0.851, 0.4627` → expect ≥6 matches.

- [ ] **Step 3: Commit**

```bash
git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Styles.hpp"
git commit -m "feat(ui): brand palette — gunmetal/steel bodies, orange accent"
```

---

## Task 2: Base control templates — `Rsc\Ressources.hpp`

**Files:**
- Modify: `Missions\[55-2hc]warfarev2_073v48co.chernarus\Rsc\Ressources.hpp`

Apply these exact edits (each `old_string` is unique in the file):

- [ ] **Step 1: RscButton rest/active/focused → steel rest, orange focus, bone text**

Replace:
```c
	colorText[] = {1, 1, 1, 0.8};
	colorBackground[] = {0.5882, 0.5882, 0.3529, 0.7};
	colorBackgroundActive[] = {0.5882, 0.5882, 0.3529, 1};
	colorDisabled[] = {0.5, 0.5, 0.5, 0.8};
	colorBackgroundDisabled[] = {0, 0, 0, 0.6};
	offsetX = 0.003;
	offsetY = 0.003;
	offsetPressedX = 0.002;
	offsetPressedY = 0.002;
	colorFocused[] = {0.5882, 0.5882, 0.3529, 0.7};
```
with:
```c
	colorText[] = {0.9059, 0.8902, 0.8392, 0.9};
	colorBackground[] = {0.1647, 0.1843, 0.2118, 0.85};
	colorBackgroundActive[] = {0.851, 0.4627, 0.2353, 1};
	colorDisabled[] = {0.5, 0.5, 0.5, 0.6};
	colorBackgroundDisabled[] = {0.0784, 0.0902, 0.1059, 0.6};
	offsetX = 0.003;
	offsetY = 0.003;
	offsetPressedX = 0.002;
	offsetPressedY = 0.002;
	colorFocused[] = {0.7216, 0.3725, 0.1647, 0.9};
```

- [ ] **Step 2: RscShortcutButtonMain accent color → orange**

Replace `color[] = {0.2588, 0.7137, 1, 1};` (the one inside `class RscShortcutButtonMain`) with `color[] = {0.851, 0.4627, 0.2353, 1};`.

Note: `class RscShortcutButton` (the base) has `color[] = {0.543, 0.5742, 0.4102, 1.0};` — leave it; only the `Main` variant is the menu-grid accent.

- [ ] **Step 3: RscListBox accent (3 sites) → orange**

In `class RscListBox`, replace:
```c
	color[] = {0.2588, 0.7137, 1, 1};
	colorText[] = {1, 1, 0.75};
```
— actually replace each of these three lines individually:
- `	color[] = {0.2588, 0.7137, 1, 1};` → `	color[] = {0.851, 0.4627, 0.2353, 1};`
- `	colorSelectBackground[] = {0.2588, 0.7137, 1, 1};` → `	colorSelectBackground[] = {0.851, 0.4627, 0.2353, 1};`
- `	colorSelectBackground2[] = {0.2588, 0.7137, 1, 1};` → `	colorSelectBackground2[] = {0.851, 0.4627, 0.2353, 1};`

- [ ] **Step 4: RscText body text gold → bone**

Replace `	colorText[] = {0.9333, 0.8980, 0.5451, 0.9};` (in `class RscText`) → `	colorText[] = {0.9059, 0.8902, 0.8392, 0.9};`.
Replace `		colorText[] = {0.9333, 0.8980, 0.5451, 0.9};` (in `class RscText_Small`) → `		colorText[] = {0.9059, 0.8902, 0.8392, 0.9};`.

- [ ] **Step 5: RscText_Title / RscText_SubTitle accent → orange**

- In `class RscText_Title`: `	colorText[] = {0.2588, 0.7137, 1, 1};` → `	colorText[] = {0.851, 0.4627, 0.2353, 1};`
- In `class RscText_SubTitle`: `	colorText[] = {0.2588, 0.7137, 1, 0.9};` → `	colorText[] = {0.851, 0.4627, 0.2353, 0.9};`

- [ ] **Step 6: RscEdit + RscCombo selection accent → orange**

- RscEdit: `	colorSelection[] = {0.2588, 0.7137, 1, 1};` → `	colorSelection[] = {0.851, 0.4627, 0.2353, 1};`
- RscCombo: `	colorSelectBackground[] = {0.2588, 0.7137, 1, 1};` → `	colorSelectBackground[] = {0.851, 0.4627, 0.2353, 1};`
- RscCombo: `	color[] = {0.2588, 0.7137, 1, 1};` → `	color[] = {0.851, 0.4627, 0.2353, 1};`

- [ ] **Step 7: Lint + assert**

Run:
```bash
python C:\Users\Steff\wasp-ui-lint.py "C:\Users\Steff\a2waspwarfare-opsconsole\Missions\[55-2hc]warfarev2_073v48co.chernarus\Rsc\Ressources.hpp"
```
Expected: `OK`. Grep file for `0.5882, 0.5882, 0.3529` → expect zero; grep for `0.851, 0.4627` → expect ≥8. Confirm the RscMapControl block (lines ~563-850) is unchanged: grep `colorLevels[] = {0.65, 0.6, 0.45, 1}` → still present.

- [ ] **Step 8: Commit**

```bash
git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Ressources.hpp"
git commit -m "feat(ui): restyle base controls — steel buttons, orange accents, bone text"
```

---

## Task 3: HUD overlays — `Rsc\Titles.hpp`

**Files:**
- Modify: `Missions\[55-2hc]warfarev2_073v48co.chernarus\Rsc\Titles.hpp`

The HUD inherits the palette automatically; this task only swaps inline literals + adds the mono numeric font.

- [ ] **Step 1: Read the file and apply the tuple substitutions (S1, S3) to every match**

For every occurrence in `Titles.hpp`:
- `0.2588, 0.7137, 1` → `0.851, 0.4627, 0.2353` (S1)
- `0.9333, 0.8980, 0.5451` → `0.9059, 0.8902, 0.8392` (S3)

Use Grep to list every line containing `0.2588, 0.7137, 1` and `0.9333, 0.8980, 0.5451`, then Edit each. Do **not** touch any `RscText`/`RscPicture` geometry or the side-color runtime logic — colors only.

- [ ] **Step 2: Set the RUBHUD numeric value rows to the mono font**

The RUBHUD value controls are idc 1347, 1349, 1351, 1353, 1355, 1357, 1359, 1361, 1363, 1365, 1367 (the `_Value` rows). For each of those control classes in `OptionsAvailable`, add/override `font = "EtelkaMonospacePro";` (insert a `font=` line inside each class; if a `font=` already exists, replace it).

If a quick check shows the value rows inherit a shared base class, set `font` once on that base instead (DRY). Inspect the block first.

- [ ] **Step 3: Lint + assert**

Run:
```bash
python C:\Users\Steff\wasp-ui-lint.py "C:\Users\Steff\a2waspwarfare-opsconsole\Missions\[55-2hc]warfarev2_073v48co.chernarus\Rsc\Titles.hpp"
```
Expected: `OK`. Grep for `0.2588, 0.7137, 1` → expect zero; grep for `EtelkaMonospacePro` → expect ≥1.

- [ ] **Step 4: Commit**

```bash
git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Titles.hpp"
git commit -m "feat(ui): brand the always-on HUD — orange accents, mono numeric readouts"
```

---

## Task 4: Hero hub — `Rsc\Dialogs.hpp` (WF_Menu, idd 11000)

**Files:**
- Modify: `Missions\[55-2hc]warfarev2_073v48co.chernarus\Rsc\Dialogs.hpp` (WF_Menu block, lines ~1019-1231)

**Behavior must not change:** every `idc`, `action = "MenuAction = N"`, and button stays. Only add chevron + footer + title font.

- [ ] **Step 1: Add the chevron picture to `controlsBackground`**

Insert a new class as the last entry inside `WF_Menu >> class controlsBackground` (immediately before the closing `};` of `controlsBackground`, after `class Background_L { ... };`):

```c
		class Brand_Chevron : RscPicture {
			idc = -1;
			x = 0.18467;
			y = 0.19200;
			w = 0.030;
			h = 0.040;
			text = "Client\Images\brand_chevron.paa";
			colorText[] = {1, 1, 1, 1};
		};
```

If Task 0 produced a `.jpg`, set `text = "Client\Images\brand_chevron.jpg";` instead.

- [ ] **Step 2: Shift the title right of the chevron + use the display font**

Replace:
```c
		class TitleMenu: RscText_Title {
			idc = 11015;
			x = 0.178164;
			y = 0.19379;
			w = 0.800001;
			sizeEx = 0.035;
		};
```
with:
```c
		class TitleMenu: RscText_Title {
			idc = 11015;
			x = 0.221164;
			y = 0.19379;
			w = 0.560000;
			sizeEx = 0.038;
			font = "PuristaBold";
		};
```

- [ ] **Step 3: Add the subtle `miksuu.com` footer pointer**

Insert as the last control inside `WF_Menu >> class controls` (immediately before the closing `};` of `controls`, after the `CA_FPSHUD_Button` class):

```c
		class Brand_Footer : RscText {
			idc = -1;
			x = 0.61000;
			y = 0.76800;
			w = 0.20066;
			h = 0.040;
			style = 0x01;
			sizeEx = 0.022;
			font = "EtelkaMonospacePro";
			text = "miksuu.com";
			colorText[] = {0.851, 0.4627, 0.2353, 0.55};
		};
```

- [ ] **Step 4: Lint + assert behavior preserved**

Run:
```bash
python C:\Users\Steff\wasp-ui-lint.py "C:\Users\Steff\a2waspwarfare-opsconsole\Missions\[55-2hc]warfarev2_073v48co.chernarus\Rsc\Dialogs.hpp"
```
Expected: `OK`. Grep the WF_Menu block for `MenuAction = ` → expect the same count as before (16); grep for `brand_chevron` → expect 1; grep for `miksuu.com` → expect 1.

- [ ] **Step 5: Commit**

```bash
git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp"
git commit -m "feat(ui): hero hub — chevron header, display title font, subtle miksuu.com footer"
```

---

## Task 5: SQF structured-text accent swap

**Files:**
- Modify: `Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\GUI\*.sqf` (only files containing the blue hex)

- [ ] **Step 1: Find every accent-blue hex literal**

Run:
```bash
grep -rniE "#42b6ff" "C:/Users/Steff/a2waspwarfare-opsconsole/Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/"
```
Record the file list and match count (N).

- [ ] **Step 2: Replace `#42b6ff`/`#42B6FF` → `#d9763c` in each matched file**

Use Edit with `replace_all: true` per file. **Only** the hex color string changes — no other characters. Do **not** touch `#76F563` (green) or `#F56363` (red) — those are semantic.

- [ ] **Step 3: Lint each edited file + assert**

Run `wasp-ui-lint.py` on every edited `.sqf`. Expected: all `OK`. Then:
```bash
grep -rniE "#42b6ff" "C:/Users/Steff/a2waspwarfare-opsconsole/Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/"
```
Expected: zero matches.

- [ ] **Step 4: Commit**

```bash
git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/"
git commit -m "feat(ui): swap blue accent to orange in menu structured-text panels"
```

---

## Task 6: Mirror to Takistan

**Files:**
- Copy: the 4 `Rsc\*.hpp` + the chevron image + any edited `Client\GUI\*.sqf` from Chernarus → Takistan.

- [ ] **Step 1: Confirm whether LoadoutManager regenerates UI files**

Run:
```bash
grep -rniE "Styles.hpp|Ressources.hpp|Titles.hpp|Dialogs.hpp|Client.GUI|Client.Images" "C:/Users/Steff/a2waspwarfare-opsconsole/Tools/LoadoutManager" 2>/dev/null | head
```
If matches reference writing these files → note that LoadoutManager must be re-run instead of copying (and stop to flag the user). If no matches → the UI files are hand-copied twins; proceed to copy.

- [ ] **Step 2: Copy the edited UI files Chernarus → Takistan**

```powershell
$src = "C:\Users\Steff\a2waspwarfare-opsconsole\Missions\[55-2hc]warfarev2_073v48co.chernarus"
$dst = "C:\Users\Steff\a2waspwarfare-opsconsole\Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
Copy-Item "$src\Rsc\Styles.hpp"      "$dst\Rsc\Styles.hpp"      -Force
Copy-Item "$src\Rsc\Ressources.hpp"  "$dst\Rsc\Ressources.hpp"  -Force
Copy-Item "$src\Rsc\Titles.hpp"      "$dst\Rsc\Titles.hpp"      -Force
Copy-Item "$src\Rsc\Dialogs.hpp"     "$dst\Rsc\Dialogs.hpp"     -Force
Copy-Item "$src\Client\Images\brand_chevron.*" "$dst\Client\Images\" -Force
```
Then copy each `Client\GUI\*.sqf` that Task 5 edited (use the file list from Task 5 Step 1).

- [ ] **Step 3: Verify Chernarus/Takistan UI files are identical**

Run (PowerShell):
```powershell
foreach ($f in "Rsc\Styles.hpp","Rsc\Ressources.hpp","Rsc\Titles.hpp","Rsc\Dialogs.hpp") {
  $a = (Get-FileHash "$src\$f").Hash; $b = (Get-FileHash "$dst\$f").Hash
  "{0}: {1}" -f $f, ($(if ($a -eq $b) {"MATCH"} else {"DIFFER"}))
}
```
Expected: all `MATCH`.

- [ ] **Step 4: Commit**

```bash
git add "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
git commit -m "feat(ui): mirror ops-console reskin to Takistan mission"
```

---

## Task 7: Verify, mockup, draft PR

**Files:**
- Create: `docs/superpowers/mockups/wf-menu-ops-console.html` (visual reference for the user)

- [ ] **Step 1: Full static sweep**

Run `wasp-ui-lint.py` over all edited files (both missions). Expected: every line `OK`. Then grep both `Rsc\Styles.hpp` files for any remaining `{0, 0, 0, 0.7}` body-background macro → expect zero (gunmetal applied).

- [ ] **Step 2: Build the HTML mockup**

Create `docs/superpowers/mockups/wf-menu-ops-console.html` rendering the hub at the real 0–1 proportions with the brand palette (gunmetal body, steel header, orange chevron underline + title, the 10 buttons with steel rest / orange focus, bone labels, `miksuu.com` footer) so the user can see the intended look without launching the game.

- [ ] **Step 3: Push the branch**

```bash
cd "C:\Users\Steff\a2waspwarfare-opsconsole"
git push -u origin feat/wf-menu-ops-console
```

- [ ] **Step 4: Open the DRAFT PR on the private fork**

```bash
gh pr create --repo rayswaynl/a2waspwarfare --base master --head feat/wf-menu-ops-console --draft \
  --title "WF Menu — Ops-Console brand reskin + hero hub" \
  --body "<summary: token-layer reskin, dark gunmetal/steel + orange accent, chevron hub, mono HUD, splash untouched, behavior unchanged. Notes: pre-existing idd collisions 23000/10200 NOT introduced here. In-engine visual smoke pending (client-side).>"
```
Expected: a draft PR URL on `rayswaynl/a2waspwarfare` (never upstream Miksuu).

- [ ] **Step 5: Deliver the mockup + PR link to the user for the in-engine visual gate.**

---

## Self-Review

**Spec coverage:** §5 palette → Task 1 (S5–S7) + Tasks 2/3 (S1–S4). §6 fonts → Task 3 Step 2 (mono) + Task 4 Step 2 (PuristaBold). §7.1 Styles → Task 1. §7.2 Ressources → Task 2. §7.3 Titles/HUD → Task 3. §7.4 hub → Task 4. §7.5 SQF swap → Task 5 (S9). §8 chevron → Task 0. §9 Takistan → Task 6. §10 verify/mockup/draft-PR → Task 7. §5.1 dark/orange-sparing → encoded in the tuples (backgrounds gunmetal/steel, orange only on accents/focus). Splash explicitly untouched (no task edits `b2zgroup`/`loadScreen.jpg`). All covered.

**Placeholder scan:** the only deferred branch is Task 0 Step 4 (PAA tool present vs `.jpg` fallback) and Task 6 Step 1 (LoadoutManager check) — both have concrete commands and concrete both-branch actions, not placeholders. Task 3/Task 5 use "read then substitute" but with exact tuple/hex pairs, so the change is deterministic.

**Type/name consistency:** chevron path `Client\Images\brand_chevron.paa` (or `.jpg`) referenced identically in Task 0 and Task 4. Orange short form `0.851, 0.4627, 0.2353` and long form `0.850980392, 0.462745098, 0.235294118` used consistently. `MenuAction` codes never altered. Mission paths identical across tasks.

**Risks carried from spec §11:** font-name validity (fallback Zeppelin32), PAA toolchain (fallback .jpg), LoadoutManager twin question (Task 6 Step 1 gate), no assistant in-engine check (Task 7 Step 5 user gate).

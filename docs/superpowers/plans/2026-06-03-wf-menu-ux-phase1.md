# WF Menu UX — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A nicer, responsive main hub + safe mission-wide polish, **keeping the original blue/black/gold WFBE style** and changing no behaviour.

**Architecture:** Two non-geometric template fixes in `Ressources.hpp` (lift every dialog), then a full rebuild of the `WF_Menu` hub block in `Dialogs.hpp` — SafeZone coordinates, logical grouping with section headers, and a grouped Tools footer — preserving every IDC and `MenuAction`. Mirror to Takistan (verbatim twins).

**Tech Stack:** Arma 2 OA mission config (`.hpp`), SafeZone position expressions, `gh` for the draft PR. Lint via `C:\Users\Steff\wasp-ui-lint.py` (reliable for `.hpp`).

**Worktree:** `C:\Users\Steff\a2waspwarfare-uxphase1` (branch `feat/wf-menu-ux-phase1` off `origin/master` 2cdf5fb8).

**Paths:** Chernarus (source) `Missions\[55-2hc]warfarev2_073v48co.chernarus`; Takistan (mirror) `Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan`.

**Verification model:** no unit-test harness exists for Arma config; each task's "test" is `wasp-ui-lint.py` passing (balanced `{}`/`()`/`[]`, even `"`) + `grep` assertions (IDCs/actions preserved). In-engine visual confirmation is a user-run gate (UI is client-side).

---

## Task 1: Foundation polish — `Rsc\Ressources.hpp`

**Files:** Modify `Missions\[55-2hc]warfarev2_073v48co.chernarus\Rsc\Ressources.hpp`

- [ ] **Step 1: Fix the red scrollbar** (in `class RscListBox`)

Replace:
```c
	colorScrollbar[] = {0.95, 0, 0, 1};
```
with:
```c
	colorScrollbar[] = {0.6, 0.7, 0.8, 1};
```

- [ ] **Step 2: Give default buttons real hover feedback** (in `class RscButton`)

Replace:
```c
	colorFocused[] = {0.5882, 0.5882, 0.3529, 0.7};
```
with:
```c
	colorFocused[] = {0.72, 0.72, 0.45, 1};
```

- [ ] **Step 3: Lint + assert**

Run:
```bash
python C:/Users/Steff/wasp-ui-lint.py "C:/Users/Steff/a2waspwarfare-uxphase1/Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Ressources.hpp"
```
Expected: `OK`. Then grep the file: `{0.95, 0, 0, 1}` → 0 matches; `{0.72, 0.72, 0.45, 1}` → 1 match. Confirm map control intact: grep `colorLevels[] = {0.65, 0.6, 0.45, 1}` → 1 match.

- [ ] **Step 4: Commit**
```bash
cd "C:/Users/Steff/a2waspwarfare-uxphase1"
GIT_LITERAL_PATHSPECS=1 git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Ressources.hpp"
git commit -m "feat(ui): polish base controls — neutral scrollbar + real button hover feedback"
```

---

## Task 2: Hub redesign — `Rsc\Dialogs.hpp` (`WF_Menu`, idd 11000)

**Files:** Modify `Missions\[55-2hc]warfarev2_073v48co.chernarus\Rsc\Dialogs.hpp` — replace the **entire** `class WF_Menu { … };` block (currently ~lines 1019–1231) with the block below.

Behaviour is preserved: same dialog `idd`, same button IDCs, same 15 `MenuAction` codes, same `onLoad` → `GUI_Menu.sqf` untouched. Only layout (SafeZone) + grouping + section-header/Tools-label decoration (idc -1) change. The dynamic title (idc 11015) is kept. The Parameters icon (11012) moves from the header into the Tools cluster.

- [ ] **Step 1: Replace the whole `WF_Menu` block** with:

```c
//--- Main Menu. | UX redesign (Phase 1) — original style, SafeZone, grouped.
class WF_Menu {
	movingEnable = 1;
	idd = 11000;
	onLoad = "ExecVM ""Client\GUI\GUI_Menu.sqf""";

	class controlsBackground {
		class Background_M : RscText {
			x = "SafeZoneX + (SafeZoneW * 0.205)";
			y = "SafeZoneY + (SafeZoneH * 0.12)";
			w = "SafeZoneW * 0.59";
			h = "SafeZoneH * 0.76";
			moving = 1;
			colorBackground[] = WFBE_Background_Color;
		};
		class Background_H : RscText {
			x = "SafeZoneX + (SafeZoneW * 0.205)";
			y = "SafeZoneY + (SafeZoneH * 0.12)";
			w = "SafeZoneW * 0.59";
			h = "SafeZoneH * 0.05";
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class Background_F : RscText {
			x = "SafeZoneX + (SafeZoneW * 0.205)";
			y = "SafeZoneY + (SafeZoneH * 0.82)";
			w = "SafeZoneW * 0.59";
			h = "SafeZoneH * 0.05";
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class Background_L : RscText {
			x = "SafeZoneX + (SafeZoneW * 0.205)";
			y = "SafeZoneY + (SafeZoneH * 0.17)";
			w = "SafeZoneW * 0.59";
			h = "SafeZoneH * 0.0025";
			colorBackground[] = WFBE_Background_Border;
		};
	};
	class controls {
		/* Dynamic title — GUI_Menu.sqf writes uptime to idc 11015 */
		class TitleMenu : RscText_Title {
			idc = 11015;
			x = "SafeZoneX + (SafeZoneW * 0.220)";
			y = "SafeZoneY + (SafeZoneH * 0.128)";
			w = "SafeZoneW * 0.40";
			h = "SafeZoneH * 0.040";
			sizeEx = 0.040;
		};

		/* Section headers (decorative, idc -1) */
		class Sect_Purchase : RscText_SubTitle {
			idc = -1;
			x = "SafeZoneX + (SafeZoneW * 0.220)";
			y = "SafeZoneY + (SafeZoneH * 0.190)";
			w = "SafeZoneW * 0.27";
			h = "SafeZoneH * 0.028";
			sizeEx = 0.028;
			text = "PURCHASE";
		};
		class Sect_General : Sect_Purchase {
			y = "SafeZoneY + (SafeZoneH * 0.438)";
			text = "GENERAL";
		};
		class Sect_Command : Sect_Purchase {
			x = "SafeZoneX + (SafeZoneW * 0.520)";
			text = "COMMAND";
		};

		/* PURCHASE column (left) */
		class Button_A : RscShortcutButtonMain {
			idc = 11001;
			x = "SafeZoneX + (SafeZoneW * 0.215)";
			y = "SafeZoneY + (SafeZoneH * 0.222)";
			w = "SafeZoneW * 0.27";
			h = "SafeZoneH * 0.098";
			text = $STR_WF_MAIN_Purchase_Units;
			tooltip = $STR_WF_TOOLTIP_MainMenu_Purchase_Units;
			action = "MenuAction = 1";
		};
		class Button_B : RscShortcutButtonMain {
			idc = 11002;
			x = "SafeZoneX + (SafeZoneW * 0.215)";
			y = "SafeZoneY + (SafeZoneH * 0.328)";
			w = "SafeZoneW * 0.27";
			h = "SafeZoneH * 0.098";
			text = $STR_WF_MAIN_Purchase_Gear;
			tooltip = $STR_WF_TOOLTIP_MainMenu_Purchase_Gear;
			action = "MenuAction = 2";
		};

		/* GENERAL column (left) */
		class Button_C : RscShortcutButtonMain {
			idc = 11003;
			x = "SafeZoneX + (SafeZoneW * 0.215)";
			y = "SafeZoneY + (SafeZoneH * 0.470)";
			w = "SafeZoneW * 0.27";
			h = "SafeZoneH * 0.098";
			text = $STR_WF_MAIN_TeamMenu;
			tooltip = $STR_WF_TOOLTIP_MainMenu_TeamMenu;
			action = "MenuAction = 3";
		};
		class Button_I : RscShortcutButtonMain {
			idc = 11009;
			x = "SafeZoneX + (SafeZoneW * 0.215)";
			y = "SafeZoneY + (SafeZoneH * 0.576)";
			w = "SafeZoneW * 0.27";
			h = "SafeZoneH * 0.098";
			text = $STR_WF_SupportMenu;
			tooltip = $STR_WF_TOOLTIP_CommandMenu_SupportMenu;
			action = "MenuAction = 9";
		};
		class Button_J : RscShortcutButtonMain {
			idc = 11010;
			x = "SafeZoneX + (SafeZoneW * 0.215)";
			y = "SafeZoneY + (SafeZoneH * 0.682)";
			w = "SafeZoneW * 0.27";
			h = "SafeZoneH * 0.098";
			text = $STR_WF_HelpMenu;
			tooltip = $STR_WF_TOOLTIP_CommandMenu_Help;
			action = "MenuAction = 13";
		};

		/* COMMAND column (right) */
		class Button_E : RscShortcutButtonMain {
			idc = 11005;
			x = "SafeZoneX + (SafeZoneW * 0.515)";
			y = "SafeZoneY + (SafeZoneH * 0.222)";
			w = "SafeZoneW * 0.27";
			h = "SafeZoneH * 0.098";
			text = $STR_WF_MAIN_CommandMenu;
			tooltip = $STR_WF_TOOLTIP_CommandMenu_Commandteam;
			action = "MenuAction = 5";
		};
		class Button_F : RscShortcutButtonMain {
			idc = 11006;
			x = "SafeZoneX + (SafeZoneW * 0.515)";
			y = "SafeZoneY + (SafeZoneH * 0.334)";
			w = "SafeZoneW * 0.27";
			h = "SafeZoneH * 0.098";
			text = $STR_WF_MAIN_TacticalMenu;
			tooltip = $STR_WF_TOOLTIP_CommandMenu_SpecialMenu;
			action = "MenuAction = 6";
		};
		class Button_G : RscShortcutButtonMain {
			idc = 11007;
			x = "SafeZoneX + (SafeZoneW * 0.515)";
			y = "SafeZoneY + (SafeZoneH * 0.446)";
			w = "SafeZoneW * 0.27";
			h = "SafeZoneH * 0.098";
			text = $STR_WF_MAIN_UpgradeMenu;
			tooltip = $STR_WF_TOOLTIP_CommandMenu_Upgrade_Menu;
			action = "MenuAction = 7";
		};
		class Button_H : RscShortcutButtonMain {
			idc = 11008;
			x = "SafeZoneX + (SafeZoneW * 0.515)";
			y = "SafeZoneY + (SafeZoneH * 0.558)";
			w = "SafeZoneW * 0.27";
			h = "SafeZoneH * 0.098";
			text = $STR_WF_MAIN_EconomyMenu;
			tooltip = $STR_WF_TOOLTIP_CommandMenu_Commander_Menu;
			action = "MenuAction = 8";
		};
		class Button_D : RscShortcutButtonMain {
			idc = 11004;
			x = "SafeZoneX + (SafeZoneW * 0.515)";
			y = "SafeZoneY + (SafeZoneH * 0.670)";
			w = "SafeZoneW * 0.27";
			h = "SafeZoneH * 0.098";
			text = $STR_WF_MAIN_VotingMenu;
			tooltip = $STR_WF_TOOLTIP_MainMenu_VoteForCommander;
			action = "MenuAction = 4";
		};

		/* Tools footer cluster */
		class Tools_Label : RscText_SubTitle {
			idc = -1;
			x = "SafeZoneX + (SafeZoneW * 0.220)";
			y = "SafeZoneY + (SafeZoneH * 0.832)";
			w = "SafeZoneW * 0.05";
			h = "SafeZoneH * 0.026";
			sizeEx = 0.022;
			text = "TOOLS";
		};
		class CA_PA_Button : RscClickableText {
			idc = 11012;
			x = "SafeZoneX + (SafeZoneW * 0.262)";
			y = "SafeZoneY + (SafeZoneH * 0.827)";
			w = "SafeZoneW * 0.024";
			h = "SafeZoneH * 0.038";
			text = "\ca\ui\data\iconvehicle_ca.paa";
			action = "MenuAction = 12";
			tooltip = $STR_WF_TOOLTIP_Parameter;
		};
		class CA_UN_Button : RscClickableText {
			idc = 11013;
			x = "SafeZoneX + (SafeZoneW * 0.290)";
			y = "SafeZoneY + (SafeZoneH * 0.827)";
			w = "SafeZoneW * 0.024";
			h = "SafeZoneH * 0.038";
			text = "\ca\ui\data\stats_soft_ca.paa";
			action = "MenuAction = 10";
			tooltip = $STR_WF_TOOLTIP_Unflip;
		};
		class CA_HB_Button : RscClickableText {
			idc = 11014;
			x = "SafeZoneX + (SafeZoneW * 0.318)";
			y = "SafeZoneY + (SafeZoneH * 0.827)";
			w = "SafeZoneW * 0.024";
			h = "SafeZoneH * 0.038";
			text = "\ca\ui\data\editor_2d_camera_ca.paa";
			action = "MenuAction = 11";
			tooltip = $STR_WF_TOOLTIP_HeadBugFix;
		};
		class CA_HUD_Button : RscClickableText {
			idc = 11018;
			x = "SafeZoneX + (SafeZoneW * 0.346)";
			y = "SafeZoneY + (SafeZoneH * 0.827)";
			w = "SafeZoneW * 0.024";
			h = "SafeZoneH * 0.038";
			text = "Client\images\hud_bis.paa";
			action = "MenuAction = 16";
			tooltip = "ALL SCREEN HUD On/Off";
		};
		class CA_FPSHUD_Button : RscClickableText {
			idc = 11019;
			x = "SafeZoneX + (SafeZoneW * 0.374)";
			y = "SafeZoneY + (SafeZoneH * 0.827)";
			w = "SafeZoneW * 0.024";
			h = "SafeZoneH * 0.038";
			text = "Client\images\fps_hud.jpg";
			action = "MenuAction = 19";
			tooltip = "FPS HUD On/Off";
		};
		class Exit_Button : RscButton_Exit {
			x = "SafeZoneX + (SafeZoneW * 0.762)";
			y = "SafeZoneY + (SafeZoneH * 0.827)";
			w = "SafeZoneW * 0.030";
			h = "SafeZoneH * 0.040";
			onButtonClick = "closeDialog 0;";
			tooltip = $STR_WF_TOOLTIP_CloseButton;
		};
	};
};
```

- [ ] **Step 2: Lint + assert behaviour preserved**

Run:
```bash
python C:/Users/Steff/wasp-ui-lint.py "C:/Users/Steff/a2waspwarfare-uxphase1/Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp"
```
Expected: `OK`. Then, scoped to the WF_Menu block:
```bash
cd "C:/Users/Steff/a2waspwarfare-uxphase1"; F="Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp"
awk '/class WF_Menu \{/,/^};/' "$F" | grep -cE "MenuAction = "      # expect 15
awk '/class WF_Menu \{/,/^};/' "$F" | grep -oE "idc = 110[0-1][0-9]" | sort   # expect 11001..11010,11012,11013,11014,11015,11018,11019
awk '/class WF_Menu \{/,/^};/' "$F" | grep -cE "SafeZone"           # expect > 60
```
Expected: 15 actions; all original IDCs present; SafeZone used throughout.

- [ ] **Step 3: Commit**
```bash
GIT_LITERAL_PATHSPECS=1 git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp"
git commit -m "feat(ui): hub redesign — grouped sections, Tools footer, SafeZone responsive (original style)"
```

---

## Task 3: Mirror to Takistan

**Files:** Copy the two edited files Chernarus → Takistan (both are verbatim twins on `origin/master`; neither is LoadoutManager-content-modified — only `GUI_Menu_Help.sqf` is, and it's untouched here).

- [ ] **Step 1: Confirm twin status (pre-copy)**
```bash
cd "C:/Users/Steff/a2waspwarfare-uxphase1"; CH="Missions/[55-2hc]warfarev2_073v48co.chernarus"; TK="Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"
for f in Rsc/Ressources.hpp Rsc/Dialogs.hpp; do a=$(git show 2cdf5fb8:"$CH/$f"|git hash-object --stdin); b=$(git show 2cdf5fb8:"$TK/$f"|git hash-object --stdin); [ "$a" = "$b" ] && echo "TWIN $f" || echo "DIFFERS $f"; done
```
Expected: both `TWIN`. (If either DIFFERS, STOP and re-apply edits to the Takistan file instead of copying.)

- [ ] **Step 2: Copy both files**
```powershell
$ch = "C:\Users\Steff\a2waspwarfare-uxphase1\Missions\[55-2hc]warfarev2_073v48co.chernarus"
$tk = "C:\Users\Steff\a2waspwarfare-uxphase1\Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
foreach ($f in "Rsc\Ressources.hpp","Rsc\Dialogs.hpp") {
  Copy-Item -LiteralPath (Join-Path $ch $f) -Destination (Join-Path $tk $f) -Force
}
```

- [ ] **Step 3: Verify identical**
```bash
for f in Rsc/Ressources.hpp Rsc/Dialogs.hpp; do a=$(git hash-object "$CH/$f"); b=$(git hash-object "$TK/$f"); [ "$a" = "$b" ] && echo "IDENTICAL $f" || echo "DIFF $f"; done
```
Expected: both `IDENTICAL`.

- [ ] **Step 4: Commit**
```bash
GIT_LITERAL_PATHSPECS=1 git add "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
git commit -m "feat(ui): mirror Phase 1 hub + polish to Takistan"
```

---

## Task 4: Verify, mockup, draft PR

**Files:** Create `docs/superpowers/mockups/wf-menu-ux-phase1.html` (and copy the rendered PNG reference already produced).

- [ ] **Step 1: Full lint sweep** — both missions' `Rsc/Ressources.hpp` + `Rsc/Dialogs.hpp` via `wasp-ui-lint.py`. Expected: all `OK`.

- [ ] **Step 2: Commit the mockup** (reuse `C:\Users\Steff\_hub_v2_mock.html` → save as the docs mockup)
```bash
cp "C:/Users/Steff/_hub_v2_mock.html" "docs/superpowers/mockups/wf-menu-ux-phase1.html"
git add docs/superpowers/mockups/wf-menu-ux-phase1.html
git commit -m "docs: Phase 1 hub mockup"
```

- [ ] **Step 3: Push**
```bash
git push -u origin feat/wf-menu-ux-phase1
```

- [ ] **Step 4: Open the DRAFT PR**
```bash
gh pr create --repo rayswaynl/a2waspwarfare --base master --head feat/wf-menu-ux-phase1 --draft \
  --title "WF Menu UX — Phase 1: hub redesign + foundation polish (original style)" \
  --body-file "C:/Users/Steff/_pr_body_p1.md"
```
(Body file authored at ship time: summary of grouping/SafeZone/Tools-footer/scrollbar/hover; original style kept; behaviour unchanged; icons deferred; in-engine smoke pending; pre-existing idd collisions not touched.)

- [ ] **Step 5: Deliver PR link + mockup to user for the in-engine visual gate.**

---

## Self-Review

**Spec coverage:** §4.1 scrollbar → T1S1. §4.2 button hover → T1S2. §5.1 grouping → T2 (PURCHASE/GENERAL/COMMAND columns). §5.2 hierarchy/spacing → T2 (section headers, accent rule Background_L, even rhythm). §5.3 Tools footer → T2 (Tools_Label + 5 icons + Exit). §5.4 SafeZone → T2 (all controls). §6 icons deferred → not implemented (correct). §7 verify/mirror/PR → T2 asserts, T3, T4. §2 constraints: original palette (no colour macros touched), no behaviour (15 actions + IDCs asserted in T2S2), no perf (static hpp), splash untouched (no `b2zgroup` edit). All covered.

**Placeholder scan:** none — full hub block is literal; the PR body file is authored at ship time (noted), not a code placeholder.

**Type/name consistency:** every button IDC (11001–11010), utility IDC (11012/13/14/18/19), title IDC (11015) preserved from the original; `MenuAction` codes 1–13,16,19 unchanged; SafeZone expression form identical across all controls; new decorative controls use `idc = -1`. Section-header classes inherit `Sect_Purchase` consistently.

**Risk note:** button height 0.098 (vs original 0.1046) is close enough that `RscShortcutButtonMain`'s internal `TextPos` needs no change (verified by keeping the panel taller, 0.12–0.88). SafeZone centering to be confirmed in the user's in-engine smoke.

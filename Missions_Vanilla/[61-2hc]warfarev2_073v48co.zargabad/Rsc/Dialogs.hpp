/* Dialogs */

//--- WF3 Upgrade Menu.
class WFBE_UpgradeMenu {
	movingEnable = 1;
	idd = 504000;
	onLoad = "(_this) ExecVM 'Client\GUI\GUI_UpgradeMenu.sqf'";
	
	class controlsBackground {
		class CA_Background : RscText {
			x = 0;
			y = 0;
			w = 0.8;
			h = 0.8;
			colorBackground[] = WFBE_Background_Color;
			moving = 1;
		};
		class CA_Background_Header : CA_Background {
			x = 0;
			y = 0;
			w = 0.8;
			h = 0.06;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class CA_Background_Footer : CA_Background {
			x = 0;
			y = 0.76;
			w = 0.8;
			h = 0.04;
			colorBackground[] = WFBE_Background_Color_Sub;
		};
		class CA_Menu_Title : RscText_Title {
			x = 0.007;
			y = 0.01;
			w = 0.5;
			text = "Upgrade Menu :";
			colorText[] = WFBE_Menu_Title_Color;
		};
		class CA_Quit_Button: RscButton_Main {
			x = 0.75;
			y = 0.0075;
			w = 0.045;
			h = 0.045;
			text = "X";
			shadow = 2;
			sizeEx = 0.03;
			
			onButtonClick = "closeDialog 0;";
		};
		class CA_Back_Button : CA_Quit_Button {
			x = 0.695;
			text = "<<";
			onButtonClick = "WFBE_MenuAction = 1000;";
			tooltip = $STR_WF_TOOLTIP_BackButton;
		};
		class CA_Menu_Details : RscText {
			x = 0.345;
			y = 0.075;
			w = 0.45;
			h = 0.20;
			colorBackground[] = {0.5, 0.5, 0.5, 0.15};
			style = ST_TEXT_BG;
		};
		class CA_Menu_Links : CA_Menu_Details {
			y = 0.29;
			h = 0.16;
		};
		class CA_Menu_Desc : CA_Menu_Details {
			y = 0.465;
			h = 0.28;
		};
	};
	
	class controls {
		class CA_UpgradeList : RscListnBox {
			idc = 504001;
			x = 0.000983551;
			y = 0.065;
			w = 0.34;
			h = 0.69;
			columns[] = {0.01, 0.25, 0.75};
			rowHeight = 0.03;
			
			onLBDblClick = "WFBE_MenuAction = 1";
			onLBSelChanged = "WFBE_MenuAction = 2";
		};
		class CA_Icon : RscPicture {
			idc = 504002;
			x = 0.67;
			y = 0.095;
			w = 0.128;
			h = 0.128;
			style = 0x30 + 0x800;
		};
		class CA_UpgradeDetails : RscStructuredText {
			idc = 504003;
			x = 0.35;
			y = 0.08;
			w = 0.32;
			h = 0.195;
			size = 0.0260;
			shadow = 2;
			
			class Attributes {
				font = "Zeppelin32";
				color = "#E8F0FF";
				align = "left";
				shadow = true;
			};
		};
		class CA_UpgradeLinks : CA_UpgradeDetails {
			idc = 504004;
			y = 0.295;
			h = 0.155;
			w = 0.45;
		};
		class CA_UpgradeDesc : CA_UpgradeLinks {
			idc = 504005;
			y = 0.47;
			h = 0.275;
		};
		class CA_Upgrade : RscButton_Main {
			idc = 504007;
			x = 0.595;
			y = 0.762;
			w = 0.095;
			h = 0.035;
			sizeEx = 0.03;
			text = "Upgrade";
			action = "WFBE_MenuAction = 1";
		};
		class CA_QueueUpgrade : RscButton_Main {
			idc = 504008;
			x = 0.700;
			y = 0.762;
			w = 0.0625;
			h = 0.035;
			sizeEx = 0.028;
			text = "Queue";
			action = "WFBE_MenuAction = 3";
			tooltip = "Queue the next level of the selected upgrade (click again to stack more levels)";
		};
		// Stacking: queueing is no longer a toggle, so cancelling needs its own button.
		class CA_DequeueUpgrade : RscButton_Main {
			idc = 504009;
			x = 0.7675;
			y = 0.762;
			w = 0.0275;
			h = 0.035;
			sizeEx = 0.03;
			text = "-";
			action = "WFBE_MenuAction = 4";
			tooltip = "Remove the last queued level of the selected upgrade";
		};
		class CA_Details : CA_UpgradeDetails {
			idc = 504006;
			// Marty: Align the running-upgrade status with the Upgrade button while keeping enough height for the countdown.
			x = 0.01;
			y = 0.748;
			w = 0.56;
			h = 0.047;
			size = 0.0250;
			shadow = 2;
		};
	};
};

//--- WF3 Vote Menu.
class WFBE_VoteMenu {
	movingEnable = 1;
	idd = 500000;
	onLoad = "(_this) ExecVM 'Client\GUI\GUI_VoteMenu.sqf'";
	
	class controlsBackground {
		class CA_Background : RscText {
			x = 0.273;
			y = 0.134;
			w = 0.5;
			h = 0.8;
			colorBackground[] = WFBE_Background_Color;
			moving = 1;
		};
		class CA_Background_Header : CA_Background {
			x = 0.273;
			y = 0.134;
			w = 0.5;
			h = 0.06;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class CA_Background_Footer : CA_Background {
			x = 0.273;
			y = 0.134 + 0.76;
			w = 0.5;
			h = 0.04;
			colorBackground[] = WFBE_Background_Color_Sub;
		};
		class CA_Menu_Title : RscText_Title {
			x = 0.28;
			y = 0.134 + 0.01;
			w = 0.5;
			text = $STR_WF_VOTING_Title;
			colorText[] = WFBE_Menu_Title_Color;
		};
		class CA_Quit_Button: RscButton_Main {
			x = 0.273 + 0.45;
			y = 0.134 + 0.0075;
			w = 0.045;
			h = 0.045;
			text = "X";
			shadow = 2;
			sizeEx = 0.03;
			
			onButtonClick = "closeDialog 0;";
		};
	};
	
	class controls {
		class CA_Vote_List : RscListnBox {
			idc = 500100;
			x = 0.28;
			y = 0.134 + 0.07;
			w = 0.489;
			h = 0.665;
			columns[] = {0.01, 0.75};
			
			colorSelectBackground[] = WFBE_Menu_ListBox_Select_Color;
			colorSelectBackground2[] = WFBE_Menu_ListBox_Select_Color;
			
			onLBSelChanged = "WFBE_MenuAction = 1";
		};
		class CA_Menu_TimeLeft : RscText {
			idc = 500101;
			x = 0.28;
			y = 0.134 + 0.762;
			w = 0.25;
			sizeEx = 0.03;
			text = "";
			colorText[] = WFBE_Menu_Text_Color;
			shadow = 2;
		};
		class CA_Menu_Elected : CA_Menu_TimeLeft {
			idc = 500102;
			x = 0.273 + 0.20;
			y = 0.134 + 0.762;
			w = 0.3;
			style = ST_RIGHT;
			text = "";
		};
		class CA_Menu_Time_Static : CA_Menu_TimeLeft {
			idc = 500103;
			x = 0.273 + 0.16;
			y = 0.134 + 0.762;
			w = 0.3;
			style = ST_RIGHT;
			text = $STR_WF_VOTING_TimeLeft;
		};
	};
};

//--- WF3 Commander Vote Menu.
class WFBE_Commander_VoteMenu {
	movingEnable = 1;
	idd = 500999;
	onLoad = "(_this) ExecVM 'Client\GUI\GUI_Commander_VoteMenu.sqf'";
	
	class controlsBackground {
		class CA_Background : RscText {
			x = 0.273;
			y = 0.134;
			w = 0.5;
			h = 0.8;
			colorBackground[] = WFBE_Background_Color;
			moving = 1;
		};
		class CA_Background_Header : CA_Background {
			x = 0.273;
			y = 0.134;
			w = 0.5;
			h = 0.06;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class CA_Background_Footer : CA_Background {
			x = 0.273;
			y = 0.134 + 0.76;
			w = 0.5;
			h = 0.04;
			colorBackground[] = WFBE_Background_Color_Sub;
		};
		class CA_Menu_Title : RscText_Title {
			x = 0.28;
			y = 0.134 + 0.01;
			w = 0.5;
			text = $STR_WF_VOTING_Title;
			colorText[] = WFBE_Menu_Title_Color;
		};
		class CA_Quit_Button: RscButton_Main {
			x = 0.273 + 0.45;
			y = 0.134 + 0.0075;
			w = 0.045;
			h = 0.045;
			text = "X";
			shadow = 2;
			sizeEx = 0.03;
			
			onButtonClick = "closeDialog 0;";
		};
	};
	
	class controls {
		class CA_Vote_List : RscListnBox {
			idc = 509100;
			x = 0.28;
			y = 0.134 + 0.07;
			w = 0.489;
			h = 0.6;
			columns[] = {0.01};
			
			colorSelectBackground[] = WFBE_Menu_ListBox_Select_Color;
			colorSelectBackground2[] = WFBE_Menu_ListBox_Select_Color;
			
			onLBSelChanged = "WFBE_MenuAction = 1";
		};

		class CA_Set_New_Commander : RscButton_Main {
			idc = 509101;
			x = 0.28;
			y = 0.85;
			w = 0.489;
			h = 0.035;
			sizeEx = 0.035;
			text = $STR_WF_SetNewCommander;
			action = "WFBE_MenuAction = 2";
		};		
	};
};

//--- WF3 Respawn menu.
class WFBE_RespawnMenu {
	movingEnable = 1;
	idd = 511000;
	onLoad = "(_this) ExecVM 'Client\GUI\GUI_RespawnMenu.sqf'";
	
	class controlsBackground {
		class CA_Background : RscText {
			x = 0;
			y = 0;
			w = 1;
			h = 1;
			colorBackground[] = WFBE_Background_Color;
			moving = 1;
		};
		class CA_Background_Header : CA_Background {
			x = 0;
			y = 0;
			w = 1;
			h = 0.06;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class CA_Background_Footer : CA_Background {
			x = 0;
			y = 0.96;
			w = 1;
			h = 0.04;
			colorBackground[] = WFBE_Background_Color_Sub;
		};
		class CA_Menu_Title : RscText_Title {
			x = 0.007;
			y = 0.01;
			w = 0.5;
			text = $STR_WF_RESPAWN_Title;
			colorText[] = WFBE_Menu_Title_Color;
		};
		class CA_Quit_Button: RscButton_Main {
			x = 0.95;
			y = 0.0075;
			w = 0.045;
			h = 0.045;
			text = "X";
			shadow = 2;
			sizeEx = 0.03;
			
			onButtonClick = "closeDialog 0;";
		};
	};
	
	class controls {
		class WF_MiniMap : RscMapControl {
			idc = 511001;
			x = 0.01;
			y = 0.07;
			w = 0.98;
			h = 0.8;
			ShowCountourInterval = 1;
			
			onMouseMoving = "mouseX = (_this Select 1);mouseY = (_this Select 2)";
			onMouseButtonDown = "mouseButtonDown = _this select 1;";
			onMouseButtonUp = "mouseButtonUp = _this select 1;";
		};
		class CA_RespawnDetails : RscStructuredText {
			idc = 511002;
			x = 0.01;
			y = 0.965;
			w = 0.49;
			h = 0.13;
			
			size = 0.0275;
			shadow = 2;
		};
		class CA_RespawnDelay : CA_RespawnDetails {
			idc = 511003;
			x = 0.5;
			w = 0.49;
			h = 0.13;
		};
		class CA_Gear_Button : RscButton {
			idc = 511004;
			x = 0.68;
			y = 0.00940119;
			w = 0.25;
			sizeEx = 0.03221;
			
			colorBackground[] = WFBE_Menu_Button_Sub_Color;
			colorBackgroundActive[] = WFBE_Menu_Button_Sub_Color;
			colorFocused[] = WFBE_Menu_Button_Sub_Focused_Color;
			
			tooltip = $STR_WF_TOOLTIP_RespawnDefault;
			onButtonClick = "WFBE_MenuAction = 1;";
		};
		//--- respawn-ui-v2: footer legend strip (IDC 511005).
		//--- Sits in the map/label gap (y=0.923), above the countdown/location labels at y=0.965.
		//--- Static text - no SQF loop needed; localised via STR_WF_RESPAWN_Legend.
		//--- Hidden at menu open when WFBE_C_RESPAWN_UI_V2=0 (SQF-controlled visibility).
		class CA_RespawnLegend : RscStructuredText {
			idc = 511005;
			show = 0;
			x = 0.01;
			y = 0.923;
			w = 0.66;
			h = 0.035;
			size = 0.022;
			shadow = 1;
			text = $STR_WF_RESPAWN_Legend;
		};
	};
};

//--- WF3 Funds Menu.
class WFBE_TransferMenu {
	movingEnable = 1;
	idd = 505000;
	onLoad = "(_this) ExecVM 'Client\GUI\GUI_TransferMenu.sqf'";
	
	class controlsBackground {
		class CA_Background : RscText {
			x = 0;
			y = 0;
			w = 0.8;
			h = 0.6;
			colorBackground[] = WFBE_Background_Color;
			moving = 1;
		};
		class CA_Background_Header : CA_Background {
			x = 0;
			y = 0;
			w = 0.8;
			h = 0.06;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class CA_Background_Footer : CA_Background {
			x = 0;
			y = 0.56;
			w = 0.8;
			h = 0.04;
			colorBackground[] = WFBE_Background_Color_Sub;
		};
		class CA_Menu_Title : RscText_Title {
			x = 0.007;
			y = 0.01;
			w = 0.5;
			text = $STR_WF_MAIN_FundsMenu;
			colorText[] = WFBE_Menu_Title_Color;
		};
		class CA_Quit_Button: RscButton_Main {
			x = 0.75;
			y = 0.0075;
			w = 0.045;
			h = 0.045;
			text = "X";
			shadow = 2;
			sizeEx = 0.03;
			
			onButtonClick = "closeDialog 0;";
		};
		class CA_Menu_Details : RscText {
			x = 0.405;
			y = 0.075;
			w = 0.385;
			h = 0.18;
			colorBackground[] = {0.5, 0.5, 0.5, 0.15};
			style = ST_TEXT_BG;
		};
		class CA_Edit_BG : RscText {
			x = 0.415;
			y = 0.165;
			w = 0.15;
			colorBackground[] = WFBE_Background_Color_Header;
		};
	};
	
	class controls {
		class CA_TransferList : RscListnBox {
			idc = 505001;
			x = 0.000983551;
			y = 0.065;
			w = 0.4;
			h = 0.488;
			columns[] = {0.01, 0.3, 0.75};
			rowHeight = 0.03;
			
			onLBDblClick = "WFBE_MenuAction = 1";
		};
		class CA_Send : RscButton_Main {
			x = 0.595;
			y = 0.562;
			w = 0.2;
			h = 0.035;
			sizeEx = 0.035;
			text = $STR_WF_Send;
			tooltip = "Send the selected amount to the highlighted player";
			action = "WFBE_MenuAction = 1";
		};
		class CA_AmountDetails : RscText {
			x = 0.415;
			y = 0.08;
			w = 0.2;
			sizeEx = 0.030;
			text = $STR_WF_Amount;
		};
		class CA_Funds_Slider : RscXSliderH {
			idc = 505002;
			x = 0.415;
			y = 0.12;
			w = 0.365;
			h = 0.029412;
			
			onSliderPosChanged = "WFBE_MenuAction = 2";
		};
		class CA_Funds_Edit : RscEdit {
			idc = 505003;
			x = 0.415;
			y = 0.165;
			w = 0.15;
			text = "0";
			sizeEx = 0.035;
		};
		class CA_Funds : RscStructuredText {
			idc = 505004;
			x = 0.415;
			y = 0.21;
			w = 0.38;
			h = 0.075;
			size = 0.03;

			colorText[] = {0.543, 0.5742, 0.4102, 1.0};
		};
		//--- UX Pass 1: Back to WF_Menu hub. WFBE_MenuAction 3 handled in GUI_TransferMenu.sqf.
		class CA_Back_Button : RscButton_Back {
			x = 0.0;
			y = 0.562;
			onButtonClick = "WFBE_MenuAction = 3;";
			tooltip = $STR_WF_TOOLTIP_BackButton;
		};
	};
};

//--- WF3 Gear Menu.
class WFBE_BuyGearMenu {
	movingEnable = 1;
	idd = 503000;
	onLoad = "(_this) ExecVM 'Client\GUI\GUI_BuyGearMenu.sqf'";
	
	class controlsBackground {
		class CA_Background : RscText {
			x = 0;
			y = 0;
			w = 1;
			h = 1;
			colorBackground[] = WFBE_Background_Color;
			moving = 1;
		};
		class CA_Background_Header : CA_Background {
			x = 0;
			y = 0;
			w = 1;
			h = 0.06;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class CA_Background_Footer : CA_Background {
			x = 0;
			y = 0.96;
			w = 1;
			h = 0.04;
			colorBackground[] = WFBE_Background_Color_Sub;
		};
		class CA_Menu_Title : RscText_Title {
			x = 0.007;
			y = 0.01;
			w = 0.5;
			text = "Gear Purchase Menu :";
			tooltip = "Buy gear, manage templates, and edit unit or vehicle cargo";
			colorText[] = WFBE_Menu_Title_Color;
		};
		class CA_Menu_Gear : RscText {
			x = 0.5;
			y = 0.06;
			w = 0.5;
			h = 0.9;
			colorBackground[] = {0.5, 0.5, 0.5, 0.15};
		};
		class LineTRH1 : RscText {
			x = 0;
			y = 0.768;
			w = 0.5;
			h = 0.001;
			colorBackground[] = {0.2588, 0.7137, 1, 0.7};
		};
		class CA_Label_View : RscText {
			x = 0.01;
			y = 0.195;
			w = 0.20;
			text = "View:";
			sizeEx = 0.035;
		};
		class CA_Label_Target : CA_Label_View {
			y = 0.15;
			text = "Target:";
		};
		class CA_Quit_Button: RscButton_Main {
			x = 0.95;
			y = 0.0075;
			w = 0.045;
			h = 0.045;
			text = "X";
			shadow = 2;
			sizeEx = 0.03;
			
			onButtonClick = "closeDialog 0;";
		};
		class CA_Back_Button : CA_Quit_Button {
			x = 0.895;
			text = "<<";
			onButtonClick = "WFBE_MenuAction = 1000;";
			tooltip = $STR_WF_TOOLTIP_BackButton;
		};
	};
	
	class controls {
		class CA_GearList : RscListnBox {
			idc = 503001;
			x = 0.000983551;
			// y = 0.24;
			y = 0.28;
			w = 0.493697;
			// h = 0.505;
			h = 0.48;
			columns[] = {0.01, 0.25, 0.75};
			rowHeight = 0.03;
			
			onLBDblClick = "WFBE_MenuAction = 1";
			onLBSelChanged = "WFBE_MenuAction = 2";
		};
		class CA_AmmoList : CA_GearList {
			idc = 503002;
			// y = 0.76;
			y = 0.775;
			// h = 0.195;
			h = 0.180;
			
			onLBDblClick = "WFBE_MenuAction = 3";
		};
		class CA_Combo_View : RscCombo {
			idc = 503003;
			x = 0.15;
			y = 0.195;
			w = 0.34;
			h = 0.037;
			onLBSelChanged = "WFBE_MenuAction = 301";
		};
		class CA_Combo_Target : CA_Combo_View {
			idc = 503004;
			y = 0.15;
			onLBSelChanged = "WFBE_MenuAction = 302";
		};
		class FilterButtonTemplate : RscClickableText {
			idc = 503301;
			style = 48 + 0x800;
			x = 0.00642873;
			y = 0.034482;
			w = 0.0699999;
			h = 0.11;
			text = "Client\Images\gearicontemplate.paa";
			tooltip = $STR_WF_TOOLTIP_FilterButtonTemplate;
			action = "UINamespace setVariable ['wfbe_display_buygear_tab', 0];";
		};
		class FilterButtonAll : FilterButtonTemplate {
			idc = 503302;
			x = 0.0814287;
			text = "Client\Images\geariconall.paa";
			tooltip = $STR_WF_TOOLTIP_FilterButtonAll;
			action = "UINamespace setVariable ['wfbe_display_buygear_tab', 1];";
		};
		class FilterButtonPrimary : FilterButtonTemplate {
			idc = 503303;
			x = 0.16979;
			text = "Client\Images\geariconprimary.paa";
			tooltip = $STR_WF_TOOLTIP_FilterButtonPrimary;
			action = "UINamespace setVariable ['wfbe_display_buygear_tab', 2];";
		};
		class FilterButtonSecondary : FilterButtonTemplate {
			idc = 503304;
			x = 0.259109;
			text = "Client\Images\geariconsecondary.paa";
			tooltip = $STR_WF_TOOLTIP_FilterButtonSecondary;
			action = "UINamespace setVariable ['wfbe_display_buygear_tab', 3];";
		};
		class FilterButtonSidearm : FilterButtonTemplate {
			idc = 503305;
			x = 0.33979;
			text = "Client\Images\geariconsidearm.paa";
			tooltip = $STR_WF_TOOLTIP_FilterButtonSidearm;
			action = "UINamespace setVariable ['wfbe_display_buygear_tab', 4];";
		};
		class FilterButtonMisc : FilterButtonTemplate {
			idc = 503306;
			x = 0.421555;
			text = "Client\Images\geariconmisc.paa";
			tooltip = $STR_WF_TOOLTIP_FilterButtonMisc;
			action = "UINamespace setVariable ['wfbe_display_buygear_tab', 5];";
		};
		class PrimaryWeapon : RscClickableText {
			idc = 503401;
			x = 0.502842;
			y = 0.200302;
			w = 0.310369;
			h = 0.198179;
			style = 48 + 0x800;
			soundDoubleClick[] = {"", 0.1, 1};
			colorBackground[] = {0.6, 0.83, 0.47, 1};
			colorBackgroundSelected[] = {0.6, 0.83, 0.47, 1};
			colorFocused[] = {0, 0, 0, 0};
			color[] = {0.85, 0.85, 0.85, 1};
			colorText[] = {0.85, 0.85, 0.85, 1};
			colorActive[] = {1, 1, 1, 1};
			text = "\Ca\UI\Data\ui_gear_gun_gs.paa";
			tooltip = "Remove the current primary weapon from the loadout";
			action = "WFBE_MenuAction = 901";
		};
		class SecondaryWeapon : PrimaryWeapon {
			idc = 503402;
			y = 0.401362;
			text = "\Ca\UI\Data\ui_gear_sec_gs.paa";
			tooltip = "Remove the current launcher, backpack, or secondary weapon";
			action = "WFBE_MenuAction = 902";
		};
		class Sidearm : PrimaryWeapon {
			idc = 503403;
			x = 0.576806;
			y = 0.607022;
			w = 0.113;
			h = 0.15;
			text = "\Ca\UI\Data\ui_gear_hgun_gs.paa";
			tooltip = "Remove the current sidearm from the loadout";
			action = "WFBE_MenuAction = 903";
		};
		class InventorySlot0 : RscClickableText {
			idc = 503501;
			x = 0.816052;
			y = 0.250721;
			w = 0.06;
			h = 0.08;
			text = "\Ca\UI\Data\ui_gear_mag_gs.paa";
			tooltip = "Remove a primary weapon magazine from the loadout";
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_main', 1]";
		};
		class InventorySlot1 : InventorySlot0 {
			idc = 503502;
			x = 0.878093;
			y = 0.250721;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_main', 2]";
		};
		class InventorySlot2 : InventorySlot0 {
			idc = 503503;
			x = 0.940501;
			y = 0.250721;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_main', 3]";
		};
		class InventorySlot3 : InventorySlot0 {
			idc = 503504;
			x = 0.816052;
			y = 0.341169;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_main', 4]";
		};
		class InventorySlot4 : InventorySlot0 {
			idc = 503505;
			x = 0.878093;
			y = 0.341169;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_main', 5]";
		};
		class InventorySlot5 : InventorySlot0 {
			idc = 503506;
			x = 0.940501;
			y = 0.341169;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_main', 6]";
		};
		class InventorySlot6 : InventorySlot0 {
			idc = 503507;
			x = 0.816052;
			y = 0.429373;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_main', 7]";
		};
		class InventorySlot7 : InventorySlot0 {
			idc = 503508;
			x = 0.878093;
			y = 0.429373;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_main', 8]";
		};
		class InventorySlot8 : InventorySlot0 {
			idc = 503509;
			x = 0.940501;
			y = 0.429373;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_main', 9]";
		};
		class InventorySlot9 : InventorySlot0 {
			idc = 503510;
			x = 0.816052;
			y = 0.519938;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_main', 10]";
		};
		class InventorySlot10 : InventorySlot0 {
			idc = 503511;
			x = 0.878093;
			y = 0.519938;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_main', 11]";
		};
		class InventorySlot11 : InventorySlot0 {
			idc = 503512;
			x = 0.940501;
			y = 0.519938;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_main', 12]";
		};
		class SidearmInventorySlot0 : RscClickableText {
			idc = 503513;
			x = 0.695848;
			y = 0.607022;
			w = 0.055;
			h = 0.074;
			text = "\Ca\UI\Data\ui_gear_hgunmag_gs.paa";
			tooltip = "Remove a sidearm magazine from the loadout";
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_gun', 1]";
		};
		class SidearmInventorySlot1 : SidearmInventorySlot0 {
			idc = 503514;
			x = 0.75653;
			y = 0.607022;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_gun', 2]";
		};
		class SidearmInventorySlot2 : SidearmInventorySlot0 {
			idc = 503515;
			x = 0.816892;
			y = 0.607022;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_gun', 3]";
		};
		class SidearmInventorySlot3 : SidearmInventorySlot0 {
			idc = 503516;
			x = 0.877253;
			y = 0.607022;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_gun', 4]";
		};
		class SidearmInventorySlot4 : SidearmInventorySlot0 {
			idc = 503517;
			x = 0.695848;
			y = 0.688504;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_gun', 5]";
		};
		class SidearmInventorySlot5 : SidearmInventorySlot0 {
			idc = 503518;
			x = 0.756529;
			y = 0.688504;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_gun', 6]";
		};
		class SidearmInventorySlot6 : SidearmInventorySlot0 {
			idc = 503519;
			x = 0.816892;
			y = 0.688504;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_gun', 7]";
		};
		class SidearmInventorySlot7 : SidearmInventorySlot0 {
			idc = 503520;
			x = 0.877252;
			y = 0.688505;
			action = "UINamespace setVariable ['wfbe_display_buygear_pool_gun', 8]";
		};
		class MiscInventorySlot0 : RscClickableText {
			idc = 503521;
			x = 0.575126;
			y = 0.774467;
			w = 0.055;
			h = 0.074;
			colorActive[] = {0.85, 0.85, 0.85, 1};
			text = "\Ca\UI\Data\ui_gear_eq_gs.paa";
			tooltip = "Remove an equipment item from the loadout";
			action = "UINamespace setVariable ['wfbe_display_buygear_misc', 0]";
		};
		class MiscInventorySlot1 : MiscInventorySlot0 {
			idc = 503522;
			x = 0.635487;
			y = 0.774468;
			action = "UINamespace setVariable ['wfbe_display_buygear_misc', 1]";
		};
		class MiscInventorySlot2 : MiscInventorySlot0 {
			idc = 503523;
			x = 0.695848;
			y = 0.774468;
			action = "UINamespace setVariable ['wfbe_display_buygear_misc', 2]";
		};
		class MiscInventorySlot3 : MiscInventorySlot0 {
			idc = 503524;
			x = 0.75653;
			y = 0.774468;
			action = "UINamespace setVariable ['wfbe_display_buygear_misc', 3]";
		};
		class MiscInventorySlot4 : MiscInventorySlot0 {
			idc = 503525;
			x = 0.816892;
			y = 0.774468;
			action = "UINamespace setVariable ['wfbe_display_buygear_misc', 4]";
		};
		class MiscInventorySlot5 : MiscInventorySlot0 {
			idc = 503526;
			x = 0.877252;
			y = 0.774468;
			action = "UINamespace setVariable ['wfbe_display_buygear_misc', 5]";
		};
		class MiscInventorySlot6 : MiscInventorySlot0 {
			idc = 503527;
			x = 0.575126;
			y = 0.85595;
			action = "UINamespace setVariable ['wfbe_display_buygear_misc', 6]";
		};
		class MiscInventorySlot7 : MiscInventorySlot0 {
			idc = 503528;
			x = 0.635487;
			y = 0.85595;
			action = "UINamespace setVariable ['wfbe_display_buygear_misc', 7]";
		};
		class MiscInventorySlot8 : MiscInventorySlot0 {
			idc = 503529;
			x = 0.695848;
			y = 0.85595;
			action = "UINamespace setVariable ['wfbe_display_buygear_misc', 8]";
		};
		class MiscInventorySlot9 : MiscInventorySlot0 {
			idc = 503530;
			x = 0.75653;
			y = 0.85595;
			action = "UINamespace setVariable ['wfbe_display_buygear_misc', 9]";
		};
		class MiscInventorySlot10 : MiscInventorySlot0 {
			idc = 503531;
			x = 0.816892;
			y = 0.85595;
			action = "UINamespace setVariable ['wfbe_display_buygear_misc', 10]";
		};
		class MiscInventorySlot11 : MiscInventorySlot0 {
			idc = 503532;
			x = 0.877253;
			y = 0.85595;
			action = "UINamespace setVariable ['wfbe_display_buygear_misc', 11]";
		};
		class SpecialInventorySlot0 : InventorySlot0 {
			idc = 503533;
			x = 0.507043;
			y = 0.0586288;
			w = 0.11384;
			h = 0.136554;
			colorActive[] = {0.85, 0.85, 0.85, 1};
			text = "\Ca\UI\Data\ui_gear_eq_gs.paa";
			tooltip = "Remove the first special item from the loadout";
			action = "WFBE_MenuAction = 904";
		};
		class SpecialInventorySlot1 : SpecialInventorySlot0 {
			idc = 503534;
			x = 0.880612;
			y = 0.0575075;
			tooltip = "Remove the second special item from the loadout";
			action = "WFBE_MenuAction = 905";
		};
		class CA_CargoList : CA_GearList {
			idc = 503005;
			x = 0.500983551;
			w = 0.493697;
			h = 0.505;
			tooltip = "Double-click a cargo item to remove it from the selected container";
			
			onLBDblClick = "WFBE_MenuAction = 906";
		};
		class CA_CargoDetails : RscStructuredText {
			idc = 503006;
			x = 0.500983551;
			y = 0.08;
			w = 0.24;
			h = 0.13;
			size = 0.0250;
			shadow = 2;
		};
		class CA_CargoDetails2 : CA_CargoDetails {
			idc = 503007;
			x = 0.755983551;
		};
		class CA_Purchase : RscButton_Main {
			x = 0.875;
			y = 0.962;
			w = 0.12;
			h = 0.035;
			sizeEx = 0.035;
			text = "Buy";
			tooltip = "Buy the selected loadout for the current target";
			action = "WFBE_MenuAction = 501";
		};
		class CA_PurchaseDetails : CA_CargoDetails {
			idc = 503008;
			x = 0.51;
			y = 0.965;
			w = 0.3;
			h = 0.13;
		};
		class CA_MakeTemplate : CA_Purchase {
			idc = 503009;
			x = 0.005;
			w = 0.24;
			sizeEx = 0.03221;
			
			colorBackground[] = WFBE_Menu_Button_Sub_Color;
			colorBackgroundActive[] = WFBE_Menu_Button_Sub_Color;
			colorFocused[] = WFBE_Menu_Button_Sub_Focused_Color;
			
			text = "Create Template";
			tooltip = "Save the current loadout as a reusable template";
			action = "WFBE_MenuAction = 601";
		};
		class CA_DeleteTemplate : CA_MakeTemplate {
			idc = 503010;
			x = 0.255;
			text = "Delete Template";
			tooltip = "Delete the highlighted gear template";
			action = "WFBE_MenuAction = 602";
		};
		class CA_FundsDetails : CA_CargoDetails {
			idc = 503011;
			x = 0.01;
			y = 0.245;
			w = 0.3;
			h = 0.13;
		};
		class CA_QuickReload : CA_MakeTemplate {
			idc = 503012;
			x = 0.505;
			y = 0.01;
			w = 0.17;
			text = "Reload";
			tooltip = $STR_WF_TOOLTIP_GearReload;
			action = "WFBE_MenuAction = 701";
		};
		class CA_QuickClear : CA_MakeTemplate {
			idc = 503013;
			x = 0.685;
			y = 0.01;
			w = 0.17;
			text = "Clear";
			tooltip = $STR_WF_TOOLTIP_GearClear;
			action = "WFBE_MenuAction = 702";
		};
	};
};

//--- Main Menu. | ALL DONE!
class WF_Menu {
	movingEnable = 1;
	idd = 11000;
	onLoad = "ExecVM ""Client\GUI\GUI_Menu.sqf""";

	class controlsBackground {
		class Background_M : RscText {
			x = 0.17467;
			y = 0.186955;
			w = 0.65066;
			h = 0.63192;
			moving = 1;
			colorBackground[] = WFBE_Background_Color;
		};
		class Background_H : RscText {
			x = 0.17467;
			y = 0.186955;
			w = 0.65066;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class Background_F : RscText {
			x = 0.17467;
			y = 0.766375;
			w = 0.65066;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class Background_L : RscText {
			x = 0.17467;
			y = 0.238455;
			w = 0.65066;
			h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
		//--- UX Pass 1: section label above PURCHASE group (left col rows 1-2).
		class Section_Purchase_L : RscText {
			idc = -1;
			x = 0.17598;
			y = 0.244;
			w = 0.313727;
			h = 0.006;
			colorBackground[] = {0, 0, 0, 0};
			colorText[] = {0.2588, 0.7137, 1, 0.55};
			text = "PURCHASE";
			style = 0x02;
			font = "Zeppelin32";
			sizeEx = 0.018;
			shadow = 0;
		};
		//--- UX Pass 1: section label above GENERAL group (left col rows 3-5).
		class Section_General_L : RscText {
			idc = -1;
			x = 0.17598;
			y = 0.446;
			w = 0.313727;
			h = 0.006;
			colorBackground[] = {0, 0, 0, 0};
			colorText[] = {0.2588, 0.7137, 1, 0.55};
			text = "GENERAL";
			style = 0x02;
			font = "Zeppelin32";
			sizeEx = 0.018;
			shadow = 0;
		};
		//--- UX Pass 1: section label above COMMAND group (right col rows 1-5).
		class Section_Command_R : RscText {
			idc = -1;
			x = 0.510943;
			y = 0.244;
			w = 0.313727;
			h = 0.006;
			colorBackground[] = {0, 0, 0, 0};
			colorText[] = {0.2588, 0.7137, 1, 0.55};
			text = "COMMAND";
			style = 0x02;
			font = "Zeppelin32";
			sizeEx = 0.018;
			shadow = 0;
		};
		//--- UX Pass 1: TOOLS label above footer strip (decorative).
		class Section_Tools_F : RscText {
			idc = -1;
			x = 0.350;
			y = 0.758;
			w = 0.12;
			h = 0.009;
			colorBackground[] = {0, 0, 0, 0};
			colorText[] = {0.2588, 0.7137, 1, 0.4};
			text = "TOOLS";
			style = 0x02;
			font = "Zeppelin32";
			sizeEx = 0.016;
			shadow = 0;
		};
	};
	class controls {
		//--- === PURCHASE ===
		class Button_A : RscShortcutButtonMain {
			idc = 11001;
			x = 0.17598;
			y = 0.250358;
			w = 0.313727;
			h = 0.104575;
			text = $STR_WF_MAIN_Purchase_Units;
			tooltip = $STR_WF_TOOLTIP_MainMenu_Purchase_Units;
			action = "MenuAction = 1";
		};
		class Button_B : RscShortcutButtonMain {
			idc = 11002;
			x = 0.17598;
			y = 0.35116;
			w = 0.313727;
			h = 0.104575;
			text = $STR_WF_MAIN_Purchase_Gear;
			tooltip = $STR_WF_TOOLTIP_MainMenu_Purchase_Gear;
			action = "MenuAction = 2";
		};
		//--- === GENERAL ===
		class Button_C : RscShortcutButtonMain {
			idc = 11003;
			x = 0.17598;
			y = 0.451959;
			w = 0.313727;
			h = 0.104575;
			text = $STR_WF_MAIN_TeamMenu;
			tooltip = $STR_WF_TOOLTIP_MainMenu_TeamMenu;
			action = "MenuAction = 3";
		};
		class Button_F : RscShortcutButtonMain {
			idc = 11006;
			x = 0.17598;
			y = 0.55276;
			w = 0.313727;
			h = 0.104575;
			text = $STR_WF_MAIN_TacticalMenu;
			tooltip = $STR_WF_TOOLTIP_CommandMenu_SpecialMenu;
			action = "MenuAction = 6";
		};
		class Button_I : RscShortcutButtonMain {
			idc = 11009;
			x = 0.17598;
			y = 0.65356;
			w = 0.313727;
			h = 0.104575;
			text = $STR_WF_SupportMenu;
			tooltip = $STR_WF_TOOLTIP_CommandMenu_SupportMenu;
			action = "MenuAction = 9";
		};
		//--- === COMMAND ===
		class Button_E : RscShortcutButtonMain {
			idc = 11005;
			x = 0.510943;
			y = 0.250358;
			w = 0.313727;
			h = 0.104575;
			text = $STR_WF_MAIN_CommandMenu;
			tooltip = $STR_WF_TOOLTIP_CommandMenu_Commandteam;
			action = "MenuAction = 5";
		};
		class Button_H : RscShortcutButtonMain {
			idc = 11008;
			x = 0.510943;
			y = 0.35116;
			w = 0.313727;
			h = 0.104575;
			text = $STR_WF_MAIN_EconomyMenu;
			tooltip = $STR_WF_TOOLTIP_CommandMenu_Commander_Menu;
			action = "MenuAction = 8";
		};
		class Button_G : RscShortcutButtonMain {
			idc = 11007;
			x = 0.510943;
			y = 0.451959;
			w = 0.313727;
			h = 0.104575;
			text = $STR_WF_MAIN_UpgradeMenu;
			tooltip = $STR_WF_TOOLTIP_CommandMenu_Upgrade_Menu;
			action = "MenuAction = 7";
		};
		class Button_J : RscShortcutButtonMain {
			idc = 11010;
			x = 0.510943;
			y = 0.55276;
			w = 0.313727;
			h = 0.104575;
			text = $STR_WF_HelpMenu;
			tooltip = $STR_WF_TOOLTIP_CommandMenu_Help;
			action = "MenuAction = 13";
		};
		class Button_D : RscShortcutButtonMain {
			idc = 11004;
			x = 0.510943;
			y = 0.65356;
			w = 0.313727;
			h = 0.104575;
			text = $STR_WF_MAIN_VotingMenu;
			tooltip = $STR_WF_TOOLTIP_MainMenu_VoteForCommander;
			action = "MenuAction = 4";
		};
		//--- === Header title + parameter icon ===
		class TitleMenu: RscText_Title {
			idc = 11015;
			x = 0.178164;
			y = 0.19379;
			w = 0.600000;
			sizeEx = 0.031;
		};
		class CA_PA_Button : RscClickableText {
			idc = 11012;
			x = 0.776399;
			y = 0.191982;
			w = 0.04;
			h = 0.04;
			text = "\ca\ui\data\iconvehicle_ca.paa";
			action = "MenuAction = 12";
			tooltip = $STR_WF_TOOLTIP_Parameter;
		};
		//--- === TOOLS footer strip ===
		class CA_UN_Button : RscClickableText {
			idc = 11013;
			x = 0.194088;
			y = 0.767144;
			w = 0.045;
			h = 0.045;
			text = "\ca\ui\data\stats_soft_ca.paa";
			action = "MenuAction = 10";
			tooltip = $STR_WF_TOOLTIP_Unflip;
		};
		class CA_HB_Button : RscClickableText {
			idc = 11014;
			x = 0.265514;
			y = 0.766938;
			w = 0.045;
			h = 0.045;
			text = "\ca\ui\data\editor_2d_camera_ca.paa";
			action = "MenuAction = 11";
			tooltip = $STR_WF_TOOLTIP_HeadBugFix;
		};
		//--- cmdcon41-w3l: Command-Deck Skin Selector re-open button.
		class CA_SkinSel_Button : RscButton_Main {
			idc = 11025;
			x = 0.362;
			y = 0.767144;
			w = 0.042;
			h = 0.045;
			text = $STR_WF_SkinSelector_MenuButton;
			sizeEx = 0.024;
			action = "MenuAction = 21";
			tooltip = $STR_WF_SkinSelector_Title;
		};
		class CA_HUD_Button : RscButton_Main {
			idc = 11018;
			x = 0.408;
			y = 0.767144;
			w = 0.042;
			h = 0.045;
			text = "HUD";
			sizeEx = 0.026;
			action = "MenuAction = 16";
			tooltip = "HUD On/Off";
		};
		// Marty: Reuse the old FPS-only HUD slot for GPS; FPS now lives in the RHUD/sidebar.
		class CA_GPS_Button : RscButton_Main {
			idc = 11019;
			x = 0.455;
			y = 0.767144;
			w = 0.042;
			h = 0.045;
			text = "GPS";
			sizeEx = 0.026;
			action = "MenuAction = 19";
			tooltip = "Enable GPS / Mini Map";
		};
		// FPS: adaptive view-distance / target-FPS picker (sits between GPS and SKIN).
		class CA_FPS_Button : RscButton_Main {
			idc = 11023;
			x = 0.503;
			y = 0.767144;
			w = 0.042;
			h = 0.045;
			text = "FPS";
			sizeEx = 0.026;
			action = "MenuAction = 23";
			tooltip = "Player Settings (view distance, FPS, HUD, toggles)";
		};
		//--- Command Deck: Skin Selector shortcut in footer strip.
		class CA_Skin_Button : RscButton_Main {
			idc = 11021;
			//--- B748 (Ray 2026-06-24): revived the hidden skins-button slot as the SETTINGS GEAR -> WFBE_SettingsMenu (idd 29000) via MenuAction 24.
			show = 1;
			x = 0.564;
			y = 0.767144;
			w = 0.057;
			h = 0.045;
			text = "SETUP";
			sizeEx = 0.022;
			action = "MenuAction = 24";
			tooltip = "Player Settings (view distance, FPS, HUD, toggles)";
		};
		// qol-polish-pack: friendly name-tag overlay toggle (loop + RscTitles in Init_Client.sqf / Titles.hpp).
		class CA_NT_Button : RscButton_Main {
			idc = 11024;
			x = 0.671;
			y = 0.767144;
			w = 0.042;
			h = 0.045;
			text = "TAGS";
			sizeEx = 0.026;
			action = "MenuAction = 25";
			tooltip = "Friendly name tags On/Off";
		};
		/* Exit */
		class Exit_Button : RscButton_Exit {
			x = 0.778103;
			y = 0.769671;
			onButtonClick = "closeDialog 0;";
			tooltip = $STR_WF_TOOLTIP_CloseButton;
		};
		//--- GUER Director Commissar Panel hub button: claim idc 11030+, do NOT reuse 11001-11025.
	};
};

//--- Team Menu. | ALL DONE!
class RscMenu_Team {
	movingEnable = 1;
	idd = 13000;
	onLoad = "_this ExecVM ""Client\GUI\GUI_Menu_Team.sqf""";
	
	class controlsBackground {
		class Background_M : RscText {
			x = 0.187276;
			y = 0.200401;
			w = 0.625448;
			h = 0.599268;
			colorBackground[] = WFBE_Background_Color;
			moving = 1;
		};
		class Background_H : RscText {
			x = 0.187276;
			y = 0.200401;
			w = 0.625448;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class Background_F : RscText {
			x = 0.187276;
			y = 0.747169;
			w = 0.625448;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class Background_L : RscText {
			x = 0.187276;
			y = 0.251901;
			w = 0.625448;
			h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
	};
	class controls {
		class Title_TeamMenu : RscText_Title {
			idc = 13001;
			x = 0.192941;
			y = 0.206879;
			w = 0.3;
			text = $STR_WF_MAIN_TeamMenu;
		};
		/* Video */
		class Video_Subtitle : RscText_SubTitle {
			idc = 13101;
			x = 0.19634;
			y = 0.265506;
			w = 0.3;
			text = $STR_WF_TEAM_VideoOptionsLabel;
		};
		class CA_VD_Label : RscText {
			idc = 13002;
			x = 0.197022;
			y = 0.314747;
			w = 0.3;
		};
		class CA_VD_Slider : RscXSliderH {
			idc = 13003;
			x = 0.513947;
			y = 0.31565;
			w = 0.279999;
			h = 0.029412;
		};
		class CA_TG_Label : RscText {
			idc = 13004;
			x = 0.197022;
			y = 0.35722;
			w = 0.3;
		};
		class CA_TG_Slider : RscXSliderH {
			idc = 13005;
			x = 0.514313;
			y = 0.363086;
			w = 0.279999;
			h = 0.029412;
		};
		/* Transfer */
		class CA_Transfer_SubTitle : RscText_SubTitle {
			idc = 13012;
			x = 0.19634;
			y = 0.465507;
			w = 0.3;
			text = $STR_WF_TEAM_MoneyTransferLabel;
		};
		class CA_TM_Label : RscText {
			idc = 13006;
			x = 0.196002;
			y = 0.57032;
			w = 0.3;
		};
		class CA_TM_Slider : RscXSliderH {
			idc = 13007;
			x = 0.513947;
			y = 0.517846;
			w = 0.279999;
			h = 0.029412;
		};
		class CA_TM_Combo : RscCombo {
			idc = 13008;
			x = 0.202366;
			y = 0.517987;
			w = 0.279999;
			h = 0.035;
		};
		class CA_TM_Button : RscButton {
			idc = 13009;
			x = 0.513949;
			y = 0.572956;
			w = 0.279999;
			text = $STR_WF_TEAM_TransferButton;			
			action = "MenuAction = 1";
		};
		class CA_TA_Button : RscButton_Main {
			idc = 13109;
			x = 0.513949;
			y = 0.465;
			w = 0.279999;
			text = "Transfer (Adv)";			
			action = "MenuAction = 101";
		};
		class CA_IC_SubTitle : RscText_SubTitle {
			idc = 13010;
			x = 0.380877;
			y = 0.20787;
			w = 0.426891;
			style = ST_RIGHT;
		};
		/* Disband */
		class CA_Disband_SubTitle : RscText_SubTitle {
			idc = 13011;
			x = 0.19532;
			y = 0.642376;
			w = 0.3;
			text = $STR_WF_TEAM_DisbandLabel;
		};
		class CA_DB_Combo : RscCombo {
			idc = 13013;
			x = 0.202364;
			y = 0.691727;
			w = 0.279999;
			h = 0.035;
		};
		class CA_DB_Button : RscButton {
			idc = 13014;
			x = 0.513951;
			y = 0.691511;
			w = 0.279999;
			text = $STR_WF_TEAM_DisbandButton;
			action = "MenuAction = 3";
		};
		/* FX */
		class CA_FX_Label : RscText {
			idc = 13015;
			x = 0.19634;
			y = 0.405641;
			w = 0.3;
			text = $STR_WF_TEAM_GraphicFilterLabel;
		};
		class CA_FX_Combo : RscCombo {
			idc = 13018;
			x = 0.514313;
			y = 0.406464;
			w = 0.0999999;
			h = 0.035;
			onLBSelChanged = "MenuAction = 6";
		};
			/* High climbing preference */
			class CA_HighClimbing_Default_Button : RscButton {
				idc = 13020;
				x = 0.203;
				y = 0.733;
				w = 0.279;
				text = "";
				tooltip = "Toggle whether newly bought vehicles start with high climbing enabled";
				action = "MenuAction = 14";
			};
			/* Vote PopUp */
			class VPOPON_Button : RscButton {
				idc = 13019;
				x = 0.203;
				y = 0.772;
				w = 0.279;
				text = "";
				tooltip = "Toggle the commander vote popup on join";
				action = "MenuAction = 13";
			};
			/* Seperator */
		class Line_TRH1 : RscText {
			x = 0.192941;
			y = 0.455916;
			w = 0.614486;
			h = WFBE_SPT1;
			colorBackground[] = WFBE_SPC1;
		};
		class Line_TRH2 : RscText {
			x = 0.192941;
			y = 0.629907;
			w = 0.614486;
			h = WFBE_SPT1;
			colorBackground[] = WFBE_SPC1;
		};
		/* Back */
		class Back_Button : RscButton_Back {
			x = 0.704632;
			y = 0.753185;
			action = "MenuAction = 8";
			tooltip = $STR_WF_TOOLTIP_BackButton;
		};
		/* Exit */
		class Exit_Button : RscButton_Exit {
			x = 0.766877;
			y = 0.753185;			
			onButtonClick = "closeDialog 0;";
			tooltip = $STR_WF_TOOLTIP_CloseButton;
		};
	};
};

//--- RscMenu_TeamV2 (idd 13050) --- Team Menu V2 (TP-21).
//--- Opens in place of RscMenu_Team when WFBE_C_TEAM_MENU_V2 > 0.
//--- Removed from V2: VD slider (13002/13003), TG slider (13004/13005),
//---   inline money transfer (13006/13007/13008/13009/13012/13109).
//--- Kept: income readout (13010), FX combo (13018), vote popup (13019), high-climb (13020).
//--- New: gear preset rows (IDC 13051-13066), squad actions (13070-13074).
class RscMenu_TeamV2 {
	movingEnable = 1;
	idd = 13050;
	onLoad = "_this ExecVM ""Client\GUI\GUI_Menu_TeamV2.sqf""";

	class controlsBackground {
		class Background_M : RscText {
			x = 0.187276;
			y = 0.200401;
			w = 0.625448;
			h = 0.599268;
			colorBackground[] = WFBE_Background_Color;
			moving = 1;
		};
		class Background_H : RscText {
			x = 0.187276;
			y = 0.200401;
			w = 0.625448;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class Background_F : RscText {
			x = 0.187276;
			y = 0.747169;
			w = 0.625448;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class Background_L : RscText {
			x = 0.187276;
			y = 0.251901;
			w = 0.625448;
			h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
	};
	class controls {
		/* Header */
		class Title_TeamMenuV2 : RscText_Title {
			idc = 13001;
			x = 0.192941;
			y = 0.206879;
			w = 0.3;
			text = "Team Menu V2";
		};
		class CA_IC_SubTitle : RscText_SubTitle {
			idc = 13010;
			x = 0.380877;
			y = 0.20787;
			w = 0.426891;
			style = ST_RIGHT;
		};
		/* --- GEAR PRESETS SECTION --- */
		class CA_GP_Title : RscText_SubTitle {
			idc = 13049;
			x = 0.19634;
			y = 0.265506;
			w = 0.614;
			text = "Gear Presets  (save current kit / apply / set rebuy-on-death)";
		};
		/* Preset row 1 */
		class CA_GP1_Badge : RscText {
			idc = 13051;
			x = 0.192941;
			y = 0.298;
			w = 0.055;
			style = ST_CENTER;
			text = "---";
		};
		class CA_GP1_Save : RscButton {
			idc = 13052;
			x = 0.252;
			y = 0.296;
			w = 0.14;
			text = "Save 1";
			action = "MenuAction = 1001";
			tooltip = "Save current loadout to preset slot 1";
		};
		class CA_GP1_Apply : RscButton {
			idc = 13053;
			x = 0.398;
			y = 0.296;
			w = 0.14;
			text = "Apply 1";
			action = "MenuAction = 1011";
			tooltip = "Equip preset slot 1 now";
		};
		class CA_GP1_Rebuy : RscButton {
			idc = 13054;
			x = 0.544;
			y = 0.296;
			w = 0.14;
			text = "Rebuy 1";
			action = "MenuAction = 1021";
			tooltip = "Set slot 1 as the kit auto-applied on death";
		};
		/* Preset row 2 */
		class CA_GP2_Badge : RscText {
			idc = 13055;
			x = 0.192941;
			y = 0.336;
			w = 0.055;
			style = ST_CENTER;
			text = "---";
		};
		class CA_GP2_Save : RscButton {
			idc = 13056;
			x = 0.252;
			y = 0.334;
			w = 0.14;
			text = "Save 2";
			action = "MenuAction = 1002";
			tooltip = "Save current loadout to preset slot 2";
		};
		class CA_GP2_Apply : RscButton {
			idc = 13057;
			x = 0.398;
			y = 0.334;
			w = 0.14;
			text = "Apply 2";
			action = "MenuAction = 1012";
			tooltip = "Equip preset slot 2 now";
		};
		class CA_GP2_Rebuy : RscButton {
			idc = 13058;
			x = 0.544;
			y = 0.334;
			w = 0.14;
			text = "Rebuy 2";
			action = "MenuAction = 1022";
			tooltip = "Set slot 2 as the kit auto-applied on death";
		};
		/* Preset row 3 */
		class CA_GP3_Badge : RscText {
			idc = 13059;
			x = 0.192941;
			y = 0.374;
			w = 0.055;
			style = ST_CENTER;
			text = "---";
		};
		class CA_GP3_Save : RscButton {
			idc = 13060;
			x = 0.252;
			y = 0.372;
			w = 0.14;
			text = "Save 3";
			action = "MenuAction = 1003";
			tooltip = "Save current loadout to preset slot 3";
		};
		class CA_GP3_Apply : RscButton {
			idc = 13061;
			x = 0.398;
			y = 0.372;
			w = 0.14;
			text = "Apply 3";
			action = "MenuAction = 1013";
			tooltip = "Equip preset slot 3 now";
		};
		class CA_GP3_Rebuy : RscButton {
			idc = 13062;
			x = 0.544;
			y = 0.372;
			w = 0.14;
			text = "Rebuy 3";
			action = "MenuAction = 1023";
			tooltip = "Set slot 3 as the kit auto-applied on death";
		};
		/* Preset row 4 */
		class CA_GP4_Badge : RscText {
			idc = 13063;
			x = 0.192941;
			y = 0.412;
			w = 0.055;
			style = ST_CENTER;
			text = "---";
		};
		class CA_GP4_Save : RscButton {
			idc = 13064;
			x = 0.252;
			y = 0.410;
			w = 0.14;
			text = "Save 4";
			action = "MenuAction = 1004";
			tooltip = "Save current loadout to preset slot 4";
		};
		class CA_GP4_Apply : RscButton {
			idc = 13065;
			x = 0.398;
			y = 0.410;
			w = 0.14;
			text = "Apply 4";
			action = "MenuAction = 1014";
			tooltip = "Equip preset slot 4 now";
		};
		class CA_GP4_Rebuy : RscButton {
			idc = 13066;
			x = 0.544;
			y = 0.410;
			w = 0.14;
			text = "Rebuy 4";
			action = "MenuAction = 1024";
			tooltip = "Set slot 4 as the kit auto-applied on death";
		};
		/* Separator: presets / squad actions */
		class Line_V2_Sep1 : RscText {
			x = 0.192941;
			y = 0.450;
			w = 0.614486;
			h = WFBE_SPT1;
			colorBackground[] = WFBE_SPC1;
		};
		/* --- SQUAD ACTIONS SECTION --- */
		class CA_SQ_Title : RscText_SubTitle {
			idc = 13070;
			x = 0.19634;
			y = 0.456;
			w = 0.3;
			text = "Squad Actions";
		};
		/* Unit selector */
		class CA_SQ_Combo : RscCombo {
			idc = 13071;
			x = 0.192941;
			y = 0.493;
			w = 0.279999;
			h = 0.035;
		};
		/* Disband button */
		class CA_SQ_Disband : RscButton {
			idc = 13072;
			x = 0.482;
			y = 0.493;
			w = 0.14;
			text = "Disband";
			action = "MenuAction = 3";
			tooltip = "Disband selected AI from your squad";
		};
		/* Eject button */
		class CA_SQ_Eject : RscButton {
			idc = 13073;
			x = 0.628;
			y = 0.493;
			w = 0.14;
			text = "Eject";
			action = "MenuAction = 2001";
			tooltip = "Eject selected AI out of its vehicle";
		};
		/* Get-out-and-repair button */
		class CA_SQ_Repair : RscButton {
			idc = 13074;
			x = 0.482;
			y = 0.535;
			w = 0.286;
			text = "Get Out & Repair (mobility)";
			action = "MenuAction = 2002";
			tooltip = "AI crew dismounts and restores mobility (wheels/tracks/engine), then remounts";
		};
		/* Separator: squad / preferences */
		class Line_V2_Sep2 : RscText {
			x = 0.192941;
			y = 0.576;
			w = 0.614486;
			h = WFBE_SPT1;
			colorBackground[] = WFBE_SPC1;
		};
		/* --- PREFERENCES SECTION (kept from V1) --- */
		class CA_FX_Label : RscText {
			idc = 13015;
			x = 0.19634;
			y = 0.582;
			w = 0.3;
			text = $STR_WF_TEAM_GraphicFilterLabel;
		};
		class CA_FX_Combo : RscCombo {
			idc = 13018;
			x = 0.514313;
			y = 0.582;
			w = 0.0999999;
			h = 0.035;
			onLBSelChanged = "MenuAction = 6";
		};
		class CA_HighClimbing_Default_Button : RscButton {
			idc = 13020;
			x = 0.203;
			y = 0.626;
			w = 0.279;
			text = "";
			tooltip = "Toggle whether newly bought vehicles start with high climbing enabled";
			action = "MenuAction = 14";
		};
		class VPOPON_Button : RscButton {
			idc = 13019;
			x = 0.203;
			y = 0.668;
			w = 0.279;
			text = "";
			tooltip = "Toggle the commander vote popup on join";
			action = "MenuAction = 13";
		};
		/* Separator before footer */
		class Line_V2_Sep3 : RscText {
			x = 0.192941;
			y = 0.708;
			w = 0.614486;
			h = WFBE_SPT1;
			colorBackground[] = WFBE_SPC1;
		};
		/* Back / Exit */
		class Back_Button : RscButton_Back {
			x = 0.704632;
			y = 0.753185;
			action = "MenuAction = 8";
			tooltip = $STR_WF_TOOLTIP_BackButton;
		};
		class Exit_Button : RscButton_Exit {
			x = 0.766877;
			y = 0.753185;
			onButtonClick = "closeDialog 0;";
			tooltip = $STR_WF_TOOLTIP_CloseButton;
		};
	};
};

//--- BuyUnits Menu. | ALL DONE!
class RscMenu_BuyUnits {
	movingEnable = 1;
	idd = 12000;
	onLoad = "_this ExecVM ""Client\GUI\GUI_Menu_BuyUnits.sqf""";
	
	class controlsBackground {
		class Background_M : RscText {
			x = -0.000119045;
			y = 0.000960164;
			w = 1.00024;
			h = 1.00046;
			moving = 1;
			colorBackground[] = WFBE_Background_Color;
		};
		class Background_H : RscText {
			x = -0.000119045;
			y = 0.000960164;
			w = 1.00024;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class Background_F : RscText {
			x = -0.000119045;
			y = 0.948079045;
			w = 1.00024;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class Background_L : RscText {
			x = -0.000119045;
			y = 0.051619045;
			w = 1.00024;
			h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
	};
	class controls {
		/* Controls */
		class CA_BuyList : RscListBoxA {
			idc = 12001;
			x = 0.000983551;
			y = 0.184483;
			w = 0.493697;
			h = 0.493299;
			columns[] = {0.01, 0.19, 0.75};
			drawSideArrows = 0;
			idcRight = -1;
			idcLeft = -1;
			
			onLBSelChanged = "MenuAction = 302";
			onLBDblClick = "MenuAction = 1";
		};
		class CA_Purchase : RscButton {
			idc = 12002;
			x = 0.688983;
			y = 0.956626;
			w = 0.12;
			text = $STR_WF_Purchase;
			action = "MenuAction = 1";
		};
		class Title_BuyUnits : RscText_Title {
			idc = 12004;
			x = 0.00477695;
			y = 0.00775912;
			w = 0.3;
			text = $STR_WF_MAIN_Purchase_Units;
		};
		/* Factory-Picture */
		class WF_Con1 : RscClickableText {
			idc = 12005;
			x = 0.499874;
			y = 0.0612043;
			w = 0.072;
			h = 0.072;
			text = "\CA\warfare2\Images\con_barracks.paa";
			tooltip = $STR_WF_TOOLTIP_UnitPurchase_Con1;
			action = "MenuAction = 101";
		};
		class WF_Con2 : WF_Con1 {
			idc = 12006;
			x = 0.585001;
			text = "\CA\warfare2\Images\con_light.paa";
			tooltip = $STR_WF_TOOLTIP_UnitPurchase_Con2;
			action = "MenuAction = 102";
		};
		class WF_Con3 : WF_Con1 {
			idc = 12007;
			x = 0.670123;
			text = "\CA\warfare2\Images\con_heavy.paa";
			tooltip = $STR_WF_TOOLTIP_UnitPurchase_Con3;
			action = "MenuAction = 103";
		};
		class WF_Con4 : WF_Con1 {
			idc = 12008;
			x = 0.753571;
			text = "\CA\warfare2\Images\con_aircraft.paa";
			tooltip = $STR_WF_TOOLTIP_UnitPurchase_Con4;
			action = "MenuAction = 104";
		};
		class WF_Con7 : WF_Con1 {
			idc = 12021;
			x = 0.838699;
			text = "\CA\warfare2\Images\con_airport.paa";
			tooltip = $STR_WF_TOOLTIP_UnitPurchase_Con5;
			action = "MenuAction = 106";
		};
		class WF_Con5 : WF_Con1 {
			idc = 12020;
			x = 0.923826;
			text = "Client\Images\con_depot.paa";
			tooltip = $STR_WF_TOOLTIP_UnitPurchase_Con6;
			action = "MenuAction = 105";
		};
		/**/
		class CA_Portrait : RscPicture {
			idc = 12009;
			x = 0.00434637;
			y = 0.726386;
			w = 0.186974;
			h = 0.219467;
			style = 0x30 + 0x800;
		};
		/* Vehicle-Crew */
		class WF_Lock : RscClickableText {
			idc = 12023;
			x = 0.443363;
			y = 0.128362;
			w = 0.05;
			h = 0.05;
			text = "Client\Images\i_lock.paa";
			tooltip = $STR_WF_TOOLTIP_Buy_Locked;
			action = "MenuAction = 401";
		};
		class WF_Driver : WF_Lock {
			idc = 12012;
			x = 0.242185;
			text = "Client\Images\i_driver.paa";
			tooltip = $STR_WF_TOOLTIP_Buy_Driver;
			action = "MenuAction = 201";
		};
		class WF_Gunner : WF_Lock {
			idc = 12013;
			x = 0.292267;
			text = "Client\Images\i_gunner.paa";
			tooltip = $STR_WF_TOOLTIP_Buy_Gunner;
			action = "MenuAction = 202";
		};
		class WF_Commander : WF_Lock {
			idc = 12014;
			x = 0.343194;
			text = "Client\Images\i_commander.paa";
			tooltip = $STR_WF_TOOLTIP_Buy_Commander;
			action = "MenuAction = 203";
		};
		class WF_Extra : WF_Lock {
			idc = 12041;
			x = 0.393278;
			text = "Client\Images\i_extra.paa";
			tooltip = $STR_WF_TOOLTIP_Buy_Extra;
			action = "MenuAction = 204";
		};
		/**/
		class WF_MiniMap : RscMapControl {
			idc = 12015;
			x = 0.5;
			y = 0.185168;
			w = 0.499378;
			h = 0.493457;
			ShowCountourInterval = 1;
		};
		class CA_Factory_Label : RscText {
			idc = 12016;
			x = 0.5;
			y = 0.140446;
			w = 0.3;
			text = $STR_WF_UNITS_Factory;
			sizeEx = 0.035;
		};
		class CA_Combo_Factory : RscCombo {
			idc = 12018;
			x = 0.626048;
			y = 0.140446;
			w = 0.368908;
			h = 0.037;
			onLBSelChanged = "MenuAction = 301";
		};
		class CA_Cash_SubTitle : RscText_SubTitle {
			idc = 12019;
			x = 0.694657;
			y = 0.007759;
			w = 0.3;
			style = ST_RIGHT;
		};
		class CA_Details : RscStructuredText {
			idc = 12022;
			x = 0.5;
			y = 0.699494;
			w = 0.500294;
			h = 0.242927;
			size = 0.0250;
		};
		class CA_Queu_SubTitle : RscText_SubTitle {
			idc = 12024;
			x = 0.350419;
			y = 0.00775906;
			w = 0.185;
			style = ST_LEFT;
		};
		//--- Task 33: cancel-last-queue button, placed in header next to queue count.
		class CA_Cancel_Queue : RscButton {
			idc = 12043;
			x = 0.578;
			y = 0.00775906;
			w = 0.07;
			h = 0.037;
			sizeEx = 0.022;
			text = "Cancel Last";
			tooltip = "Cancel and refund the most recent queued unit order";
			colorBackground[] = {0.6, 0.1, 0.0, 0.8};
			colorBackgroundActive[] = {0.8, 0.2, 0.0, 0.9};
			colorText[] = {1, 1, 1, 1};
			action = "MenuAction = 501";
		};
		class CA_Faction_Label : RscText {
			idc = 12025;
			x = 0.000797182;
			y = 0.062964;
			w = 0.3;
			sizeEx = 0.035;
		};
		class CA_Combo_Faction : RscCombo {
			idc = 12026;
			x = 0.218874;
			y = 0.0652035;
			w = 0.261343;
			h = 0.035;
			onLBSelChanged = "MenuAction = 303";
		};
		/* Info-Labels */
		class CA_Faction_Small : RscText_Small {
			idc = 12027;
			x = 0.194959;
			y = 0.692771;
			w = 0.3;
			h = 0.037;
			text = $STR_WF_UNITS_FactionLabel;
		};
		class CA_Price_Small : CA_Faction_Small {
			idc = 12010;
			x = 0.194959;
			y = 0.730336;
			text = $STR_WF_Price;
		};
		class CA_Time_Small : CA_Faction_Small {
			idc = 12028;
			x = 0.194957;
			y = 0.76566;
			text = $STR_WF_UNITS_DurationLabel;
		};
		class CA_Skill_Small : CA_Faction_Small {
			idc = 12029;
			x = 0.194959;
			y = 0.803222;
			text = $STR_WF_UNITS_SkillLabel;
		};
		class CA_TransportCapacity_Small : CA_Faction_Small {
			idc = 12030;
			x = 0.194959;
			y = 0.838545;
			text = $STR_WF_UNITS_TransportCabilityLabel;
		};
		class CA_MaxSpeed_Small : CA_Faction_Small {
			idc = 12031;
			x = 0.194959;
			y = 0.876108;
			text = $STR_WF_UNITS_MaxSpeedLabel;
		};
		class CA_Armor_Small : CA_Faction_Small {
			idc = 12032;
			x = 0.194959;
			y = 0.911431;
			text = $STR_WF_UNITS_ArmorLabel;
		};
		/* Info-Values */
		class CA_Faction_Value : RscText_Small {
			idc = 12033;
			x = 0.305041;
			y = 0.692773;
			w = 0.19;
			h = 0.037;
			style = 1;
		};
		class CA_Price_Value : CA_Faction_Value {
			idc = 12034;
			x = 0.305042;
			y = 0.730336;
			colorText[] = {1, 0, 0, 1};
		};
		class CA_Time_Value : CA_Faction_Value {
			idc = 12035;
			x = 0.305041;
			y = 0.765659;
		};
		class CA_Skill_Value : CA_Faction_Value {
			idc = 12036;
			x = 0.305041;
			y = 0.803222;
		};
		class CA_TransportCapacity_Value : CA_Faction_Value {
			idc = 12037;
			x = 0.305042;
			y = 0.838545;
		};
		class CA_MaxSpeed_Value : CA_Faction_Value{
			idc = 12038;
			x = 0.305041;
			y = 0.876109;
		};
		class CA_Armor_Value : CA_Faction_Value {
			idc = 12039;
			x = 0.30504;
			y = 0.911432;
		};
		/**/
		class CA_Unit_SubTitle : RscText_SubTitle {
			idc = 12040;
			x = 0.000575542;
			y = 0.686365;
			w = 0.3;
			text = $STR_WF_UNITS_InformationLabel;
		};
		/* Seperator */
		class LineTRH1 : RscText {
			x = 0.00470637;
			y = 0.685127;
			w = 0.990954;
			h = WFBE_SPT1;
			colorBackground[] = WFBE_SPC1;
		};
		/* Back */
		class Back_Button : RscButton_Back {
			x = 0.892748;
			y = 0.953506;
			action = "MenuAction = 2";
			tooltip = $STR_WF_TOOLTIP_BackButton;
		};
		/* Exit */
		class Exit_Button : RscButton_Exit {
			x = 0.953972;
			y = 0.953506;
			onButtonClick = "closeDialog 0;";
			tooltip = $STR_WF_TOOLTIP_CloseButton;
		};
	};
};

//--- Command Menu. | ALL DONE!
class RscMenu_Command {
	movingEnable = 1;
	idd = 14000;
	onLoad = "_this ExecVM 'Client\GUI\GUI_Menu_Command.sqf'";
	
	class controlsBackground {
		class Background_M : RscText {
			x = 0.000960961;
			y = 0.00128184;
			w = 0.999761;
			h = 1.00023;
			moving = 1;
			colorBackground[] = WFBE_Background_Color;
		};
		class Background_H : RscText {
			x = 0.000960961;
			y = 0.00128184;
			w = 0.999761;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class Background_F : RscText {
			x = 0.000960961;
			y = 0.94901184;
			w = 0.999761;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class Background_L : RscText {
			x = 0.000960961;
			y = 0.05278184;
			w = 0.999761;
			h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
		/* War-room framing sub-panels (claude-gaming): subtle dark backers behind the three left-column
		   clusters (econ/intent header, roster, order buttons) using the WFBE_Background_Color_Sub idiom
		   every other menu uses. Background controls only - they sit behind whichever STATE's controls show. */
		class CA_Cmd_Panel_Header : RscText {
			x = 0.00261695;
			y = 0.058000;
			w = 0.465244;
			h = 0.306000;
			colorBackground[] = WFBE_Background_Color_Sub;
		};
		class CA_Cmd_Panel_Roster : RscText {
			x = 0.00261695;
			y = 0.368000;
			w = 0.465244;
			h = 0.280000;
			colorBackground[] = WFBE_Background_Color_Sub;
		};
		class CA_Cmd_Panel_Orders : RscText {
			x = 0.00261695;
			y = 0.652000;
			w = 0.465244;
			//--- Extended to 0.218 (ends 0.870) so the backer also covers the bulk-order + build-priority row, which
			//--- previously sat on bare background below the panel. Stops just above the help line (0.872).
			h = 0.218000;
			colorBackground[] = WFBE_Background_Color_Sub;
		};
	};
	class controls {
		class WF_MiniMap : RscMapControl {
			idc = 14002;
			x = 0.468907;
			y = 0.0563169;
			w = 0.532152;
			h = 0.892336;
			ShowCountourInterval = 1;
			onMouseMoving = "mouseX = (_this Select 1);mouseY = (_this Select 2)";
			onMouseButtonDown = "mouseButtonDown = _this Select 1";
			onMouseButtonUp = "mouseButtonUp = _this Select 1";
		};
		class Title_OrderMenu : RscText_Title {
			idc = 14003;
			x = 0.00561695;
			y = 0.00775909;
			w = 0.3;
			text = $STR_WF_MAIN_CommandMenu;
		};
		/* =====================================================================================
		   COMMAND CONSOLE (production rework, claude-gaming 2026-06-28). The old squad-order tab is
		   gutted; the whole left column is the player <-> AI-commander console. The embedded map
		   (idc 14002) is the order-designation surface. All controls live in the 14600-14699 band.
		   Order buttons set MenuAction; the controller (GUI_Menu_Command.sqf) does press -> click-map
		   -> send / direct-team-task. Two STATES are toggled live by the controller (see below): the
		   actual control set is STATE-dependent, so each order is shown only where the server honours it.
		   The committed orders are: per-team Attack/Move, Defend, Patrol, Release; bulk ALL PUSH/HOLD;
		   Artillery (player-arty flag); Request-Unit/Build priority; and a STATE-A PUSH/HOLD posture
		   nudge. (Donate is NOT here - it lives in the Transfer menu via RequestAIComDonate.)
		   ===================================================================================== */
		/* Console title band (14605 text set at runtime: "COMMAND" in STATE A / "WAR ROOM" in STATE B).
		   14600 is dual-purpose: STATE A = the take-command explainer, STATE B = the economy header. The
		   live AI-INTENT readout has its own STATE-A control (14607); the two never share a control. */
		class CA_Cmd_IntentTitle : RscText_SubTitle {
			idc = 14605;
			x = 0.00561695;
			y = 0.062000;
			w = 0.459244;
			text = "AI COMMANDER";
		};
		class CA_Cmd_Intent : RscStructuredText {
			idc = 14600;
			x = 0.00561695;
			y = 0.105000;
			w = 0.459244;
			h = 0.255000;
			size = 0.030;
		};
		/* =====================================================================================
		   WAR ROOM controls. Two states, toggled by the controller (GUI_Menu_Command.sqf) via ctrlShow:
		     STATE A (not commander, AI runs the side): TAKE COMMAND (14670) + the 14600 explainer + the
		       live AI-intent readout (14606/14607) + the PUSH/HOLD posture nudge (14608/14609/14612).
		     STATE B (commander): the 14600 economy header + roster listbox (14660/14661) + the order
		       buttons (14620-14624), bulk push/hold (14610/14611), and Request-Unit combo+Build (14640-14642).
		   The controller ctrlShow's exactly the right control set per state, so the STATE-A advisory block
		   and the STATE-B roster/orders share the same screen region cleanly (only one set is ever visible).
		   ===================================================================================== */
		/* TAKE COMMAND button - shown ONLY in the not-commander state (controller toggles ctrlShow). */
		class CA_Cmd_Claim : RscButton_Main {
			idc = 14670;
			x = 0.00561695;
			y = 0.372000;
			w = 0.459244;
			h = 0.060000;
			text = $STR_WF_CMD_Claim;
			action = "MenuAction = 750";
			tooltip = $STR_WF_CMD_Claim_TT;
		};
		/* =====================================================================================
		   STATE A (NOT commander) ADVISORY block: a live AI-commander INTENT readout (14607, fed
		   from the WFBE_AICOM_*_<sid> side-keyed vars) + a strategic POSTURE toggle (PUSH/HOLD,
		   14609/14612) that nudges the still-running AI's expansion-vs-consolidate bias. The
		   controller ctrlShow's these ONLY in STATE A (the AI runs the side, so the nudge bites);
		   in STATE B (you command) they hide and the war-room roster/orders take this region. */
		class CA_Cmd_IntentTitleA : RscText_SubTitle {
			idc = 14606;
			x = 0.00561695;
			y = 0.444000;
			w = 0.459244;
			text = $STR_WF_CMD_IntentTitleA;
		};
		class CA_Cmd_IntentA : RscStructuredText {
			idc = 14607;
			x = 0.00561695;
			y = 0.486000;
			w = 0.459244;
			h = 0.140000;
			size = 0.030;
		};
		class CA_Cmd_PostureTitle : RscText_SubTitle {
			idc = 14608;
			x = 0.00561695;
			y = 0.636000;
			w = 0.459244;
			text = $STR_WF_CMD_PostureTitle;
		};
		class CA_Cmd_PosturePush : RscButton_Main {
			idc = 14609;
			x = 0.00561695;
			y = 0.678000;
			w = 0.224000;
			h = 0.044000;
			text = $STR_WF_CMD_Push;
			action = "MenuAction = 760";
			tooltip = $STR_WF_CMD_Push_TT;
			//--- Posture colour-coding to match the order palette: PUSH = aggressive blue, HOLD = defensive green.
			colorBackground[] = {0, 0, 0.85, 0.85};
			colorBackgroundActive[] = {0.15, 0.15, 1, 1};
		};
		class CA_Cmd_PostureHold : CA_Cmd_PosturePush {
			idc = 14612;
			x = 0.241244;
			y = 0.678000;
			text = $STR_WF_CMD_Hold;
			action = "MenuAction = 761";
			tooltip = $STR_WF_CMD_Hold_TT;
			colorBackground[] = {0, 0.65, 0, 0.85};
			colorBackgroundActive[] = {0.1, 0.85, 0.1, 1};
		};
		/* cmdcon27 THREAD C: FIELD-ORDER nudges (STATE-A advisory, shown only when the AI runs the side). Cloned
		   from CA_Cmd_PosturePush (idc 14609). Row 1 (y=0.728): SPLIT UP / PUSH TOGETHER. Row 2 (y=0.772):
		   HARASS / FALL BACK. MenuAction 762-765 -> aicom-fieldorder (SPLIT/MASS/HARASS/FALLBACK). Inline text. */
		class CA_Cmd_NudgeSplit : CA_Cmd_PosturePush {
			idc = 14613;
			x = 0.00561695;
			y = 0.728000;
			w = 0.224000;
			h = 0.044000;
			text = "SPLIT UP";
			action = "MenuAction = 762";
			tooltip = "Spread the main effort across multiple fronts (more fist towns + more expansion teams).";
			colorBackground[] = {0, 0, 0.85, 0.85};
			colorBackgroundActive[] = {0.15, 0.15, 1, 1};
		};
		class CA_Cmd_NudgeMass : CA_Cmd_PosturePush {
			idc = 14614;
			x = 0.241244;
			y = 0.728000;
			w = 0.224000;
			h = 0.044000;
			text = "PUSH TOGETHER";
			action = "MenuAction = 763";
			tooltip = "Concentrate the whole side onto ONE fist town (no expand/harass split).";
			colorBackground[] = {0, 0, 0.85, 0.85};
			colorBackgroundActive[] = {0.15, 0.15, 1, 1};
		};
		class CA_Cmd_NudgeHarass : CA_Cmd_PosturePush {
			idc = 14615;
			x = 0.00561695;
			y = 0.772000;
			w = 0.224000;
			h = 0.044000;
			text = "HARASS";
			action = "MenuAction = 764";
			tooltip = "Send many mounted teams to raid the enemy's rear / supply hub (main fist kept).";
			colorBackground[] = {0.65, 0.45, 0, 0.85};
			colorBackgroundActive[] = {0.85, 0.6, 0.1, 1};
		};
		class CA_Cmd_NudgeFallback : CA_Cmd_PosturePush {
			idc = 14616;
			x = 0.241244;
			y = 0.772000;
			w = 0.224000;
			h = 0.044000;
			text = "FALL BACK";
			action = "MenuAction = 765";
			tooltip = "Stop clashing and pull back to owned towns (raise the engage threshold).";
			colorBackground[] = {0, 0.65, 0, 0.85};
			colorBackgroundActive[] = {0.1, 0.85, 0.1, 1};
		};
		/* Command Console v2 (claude-gaming 2026-07-01): STATE-A "AI: FOCUS TOWN" advisory. Full-width button under the
		   field-order nudges (bottom of the field-order cluster 0.816 < this 0.822). Player ARMS it, then clicks a town
		   on the map; the controller resolves the nearest town and sends aicom-focus (the SAME mechanism the M4-key /
		   command-center focus uses) so the still-running AI prioritises that town WITHOUT the player taking command.
		   Inherits CA_Cmd_PosturePush (STATE-A advisory; controller ctrlShow's it only when NOT commander). Slate/teal
		   tint distinct from the PUSH/HOLD/field-order palette. MenuAction 766. */
		class CA_Cmd_Focus : CA_Cmd_PosturePush {
			idc = 14617;
			x = 0.00561695;
			y = 0.822000;
			w = 0.459244;
			h = 0.040000;
			text = "AI: FOCUS TOWN (click map)";
			action = "MenuAction = 766";
			tooltip = "Point the running AI commander at a town: arm this, then click the town on the map. The AI prioritises it - you do NOT take command.";
			colorBackground[] = {0.12, 0.35, 0.42, 0.85};
			colorBackgroundActive[] = {0.18, 0.5, 0.58, 1};
		};
		/* cmdcon41-w3d COMMAND-MENU V2: REQUEST AI SUPPORT (non-commander). Any player (even under a HUMAN commander, where
		   the posture/focus nudges are inert) can call the nearest free same-side AI team to their position. STATE-A control
		   (added to _adviseCtrls); shown only when NOT the commander. Full-width, below the FOCUS button (14617 bottom 0.862).
		   Sends the player's own pos to the server, which validates + road-moves ONE nearby idle team (per-player cooldown).
		   MenuAction 767. Amber/help tint, distinct from the AI-steering palette. */
		class CA_Cmd_ReqSupport : CA_Cmd_PosturePush {
			idc = 14618;
			x = 0.00561695;
			y = 0.866000;
			w = 0.459244;
			h = 0.038000;
			text = "REQUEST AI SUPPORT (to me)";
			action = "MenuAction = 767";
			tooltip = "Call the nearest free friendly AI team to your position. Works even under a human commander. Cooldown applies.";
			colorBackground[] = {0.5, 0.35, 0, 0.85};
			colorBackgroundActive[] = {0.7, 0.5, 0.05, 1};
		};
		/* ROSTER of your AI teams (commander state). Row = "Squad type | Target | Alive" (Command Console v2). Click to
		   select; double-click opens the unit camera on that team's leader (VIEW TEAM, MenuAction 726). */
		class CA_Cmd_RosterTitle : RscText_SubTitle {
			idc = 14660;
			x = 0.00561695;
			y = 0.372000;
			w = 0.459244;
			show = 0;                          //--- STRUCTURAL GUARD: war-room (STATE-B) controls default HIDDEN so a non-commander never overlaps the STATE-A advisory block even if the controller hiccups. Controller shows them only when _isCmd. (Derived classes inherit this show.)
			text = $STR_WF_CMD_RosterTitle;
		};
		class CA_Cmd_Roster : RscListBox {
			idc = 14661;
			x = 0.00561695;
			y = 0.414000;
			w = 0.459244;
			h = 0.230000;
			rowHeight = 0.03;                  //--- REQUIRED (claude 2026-06-29): explicit rowHeight - inherited RscListBox value not in inherit-scope for this dialog; absence threw "No entry ...CA_Cmd_Roster.rowHeight" and broke the console.
			show = 0;                          //--- STRUCTURAL GUARD (see 14660).
			//--- selection is read live via lbCurSel 14661 in the controller loop; no onLBSelChanged needed.
			//--- Command Console v2 (claude-gaming 2026-07-01): double-click a roster row = VIEW TEAM. The controller reads
			//--- MenuAction 726, closes the console and opens the existing unit camera (RscMenu_UnitCamera) on the selected
			//--- team's leader. Proven A2-OA idiom (onLBDblClick -> MenuAction, e.g. RscMenu list at Dialogs.hpp:1582).
			onLBDblClick = "MenuAction = 726";
		};
		class LineCmd1 : RscText {
			idc = 14690;
			x = 0.00561695;
			y = 0.648000;
			w = 0.459244;
			h = WFBE_SPT1;
			show = 0;                          //--- STRUCTURAL GUARD (see 14660). LineCmd2 (14691) inherits this.
			colorBackground[] = WFBE_SPC1;
		};
		/* Order buttons (map-click; act on the selected roster team, else nearest idle AI team). */
		class CA_Cmd_Move : RscButton_Main {
			idc = 14620;
			x = 0.00561695;
			y = 0.660000;
			w = 0.224000;
			h = 0.044000;
			show = 0;                          //--- STRUCTURAL GUARD (see 14660). Defend/Patrol/Release/Arty (14621/22/24/23) inherit this.
			text = $STR_WF_CMD_Move;
			action = "MenuAction = 720";
			tooltip = $STR_WF_CMD_Move_TT;
			//--- Order-button color-coding: match the map marker the controller drops (GUI_Menu_Command.sqf:336-341).
			//--- move => ColorBlue {0,0,1}. colorBackgroundActive keeps the tint on hover/press.
			colorBackground[] = {0, 0, 0.85, 0.85};
			colorBackgroundActive[] = {0.15, 0.15, 1, 1};
		};
		class CA_Cmd_Defend : CA_Cmd_Move {
			idc = 14621;
			x = 0.241244;
			y = 0.660000;
			text = $STR_WF_CMD_Defend;
			action = "MenuAction = 721";
			tooltip = $STR_WF_CMD_Defend_TT;
			//--- defense => ColorGreen {0,0.8,0}.
			colorBackground[] = {0, 0.65, 0, 0.85};
			colorBackgroundActive[] = {0.1, 0.85, 0.1, 1};
		};
		class CA_Cmd_Patrol : CA_Cmd_Move {
			idc = 14622;
			x = 0.00561695;
			y = 0.710000;
			text = $STR_WF_CMD_Patrol;
			action = "MenuAction = 722";
			tooltip = $STR_WF_CMD_Patrol_TT;
			//--- patrol => ColorOrange {1,0.5,0}.
			colorBackground[] = {0.85, 0.45, 0, 0.85};
			colorBackgroundActive[] = {1, 0.55, 0.05, 1};
		};
		class CA_Cmd_Release : CA_Cmd_Move {
			idc = 14624;
			x = 0.241244;
			y = 0.710000;
			text = $STR_WF_CMD_Release;
			action = "MenuAction = 724";
			tooltip = $STR_WF_CMD_Release_TT;
			//--- release => grey {0.6,0.6,0.6}.
			colorBackground[] = {0.5, 0.5, 0.5, 0.85};
			colorBackgroundActive[] = {0.65, 0.65, 0.65, 1};
		};
		class CA_Cmd_Arty : CA_Cmd_Move {
			idc = 14623;
			x = 0.00561695;
			y = 0.760000;
			w = 0.224000;                          //--- HALVED from full-width to share the y=0.760 row with CA_Cmd_AICmd (the squad-command mode toggle) on the right; both stay above the 0.808 separator (button bottom 0.804).
			text = $STR_WF_CMD_Arty;
			action = "MenuAction = 723";
			tooltip = $STR_WF_CMD_Arty_TT;
			//--- arty => ColorRed {0.9,0,0}.
			colorBackground[] = {0.75, 0, 0, 0.85};
			colorBackgroundActive[] = {1, 0.1, 0.1, 1};
		};
		/* Squad-command mode toggle (claude-gaming 2026-06-29): DIRECT (player maneuvers squads, today's default) <->
		   AI STRATEGY (the AI maneuver-brain runs Strategy+AssignTowns under the human commander; player keeps the
		   economy). Inherits CA_Cmd_Move (show=0 STRUCTURAL GUARD, h=0.044). Shares the y=0.760 order-button row with
		   the now-halved CA_Cmd_Arty, so it does NOT overlap CA_Cmd_Arty (left half) or the LineCmd2 separator (0.808). */
		class CA_Cmd_AICmd : CA_Cmd_Move {
			idc = 14625;
			x = 0.241244;
			y = 0.760000;
			w = 0.224000;
			text = $STR_WF_CMD_AICmd;
			action = "MenuAction = 730";
			tooltip = $STR_WF_CMD_AICmd_TT;
			//--- mode toggle => slate/teal {0.15,0.4,0.45}, distinct from the order-color cluster.
			colorBackground[] = {0.12, 0.35, 0.42, 0.85};
			colorBackgroundActive[] = {0.18, 0.5, 0.58, 1};
		};
		/* Separator dividing the per-team order buttons (above) from the bulk/build cluster (below). Raised to 0.808
		   so the whole bulk/build row sits cleanly BELOW the line (previously the "Build priority:" caption straddled it). */
		class LineCmd2 : LineCmd1 {
			idc = 14691;
			y = 0.808000;
		};
		/* Bulk posture + Request-Unit (the two hybrid orders that still bite in assist-mode). One tidy row at y=0.834:
		   ALL PUSH | ALL HOLD on the left, the Build-priority caption+combo+Build button on the right, all below the
		   separator and clear of the help line (combo bottom 0.867 < help top 0.872). */
		class CA_Cmd_Push : RscButton_Main {
			idc = 14610;
			x = 0.00561695;
			y = 0.834000;
			w = 0.148000;
			h = 0.034000;
			show = 0;                          //--- STRUCTURAL GUARD (see 14660). CA_Cmd_Hold (14611) inherits this.
			text = $STR_WF_CMD_AllPush;
			action = "MenuAction = 710";
			tooltip = $STR_WF_CMD_AllPush_TT;
		};
		class CA_Cmd_Hold : CA_Cmd_Push {
			idc = 14611;
			x = 0.160244;
			y = 0.834000;
			text = $STR_WF_CMD_AllHold;
			action = "MenuAction = 711";
			tooltip = $STR_WF_CMD_AllHold_TT;
		};
		/* Caption above the Build-priority combo so a new commander knows what the dropdown does (sits below the separator). */
		class CA_Cmd_ReqLabel : RscText {
			idc = 14642;
			x = 0.317244;
			y = 0.814000;
			w = 0.148000;
			h = 0.018000;
			show = 0;                          //--- STRUCTURAL GUARD (see 14660).
			text = $STR_WF_CMD_BuildPrio;
			sizeEx = 0.022;
		};
		class CA_Cmd_ReqCombo : RscCombo {
			idc = 14640;
			x = 0.317244;
			y = 0.834000;
			w = 0.090000;
			h = 0.033;
			show = 0;                          //--- STRUCTURAL GUARD (see 14660).
		};
		class CA_Cmd_ReqBtn : RscButton_Main {
			idc = 14641;
			x = 0.412244;
			y = 0.834000;
			w = 0.052561;
			h = 0.034000;
			show = 0;                          //--- STRUCTURAL GUARD (see 14660).
			text = $STR_WF_CMD_BuildBtn;
			action = "MenuAction = 740";
			tooltip = $STR_WF_CMD_BuildBtn_TT;
		};
		/* cmdcon41-w3d COMMAND-MENU V2: three per-team STEERING VERBS (act on the selected roster team) - RALLY (pull back
		   to the nearest own HQ/town), REFIT (funds-charged infantry top-up), HOLD (garrison the nearest own town). Thin
		   3-across row squeezed into the top of the old help-line band (help shrunk + moved down below). show=0 STRUCTURAL
		   GUARD -> STATE-B (commander) only; added to _warCtrls in GUI_Menu_Command.sqf. MenuAction 727/728/729. Inherit
		   CA_Cmd_Move (RscButton_Main + show=0). Distinct tints from the order palette. */
		class CA_Cmd_Rally : CA_Cmd_Move {
			idc = 14628;
			x = 0.00561695;
			y = 0.872000;
			w = 0.148000;
			h = 0.030000;
			text = "RALLY";
			action = "MenuAction = 727";
			tooltip = "Pull the SELECTED team back to your nearest HQ / owned town. It re-tasks normally once it arrives.";
			colorBackground[] = {0.35, 0.25, 0.5, 0.85};
			colorBackgroundActive[] = {0.5, 0.35, 0.7, 1};
		};
		class CA_Cmd_Refit : CA_Cmd_Rally {
			idc = 14629;
			x = 0.160244;
			y = 0.872000;
			w = 0.148000;
			text = "REFIT";
			action = "MenuAction = 728";
			tooltip = "Buy infantry replacements for the SELECTED team (charged from the war chest; per-team cooldown).";
			colorBackground[] = {0.15, 0.4, 0.45, 0.85};
			colorBackgroundActive[] = {0.2, 0.55, 0.6, 1};
		};
		class CA_Cmd_HoldTown : CA_Cmd_Rally {
			idc = 14630;
			x = 0.317244;
			y = 0.872000;
			w = 0.148000;
			text = "HOLD";
			action = "MenuAction = 729";
			tooltip = "Garrison the SELECTED team on its nearest OWNED town (it stays put until the hold expires).";
			colorBackground[] = {0, 0.5, 0, 0.85};
			colorBackgroundActive[] = {0.1, 0.7, 0.1, 1};
		};
		/* cmdcon41-w3i (Ray 2026-07-02) UI CONSOLIDATION: the SCUD (carrier) button (was idc 14631 / MenuAction 770) and
		   the two land-TEL munition buttons (were idc 14632/14633 "TEL: SATURATE"/"TEL: RECON", MenuActions 771/772) have
		   been REMOVED from the war room. ALL SCUD/TEL fire calls now live in the TACTICAL menu (Client/GUI/GUI_Menu_Tactical.sqf)
		   as support-list entries beside the classic ICBM/NUKE — "SCUD STRIKE (carrier)", "SCUD: SATURATION", "SCUD: RECON FLASH",
		   "SCUD: FASCAM (mines)", "SCUD: STEEL RAIN (anti-inf)", "SCUD: BUNKER BUSTER (point)". idc 14631/14632/14633 and
		   MenuActions 770/771/772 are now FREE. The carrier deck addAction is unchanged. */
		/* Status / hint line at the bottom of the console (shrunk + moved down to make room for the steering-verb row above). */
		class CA_Cmd_Help : RscStructuredText {
			idc = 14650;
			x = 0.00561695;
			y = 0.906000;
			w = 0.459244;
			h = 0.040000;
			size = 0.027;
		};
		/* DISBAND AI TEAMS (claude-gaming 2026-06-30, Ray): player-commander FAILSAFE - flags every AI field team for
		   disband (the proven wfbe_aicom_disband path; the HC deletes each only when no player is within SAFE_DIST and it
		   is not in COMBAT, so nothing vanishes in view). Server enforces a 15-min per-side cooldown + a human-commander
		   check. Two-click confirm client-side. Bottom-left, clear of Back/Exit (x>0.89). show=0 STRUCTURAL GUARD -> only
		   shown in STATE B (commander); added to _warCtrls in GUI_Menu_Command.sqf. Maroon = destructive. MenuAction 745. */
		class CA_Cmd_Disband : RscButton_Main {
			idc = 14626;
			x = 0.00561695;
			y = 0.953825;
			w = 0.224000;
			h = 0.040000;
			show = 0;
			text = "DISBAND AI TEAMS";
			action = "MenuAction = 745";
			tooltip = "FAILSAFE: stand down ALL AI field teams (the AI re-founds fresh). ~15-min cooldown. Click twice to confirm.";
			colorBackground[] = {0.45, 0.05, 0.1, 0.85};
			colorBackgroundActive[] = {0.7, 0.1, 0.15, 1};
		};
		/* DISBAND SELECTED (Command Console v2, claude-gaming 2026-07-01): stand down ONLY the highlighted roster team
		   (same player-safe teardown as DISBAND ALL - flags wfbe_aicom_disband; the HC deletes it only when no player is
		   near + not in combat). Sits on the same bottom row to the RIGHT of DISBAND ALL (x 0.241, right edge 0.465;
		   Back/Exit stay at x>0.89). show=0 STRUCTURAL GUARD -> STATE-B only; added to _warCtrls. Two-click confirm client
		   side. Server 'aicom-team-disband' handler extended to accept a specific team id. MenuAction 746. */
		class CA_Cmd_DisbandSel : CA_Cmd_Disband {
			idc = 14627;
			x = 0.241244;
			y = 0.953825;
			w = 0.224000;
			text = "DISBAND SELECTED";
			action = "MenuAction = 746";
			tooltip = "Stand down ONLY the highlighted team (player-safe: deletes it where no player is near + not in combat). Click twice to confirm.";
			colorBackground[] = {0.45, 0.05, 0.1, 0.85};
			colorBackgroundActive[] = {0.7, 0.1, 0.15, 1};
		};
		/* Back */
		class Back_Button : RscButton_Back {
			x = 0.892507;
			y = 0.953825;
			action = "MenuAction = 4";
			tooltip = $STR_WF_TOOLTIP_BackButton;
		};
		/* Exit */
		class Exit_Button : RscButton_Exit {
			x = 0.955773;
			y = 0.953825;
			onButtonClick = "closeDialog 0;";
			tooltip = $STR_WF_TOOLTIP_CloseButton;
		};
	};
};


//--- Tactical Menu. | ALL DONE!
class RscMenu_Tactical {
	movingEnable = 1;
	idd = 17000;
	onLoad = "_this ExecVM 'Client\GUI\GUI_Menu_Tactical.sqf'";
	
	class controlsBackground {
		class Background_M : RscText {
			x = 0.000960961;
			y = 0.00128125;
			w = 0.999759;
			h = 1.00023;
			moving = 1;
			colorBackground[] = WFBE_Background_Color;
		};
		class Background_H : RscText {
			x = 0.000960961;
			y = 0.00128125;
			w = 0.999759;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class Background_F : RscText {
			x = 0.000960961;
			y = 0.94901125;
			w = 0.999759;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class Background_L : RscText {
			x = 0.000960961;
			y = 0.05278125;
			w = 0.999759;
			h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
	};
	class controls {
		class WF_MiniMap : RscMapControl {
			idc = 17002;
			x = 0.374789;
			y = 0.0574369;
			w = 0.625427;
			h = 0.888975;
			ShowCountourInterval = 1;
			onMouseMoving = "mouseX = (_this Select 1);mouseY = (_this Select 2)";
			onMouseButtonDown = "mouseButtonDown = _this Select 1";
			onMouseButtonUp = "mouseButtonUp = _this Select 1";
		};
		class Title_Tactical : RscText_Title {
			idc = 17003;
			x = 0.00561695;
			y = 0.00999998;
			w = 0.3;
			text = $STR_WF_MAIN_TacticalMenu;
		};
		class CA_Artillery_SubTitle : RscText_SubTitle {
			idc = 17004;
			x = 0.00434637;
			y = 0.0596783;
			w = 0.2;
			text = $STR_WF_TACTICAL_Artillery;
		};
		// Marty: Shift the radius controls down to make room for artillery ammo selection.
		class CA_Artillery_Label_Radius : RscText {
			idc = 17030;
			x = 0.00602637;
			y = 0.223262;
			w = 0.2;
			text = $STR_WF_TACTICAL_ArtilleryRadius;
		};
		class CA_Artillery_Label_Unit : RscText {
			idc = 17031;
			x = 0.00434496;
			y = 0.14259;
			w = 0.2;
			text = $STR_WF_TACTICAL_Artillery;
		};
		// Marty: Keep the radius slider aligned with the shifted radius label.
		class CA_Artillery_Slider : RscXSliderH {
			idc = 17005;
			x = 0.14652;
			y = 0.229131;
			w = 0.224033;
			h = 0.029412;
		};
		class CA_SetFMission_Button : RscButton {
			idc = 17006;
			x = 0.12047;
			y = 0.507631;
			w = 0.25;
			text = $STR_WF_TACTICAL_ArtillerySetFireMission;
			action = "MenuAction = 1";
			/* spezial */
			colorBackground[] = {0.5882, 0.5882, 0.3529, 0.7};
			colorBackgroundActive[] = {0.5882, 0.5882, 0.3529, 1};
			colorFocused[] = {0.5882, 0.5882, 0.3529, 1};
		};
		class CA_FireMission_Button : RscButton {
			idc = 17007;
			x = 0.12047;
			y = 0.551631;
			w = 0.25;
			text = $STR_WF_TACTICAL_ArtilleryCallFireMission;
			action = "MenuAction = 2";
		};
		class CA_Artillery_Combo : RscCombo {
			idc = 17008;
			x = 0.145945;
			y = 0.146217;
			w = 0.147;
			h = 0.029412;
			onLBSelChanged = "MenuAction = 200";
		};
		// Card #113: one-click crew-all-artillery. Mounts available group AI into the empty
		// driver/gunner seats of the player's own artillery pieces.
		class CA_CrewArtillery_Button : RscButton {
			idc = 17040;
			x = 0.12047;
			y = 0.595631;
			w = 0.25;
			text = $STR_WF_TACTICAL_CrewArtillery;
			action = "MenuAction = 50";
			tooltip = $STR_WF_TACTICAL_CrewArtilleryTooltip;
		};
		// Marty: Ammo selector applies the selected shell type to all matching player artillery units.
		class CA_Artillery_Label_Ammo : RscText {
			idc = 17033;
			x = 0.00434496;
			y = 0.182926;
			w = 0.2;
			text = "Ammo:";
		};
		class CA_Artillery_Ammo_Combo : RscCombo {
			idc = 17034;
			x = 0.145945;
			y = 0.186553;
			w = 0.224033;
			h = 0.029412;
			onLBSelChanged = "MenuAction = 201";
		};
		class CA_Support_SubTitle : RscText_SubTitle {
			idc = 17009;
			x = 0.00518464;
			y = 0.646955;
			w = 0.2;
			text = $STR_WF_TACTICAL_Support;
		};
		class CA_Artillery_Label_Status : RscText {
			idc = 17032;
			x = 0.00602637;
			y = 0.102254;
			w = 0.2;
			text = $STR_WF_TACTICAL_ArtilleryStatus;
		};
		class CA_ArtilleryTimeout : RscStructuredText {
			idc = 17016;
			x = 0.139245;
			y = 0.107786;
			w = 0.213025;
			size = 0.03;
			shadow = 2;
		};
		class SupportList : RscListBox {
			idc = 17019;
			x = 0.00602497;
			y = 0.663556;
			w = 0.365965;
			h = 0.237187;
			rowHeight = 0.01;
			sizeEx = 0.026;
		};
		class CA_Button_Use : RscButton {
			idc = 17020;
			x = 0.22021;
			y = 0.905171;
			w = 0.15;
			text = $STR_WF_TACTICAL_RequestButton;
			action = "MenuAction = 20";
			/* spezial */
			colorBackground[] = {0.5882, 0.5882, 0.3529, 0.7};
			colorBackgroundActive[] = {0.5882, 0.5882, 0.3529, 1};
			colorFocused[] = {0.5882, 0.5882, 0.3529, 1};
		};
		class CA_SupportCost_Label : RscText {
			idc = 17026;
			x = 0.0119054;
			y = 0.907169;
			w = 0.11;
			text = "$STR_WF_TACTICAL_Price";
			sizeEx = 0.032;
		};
		class CA_SupportCost : RscText {
			idc = 17021;
			x = 0.111905;
			y = 0.907169;
			w = 0.11;
			sizeEx = 0.032;
			colorText[] = {1, 0, 0, 1};
		};
		class CA_InformationText : RscStructuredText {
			idc = 17022;
			x = 0.380816;
			y = 0.0188458;
			w = 0.614286;
			h = 0.035;
			size = 0.03;
			class Attributes {
				align = "center";
			};
		};
		//--- QoL item2 (client-qol-batch2): dedicated deny-reason text for Fast Travel.
		//--- Positioned just below CA_InformationText (17022). Separate IDC so it is
		//--- never overwritten by the SetControlFadeAnim that owns 17022.
		class CA_FTDenyReason : RscText {
			idc = 17027;
			x = 0.380816;
			y = 0.0558458;
			w = 0.614286;
			h = 0.030;
			sizeEx = 0.025;
			colorText[] = {1, 0.65, 0.1, 1};
			class Attributes {
				align = "center";
			};
		};
		class Ca_ArtilleryToggle : RscClickableText {
			idc = 17023;
			x = 0.310672;
			y = 0.121233;
			w = 0.064;
			h = 0.064;
			text = "Client\Images\tog_arty.paa";
			action = "MenuAction = 40";
			tooltip = $STR_WF_TOOLTIP_ArtilleryToggle;
		};
		// Marty: Move the artillery status table down after adding the ammo selector.
		class CA_ArtilleryList : RscListBoxA {
			idc = 17024;
			x = 0.00459768;
			y = 0.309084;
			w = 0.365209;
			h = 0.196;
			columns[] = {0.02, 0.55};
			drawSideArrows = 0;
			idcRight = -1;
			idcLeft = -1;
			rowHeight = 0.05;
			sizeEx = 0.023;
			
			/* extra */
			colorSelectBackground[] = {0, 0, 0, 0.5};
			colorSelectBackground2[] = {0, 0, 0, 0.5};
			
			onLBSelChanged = "MenuAction = 60";
		};	
		// Marty: Keep the artillery overview title aligned with the shifted table.
		class CA_ArtilleryTable_Label : RscText {
			idc = 17025;
			x = 0.00495766;
			y = 0.265604;
			w = 0.339999;
		};
		/* Separators */
		class LineTRH1 : RscText {
			x = 0.00638635;
			y = 0.63966;
			w = 0.364063;
			h = WFBE_SPT1;
			colorBackground[] = WFBE_SPC1;
		};
		/* Back */
		class Back_Button : RscButton_Back {
			x = 0.892328;
			y = 0.953825;
			action = "MenuAction = 30";
			tooltip = $STR_WF_TOOLTIP_BackButton;
		};
		/* Exit */
		class Exit_Button : RscButton_Exit {
			x = 0.956614;
			y = 0.953825;
			onButtonClick = "closeDialog 0;";
			tooltip = $STR_WF_TOOLTIP_CloseButton;
		};
	};
};


//--- Service Menu. | ALL DONE!
class RscMenu_Service {
	movingEnable = 1;
	idd = 20000;
	onLoad = "ExecVM ""Client\GUI\GUI_Menu_Service.sqf""";
	
	class controlsBackground {
		// Marty: Extend the service menu to fit the EASA row under the batch buttons.
		class Background_M : RscText {
			x = 0.157263;
			y = 0.151421;
			w = 0.687155;
			h = 0.815949;
			moving = 1;
			colorBackground[] = WFBE_Background_Color;
		};
		class Background_H : RscText {
			x = 0.157263;
			y = 0.151421;
			w = 0.687155;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		// Marty: Move the footer down with the enlarged service menu.
		class Background_F : RscText {
			x = 0.157263;
			y = 0.914870;
			w = 0.687155;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class Background_L : RscText {
			x = 0.157263;
			y = 0.202921;
			w = 0.687155;
			h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
	};
	class controls {
		class Title_Service : RscText_Title {
			idc = 20001;
			x = 0.161008;
			y = 0.157731;
			w = 0.3;
			text = $STR_WF_SupportMenu;
		};
		class CA_UnitList : RscListBox {
			idc = 20002;
			x = 0.162101;
			y = 0.209804;
			w = 0.677143;
			h = 0.385000;
			rowHeight = 0.025;
			sizeEx = 0.035;
		};
		class CA_ServiceInfo : RscStructuredText {
			idc = 20021;
			x = 0.162101;
			y = 0.604500;
			w = 0.677143;
			h = 0.082000;
			size = 0.021;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class CA_Rearm_Button : RscButton {
			idc = 20003;
			x = 0.161261;
			y = 0.686391;
			w = 0.165;
			text = $STR_WF_SERVICE_Rearm;
			action = "MenuAction = 1";
		};
		class CA_Repair_Button : RscButton {
			idc = 20004;
			x = 0.50748;
			y = 0.686391;
			w = 0.165;
			text = $STR_WF_SERVICE_Repair;
			action = "MenuAction = 2";
		};
		class CA_Refuel_Button : RscButton {
			idc = 20005;
			x = 0.161261;
			y = 0.733899;
			w = 0.165;
			text = $STR_WF_SERVICE_Refuel;
			action = "MenuAction = 3";
		};
		class CA_Heal_Button : RscButton {
			idc = 20008;
			x = 0.50748;
			y = 0.733899;
			w = 0.165;
			text = $STR_WF_SERVICE_Heal;
			action = "MenuAction = 5";
		};
		// Marty: Compact all-unit buttons sit inside the old single-action button width.
		class CA_RearmAll_Button : RscButton {
			idc = 20015;
			x = 0.329261;
			y = 0.686391;
			w = 0.052;
			text = "All";
			action = "MenuAction = 11";
		};
		class CA_RepairAll_Button : RscButton {
			idc = 20017;
			x = 0.675480;
			y = 0.686391;
			w = 0.052;
			text = "All";
			action = "MenuAction = 12";
		};
		class CA_RefuelAll_Button : RscButton {
			idc = 20022;
			x = 0.329261;
			y = 0.733899;
			w = 0.052;
			text = "All";
			action = "MenuAction = 13";
		};
		class CA_HealAll_Button : RscButton {
			idc = 20019;
			x = 0.675480;
			y = 0.733899;
			w = 0.052;
			text = "All";
			action = "MenuAction = 15";
		};
		class CA_LabelRearm: RscText {
			idc = 20011;
			x = 0.388739;
			y = 0.689752;
			w = 0.12;
		};
		class CA_LabelRepair : CA_LabelRearm {
			idc = 20012;
			x = 0.724957;
			y = 0.689752;
			w = 0.095;
		};
		class CA_LabelRefuel : CA_LabelRearm {
			idc = 20013;
			x = 0.388739;
			y = 0.735691;
			w = 0.12;
		};
		class CA_LabelHeal : CA_LabelRearm {
			idc = 20014;
			x = 0.724957;
			y = 0.735691;
			w = 0.095;
		};
		// Marty: Hidden total-price labels kept so older scripts/control maps stay harmless.
		class CA_LabelRearmAll: CA_LabelRearm {
			idc = 20016;
			x = 0;
			y = 0;
			w = 0;
			h = 0;
		};
		class CA_LabelRepairAll : CA_LabelRearmAll {
			idc = 20018;
		};
		class CA_LabelHealAll : CA_LabelRearmAll {
			idc = 20020;
		};
		// QoL item4 (client-qol-batch2): refuel-all batch price label (matches the pattern of 20016/20018/20020).
		class CA_LabelRefuelAll : CA_LabelRearmAll {
			idc = 20025;
		};
		class CA_FullService_Button : RscButton {
			idc = 20023;
			x = 0.161261;
			y = 0.767311;
			w = 0.22;
			text = "Full Service";
			action = "MenuAction = 16";
		};
		class CA_LabelFullService : CA_LabelRearm {
			idc = 20024;
			x = 0.388739;
			y = 0.770672;
			w = 0.12;
		};
		// Marty: Keep EASA visible as a loadout/configuration action, not a generic service action.
		class CA_EASA_Button : RscButton {
			idc = 20010;
			x = 0.50748;
			y = 0.767311;
			w = 0.331764;
			text = "Loadout (EASA)";
			action = "MenuAction = 7";
		};
		/* Back */
		// Marty: Align footer buttons with the enlarged service window.
		class Back_Button : RscButton_Back {
			x = 0.737046;
			y = 0.919685;
			action = "MenuAction = 8";
			tooltip = $STR_WF_TOOLTIP_BackButton;
		};
		/* Exit */
		// Marty: Align footer buttons with the enlarged service window.
		class Exit_Button : RscButton_Exit {
			x = 0.800311;
			y = 0.919685;
			onButtonClick = "closeDialog 0;";
			tooltip = $STR_WF_TOOLTIP_CloseButton;
		};
	};
};

//--- UnitCamera Menu. | ALL DONE!
class RscMenu_UnitCamera {
	movingEnable = 1;
	idd = 21000;
	onLoad = "_this ExecVM ""Client\GUI\GUI_Menu_UnitCamera.sqf""";
	
	class controlsBackground {
		class Background_M : RscText {
			x = 0.000119537;
			y = 0.70044;
			w = 0.999761;
			h = 0.298829;
			moving = 1;
			colorBackground[] = WFBE_Background_Color;
		};
		class Background_H : RscText {
			x = 0.000119537;
			y = 0.70044;
			w = 0.999761;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class Background_F : RscText {
			x = 0.000119537;
			y = 0.946769;
			w = 0.999761;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class Background_L : RscText {
			x = 0.000119537;
			y = 0.75194;
			w = 0.999761;
			h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
	};
	class controls {
		class Title_UnitCam : RscText_Title {
			idc = 21001;
			x = 0.00470497;
			y = 0.706961;
			w = 0.3;
			text = $STR_WF_TACTICAL_UnitCam;
		};
		class CA_Camera_UnitList : RscListBox {
			idc = 21002;
			x = -0.000335053;
			y = 0.755239;
			w = 0.311932;
			h = 0.190877;
			rowHeight = 0.01;
			sizeEx = 0.024;
			onLBSelChanged = "MenuAction = 101";
		};
		class CA_SquadKI_Label : RscText {
			idc = 21003;
			x = 0.312271;
			y = 0.714061;
			w = 0.3;
			colorText[] = {0.2588, 0.7137, 1, 1};
			text = $STR_WF_UNITCAM_SquadKI;
		};
		class CA_Camera_AIList : RscListBox {
			idc = 21004;
			x = 0.312269;
			y = 0.754063;
			w = 0.311932;
			h = 0.190877;
			rowHeight = 0.01;
			sizeEx = 0.024;
			onLBSelChanged = "MenuAction = 102";
		};
		class CA_Camera_Mode : RscText {
			idc = 21005;
			x = 0.629077;
			y = 0.713836;
			w = 0.3;
			colorText[] = {0.2588, 0.7137, 1, 1};
			text = $STR_WF_UNITCAM_CamMode;
		};
		class CA_Camera_Combo : RscCombo {
			idc = 21006;
			x = 0.831595;
			y = 0.711259;
			w = 0.163193;
			h = 0.035;
			onLBSelChanged = "MenuAction = 103";
		};
		class CA_MiniMap : RscMapControl {
            idc = 21007;
            x = 0.625041;
            y = 0.75514;
            w = 0.374504;
            h = 0.191614;
            ShowCountourInterval = 1;
            widthRailWay = 1;

            onMouseMoving = "mouseX = (_this Select 1);mouseY = (_this Select 2)";
            onMouseButtonDown = "mouseButtonDown = _this Select 1";
            onMouseButtonUp = "mouseButtonUp = _this Select 1";
        };
        //--Unflip button in Unit Camera Menu--
        class CA_UN_Button : RscClickableText {
            idc = 160003;
            x = 0.76602464;
            y = 0.953825;
            w = 0.045;
            h = 0.045;
            text = "\ca\ui\data\stats_soft_ca.paa";
            onButtonClick = "WF_MenuAction = 140";
            colorDisabled[] = {1,1,1,0.3};
            tooltip = $STR_WF_TOOLTIP_UnitCamUnflip;
        };
        /* Exit */
        class CA_UN_Exit_Button : RscButton_Exit {
            x = 0.954933;
            y = 0.953825;
            onButtonClick = "closeDialog 0;";
            tooltip = $STR_WF_TOOLTIP_CloseButton;
        };
	};
};

//--- Prameters Display. | ALL DONE!
class RscDisplay_Parameters {
	movingEnable = 1;
	idd = 22000;
	onLoad = "_this ExecVM ""Client\GUI\GUI_Display_Parameters.sqf""";
	
	class controlsBackground {
		class Background_M : RscText {
			x = -0.000478864;
			y = 0.151421;
			w = 1.00096;
			h = 0.699949;
			moving = 1;
			colorBackground[] = WFBE_Background_Color;
		};
		class Background_H : RscText {
			x = -0.000478864;
			y = 0.151421;
			w = 1.00096;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class Background_F : RscText {
			x = -0.000478864;
			y = 0.798870;
			w = 1.00096;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class Background_L : RscText {
			x = -0.000478864;
			y = 0.202921;
			w = 1.00096;
			h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
	};
	class controls {
		class Title_Parameter : RscText_Title {
			idc = 22002;
			x = 0.00510308;
			y = 0.157759;
			w = 0.3;
			text = $STR_WF_PARAMETER_Parameters;
		};
		class LB_ParamsTitles : RscListBoxA {
			idc = 22003;
			columns[] = {0.01, 0.55};
			rowHeight = 0.036;
			drawSideArrows = 0;
			idcRight = -1;
			idcLeft = -1;
			x = 0.00204286;
			y = 0.211603;
			w = 0.997959;
			h = 0.579722;
		};
		/* Back */
		class Back_Button : RscButton_Back {
			x = 0.892509;
			y = 0.804806;
			action = "MenuAction = 1";
			tooltip = $STR_WF_TOOLTIP_BackButton;
		};
		/* Exit */
		class Exit_Button : RscButton_Exit {
			x = 0.955774;
			y = 0.804806;
			onButtonClick = "closeDialog 0;";
			tooltip = $STR_WF_TOOLTIP_CloseButton;
		};
	};
};

//--- EASA Menu. | ALL DONE!
class RscMenu_EASA {
	movingEnable = 1;
	idd = 24000;
	onLoad = "_this ExecVM ""Client\GUI\GUI_Menu_EASA.sqf""";
	
	class controlsBackground {
		class Background_M : RscText {
			x = 0.157263;
			y = 0.200721;
			w = 0.687155;
			h = 0.601349;
			moving = 1;
			colorBackground[] = WFBE_Background_Color;
		};
		class Background_H : RscText {
			x = 0.157263;
			y = 0.200721;
			w = 0.687155;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class Background_F : RscText {
			x = 0.157263;
			y = 0.749570;
			w = 0.687155;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class Background_L : RscText {
			x = 0.157263;
			y = 0.252221;
			w = 0.687155;
			h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
	};
	class controls {
		class Title_EASA : RscText_Title {
			idc = 23002;
			x = 0.162105;
			y = 0.207843;
			w = 0.6;
			text = $STR_WF_EASA;
		};
		class LB_EASA : RscListBoxA {
			idc = 23003;
			columns[] = {0.01, 0.16};
			rowHeight = 0.036;
			drawSideArrows = 0;
			idcRight = -1;
			idcLeft = -1;
			x = 0.162186;
			y = 0.263187;
			w = 0.67689;
			h = 0.476481;
			onLBDblClick = "MenuAction = 101";
		};
		class CA_Purchase : RscButton {
			idc = 22004;
			x = 0.613615;
			y = 0.758018;
			w = 0.1;
			text = $STR_WF_Purchase;
			action = "MenuAction = 101";
		};
		/* Back to WF_Menu hub (UX Pass 1). MenuAction 102 handled in GUI_Menu_EASA.sqf. */
		class Back_Button : RscButton_Back {
			x = 0.157263;
			y = 0.755506;
			onButtonClick = "MenuAction = 102;";
			tooltip = $STR_WF_TOOLTIP_BackButton;
		};
		/* Exit */
		class Exit_Button : RscButton_Exit {
			x = 0.799471;
			y = 0.755506;
			onButtonClick = "closeDialog 0;";
			tooltip = $STR_WF_TOOLTIP_CloseButton;
		};
	};
};

//--- Economy Menu. | ALL DONE!
class RscMenu_Economy {
	movingEnable = 1;
	idd = 23000;
	onLoad = "_this ExecVM 'Client\GUI\GUI_Menu_Economy.sqf'";
	
	class controlsBackground {
		class Background_M : RscText {
			x = 0.0318137;
			y = 0.2004;
			w = 0.938056;
			h = 0.59934;
			moving = 1;
			colorBackground[] = WFBE_Background_Color;
		};
		class Background_H : RscText {
			x = 0.0318137;
			y = 0.2004;
			w = 0.938056;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class Background_F : RscText {
			x = 0.0318137;
			y = 0.74724;
			w = 0.938056;
			h = 0.0525;
			moving = 1;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class Background_L : RscText {
			x = 0.0318137;
			y = 0.2519;
			w = 0.938056;
			h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
	};
	class controls {
		class WF_MiniMap : RscMapControl {
			idc = 23002;
			x = 0.5;
			y = 0.254636;
			w = 0.469125;
			h = 0.492337;
			ShowCountourInterval = 1;
			
			onMouseMoving = "mouseX = (_this Select 1);mouseY = (_this Select 2)";
			onMouseButtonDown = "mouseButtonDown = _this Select 1";
			onMouseButtonUp = "mouseButtonUp = _this Select 1";
		};
		class Title_CommanderMenu : RscText_Title {
			idc = 23003;
			x = 0.0367093;
			y = 0.207199;
			w = 0.3;
			text = $STR_WF_MAIN_EconomyMenu;
		};
		class CA_LabelPartWorkers : RscText_SubTitle {
			idc = 23008;
			x = 0.0322372;
			y = 0.264119;
			w = 0.25;
			text = "Economy Overview";
		};
		class CA_EconomyDashboard : RscStructuredText {
			idc = 23020;
			x = 0.0372786;
			y = 0.305000;
			w = 0.360000;
			h = 0.140000;
			size = 0.030;
			shadow = 1;
		};
		/* Income */
		class CA_LabelPartIncome : CA_LabelPartWorkers {
			idc = 23009;
			x = 0.0322358;
			y = 0.456346;
			w = 0.25;
			text = $STR_WF_ECONOMY_Income_Sys;
		};
		class CA_Slider_Income : RscXSliderH {
			idc = 23010;
			x = 0.0372786;
			y = 0.514272;
			w = 0.333109;
			h = 0.029412;
		};
		class CA_LabelIncomePercent : RscText {
			idc = 23011;
			x = 0.394873;
			y = 0.512032;
			w = 0.15;
		};
		class CA_IncomeSet_Button : RscButton {
			idc = 23012;
			x = 0.0372772;
			y = 0.567717;
			w = 0.334;
			text = $STR_WF_ECONOMY_SetIncome;
			action = "MenuAction = 3";
		};
		class CA_LabelIncomeCommander : RscText {
			idc = 23013;
			x = 0.0372772;
			y = 0.634608;
			w = 0.399999;
		};
		class CA_LabelPlayerCommander : CA_LabelIncomeCommander {
			idc = 23014;
			x = 0.0372772;
			y = 0.687535;
			w = 0.399999;
		};
		/* Selling Structures */
		class CA_Sell : RscButton {
			idc = 23015;
			x = 0.501454;
			y = 0.757255;
			w = 0.28; 
			text = $STR_WF_ECONOMY_SellStructure;
			action = "MenuAction = 105";
			/* spezial */
			colorBackground[] = {0.5882, 0.5882, 0.3529, 0.7};
			colorBackgroundActive[] = {0.5882, 0.5882, 0.3529, 1};
			colorFocused[] = {0.5882, 0.5882, 0.3529, 1};
		};
		/* Respawn Supply Truck Debug */
		class CA_RespST_Button : RscClickableText {
			idc = 23016;
			x = 0.0368904;
			y = 0.751251;
			w = 0.05;
			h = 0.05;
			text = "Client\Images\picturepapercar_ca.paa";
			action = "MenuAction = 4";
			tooltip = $STR_WF_TOOLTIP_RespawnST;
		};
		/* Separators */
		class LineTRH1 : RscText {
			x = 0.0349591;
			y = 0.449622;
			w = 0.459861;
			h = WFBE_SPT1;
			colorBackground[] = WFBE_SPC1;
		};
		/* Back */
		class Back_Button : RscButton_Back {
			x = 0.861415;
			y = 0.754385;
			action = "MenuAction = 5";
			tooltip = $STR_WF_TOOLTIP_BackButton;
		};
		/* Exit */
		class Exit_Button : RscButton_Exit {
			x = 0.924681;
			y = 0.754385;
			onButtonClick = "closeDialog 0;";
			tooltip = $STR_WF_TOOLTIP_CloseButton;
		};
	};
};

//--- Help Menu (REDESIGN)
class RscMenu_Help {
	movingEnable = 1;
	idd = 508000;
	onLoad  = "uiNamespace setVariable ['dialog_HelpPanel', _this select 0];['onLoad'] execVM 'Client\GUI\GUI_Menu_Help.sqf'";
	onUnload = "uiNamespace setVariable ['dialog_HelpPanel', nil];";

	class controlsBackground {
		//--- Full-panel backdrop
		class WF_Background : RscText {
			x = "SafeZoneX + (SafeZoneW * 0.1)";
			y = "SafeZoneY + (SafezoneH * 0.105)";
			w = "SafeZoneW * 0.8";
			h = "SafeZoneH * 0.8";
			colorBackground[] = WFBE_Background_Color;
			moving = 1;
		};
		//--- Header strip (drag handle)
		class WF_Background_Header : WF_Background {
			y = "SafeZoneY + (SafezoneH * 0.105)";
			h = "SafeZoneH * 0.05";
			colorBackground[] = WFBE_Background_Color_Header;
		};
		//--- Footer strip
		class Footer : RscText {
			x = "SafeZoneX + (SafeZoneW * 0.1)";
			y = 0.871195 * safezoneH + safezoneY;
			w = "SafeZoneW * 0.8";
			h = 0.034396 * safezoneH;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		//--- Left section-list frame (slightly narrower than stock for a wider read pane)
		class CTI_Menu_InfoListFrame : RscFrame {
			x = "SafeZoneX + (SafeZoneW * 0.12)";
			y = "SafeZoneY + (SafezoneH * 0.175)";
			w = "SafeZoneW * 0.19";
			h = 0.676391 * safezoneH;
		};
		//--- Right content frame + translucent backing
		class CTI_Menu_InfoResourcesFrame : RscFrame {
			x = "SafeZoneX + (SafeZoneW * 0.325)";
			y = "SafeZoneY + (SafezoneH * 0.175)";
			w = "SafeZoneW * 0.555";
			h = 0.676391 * safezoneH;
		};
		class CTI_Menu_Info_Background : RscText {
			x = "SafeZoneX + (SafeZoneW * 0.325)";
			y = "SafeZoneY + (SafezoneH * 0.175)";
			w = "SafeZoneW * 0.555";
			h = 0.676391 * safezoneH;
			colorBackground[] = {0.5, 0.5, 0.5, 0.20};
		};
	};

	class controls {
		//--- Dynamic title bar (rewritten per-section by the controller).
		//    StructuredText (not RscText) so we can color/size the active page name.
		class CTI_Menu_Title : RscStructuredText {
			idc = 160003;
			x = "SafeZoneX + (SafeZoneW * 0.12)";
			y = "SafeZoneY + (SafezoneH * 0.112)";
			w = "SafeZoneW * 0.76";
			h = "SafeZoneH * 0.040";
			size = "0.95 * (((((safezoneW / safezoneH) min 1.2) / 1.2) / 25) * 1)";
			text = "";
		};

		//--- LEFT: section list
		class CTI_Menu_Help_Topics : RscListBox {
			idc = 160001;
			x = "SafeZoneX + (SafeZoneW * 0.12)";
			y = "SafeZoneY + (SafezoneH * 0.175)";
			w = "SafeZoneW * 0.19";
			h = 0.676389 * safezoneH;

			rowHeight = "1.7 * (((((safezoneW / safezoneH) min 1.2) / 1.2) / 25))";
			sizeEx    = "0.82 * (((((safezoneW / safezoneH) min 1.2) / 1.2) / 25))";

			colorText[]       = {1, 1, 1, 1};
			colorBackground[] = {0, 0, 0, 0};
			onLBSelChanged = "['onHelpLBSelChanged', _this select 1] call compile preprocessFileLineNumbers 'Client\GUI\GUI_Menu_Help.sqf'";
		};

		//--- RIGHT: scrollable content pane inside a controls group
		class Menu_Help_ControlsGroup : RscControlsGroup {
			x = "SafeZoneX + (SafeZoneW * 0.335)";
			y = "SafeZoneY + (SafezoneH * 0.185)";
			w = "SafeZoneW * 0.535";
			h = 0.656389 * safezoneH;

			class controls {
				class CTI_Menu_Help_Explanation : RscStructuredText {
					idc = 160002;
					x = "0";
					y = "0";
					w = "SafeZoneW * 0.515";
					h = "SafeZoneH * 2.71";  // tall so vertical scrollbar engages for long copy
					size = "0.85 * (((((safezoneW / safezoneH) min 1.2) / 1.2) / 25) * 1)";
				};
			};
		};

		//--- Back to the WF command menu (sibling-consistent).
		class Back_Button : RscButton_Back {
			x = 0.822374 * safezoneW + safezoneX;
			y = 0.878751 * safezoneH + safezoneY;
			tooltip = $STR_WF_TOOLTIP_BackButton;
			onButtonClick = "closeDialog 0; createDialog 'WF_Menu';";
		};

		//--- Close.
		class Exit_Button : RscButton_Exit {
			x = 0.868374 * safezoneW + safezoneX;
			y = 0.878751 * safezoneH + safezoneY;
			tooltip = $STR_WF_TOOLTIP_CloseButton;
			onButtonClick = "closeDialog 0;";
		};
	};
};

//--- Command Deck: Skin Selector (idd 27000).
class WFBE_SkinSelectorMenu {
	movingEnable = 1;
	idd = 27000;
	onLoad = "(_this) ExecVM 'Client\GUI\GUI_SkinSelectorMenu.sqf'";

	class controlsBackground {
		class CA_Background : RscText {
			x = 0.25;
			y = 0.08;
			w = 0.50;
			h = 0.84;
			colorBackground[] = WFBE_Background_Color;
			moving = 1;
		};
		class CA_Background_Header : CA_Background {
			x = 0.25;
			y = 0.08;
			w = 0.50;
			h = 0.06;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class CA_Background_Footer : CA_Background {
			x = 0.25;
			y = 0.08 + 0.80;
			w = 0.50;
			h = 0.04;
			colorBackground[] = WFBE_Background_Color_Sub;
		};
		//--- Accent border line below header.
		class CA_Border : RscText {
			x = 0.25;
			y = 0.08 + 0.06;
			w = 0.50;
			h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
	};

	class controls {
		//--- Header title (idc 27008) — RscButton_Main so ctrlSetText works at runtime.
		class CA_Title : RscButton_Main {
			idc = 27008;
			x = 0.255;
			y = 0.08 + 0.012;
			w = 0.35;
			h = 0.038;
			text = $STR_WF_SkinSelector_Title;
			sizeEx = 0.028;
			colorBackground[] = {0, 0, 0, 0};
			colorBackgroundFocus[] = {0, 0, 0, 0};
			colorBackgroundActive[] = {0, 0, 0, 0};
			colorText[] = WFBE_Menu_Text_Color;
			shadow = 2;
			default = false;
		};
		//--- Close button.
		class CA_Quit_Button : RscButton_Main {
			x = 0.25 + 0.45;
			y = 0.08 + 0.0075;
			w = 0.045;
			h = 0.045;
			text = "X";
			shadow = 2;
			sizeEx = 0.03;
			onButtonClick = "WFBE_MenuAction = 2;";
		};
		//--- Skin list (idc 27001).
		class CA_SkinList : RscListBox {
			idc = 27001;
			x = 0.255;
			y = 0.08 + 0.07;
			w = 0.22;
			h = 0.65;
			rowHeight = 0.03;
			colorSelectBackground[] = WFBE_Menu_ListBox_Select_Color;
			onLBSelChanged = "";
		};
		//--- Portrait picture (idc 27002).
		class CA_Portrait : RscPicture {
			idc = 27002;
			x = 0.485;
			y = 0.08 + 0.07;
			w = 0.12;
			h = 0.24;
			style = 0x30 + 0x800;
			text = "";
		};
		//--- Skin name label (idc 27003).
		class CA_SkinName : RscText {
			idc = 27003;
			x = 0.485;
			y = 0.08 + 0.32;
			w = 0.255;
			h = 0.04;
			sizeEx = 0.026;
			text = "";
			colorText[] = WFBE_Menu_Text_Color;
			shadow = 2;
		};
		//--- Faction label (idc 27004).
		class CA_FactionName : RscText {
			idc = 27004;
			x = 0.485;
			y = 0.08 + 0.365;
			w = 0.255;
			h = 0.035;
			sizeEx = 0.022;
			text = "";
			colorText[] = WFBE_Menu_Text_Color;
			shadow = 2;
		};
		//--- Ghillie note (idc 27005).
		class CA_GhillieNote : RscText {
			idc = 27005;
			x = 0.255;
			y = 0.08 + 0.73;
			w = 0.485;
			h = 0.03;
			sizeEx = 0.020;
			text = "";
			colorText[] = WFBE_Menu_Text_Color;
			shadow = 2;
		};
		//--- APPLY button (idc 27006) — RscButton_Main for ctrlSetText compat.
		class CA_Apply : RscButton_Main {
			idc = 27006;
			x = 0.330;
			y = 0.08 + 0.762;
			w = 0.15;
			h = 0.035;
			sizeEx = 0.028;
			text = $STR_WF_SkinSelector_Apply;
			action = "WFBE_MenuAction = 1";
		};
		//--- SKIP button (idc 27007).
		class CA_Skip : RscButton_Main {
			idc = 27007;
			x = 0.490;
			y = 0.08 + 0.762;
			w = 0.10;
			h = 0.035;
			sizeEx = 0.026;
			text = $STR_WF_SkinSelector_Skip;
			action = "WFBE_MenuAction = 2";
		};
	};
};

//--- Per-player Settings menu (idd 29000). Opened from the WF-menu GEAR button (revived skins slot, MenuAction 24).
//--- All labels (29010-29014 toggles, 29020 VD) set live by WASP\actions\Settings\Settings_Open.sqf (sub-dialog global WFBE_MenuAction).
class WFBE_SettingsMenu {
	movingEnable = 1;
	idd = 29000;

	class controlsBackground {
		class CA_Background : RscText {
			x = 0.30; y = 0.18; w = 0.40; h = 0.66;
			colorBackground[] = WFBE_Background_Color;
			moving = 1;
		};
		class CA_Background_Header : CA_Background {
			h = 0.06;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class CA_Border : RscText {
			x = 0.30; y = 0.18 + 0.06; w = 0.40; h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
	};

	class controls {
		class CA_Title : RscButton_Main {
			idc = 29001;
			x = 0.305; y = 0.18 + 0.012; w = 0.30; h = 0.038;
			text = "SETTINGS";
			sizeEx = 0.028;
			colorBackground[] = {0, 0, 0, 0};
			colorBackgroundFocus[] = {0, 0, 0, 0};
			colorBackgroundActive[] = {0, 0, 0, 0};
			colorText[] = WFBE_Menu_Text_Color;
			shadow = 2;
			default = false;
		};
		class CA_Quit_Button : RscButton_Main {
			x = 0.30 + 0.355; y = 0.18 + 0.0075; w = 0.045; h = 0.045;
			text = "X";
			shadow = 2; sizeEx = 0.03;
			onButtonClick = "WFBE_MenuAction = 9;";
		};
		//--- Toggle rows (text set live by the controller; click flips the pref).
		class CA_HUD : RscButton_Main {
			idc = 29010;
			x = 0.325; y = 0.18 + 0.085; w = 0.35; h = 0.044;
			sizeEx = 0.026;
			text = "HUD Overlay: ON";
			action = "WFBE_MenuAction = 1";
		};
		class CA_AAR  : CA_HUD { idc = 29011; y = 0.18 + 0.135; text = "AAR Map Markers: ON";   action = "WFBE_MenuAction = 2"; };
		class CA_Bomb : CA_HUD { idc = 29012; y = 0.18 + 0.185; text = "Bomb Alt Warning: ON";   action = "WFBE_MenuAction = 3"; };
		class CA_Amb  : CA_HUD { idc = 29013; y = 0.18 + 0.235; text = "Ambulance Circles: ON";  action = "WFBE_MenuAction = 4"; };
		class CA_Kill : CA_HUD { idc = 29014; y = 0.18 + 0.285; text = "Kill Feed: ON";          action = "WFBE_MenuAction = 5"; };
		class CA_IRS   : CA_HUD { idc = 29015; y = 0.18 + 0.335; text = "Auto IR Smoke: ON";     action = "WFBE_MenuAction = 6"; };
		class CA_Bipod : CA_HUD { idc = 29016; y = 0.18 + 0.385; text = "Auto Deploy Bipod: ON"; action = "WFBE_MenuAction = 7"; };
		class CA_Audio : CA_HUD { idc = 29017; y = 0.18 + 0.435; text = "Audio Cues: OFF";       action = "WFBE_MenuAction = 8"; };
		//--- View-distance label + choice row.
		class CA_VDLabel : RscText {
			idc = 29020;
			x = 0.325; y = 0.18 + 0.49; w = 0.35; h = 0.03;
			sizeEx = 0.022;
			text = "View Distance:";
			colorText[] = WFBE_Menu_Text_Color;
			shadow = 2;
		};
		class CA_VD1 : RscButton_Main {
			idc = 29021;
			x = 0.325; y = 0.18 + 0.525; w = 0.066; h = 0.05;
			sizeEx = 0.022;
			text = "1000";
			action = "WFBE_MenuAction = 11";
		};
		class CA_VD2 : CA_VD1 { idc = 29022; x = 0.325 + 0.070; text = "2000"; action = "WFBE_MenuAction = 12"; };
		class CA_VD3 : CA_VD1 { idc = 29023; x = 0.325 + 0.140; text = "3000"; action = "WFBE_MenuAction = 13"; };
		class CA_VD4 : CA_VD1 { idc = 29024; x = 0.325 + 0.210; text = "4000"; action = "WFBE_MenuAction = 14"; };
		class CA_VD5 : CA_VD1 { idc = 29025; x = 0.325 + 0.280; text = "5000"; action = "WFBE_MenuAction = 15"; };
		//--- Done.
		class CA_Done : RscButton_Main {
			idc = 29009;
			x = 0.325; y = 0.18 + 0.60; w = 0.35; h = 0.04;
			sizeEx = 0.026;
			text = "Done";
			action = "WFBE_MenuAction = 9";
		};
	};
};

//--- Adaptive View-Distance / Target-FPS picker (idd 28000). Opened from the WF-menu "FPS" button.
//--- Labels (idc 28001 toggle, 28006 status) are set live by WASP\actions\FPSPicker\FPSPicker_Open.sqf.
class WFBE_FPSPickerMenu {
	movingEnable = 1;
	idd = 28000;

	class controlsBackground {
		class CA_Background : RscText {
			x = 0.32;
			y = 0.30;
			w = 0.36;
			h = 0.40;
			colorBackground[] = WFBE_Background_Color;
			moving = 1;
		};
		class CA_Background_Header : CA_Background {
			h = 0.06;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class CA_Background_Footer : CA_Background {
			y = 0.30 + 0.36;
			h = 0.04;
			colorBackground[] = WFBE_Background_Color_Sub;
		};
		class CA_Border : RscText {
			x = 0.32;
			y = 0.30 + 0.06;
			w = 0.36;
			h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
	};

	class controls {
		//--- Header title.
		class CA_Title : RscButton_Main {
			idc = 28008;
			x = 0.325;
			y = 0.30 + 0.012;
			w = 0.30;
			h = 0.038;
			text = "VD / FPS";
			sizeEx = 0.028;
			colorBackground[] = {0, 0, 0, 0};
			colorBackgroundFocus[] = {0, 0, 0, 0};
			colorBackgroundActive[] = {0, 0, 0, 0};
			colorText[] = WFBE_Menu_Text_Color;
			shadow = 2;
			default = false;
		};
		//--- Close (X).
		class CA_Quit_Button : RscButton_Main {
			x = 0.32 + 0.315;
			y = 0.30 + 0.0075;
			w = 0.045;
			h = 0.045;
			text = "X";
			shadow = 2;
			sizeEx = 0.03;
			onButtonClick = "WFBE_MenuAction = 9;";
		};
		//--- Auto-VD on/off toggle (text set at runtime, idc 28001).
		class CA_Toggle : RscButton_Main {
			idc = 28001;
			x = 0.345;
			y = 0.30 + 0.085;
			w = 0.31;
			h = 0.05;
			sizeEx = 0.028;
			text = "Auto-VD: OFF";
			action = "WFBE_MenuAction = 1";
		};
		//--- Explanatory line.
		class CA_Status : RscText {
			idc = 28002;
			x = 0.345;
			y = 0.30 + 0.145;
			w = 0.31;
			h = 0.03;
			sizeEx = 0.020;
			text = "Adapts VD to hold your target FPS.";
			colorText[] = WFBE_Menu_Text_Color;
			shadow = 2;
		};
		//--- Target-FPS preset buttons (30 / 45 / 50 / 60).
		class CA_FPS45 : RscButton_Main {
			idc = 28003;
			x = 0.4225;
			y = 0.30 + 0.20;
			w = 0.07;
			h = 0.05;
			sizeEx = 0.024;
			text = "45 FPS";
			action = "WFBE_MenuAction = 2";
		};
		class CA_FPS30 : CA_FPS45 {
			idc = 28009;
			x = 0.345;
			text = "30 FPS";
			action = "WFBE_MenuAction = 5";
		};
		class CA_FPS50 : CA_FPS45 {
			idc = 28004;
			x = 0.50;
			text = "50 FPS";
			action = "WFBE_MenuAction = 3";
		};
		class CA_FPS60 : CA_FPS45 {
			idc = 28005;
			x = 0.5775;
			text = "60 FPS";
			action = "WFBE_MenuAction = 4";
		};
		//--- Current state (set at runtime, idc 28006).
		class CA_Current : RscText {
			idc = 28006;
			x = 0.345;
			y = 0.30 + 0.265;
			w = 0.31;
			h = 0.035;
			sizeEx = 0.022;
			text = "";
			colorText[] = WFBE_Menu_Text_Color;
			shadow = 2;
		};
		//--- Done / close.
		class CA_Done : RscButton_Main {
			idc = 28007;
			x = 0.345;
			y = 0.30 + 0.325;
			w = 0.31;
			h = 0.04;
			sizeEx = 0.026;
			text = "Close";
			action = "WFBE_MenuAction = 9";
		};
	};
};

//--- ============================================================================================
//--- PLAYER SETTINGS dialog v2 (idd 30000). GR-2026-07-03a.
//--- One native-styled screen that unifies every player-side toggle/option (was: two scroll menus,
//--- WFBE_SettingsMenu idd 29000 + WFBE_FPSPickerMenu idd 28000). Both WF-menu footer buttons
//--- (FPS = MenuAction 23, SETUP = MenuAction 24) now open THIS dialog.
//--- Controller: WASP\actions\Settings\Settings_Open.sqf (polls WFBE_MenuAction; applies live;
//--- persists via WFBE_CO_FNC_SetProfileVariable using the SAME profile keys as before).
//--- IDC map: 30001 title | 30009 close | Video: 30010 VD-label 30011 VD-slider(RscXSliderH)
//--- 30012 Auto-VD toggle 30013..30016 FPS 30/45/50/60 | Gameplay: 30020..30026 seven toggles
//--- Audio: 30030 Audio Cues | 30040 footer Close. Slider range clamps to WFBE_C_ENVIRONMENT_MAX_VIEW.
//--- A2-OA-safe: RscXSliderH (type 43) + RscButton_Main are already used by the Team menu (idd 13000).
//--- No A3 checkbox class. ctrlShow on this idd dialog MUST use the global ctrlShow [idc,bool] form.
class WFBE_PlayerSettingsMenu {
	movingEnable = 1;
	idd = 30000;

	class controlsBackground {
		class CA_Background : RscText {
			x = 0.275; y = 0.135; w = 0.45; h = 0.822;
			colorBackground[] = WFBE_Background_Color;
			moving = 1;
		};
		class CA_Background_Header : CA_Background {
			h = 0.06;
			colorBackground[] = WFBE_Background_Color_Header;
		};
		class CA_Background_Footer : CA_Background {
			y = 0.135 + 0.782;
			h = 0.04;
			colorBackground[] = WFBE_Background_Color_Footer;
		};
		class CA_Border : RscText {
			x = 0.275; y = 0.135 + 0.06; w = 0.45; h = WFBE_Background_Border_Thick;
			colorBackground[] = WFBE_Background_Border;
		};
	};

	class controls {
		//--- Header title.
		class CA_Title : RscText_Title {
			idc = 30001;
			x = 0.29; y = 0.135 + 0.012; w = 0.40; h = 0.04;
			text = "PLAYER SETTINGS";
		};
		//--- Close (X) top-right.
		class CA_Quit_Button : RscButton_Main {
			idc = 30008;
			x = 0.275 + 0.405; y = 0.135 + 0.0075; w = 0.045; h = 0.045;
			text = "X";
			shadow = 2; sizeEx = 0.03;
			onButtonClick = "WFBE_MenuAction = 9;";
		};

		//--- ===== VIDEO =====
		class CA_VideoHead : RscText_SubTitle {
			idc = 30002;
			x = 0.29; y = 0.135 + 0.075; w = 0.40; h = 0.035;
			text = "VIDEO";
		};
		//--- View-distance label (value set live by the controller) + slider (range set live, clamped to map cap).
		class CA_VDLabel : RscText {
			idc = 30010;
			x = 0.29; y = 0.135 + 0.115; w = 0.20; h = 0.03;
			sizeEx = 0.024;
			text = "View Distance:";
			colorText[] = WFBE_Menu_Text_Color;
			shadow = 2;
		};
		class CA_VDSlider : RscXSliderH {
			idc = 30011;
			x = 0.475; y = 0.135 + 0.117; w = 0.235; h = 0.029;
		};
		//--- Terrain-grid / clutter label (value set live) + slider (range set live to WFBE_C_ENVIRONMENT_MAX_CLUTTER).
		class CA_TGLabel : RscText {
			idc = 30017;
			x = 0.29; y = 0.135 + 0.155; w = 0.20; h = 0.03;
			sizeEx = 0.024;
			text = "Terrain Grid:";
			colorText[] = WFBE_Menu_Text_Color;
			shadow = 2;
		};
		class CA_TGSlider : RscXSliderH {
			idc = 30018;
			x = 0.475; y = 0.135 + 0.157; w = 0.235; h = 0.029;
		};
		//--- Auto view-distance toggle (text set live).
		class CA_AutoVD : RscButton_Main {
			idc = 30012;
			x = 0.29; y = 0.135 + 0.195; w = 0.42; h = 0.042;
			sizeEx = 0.024;
			text = "Auto View Distance: OFF";
			action = "WFBE_MenuAction = 20";
		};
		//--- Target FPS row (auto-VD chases this): 30 / 45 / 50 / 60.
		class CA_FPSLabel : RscText {
			idc = 30003;
			x = 0.29; y = 0.135 + 0.245; w = 0.16; h = 0.03;
			sizeEx = 0.022;
			text = "Target FPS:";
			colorText[] = WFBE_Menu_Text_Color;
			shadow = 2;
		};
		class CA_FPS30 : RscButton_Main {
			idc = 30013;
			x = 0.455; y = 0.135 + 0.242; w = 0.06; h = 0.04;
			sizeEx = 0.022;
			text = "30";
			action = "WFBE_MenuAction = 30";
		};
		class CA_FPS45 : CA_FPS30 { idc = 30014; x = 0.520; text = "45"; action = "WFBE_MenuAction = 31"; };
		class CA_FPS50 : CA_FPS30 { idc = 30015; x = 0.585; text = "50"; action = "WFBE_MenuAction = 32"; };
		class CA_FPS60 : CA_FPS30 { idc = 30016; x = 0.650; text = "60"; action = "WFBE_MenuAction = 33"; };

		//--- ===== GAMEPLAY =====
		class CA_GameplayHead : RscText_SubTitle {
			idc = 30004;
			x = 0.29; y = 0.135 + 0.305; w = 0.40; h = 0.035;
			text = "GAMEPLAY";
		};
		//--- Ray 2026-07-04b: HUD-Overlay toggle RESTORED (supersedes the 2026-07-04 hard-off; Ray re-enabled the RHUD by
		//--- default - see Client_UpdateRHUD.sqf). CA_HUD carries the shared geometry; every row keeps its original slot.
		//--- Toggle rows, two columns. Text set live by the controller; click flips the pref.
		class CA_HUD : RscButton_Main {
			idc = 30020;
			x = 0.29; y = 0.135 + 0.345; w = 0.205; h = 0.042;
			sizeEx = 0.022;
			text = "HUD Overlay: ON";
			action = "WFBE_MenuAction = 1";
		};
		class CA_AAR   : CA_HUD { idc = 30021; x = 0.505; y = 0.135 + 0.345; text = "AAR Markers: ON";    action = "WFBE_MenuAction = 2"; };
		class CA_Bomb  : CA_HUD { idc = 30022; x = 0.29;  y = 0.135 + 0.392; text = "Bomb Warning: ON";   action = "WFBE_MenuAction = 3"; };
		class CA_Amb   : CA_HUD { idc = 30023; x = 0.505; y = 0.135 + 0.392; text = "Ambulance Rings: ON"; action = "WFBE_MenuAction = 4"; };
		class CA_Kill  : CA_HUD { idc = 30024; x = 0.29;  y = 0.135 + 0.439; text = "Kill Feed: ON";       action = "WFBE_MenuAction = 5"; };
		class CA_IRS   : CA_HUD { idc = 30025; x = 0.505; y = 0.135 + 0.439; text = "Auto IR Smoke: ON";   action = "WFBE_MenuAction = 6"; };
		class CA_Bipod : CA_HUD { idc = 30026; x = 0.29;  y = 0.135 + 0.486; w = 0.42; text = "Auto Deploy Bipod: ON"; action = "WFBE_MenuAction = 7"; };
		//--- High-climbing default (same var/key/localized labels as the Team-menu control; text set live).
		class CA_HighClimb : CA_HUD { idc = 30027; x = 0.29;  y = 0.135 + 0.533; w = 0.42; text = "High climbing default: OFF"; action = "WFBE_MenuAction = 10"; };

		//--- ===== AUDIO =====
		class CA_AudioHead : RscText_SubTitle {
			idc = 30005;
			x = 0.29; y = 0.135 + 0.592; w = 0.40; h = 0.035;
			text = "AUDIO";
		};
		class CA_Audio : CA_HUD {
			idc = 30030;
			x = 0.29; y = 0.135 + 0.632; w = 0.42;
			text = "Audio Cues: OFF";
			action = "WFBE_MenuAction = 8";
		};

		//--- ===== Footer Close =====
		class CA_Done : RscButton_Main {
			idc = 30040;
			x = 0.29; y = 0.135 + 0.702; w = 0.42; h = 0.045;
			sizeEx = 0.026;
			text = "Close";
			action = "WFBE_MenuAction = 9";
		};
	};
};

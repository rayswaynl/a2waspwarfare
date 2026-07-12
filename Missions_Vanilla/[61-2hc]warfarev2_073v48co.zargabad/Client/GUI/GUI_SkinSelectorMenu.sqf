/*
	GUI_SkinSelectorMenu.sqf
	onLoad handler for the WFBE_SkinSelectorMenu dialog (idd 27000).
	Sets the dialog title text and registers the display reference.
	The controller loop lives in SkinSelector_Open.sqf (spawned via execVM).
*/

disableSerialization;

uiNamespace setVariable ["WFBE_Display_SkinSelector", _this select 0];

ctrlSetText [27008, localize "STR_WF_SkinSelector_Title"];

// Trello #71: Re-entry guard so the commander cannot spam the base-repair action to
// repair faster / double-charge supplies. Mirrors the MHQ wfbe_hq_repairing pattern.
// (repairprocess can't double as the guard: viem.sqf holds it "yes" the whole time the
//  action is offered, so it is never "no" while the action is clickable.)
if (player getVariable ["WASP_BaseRepair_Running", false]) exitWith {};
player setVariable ["WASP_BaseRepair_Running", true, false];
// Remove the menu item so it disappears during the repair (viem.sqf re-adds it next loop).
if ((player getVariable ["WASP_BaseRepair_Action", -1]) >= 0) then {
	player removeAction (player getVariable ["WASP_BaseRepair_Action", -1]);
	player setVariable ["WASP_BaseRepair_Action", -1, false];
};

_color = "#00ff00";
_dam = (1 - getDammage obj)*100;
_dr = 100 - _dam;

sleep 1;
_currentSupply = 0;
_currentSupply = (sideJoined) Call GetSideSupply;
if (_currentSupply > 5) then {
for "_j" from 0 to 1 do 
 {
  sleep 1;
  player playMove "AinvPknlMstpSlayWrflDnon_medic";
  for "_i" from 0 to 6 do 
   {
   
    _dam = (1 - getDammage obj)*100;
	if ( _dam > 67) then {_color = "#00ff00";} else {
    if ( _dam > 37) then {_color = "#ffe400"} else {_color = "#ff0000"}};
    _text = composeText [
    parseText format ["<t size='1'>%1</t><br /><t size='1.2'>%2:</t><t size='1.2' color='%3' align='center'> %4 %5</t>",(baseb select objnum) select 1,localize "RB_state",_color ,str (_dam), "%"]
    ];
    hintSilent _text;
    if (_dam == 100 && _currentSupply == 0) exitWith {repairprocess = "no"; player setVariable ["WASP_BaseRepair_Running", false, false];};
	[sideJoined, -15, "Factory being repaired. (It's normal for this message to show repeatedly.)", false] Call ChangeSideSupply;
    _dam = _dam + (baseb select objnum select 3);
    _dam = 1 - (_dam/100);	
    obj setDamage _dam;
    sleep 1; 
   };
 };}
 else {_text = composeText [parseText format ["<t size='1'>%1</t><br /><t size='1.2'>%2:</t><t size='1.2' color='%3' align='center'> %4 %5</t>",(baseb select _i) select 1,localize "RB_have_no_suppluys_for_rep",_color ,str (_dam), "%"]];
 hint _text;
 player setVariable ["WASP_BaseRepair_Running", false, false];
 };


repairprocess = "no";
// Trello #71: Clear the re-entry guard on the normal fall-through exit.
player setVariable ["WASP_BaseRepair_Running", false, false];

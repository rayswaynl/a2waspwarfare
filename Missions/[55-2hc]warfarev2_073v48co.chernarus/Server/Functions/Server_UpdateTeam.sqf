Private ['_formations','_team'];
_team = _this;

_formations = ['FILE','DIAMOND','STAG COLUMN','WEDGE'];
_team setFormation (_formations select floor (random (count _formations))); //--- uniform 0..n-1 (round halves end weights / can be off-by-one-ish)
_team setBehaviour "AWARE";
_team setSpeedMode "NORMAL";
_team setCombatMode "YELLOW";
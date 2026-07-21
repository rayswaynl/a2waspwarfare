/*
	KA-02: click handler for the standing "reserved" action shown on a LOCKED
	town-defense static (see Client\Init\Init_TownStaticReserved.sqf for how it
	gets attached). Feedback only - never touches lock state.
*/
hintSilent "This weapon is reserved for the AI garrison.";
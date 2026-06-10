/* BulldozeFelled.sqf — client-side PVF handler for engineer bulldozer feedback.
   Shows a group-chat line when a tree is felled, including the running session count
   and supply cost (mirrors the GroupChatMessage style used in BankPayout.sqf).

   Parameters (as received via WFBE_CL_FNC_HandlePVF dispatch):
     0 - session tree count (number) — total trees felled this session by this player
*/
Private ["_count"];

_count = _this select 0;

(Format ["Bulldozer: tree cleared (%1 this session, 10 supply)", _count]) Call GroupChatMessage;

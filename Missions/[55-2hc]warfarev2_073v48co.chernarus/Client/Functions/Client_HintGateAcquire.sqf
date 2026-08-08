/*
	Tutorial hint coordinator - acquire (tutorial-pacing pass, claude-gaming 2026-08-08).

	One shared uiNamespace flag, WFBE_CL_VAR_HintSlotBusy, arbitrates the mission's single
	hint/hintSilent control between the three uncoordinated tutorial systems (Common_Onboarding.sqf,
	Client_JIPCatchupBriefing.sqf, Client_QOL_Advisor.sqf - all spawned within a few lines of each
	other in Init_Client.sqf). A2-OA hint/hintSilent has no queue: any call instantly replaces
	whatever is on screen, mid-dwell. This makes callers WAIT for a free slot instead of firing over
	each other.

	Deliberately NOT wired into Client_TipRotation.sqf (systemChat only, never hint/hintSilent - it
	cannot clobber this surface) or into any player-triggered hint (menus, actions). Those must
	never be delayed and are out of scope by design.

	Usage:
		[] call WFBE_CL_FNC_HintGateAcquire;
		hint _card;
		uiSleep _dwell;
		[] call WFBE_CL_FNC_HintGateRelease;

	Bounded wait (WFBE_C_HINT_GATE_TIMEOUT, default 45s): if a holder errors out mid-sequence
	without releasing, every other tutorial system force-acquires after the bound rather than
	waiting forever - a stuck tutorial script must never permanently silence the others. All current
	dwells are well under this bound in normal operation, so the bound is a safety net, not an
	expected path. Mirrors the same time-elapsed-bounded-wait idiom already used by
	Common_Onboarding.sqf's own alive-player wait.

	A2-OA 1.64 safe: uiSleep real-time polling, missionNamespace/uiNamespace getVariable
	[name,default], numeric-only comparisons. No isEqualType / isEqualTo / A3-only commands.
*/

private ["_timeout","_t0"];

//--- Safety bound on the wait below (seconds); not expected to be hit in normal play.
_timeout = missionNamespace getVariable ["WFBE_C_HINT_GATE_TIMEOUT", 45];

_t0 = time;
waitUntil { uiSleep 1; !(uiNamespace getVariable ["WFBE_CL_VAR_HintSlotBusy", false]) || ((time - _t0) > _timeout) };

uiNamespace setVariable ["WFBE_CL_VAR_HintSlotBusy", true];

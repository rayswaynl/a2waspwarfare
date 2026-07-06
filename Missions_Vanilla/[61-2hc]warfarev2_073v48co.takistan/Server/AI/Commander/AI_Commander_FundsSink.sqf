/*
	AI Commander - FUNDS-SINK worker (SYSTEM 1).
	claude-gaming 2026-06-29. Server-side; called per AI side from a hook in updateresources.sqf
	on the income cadence (~60s). Gated WFBE_C_AICOM_FUNDS_SINK_ENABLE (default 0 -> early-exit, inert).

	WHY: in AI-vs-AI soak both commanders pin at WFBE_C_AICOM_WEALTH_CAP (~1.5M) with nothing to
	buy - units cost FUNDS but the 8-team hard cap (WFBE_C_AICOM_TEAMS_HARD_CAP) blocks more teams,
	and tech/structures cost SUPPLY not funds. So a hoard of money is meaningless and rounds never
	resolve. This worker DRAINS the hoard into OFFENSE without founding extra teams: when funds are
	over WFBE_C_AICOM_FUNDS_SINK_THRESHOLD it (a) arms the wealth-conversion reinforcement flag so the
	Produce worker doubles its per-team batch cap next tick (fuller/heavier EXISTING teams = a heavy
	push wave routed at the spearhead the Allocator already picked), (b) arms the one-shot veteran /
	premium-template founding (cooldown-respected, same lever AI_Commander.sqf P4 uses) so the next
	founding/refill skews to a heavy template, and (c) DEBITS a discounted one-off chunk of the hoard
	so the cap stops being a meaningless ceiling and the side visibly converts money into pressure.

	A2-OA 1.64 SAFE: plain getVariable/setVariable on the side-logic OBJECT and missionNamespace
	(never on a GROUP), scalar compares, no A3-only commands. Does NOT spawn units itself (no FPS
	risk / no antistack touch) - it only flips the existing reinforcement levers + debits funds; the
	Produce/Teams workers do the actual buying on their own cadence within the AI cap.

	Parameter: _this = side.
*/

private ["_side","_logik","_funds","_threshold","_drain","_drainPct","_drainMax"];

_side = _this;
if (isNil "_side") exitWith {};

//--- HARD GATE: dark unless explicitly armed (default 0).
if ((missionNamespace getVariable ["WFBE_C_AICOM_FUNDS_SINK_ENABLE", 0]) <= 0) exitWith {};

//--- Only AI-commanded sides have an AICOM treasury; GUER has none.
if (_side == resistance) exitWith {};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
if (isNull _logik) exitWith {};

//--- Only act while the AI actually holds command (no human commander) - mirrors the
//--- wfbe_aicom_running flag the supervisor maintains. Under a human commander the human
//--- owns the spend, so the sink stays out of the way.
if !(_logik getVariable ["wfbe_aicom_running", false]) exitWith {};

_funds = (_side) Call GetAICommanderFunds;
_threshold = missionNamespace getVariable ["WFBE_C_AICOM_FUNDS_SINK_THRESHOLD", 1000000];

//--- Below the hoard threshold: nothing to drain. Clear the rich flag only if WE set it
//--- (do not stomp the supervisor's own P4 wealth-conversion latch - it re-asserts each tick).
if (_funds <= _threshold) exitWith {};

//--- (a) WEALTH-CONVERSION: arm the reinforcement-rich flag so AI_Commander_Produce doubles its
//--- per-team batch cap on its next cadence -> existing teams refill fuller/faster = a heavy push.
_logik setVariable ["wfbe_aicom_reinforce_rich", true];
_logik setVariable ["wfbe_aicom_econ_surge", true, true]; //--- Keep Teams/AssignTypes surge consumers aligned with the income-cadence FundsSink pulse.

//--- (b) VETERAN / PREMIUM one-shot, cooldown-respected (same lever + cooldown the P4 controller
//--- uses in AI_Commander.sqf) so the hoard skews the NEXT founding/refill toward a heavy template
//--- routed at the spearhead, without spamming the single highest tier every tick.
if (time - (_logik getVariable ["wfbe_aicom_veteran_t0", -1e10]) > (missionNamespace getVariable ["WFBE_C_AICOM_VETERAN_COOLDOWN", 900])) then {
	_logik setVariable ["wfbe_aicom_veteran_next", true];
	_logik setVariable ["wfbe_aicom_veteran_t0", time];
};

//--- (c) DISCOUNTED ONE-OFF DRAIN: debit a fraction of the OVER-THRESHOLD surplus so the cap stops
//--- being a meaningless wall and the money visibly converts to pressure (the doubled batch + veteran
//--- founding above is the OFFENSE the drained funds pay for). Clamped to a per-tick max so it is a
//--- steady bleed, not a one-shot dump. Negative amount = debit (ChangeAICommanderFunds plain-adds).
_drainPct = missionNamespace getVariable ["WFBE_C_AICOM_FUNDS_SINK_DRAIN_PCT", 0.25];
_drainMax = missionNamespace getVariable ["WFBE_C_AICOM_FUNDS_SINK_DRAIN_MAX", 120000];
_drain = round ((_funds - _threshold) * _drainPct);
if (_drain > _drainMax) then {_drain = _drainMax};
if (_drain > 0) then {
	[_side, (-1 * _drain)] Call ChangeAICommanderFunds;
};

//--- ONE-LINE soak confirmation (INFORMATION; always on so a soak RPT proves activation).
["INFORMATION", Format ["AI_Commander_FundsSink.sqf: [%1] FUNDS-SINK fired - funds %2 over threshold %3; armed wealth-conversion + veteran push, drained %4 into offense.", str _side, _funds, _threshold, _drain]] Call WFBE_CO_FNC_LogContent;
diag_log ("AICOM2|v1|FUNDS|" + (str _side) + "|" + str (round (time / 60)) + "|event=FUNDS_SINK|funds=" + str _funds + "|drain=" + str _drain);

/*
	Common_DelaylessCall.sqf
	WFBE_CO_FNC_DelaylessCall

	Zero-scheduler-delay dispatch for hot-path one-shot calls, part of the SQF utility library
	(card #25). `spawn` always queues the new script handle onto the scheduler and does not
	begin executing it until a later scheduler slot - an unwanted extra frame(s) of latency for
	code that must fire-and-forget but start "now". This wraps `execFSM` instead: an FSM's
	first state's `init` code is intended to run in the SAME frame `execFSM` is called (see
	Common\FSM\delayless.fsm), while still giving the dispatched code its own suspendable scope
	like `spawn` (it CAN sleep/waitUntil after its first line without blocking the caller).

	No gameplay consumer in this PR - reusable by future hot-path work (referenced against
	card #1/#12/#14 in this repo's mining-review process). WFBE_C_UTIL_LIB_SELFTEST (default 0)
	arms Common_UtilLibSelfTest.sqf, which MEASURES this dispatch's actual same-frame behavior
	against a plain `spawn` and logs the comparison to RPT rather than assuming it - this
	session could not complete an engine network-verification round on the underlying claim
	(that an FSM's Init state receives execFSM's argument as `_this` and runs it same-frame).
	Run the self-test once on a real server before relying on the same-frame claim in any
	follow-up PR that adopts this on a real hot path.

	Params:
		0: _args  ARRAY, arguments made available to _code as `_this`.
		1: _code  CODE, the code to dispatch.

	Returns: nothing meaningful (the FSM handle itself, discarded by convention - do not rely
	         on a return value; this is fire-and-forget, matching `spawn`'s usage pattern, not
	         `call`).
*/

private ["_args","_code"];

_args = _this select 0;
_code = _this select 1;

[_args, _code] execFSM "Common\FSM\delayless.fsm";

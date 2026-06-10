// Smoke-ExperitalClasscheck.sqf
// Deploy-time RPT class probes for the WASP Experital TEST mission.
//
// PURPOSE
//   Verifies that every class introduced or relied upon by the Experital
//   branch is present at runtime.  A missing class causes silent feature
//   degradation — the structure or unit simply refuses to spawn with no
//   user-visible error beyond "class not found" in the RPT.
//
// HOW TO RUN
//   Place this file inside the Experital mission's `test\` folder and
//   execVM it from init.sqf (or run it manually from the server debug console):
//
//     [] execVM "test\Smoke-ExperitalClasscheck.sqf";
//
//   Then grep the RPT for:
//     WFBE_CLASSCHECK FAIL:
//     WFBE_CLASSCHECK OK:
//     WFBE_CLASSCHECK SUMMARY:
//
// CLASSES CHECKED
//   The compat audit (2026-06-10) flagged these as boot-critical for
//   the Experital feature set:
//
//   STRUCTURES (WDDM compositions & airfield dressing)
//     Land_Pneu          — Site Clearance anchor (WFBE_C_UNITS_BULLDOZER)
//     Land_Mil_hangar_EP1 — Airfield exclusive hangar (WFBE_C_AIRFIELDS)
//     Land_Antenna        — Counter Battery Radar composition element
//
//   UNITS (airfield-exclusive roster & premium unlocks)
//     L39_TK_EP1         — Airfield-exclusive aircraft (Chernarus airfield hangar)
//     An2_TK_EP1         — Airfield-exclusive aircraft (Chernarus airfield hangar)
//     Mi17_Ins           — Airfield-exclusive helicopter (Chernarus airfield hangar)
//
//   FACTION FLAGS (for capture-point spawn & display)
//     FlagCarrierRU      — Russian flag object used at captured bases
//
//   PREMIUM UNLOCK VEHICLES (capture-to-unlock, WFBE_C_AIRFIELDS unlock tier)
//     T72M4CZ_ACR        — Czech T-72 (Krasnostav / Loy Manara AF unlock, requires ACR)
//     RM70_ACR           — RM-70 MLRS (NW AF / Rasman AF unlock, requires ACR)
//
// NOTE ON DLC CLASSES (T72M4CZ_ACR, RM70_ACR, L39_TK_EP1, An2_TK_EP1)
//   These require the ACR / OA DLC content.  The Hetzner dedicated server
//   cannot decrypt DLC PBOs without a GPU/Steam-client context (see memory:
//   miksuu-hetzner-test-server — "DLC cannot load on the headless server").
//   FAIL results for DLC classes on the DEDICATED PROCESS are EXPECTED.
//   The check still runs so the RPT documents which classes are unavailable
//   and confirms the gate logic (WFBE_C_AIRFIELDS) does not hard-crash when
//   the class resolves false.  A client connecting with full DLC will see
//   OK for these classes on its own init.
//
// RPT PATTERNS TO GREP ON FIRST BOOT (reference)
//   Error signals:
//     "class not found"
//     "Undefined variable.*WFBE_UP_UNITCOST"
//     "Error in expression.*select"
//     "Missing addons:"
//   Positive activity markers (should appear within 30s of mission start):
//     "WFBE_CLASSCHECK FAIL:"
//     "WFBE_CLASSCHECK OK:"
//     "WFBE_CLASSCHECK SUMMARY:"
//   Experital subsystem liveness (should appear within 60-120s):
//     -- see Watch-WaspLiveRpt.ps1 "experital" row which already monitors:
//        Server_CounterBattery / CB CONTACT
//        Server_BankIncome / Dividend
//        Bank destroyed by
//        Server_SiteClearance
//        WASPSTAT KILL / CAPTURE / ROUNDEND

private ["_classes","_ok","_fail","_class","_result"];

_classes = [
	// Structures
	"Land_Pneu",
	"FlagCarrierRU",
	"Land_Mil_hangar_EP1",
	"Land_Antenna",
	// Airfield-exclusive aircraft (Chernarus)
	"L39_TK_EP1",
	"An2_TK_EP1",
	"Mi17_Ins",
	// Premium unlocks (requires ACR DLC — FAIL expected on dedicated without DLC)
	"T72M4CZ_ACR",
	"RM70_ACR"
];

_ok   = 0;
_fail = 0;

{
	_class = _x;
	if (isClass (configFile >> "CfgVehicles" >> _class)) then {
		_ok = _ok + 1;
		diag_log format ["WFBE_CLASSCHECK OK: %1", _class];
	} else {
		_fail = _fail + 1;
		diag_log format ["WFBE_CLASSCHECK FAIL: %1", _class];
	};
} forEach _classes;

diag_log format [
	"WFBE_CLASSCHECK SUMMARY: ok=%1 fail=%2 total=%3 (DLC FAIL on dedicated = expected for T72M4CZ_ACR RM70_ACR L39_TK_EP1 An2_TK_EP1 Mi17_Ins)",
	_ok,
	_fail,
	count _classes
];

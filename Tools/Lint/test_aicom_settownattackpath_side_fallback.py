"""Regression coverage for Server_AI_SetTownAttackPath undefined-_side guard.

Post-match RPT (Chernarus, 2026-07-17) logged two unique signatures:
Server_AI_SetTownAttackPath.sqf lines 51-52, "Undefined variable in expression: _side",
immediately after WEST ASSAULT_DISPATCH.

Root cause: a team reaching assault dispatch without a "wfbe_side" group var makes
`_team getVariable "wfbe_side"` return nil; feeding nil to WFBE_CO_FNC_GetSideID returns
nil (switch-on-nil never reaches the numeric default), so `_side` stays undefined and the
first read of it (the PosIsSafe array literal at line 51) throws.

Fix: resolve `_side` in two steps and fall back to the group's engine side when the group
var is missing, so `_side` is always a valid side ID before it reaches GetSideID / PosIsSafe.
This probe deterministically fails on the pre-fix one-liner and passes only when the guard
is present in every mirrored copy (Chernarus source + Takistan + Zargabad).
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ATTACK_PATH_FILES = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_AI_SetTownAttackPath.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_AI_SetTownAttackPath.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Functions/Server_AI_SetTownAttackPath.sqf"),
)

UNSAFE_ONELINER = '_side = (_team getVariable "wfbe_side") Call WFBE_CO_FNC_GetSideID;'
SIDE_LOOKUP = '_side = _team getVariable "wfbe_side";'
NIL_FALLBACK = 'if (isNil "_side") then {_side = side _team};'
SIDE_ID_RESOLVE = '_side = _side Call WFBE_CO_FNC_GetSideID;'


def test_side_has_nil_fallback_before_getsideid() -> None:
    for relative_path in ATTACK_PATH_FILES:
        text = (ROOT / relative_path).read_text(encoding="utf-8")

        # The pre-fix one-liner fed a possibly-nil group var straight into GetSideID.
        assert UNSAFE_ONELINER not in text, f"pre-fix unsafe _side one-liner still present in {relative_path}"

        # The lookup, the nil fallback, and the ID resolve must all be present...
        for needle in (SIDE_LOOKUP, NIL_FALLBACK, SIDE_ID_RESOLVE):
            assert needle in text, f"missing {needle!r} in {relative_path}"

        # ...and the nil fallback must run BEFORE _side is converted to a side ID.
        assert text.index(NIL_FALLBACK) < text.index(SIDE_ID_RESOLVE), (
            f"nil fallback resolved after GetSideID in {relative_path}"
        )

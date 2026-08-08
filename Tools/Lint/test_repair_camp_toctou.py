#!/usr/bin/env python3
"""Regression contract for repair-camp validation at the effect boundary.

RequestSpecial validates a paid player's alive, range, and side state, then
dispatches Server_HandleSpecial in a new scheduled script.  The handler must
re-read those mutable preconditions before it claims the repair latch or
creates the replacement bunker.  Server-internal presence repairs omit the
requester argument and intentionally bypass the player-only checks; a supplied
requester that becomes ``objNull`` must still fail closed.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)

PLAYER_REVALIDATIONS = (
    "if (_repairHasRequester && {isNull _repairRequester}) exitWith {",
    "if (_repairHasRequester && {!isPlayer _repairRequester}) exitWith {",
    "if (_repairHasRequester && {!alive _repairRequester}) exitWith {",
    'if (_repairHasRequester && {(_repairRequester distance _logic) > (missionNamespace getVariable ["WFBE_C_CAMPS_REPAIR_SERVER_RADIUS", 50])}) exitWith {',
    "if (_repairHasRequester && {(side group _repairRequester) != (_repairSideID Call WFBE_CO_FNC_GetSideFromID)}) exitWith {",
)


def _repair_case(mission: Path) -> str:
    source = (
        ROOT / mission / "Server/Functions/Server_HandleSpecial.sqf"
    ).read_text(encoding="utf-8")
    start = source.index('case "repair-camp": {')
    end = source.index('\n\tcase "', start + 1)
    return source[start:end]


def test_player_state_is_revalidated_before_repair_effect() -> None:
    terrain_bytes = []
    for mission in MISSIONS:
        path = ROOT / mission / "Server/Functions/Server_HandleSpecial.sqf"
        terrain_bytes.append(path.read_bytes())
        body = _repair_case(mission)

        requester_presence = body.index(
            "_repairHasRequester = (count _args) > 3;"
        )
        requester_parse = body.index("_repairRequester =")
        latch = body.index(
            '_logic setVariable ["wfbe_camp_repairing", true, true];'
        )
        effect = body.index("createVehicle [")

        for guard in PLAYER_REVALIDATIONS:
            guard_index = body.index(guard)
            assert requester_presence < requester_parse < guard_index < latch < effect, (
                f"{mission}: mutable player guard is not immediately before "
                f"the repair latch/effect: {guard!r}"
            )

        guarded_prefix = body[requester_parse:latch]
        assert guarded_prefix.count("_repairHasRequester") >= len(
            PLAYER_REVALIDATIONS
        ), f"{mission}: three-argument internal presence-repair bypass was not preserved"

    assert terrain_bytes[0] == terrain_bytes[1] == terrain_bytes[2], (
        "CH/TK/ZG Server_HandleSpecial mirrors drifted"
    )


if __name__ == "__main__":
    test_player_state_is_revalidated_before_repair_effect()
    print("repair-camp TOCTOU contract: PASS")

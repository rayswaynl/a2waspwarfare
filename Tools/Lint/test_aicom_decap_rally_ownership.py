"""Contracts that keep DECAP from reclaiming an in-flight rally withdrawal."""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
RELATIVE = "Server/AI/Commander/AI_Commander_Decapitate.sqf"


def _read(mission: str) -> str:
    return mask_comments(
        (ROOT / mission / RELATIVE).read_text(encoding="utf-8-sig")
    )


def test_decap_excludes_rallying_teams_from_sensing_and_stamping() -> None:
    rally_read = '_rallying = _t getVariable "wfbe_aicom_rallying";'
    rally_default = 'if (isNil "_rallying") then {_rallying = false};'
    eligible_guard = (
        '_t != _garTeam && {!_isHolding} && {!_rallying} '
        '&& {!isPlayer (leader _t)}'
    )

    for mission in MISSIONS:
        source = _read(mission)
        assert '"_rallying"' in source[source.index("private [") : source.index("];", source.index("private ["))]
        assert source.count(rally_read) == 2
        assert source.count(rally_default) == 2
        assert source.count(eligible_guard) == 2


def test_decap_never_cancels_the_rally_lifecycle_it_now_respects() -> None:
    for mission in MISSIONS:
        source = _read(mission)
        assert 'setVariable ["wfbe_aicom_rallying"' not in source


def test_decap_rally_ownership_mirrors_are_byte_identical() -> None:
    contents = [(ROOT / mission / RELATIVE).read_bytes() for mission in MISSIONS]
    assert contents[0] == contents[1] == contents[2]

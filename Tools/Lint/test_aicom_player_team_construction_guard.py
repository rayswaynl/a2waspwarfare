"""Regression contract for player-owned AICOM team construction aging."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEAMS_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Teams.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Teams.sqf"),
)


def test_claimed_player_team_counts_as_founded_not_empty_construction() -> None:
    sources = [(ROOT / path).read_text(encoding="utf-8-sig") for path in TEAMS_PATHS]
    reset = r'_grp setVariable \["wfbe_aicom_construction_since", nil\];'

    for path, source in zip(TEAMS_PATHS, sources):
        census_start = source.index("if (_real) then {")
        census_end = source.index("} forEach _teams;", census_start)
        census = source[census_start:census_end]

        claimed_branch = re.search(
            r'if \(_liveCount > 0 \|\| \{!\(isNil \{_grp getVariable "wfbe_uid"\}\)\}\) '
            r"then \{(?P<body>.*?)\} else \{",
            census,
            re.DOTALL,
        )
        assert claimed_branch, f"claimed player teams are not counted as founded in {path}"
        assert re.search(reset, claimed_branch.group("body")), (
            f"live or claimed AICOM teams retain a stale construction age in {path}"
        )
        assert "_foundedTeams = _foundedTeams + 1;" in claimed_branch.group("body")
        construction_read = (
            '_constructionSince = _grp getVariable "wfbe_aicom_construction_since";'
        )
        resets = [match.start() for match in re.finditer(reset, census)]
        assert claimed_branch.end() < census.index(construction_read)
        assert len(resets) == 1, f"construction age reset contract drifted in {path}"

    assert sources[0].encode("utf-8") == sources[1].encode("utf-8") == sources[2].encode("utf-8")

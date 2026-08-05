"""Regression coverage for AICOM founding census count reuse."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEAMS_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Teams.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Teams.sqf"),
)

INIT_COUNTS = "_aicomTeamUnits = 0;\n_aicomHusk = 0;"
REUSE_COUNTS = "_aicomTeamUnits = _aicomTeamUnits + _liveCount;"
HUSK_REUSE = 'if (_liveCount < 4 && {[_grp, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool}) then {_aicomHusk = _aicomHusk + 1};'
SECOND_PASS = "private [\"_c3Live\",\"_c3Real\",\"_c3Hc\"];"


def test_aicom_fieldsplit_reuses_founding_census_counts() -> None:
    for relative_path in TEAMS_PATHS:
        text = (ROOT / relative_path).read_text(encoding="utf-8")

        assert INIT_COUNTS in text, f"count accumulators are not initialized in {relative_path}"
        assert text.count(REUSE_COUNTS) == 1, f"live-body count is not reused exactly once in {relative_path}"
        assert text.count(HUSK_REUSE) == 1, f"HC husk count is not reused exactly once in {relative_path}"
        assert SECOND_PASS not in text, f"duplicate per-team units pass remains in {relative_path}"

        assert text.index(INIT_COUNTS) < text.index(REUSE_COUNTS)
        assert text.index(REUSE_COUNTS) < text.index("_aicomTeams = _foundedTeams;")

"""Regression contracts for failed-plan rally invalidation.

The repository's lint suite has no Arma 2 OA runtime, so this contract checks
the source-level state boundary shared by the server planner and HC executor:
an in-flight rally must not retain or consume an offensive allocator target.
"""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
STRATEGY = Path("Server/AI/Commander/AI_Commander_Strategy.sqf")
ALLOCATE = Path("Server/AI/Commander/AI_Commander_Allocate.sqf")
ASSIGN = Path("Server/AI/Commander/AI_Commander_AssignTowns.sqf")
COMMON = Path("Common/Functions/Common_RunCommanderTeam.sqf")


def _source(relative_path: Path, mission: Path) -> str:
    return (mission / relative_path).read_text(encoding="utf-8-sig")


def test_rally_issue_invalidates_the_prior_allocator_assignment() -> None:
    """A withdrawal must not carry its failed offensive target into regrouping."""
    for mission in MISSIONS:
        source = _source(STRATEGY, mission)
        rally = source[source.index('"rally", _gwRallyPos') - 900 : source.index('"rally", _gwRallyPos') + 700]
        assert '_gwTeam setVariable ["wfbe_aicom_alloc_target", nil]' in rally
        assert '_gwTeam setVariable ["wfbe_aicom_alloc_tick", nil]' in rally


def test_rallying_teams_are_excluded_from_allocator_and_assignment_consumers() -> None:
    """A live rally state must block both writers and readers of offensive tasking."""
    for mission in MISSIONS:
        allocate = _source(ALLOCATE, mission)
        eligibility = allocate[allocate.index("_rallying ="): allocate.index("_ldrPos = getPos _ldr;")]
        assert '"wfbe_aicom_rallying"' in eligibility
        assert "!_rallying" in eligibility

        feint = allocate[allocate.index("//--- D7 AICOM FEINT"): allocate.index("//--- COMMAND CONSOLE (PR backend, claude-gaming 2026-06-28) REINFORCE HOOK")]
        assert '"wfbe_aicom_rallying"' in feint
        assert "!_feintRallying" in feint

        reinforce = allocate[allocate.index("//--- COMMAND CONSOLE (PR backend, claude-gaming 2026-06-28) REINFORCE HOOK"):]
        assert '"wfbe_aicom_rallying"' in reinforce
        assert "!_riRallying" in reinforce

        assign = _source(ASSIGN, mission)
        assert '"wfbe_aicom_rallying"' in assign
        assert "if (_rallying) then {_explicitMode = true};" in assign


def test_rally_arrival_clears_any_residual_allocator_assignment() -> None:
    """Arrival must not re-use a stamp written by a competing or late producer."""
    for mission in MISSIONS:
        source = _source(COMMON, mission)
        arrival = source[source.index("if (_rallying) then {"): source.index("} else {", source.index("if (_rallying) then {"))]
        target_clear = arrival.index('"wfbe_aicom_alloc_target", objNull')
        tick_clear = arrival.index('"wfbe_aicom_alloc_tick", -1')
        mode_reset = arrival.index('"wfbe_teammode", "towns"')
        assert target_clear < mode_reset
        assert tick_clear < mode_reset


def test_all_rally_invalidation_sources_match_chernarus() -> None:
    """Generated mission mirrors must carry the same dependency contract."""
    for relative_path in (STRATEGY, ALLOCATE, ASSIGN, COMMON):
        expected = sha256(_source(relative_path, MISSIONS[0]).encode("utf-8")).hexdigest()
        for mission in MISSIONS[1:]:
            actual = sha256(_source(relative_path, mission).encode("utf-8")).hexdigest()
            assert actual == expected, f"{relative_path} drifted in {mission.name}"

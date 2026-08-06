"""Regression coverage for AICOM arrival-band reissue accounting."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COMMANDER_PATHS = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
        "Server/AI/Commander/AI_Commander.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
        "Server/AI/Commander/AI_Commander.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/"
        "Server/AI/Commander/AI_Commander.sqf"
    ),
)
ASSIGN_PATHS = tuple(path.parent / "AI_Commander_AssignTowns.sqf" for path in COMMANDER_PATHS)

REISSUE_BUMP = (
    '_logik setVariable ["wfbe_aicom_arrival_reissue", '
    '(_logik getVariable ["wfbe_aicom_arrival_reissue", 0]) + 1]'
)
REISSUE_READ = '_arrReissue = _logik getVariable ["wfbe_aicom_arrival_reissue", 0];'
REISSUE_RESET = '_logik setVariable ["wfbe_aicom_arrival_reissue", 0];'


def test_arrival_bands_emits_and_resets_same_target_reissues() -> None:
    for relative_path in COMMANDER_PATHS:
        text = (ROOT / relative_path).read_text(encoding="utf-8")

        assert REISSUE_READ in text, f"reissue counter is not read in {relative_path}"
        assert '|reissue=" + str _arrReissue + "|stranded=' in text
        assert text.count(REISSUE_RESET) == 1, f"reissue counter is not reset exactly once in {relative_path}"
        assert text.index(REISSUE_READ) < text.index("ARRIVAL_BANDS")
        assert text.index("ARRIVAL_BANDS") < text.index(REISSUE_RESET)


def test_assign_towns_books_reissues_separately_from_dispatches() -> None:
    for relative_path in ASSIGN_PATHS:
        text = (ROOT / relative_path).read_text(encoding="utf-8")

        assert text.count(REISSUE_BUMP) == 1, f"reissue counter is not bumped exactly once in {relative_path}"
        reissue_gate = "if (_priorOpen && {_sameTgt}) then {"
        retarget_gate = "if (_priorOpen && {!_sameTgt} && {count _priorOrd >= 1}"
        assert reissue_gate in text
        assert retarget_gate in text
        reissue_gate_index = text.index(reissue_gate)
        reissue_bump_index = text.index(REISSUE_BUMP)
        retarget_gate_index = text.index(retarget_gate)
        dispatch_index = text.index('"wfbe_aicom_arrival_dispatched"')
        assert text.count(reissue_gate) == 1
        assert reissue_gate_index < reissue_bump_index < retarget_gate_index
        assert reissue_bump_index < dispatch_index

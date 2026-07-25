"""Regression coverage for AICOM capture-holds under hostile contact."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ASSIGN_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_AssignTowns.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_AssignTowns.sqf"),
)


def test_active_capture_hold_survives_its_initial_timer() -> None:
    """A holder must not be retasked while its captured town remains under attack."""
    for relative_path in ASSIGN_PATHS:
        text = (ROOT / relative_path).read_text(encoding="utf-8")

        assert '"_htUntil","_htEnemyDist","_htUnderAttack"' in text
        assert "_htUnderAttack = false;" in text
        assert (
            'if ((_ht getVariable ["wfbe_active", false]) && '
            '{({alive _x && {(side _x) != _side && {(side _x) != civilian}}} '
            'count ((getPos _ht) nearEntities [["Man","LandVehicle","Air"], _htEnemyDist])) > 0}) '
            'then {_htUnderAttack = true};' in text
        )
        assert 'if (_htSide == _sideID && {(time < _htUntil) || {_htUnderAttack}}) then {_htLive = true};' in text

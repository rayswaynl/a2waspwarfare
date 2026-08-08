"""Contract for the planner's enemy-information boundary.

The live snapshot must not turn the enemy side's private team registry into
perfect enemy-strength intelligence.  Until a real contact/intel feed exists,
the effective enemy estimate is the public held-town credit already present in
the snapshot.  The manual Strategy fallback must obey the same boundary.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def _read(mission: str, rel: str) -> str:
    return (ROOT / mission / rel).read_text(encoding="utf-8-sig")


def _snapshot_enemy_strength_block(source: str) -> str:
    start = source.index("//--- MANEUVER STRENGTH")
    end = source.index("//--- EFFECTIVE STRENGTH", start)
    return source[start:end]


def _strategy_manual_strength_block(source: str) -> str:
    start = source.index("if (!_snapOk) then {")
    end = source.index("//--- 0) LAST-STAND", start)
    return source[start:end]


def test_snapshot_does_not_read_enemy_team_registry_for_strength() -> None:
    for mission in MISSIONS:
        snapshot = _read(
            mission, "Server/AI/Commander/AI_Commander_Snapshot.sqf"
        )
        block = _snapshot_enemy_strength_block(snapshot)

        assert "_enStr = 0;" in block
        assert "_enemyLogik" not in block
        assert "forEach (_enemyLogik getVariable" not in block


def test_manual_strategy_fallback_keeps_enemy_strength_public_only() -> None:
    for mission in MISSIONS:
        strategy = _read(
            mission, "Server/AI/Commander/AI_Commander_Strategy.sqf"
        )
        block = _strategy_manual_strength_block(strategy)

        assert "_enStr = 0;" in block
        assert "_enemyLogik" not in block
        assert "forEach (_enemyLogik getVariable" not in block


def test_strength_snapshot_and_strategy_mirrors_are_byte_identical() -> None:
    for rel in (
        "Server/AI/Commander/AI_Commander_Snapshot.sqf",
        "Server/AI/Commander/AI_Commander_Strategy.sqf",
    ):
        paths = [ROOT / mission / rel for mission in MISSIONS]
        contents = [path.read_bytes() for path in paths]
        assert contents[0] == contents[1] == contents[2]
